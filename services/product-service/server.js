const express = require("express");
const cors = require("cors");
const mysql = require("mysql2/promise");
const redis = require("redis");
const client = require("prom-client");
const app = express();
const PORT = process.env.PORT || 3000;
app.use(cors()); app.use(express.json()); client.collectDefaultMetrics();
const requests = new client.Counter({ name: "product_service_http_requests_total", help: "Total HTTP requests", labelNames: ["method", "path", "status"] });
app.use((req, res, next) => { res.on("finish", () => requests.inc({ method: req.method, path: req.path, status: String(res.statusCode) })); next(); });
const pool = mysql.createPool({ host: process.env.MYSQL_HOST || "mysql", user: process.env.MYSQL_USER || "root", password: process.env.MYSQL_PASSWORD || "root123", database: "product_db", waitForConnections: true, connectionLimit: 10 });
const redisClient = redis.createClient({ url: `redis://${process.env.REDIS_HOST || "redis"}:6379` });
redisClient.on("error", err => console.log("Redis error:", err.message));
redisClient.connect().catch(err => console.log("Redis connect failed:", err.message));
app.get("/health", (req, res) => res.json({ service: "product-service", status: "ok" }));
app.get("/ready", async (req, res) => { try { await pool.query("SELECT 1"); res.json({ ready: true }); } catch (e) { res.status(500).json({ ready: false, error: e.message }); } });
app.get("/metrics", async (req, res) => { res.set("Content-Type", client.register.contentType); res.end(await client.register.metrics()); });
app.get("/products", async (req, res) => {
  try { if (redisClient.isOpen) { const cached = await redisClient.get("products:list"); if (cached) return res.json(JSON.parse(cached)); }
    const [rows] = await pool.execute("SELECT * FROM products ORDER BY id DESC");
    if (redisClient.isOpen) await redisClient.set("products:list", JSON.stringify(rows), { EX: 60 });
    res.json(rows);
  } catch (e) { res.status(500).json({ error: "failed to fetch products", detail: e.message }); }
});
app.get("/products/:id", async (req, res) => { const [rows] = await pool.execute("SELECT * FROM products WHERE id = ?", [req.params.id]); if (rows.length === 0) return res.status(404).json({ error: "product not found" }); res.json(rows[0]); });
app.post("/products", async (req, res) => {
  try { const { name, description, category, price, image_url } = req.body;
    if (!name || !price) return res.status(400).json({ error: "name and price are required" });
    const [result] = await pool.execute("INSERT INTO products (name, description, category, price, image_url) VALUES (?, ?, ?, ?, ?)", [name, description || "", category || "Electronics", price, image_url || "https://dummyimage.com/700x450/e8f0fe/111827&text=Product"]);
    if (redisClient.isOpen) await redisClient.del("products:list");
    res.status(201).json({ id: result.insertId, name, description, category: category || "Electronics", price, image_url });
  } catch (e) { res.status(500).json({ error: "failed to create product", detail: e.message }); }
});
app.listen(PORT, () => console.log(`product-service running on ${PORT}`));
