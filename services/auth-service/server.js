const express = require("express");
const cors = require("cors");
const mysql = require("mysql2/promise");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const client = require("prom-client");

const app = express();
const PORT = process.env.PORT || 3000;
const JWT_SECRET = process.env.JWT_SECRET || "dev-secret";
app.use(cors());
app.use(express.json());
client.collectDefaultMetrics();

const requests = new client.Counter({ name: "auth_service_http_requests_total", help: "Total HTTP requests", labelNames: ["method", "path", "status"] });
app.use((req, res, next) => { res.on("finish", () => requests.inc({ method: req.method, path: req.path, status: String(res.statusCode) })); next(); });

const pool = mysql.createPool({ host: process.env.MYSQL_HOST || "mysql", user: process.env.MYSQL_USER || "root", password: process.env.MYSQL_PASSWORD || "root123", database: "auth_db", waitForConnections: true, connectionLimit: 10 });

app.get("/health", (req, res) => res.json({ service: "auth-service", status: "ok" }));
app.get("/ready", async (req, res) => { try { await pool.query("SELECT 1"); res.json({ ready: true }); } catch (e) { res.status(500).json({ ready: false, error: e.message }); } });
app.get("/metrics", async (req, res) => { res.set("Content-Type", client.register.contentType); res.end(await client.register.metrics()); });

app.post("/auth/register", async (req, res) => {
  try {
    const { name, email, password } = req.body;
    if (!name || !email || !password) return res.status(400).json({ error: "name, email and password are required" });
    const [existing] = await pool.execute("SELECT id FROM users WHERE email = ?", [email]);
    if (existing.length > 0) return res.status(409).json({ error: "email already registered, please login" });
    const hash = await bcrypt.hash(password, 10);
    const [result] = await pool.execute("INSERT INTO users (name, email, password_hash, role) VALUES (?, ?, ?, ?)", [name, email, hash, "USER"]);
    const user = { id: result.insertId, name, email, role: "USER" };
    const token = jwt.sign(user, JWT_SECRET, { expiresIn: "8h" });
    res.status(201).json({ token, user });
  } catch (e) { res.status(500).json({ error: "registration failed", detail: e.message }); }
});

app.post("/auth/login", async (req, res) => {
  try {
    const { email, password } = req.body;
    const [rows] = await pool.execute("SELECT * FROM users WHERE email = ?", [email]);
    if (rows.length === 0) return res.status(401).json({ error: "invalid credentials" });
    const userRow = rows[0];
    const valid = await bcrypt.compare(password, userRow.password_hash);
    if (!valid) return res.status(401).json({ error: "invalid credentials" });
    const user = { id: userRow.id, name: userRow.name, email: userRow.email, role: userRow.role };
    const token = jwt.sign(user, JWT_SECRET, { expiresIn: "8h" });
    res.json({ token, user });
  } catch (e) { res.status(500).json({ error: "login failed", detail: e.message }); }
});

app.get("/auth/validate", (req, res) => {
  try { const token = (req.headers.authorization || "").replace("Bearer ", ""); res.json({ valid: true, user: jwt.verify(token, JWT_SECRET) }); }
  catch { res.status(401).json({ valid: false }); }
});

app.listen(PORT, () => console.log(`auth-service running on ${PORT}`));
