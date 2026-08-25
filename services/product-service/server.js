const express = require('express');
const mysql = require('mysql2/promise');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());
const PORT = process.env.PORT || 4003;

const pool = mysql.createPool({
  host: process.env.DB_HOST || 'mysql',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || 'rootpass',
  database: 'product_db',
  waitForConnections: true,
  connectionLimit: 5
});

app.get('/health', (req, res) => res.json({ status: 'ok', service: 'product-service' }));

app.get('/products', async (req, res) => {
  const { category, search } = req.query;
  let sql = 'SELECT * FROM products WHERE 1=1';
  const params = [];
  if (category) { sql += ' AND category = ?'; params.push(category); }
  if (search) { sql += ' AND name LIKE ?'; params.push(`%${search}%`); }
  const [rows] = await pool.query(sql, params);
  res.json(rows);
});

app.get('/products/:id', async (req, res) => {
  const [rows] = await pool.query('SELECT * FROM products WHERE id = ?', [req.params.id]);
  if (!rows.length) return res.status(404).json({ error: 'not found' });
  res.json(rows[0]);
});

app.post('/products', async (req, res) => {
  const { name, description, category, price, image_url } = req.body;
  const [result] = await pool.query(
    'INSERT INTO products (name, description, category, price, image_url) VALUES (?, ?, ?, ?, ?)',
    [name, description, category, price, image_url]
  );
  res.status(201).json({ id: result.insertId });
});

app.get('/categories', async (req, res) => {
  const [rows] = await pool.query('SELECT * FROM categories');
  res.json(rows);
});

app.listen(PORT, () => console.log(`product-service listening on ${PORT}`));
