const express = require('express');
const mysql = require('mysql2/promise');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 4001;
const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret-change-me';

const pool = mysql.createPool({
  host: process.env.DB_HOST || 'mysql',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || 'rootpass',
  database: 'auth_db',
  waitForConnections: true,
  connectionLimit: 5
});

app.get('/health', (req, res) => res.json({ status: 'ok', service: 'auth-service' }));

app.post('/register', async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) return res.status(400).json({ error: 'email and password required' });
    const hash = await bcrypt.hash(password, 10);
    const [result] = await pool.query(
      'INSERT INTO users (email, password_hash) VALUES (?, ?)', [email, hash]
    );
    res.status(201).json({ id: result.insertId, email });
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') return res.status(409).json({ error: 'email already registered' });
    res.status(500).json({ error: 'internal error', detail: err.message });
  }
});

app.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    const [rows] = await pool.query('SELECT * FROM users WHERE email = ?', [email]);
    if (!rows.length) return res.status(401).json({ error: 'invalid credentials' });
    const user = rows[0];
    const ok = await bcrypt.compare(password, user.password_hash);
    if (!ok) return res.status(401).json({ error: 'invalid credentials' });
    const token = jwt.sign({ id: user.id, email: user.email, role: user.role }, JWT_SECRET, { expiresIn: '2h' });
    res.json({ token, user: { id: user.id, email: user.email, role: user.role } });
  } catch (err) {
    res.status(500).json({ error: 'internal error', detail: err.message });
  }
});

app.get('/verify', (req, res) => {
  const token = (req.headers.authorization || '').replace('Bearer ', '');
  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    res.json({ valid: true, decoded });
  } catch {
    res.status(401).json({ valid: false });
  }
});

app.listen(PORT, () => console.log(`auth-service listening on ${PORT}`));
