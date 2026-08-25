const express = require('express');
const mysql = require('mysql2/promise');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());
const PORT = process.env.PORT || 4009;

const pool = mysql.createPool({
  host: process.env.DB_HOST || 'mysql',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || 'rootpass',
  database: 'review_db',
  waitForConnections: true,
  connectionLimit: 5
});

app.get('/health', (req, res) => res.json({ status: 'ok', service: 'review-service' }));

app.get('/reviews/product/:productId', async (req, res) => {
  const [rows] = await pool.query('SELECT * FROM reviews WHERE product_id = ? ORDER BY created_at DESC', [req.params.productId]);
  res.json(rows);
});

app.post('/reviews', async (req, res) => {
  const { product_id, user_id, rating, comment } = req.body;
  if (rating < 1 || rating > 5) return res.status(400).json({ error: 'rating must be 1-5' });
  const [result] = await pool.query(
    'INSERT INTO reviews (product_id, user_id, rating, comment) VALUES (?, ?, ?, ?)',
    [product_id, user_id, rating, comment]
  );
  res.status(201).json({ id: result.insertId });
});

app.listen(PORT, () => console.log(`review-service listening on ${PORT}`));
