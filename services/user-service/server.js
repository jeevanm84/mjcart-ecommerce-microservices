const express = require('express');
const mysql = require('mysql2/promise');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());
const PORT = process.env.PORT || 4002;

const pool = mysql.createPool({
  host: process.env.DB_HOST || 'mysql',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || 'rootpass',
  database: 'user_db',
  waitForConnections: true,
  connectionLimit: 5
});

app.get('/health', (req, res) => res.json({ status: 'ok', service: 'user-service' }));

app.post('/profiles', async (req, res) => {
  const { user_id, name, phone, address } = req.body;
  const [result] = await pool.query(
    'INSERT INTO profiles (user_id, name, phone, address) VALUES (?, ?, ?, ?)',
    [user_id, name, phone, address]
  );
  res.status(201).json({ id: result.insertId });
});

app.get('/profiles/:userId', async (req, res) => {
  const [rows] = await pool.query('SELECT * FROM profiles WHERE user_id = ?', [req.params.userId]);
  if (!rows.length) return res.status(404).json({ error: 'not found' });
  res.json(rows[0]);
});

app.put('/profiles/:userId', async (req, res) => {
  const { name, phone, address } = req.body;
  await pool.query(
    'UPDATE profiles SET name=?, phone=?, address=? WHERE user_id=?',
    [name, phone, address, req.params.userId]
  );
  res.json({ updated: true });
});

app.listen(PORT, () => console.log(`user-service listening on ${PORT}`));
