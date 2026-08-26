const express = require("express");
const cors = require("cors");
const mysql = require("mysql2/promise");
const axios = require("axios");
const client = require("prom-client");
const app = express(); const PORT = process.env.PORT || 3000;
const INVENTORY_URL = process.env.INVENTORY_URL || "http://inventory-service";
const SHIPPING_URL = process.env.SHIPPING_URL || "http://shipping-service";
const NOTIFICATION_URL = process.env.NOTIFICATION_URL || "http://notification-service";
app.use(cors()); app.use(express.json()); client.collectDefaultMetrics();
const requests = new client.Counter({ name: "order_service_http_requests_total", help: "Total HTTP requests", labelNames: ["method", "path", "status"] });
const ordersCreated = new client.Counter({ name: "order_service_orders_created_total", help: "Total orders created" });
app.use((req, res, next) => { res.on("finish", () => requests.inc({ method: req.method, path: req.path, status: String(res.statusCode) })); next(); });
const pool = mysql.createPool({ host: process.env.MYSQL_HOST || "mysql", user: process.env.MYSQL_USER || "root", password: process.env.MYSQL_PASSWORD || "root123", database: "order_db", waitForConnections: true, connectionLimit: 10 });
app.get("/health", (req, res) => res.json({ service: "order-service", status: "ok" }));
app.get("/ready", async (req, res) => { try { await pool.query("SELECT 1"); res.json({ ready: true }); } catch (e) { res.status(500).json({ ready: false, error: e.message }); } });
app.get("/metrics", async (req, res) => { res.set("Content-Type", client.register.contentType); res.end(await client.register.metrics()); });
// No payment gateway on this platform - checkout is Cash-on-Delivery (COD) only.
// Flow: reserve stock -> create order (status PLACED, payment_method COD) -> create shipment -> notify.
app.post("/orders", async (req, res) => {
  const { userId, items } = req.body;
  if (!userId || !items || items.length === 0) return res.status(400).json({ error: "userId and items are required" });
  const total = items.reduce((sum, item) => sum + Number(item.price) * Number(item.quantity), 0);
  try {
    for (const item of items) await axios.post(`${INVENTORY_URL}/inventory/reserve`, { productId: item.productId, quantity: item.quantity });
    const [orderResult] = await pool.execute("INSERT INTO orders (user_id, total_amount, payment_method, status) VALUES (?, ?, ?, ?)", [userId, total, "COD", "PLACED"]);
    const orderId = orderResult.insertId;
    for (const item of items) await pool.execute("INSERT INTO order_items (order_id, product_id, name, price, quantity) VALUES (?, ?, ?, ?, ?)", [orderId, item.productId, item.name, item.price, item.quantity]);
    const shipping = (await axios.post(`${SHIPPING_URL}/shipping/create`, { orderId })).data;
    await axios.post(`${NOTIFICATION_URL}/notifications/send`, { userId, type: "ORDER_PLACED", message: `Order ${orderId} placed successfully (Cash on Delivery)` });
    ordersCreated.inc();
    return res.status(201).json({ orderId, total, paymentMethod: "COD", status: "PLACED", shipping });
  } catch (e) { res.status(500).json({ error: "order failed", detail: e.response?.data || e.message }); }
});
app.get("/orders/:userId", async (req, res) => { const [rows] = await pool.execute("SELECT * FROM orders WHERE user_id = ? ORDER BY id DESC", [req.params.userId]); res.json(rows); });
app.get("/orders/detail/:orderId", async (req, res) => { const [orders] = await pool.execute("SELECT * FROM orders WHERE id = ?", [req.params.orderId]); const [items] = await pool.execute("SELECT * FROM order_items WHERE order_id = ?", [req.params.orderId]); res.json({ order: orders[0], items }); });
app.listen(PORT, () => console.log(`order-service running on ${PORT}`));
