const express = require('express');
const mysql = require('mysql2/promise');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());
const PORT = process.env.PORT || 4004;

const pool = mysql.createPool({
  host: process.env.DB_HOST || 'mysql',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || 'rootpass',
  database: 'inventory_db',
  waitForConnections: true,
  connectionLimit: 5
});

app.get('/health', (req, res) => res.json({ status: 'ok', service: 'inventory-service' }));

app.get('/stock/:productId', async (req, res) => {
  const [rows] = await pool.query('SELECT * FROM stock WHERE product_id = ?', [req.params.productId]);
  if (!rows.length) return res.status(404).json({ error: 'not found' });
  res.json(rows[0]);
});

// Used internally by order-service to check + reserve stock at checkout time
app.post('/stock/:productId/reserve', async (req, res) => {
  const { quantity } = req.body;
  const [rows] = await pool.query('SELECT quantity FROM stock WHERE product_id = ?', [req.params.productId]);
  if (!rows.length || rows[0].quantity < quantity) {
    return res.status(409).json({ error: 'insufficient stock' });
  }
  await pool.query('UPDATE stock SET quantity = quantity - ? WHERE product_id = ?', [quantity, req.params.productId]);
  res.json({ reserved: quantity });
});

app.put('/stock/:productId', async (req, res) => {
  const { quantity } = req.body;
  await pool.query(
    'INSERT INTO stock (product_id, quantity) VALUES (?, ?) ON DUPLICATE KEY UPDATE quantity = ?',
    [req.params.productId, quantity, quantity]
  );
  res.json({ updated: true });
});

app.listen(PORT, () => console.log(`inventory-service listening on ${PORT}`));
