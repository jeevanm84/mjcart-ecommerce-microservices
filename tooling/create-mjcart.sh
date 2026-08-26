#!/bin/bash
set -euo pipefail

PROJECT="${PROJECT:-mjcart-ecommerce-microservices}"
DOCKER_USER="${DOCKER_USER:-jeevanm84}"
IMAGE_TAG="${IMAGE_TAG:-v1}"
NAMESPACE="${NAMESPACE:-mjcart}"
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-ChangeMe_RootPass123}"
JWT_SECRET="${JWT_SECRET:-mjcart-jwt-secret-change-me}"

rm -rf "$PROJECT"
mkdir -p "$PROJECT"
cd "$PROJECT"

mkdir -p services frontend/src database k8s scripts

SERVICES=(
  api-gateway
  auth-service
  user-service
  product-service
  inventory-service
  cart-service
  order-service
  shipping-service
  notification-service
  review-service
)
# NOTE: intentionally no payment-service - this platform has no payment
# gateway. Checkout is Cash-on-Delivery (COD) only.

for svc in "${SERVICES[@]}"; do
  mkdir -p "services/$svc"
done

cat > database/init.sql <<'SQL'
CREATE DATABASE IF NOT EXISTS auth_db;
CREATE DATABASE IF NOT EXISTS user_db;
CREATE DATABASE IF NOT EXISTS product_db;
CREATE DATABASE IF NOT EXISTS inventory_db;
CREATE DATABASE IF NOT EXISTS order_db;
CREATE DATABASE IF NOT EXISTS shipping_db;
CREATE DATABASE IF NOT EXISTS notification_db;
CREATE DATABASE IF NOT EXISTS review_db;

USE auth_db;
CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  email VARCHAR(150) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  role VARCHAR(30) DEFAULT 'USER',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

USE user_db;
CREATE TABLE IF NOT EXISTS user_profiles (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL UNIQUE,
  name VARCHAR(100),
  phone VARCHAR(50),
  address VARCHAR(255),
  city VARCHAR(100),
  country VARCHAR(100),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

USE product_db;
CREATE TABLE IF NOT EXISTS products (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(150) NOT NULL,
  description TEXT,
  category VARCHAR(50) DEFAULT 'Electronics',
  price DECIMAL(10,2) NOT NULL,
  image_url VARCHAR(500),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO products (id, name, description, category, price, image_url) VALUES
(1, 'Laptop Pro 15', 'High performance laptop for developers', 'Laptops', 89999.00, 'https://images.unsplash.com/photo-1496181133206-80ce9b88a853?auto=format&fit=crop&w=700&q=80'),
(2, 'Wireless Mouse', 'Ergonomic wireless mouse', 'Accessories', 1499.00, 'https://images.unsplash.com/photo-1527814050087-3793815479db?auto=format&fit=crop&w=700&q=80'),
(3, 'Mechanical Keyboard', 'RGB mechanical keyboard', 'Accessories', 3999.00, 'https://images.unsplash.com/photo-1587829741301-dc798b83add3?auto=format&fit=crop&w=700&q=80'),
(4, 'Noise Cancelling Headphones', 'Premium Bluetooth headphones', 'Accessories', 6999.00, 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?auto=format&fit=crop&w=700&q=80'),
(5, 'iPhone 15 Pro', 'Premium Apple smartphone with powerful camera', 'Mobiles', 129999.00, 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?auto=format&fit=crop&w=700&q=80'),
(6, 'Samsung Galaxy S24', 'Flagship Android smartphone with AI features', 'Mobiles', 89999.00, 'https://images.unsplash.com/photo-1610945265064-0e34e5519bbf?auto=format&fit=crop&w=700&q=80'),
(7, 'Dell XPS Developer Laptop', 'Premium developer laptop for DevOps engineers', 'Laptops', 119999.00, 'https://images.unsplash.com/photo-1593642702749-b7d2a804fbcf?auto=format&fit=crop&w=700&q=80'),
(8, 'Smart TV 55 Inch', '4K Ultra HD smart television', 'Electronics', 45999.00, 'https://images.unsplash.com/photo-1593359677879-a4bb92f829d1?auto=format&fit=crop&w=700&q=80'),
(9, 'Bluetooth Speaker', 'Portable wireless Bluetooth speaker', 'Electronics', 2999.00, 'https://images.unsplash.com/photo-1608043152269-423dbba4e7e1?auto=format&fit=crop&w=700&q=80'),
(10, 'USB-C Fast Charger', 'Fast charging adapter for mobiles and laptops', 'Accessories', 999.00, 'https://images.unsplash.com/photo-1583394838336-acd977736f90?auto=format&fit=crop&w=700&q=80')
ON DUPLICATE KEY UPDATE
  name=VALUES(name),
  description=VALUES(description),
  category=VALUES(category),
  price=VALUES(price),
  image_url=VALUES(image_url);

USE inventory_db;
CREATE TABLE IF NOT EXISTS inventory (
  id INT AUTO_INCREMENT PRIMARY KEY,
  product_id INT NOT NULL UNIQUE,
  quantity INT NOT NULL DEFAULT 0,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

INSERT INTO inventory (product_id, quantity) VALUES
(1, 20),(2, 100),(3, 50),(4, 35),(5, 25),
(6, 30),(7, 15),(8, 12),(9, 60),(10, 80)
ON DUPLICATE KEY UPDATE quantity=VALUES(quantity);

USE order_db;
-- No payment gateway on this platform: every order is Cash-on-Delivery (COD).
CREATE TABLE IF NOT EXISTS orders (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  total_amount DECIMAL(10,2) NOT NULL,
  payment_method VARCHAR(20) DEFAULT 'COD',
  status VARCHAR(50) DEFAULT 'PLACED',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS order_items (
  id INT AUTO_INCREMENT PRIMARY KEY,
  order_id INT NOT NULL,
  product_id INT NOT NULL,
  name VARCHAR(150),
  price DECIMAL(10,2),
  quantity INT NOT NULL
);

USE shipping_db;
CREATE TABLE IF NOT EXISTS shipments (
  id INT AUTO_INCREMENT PRIMARY KEY,
  order_id INT NOT NULL UNIQUE,
  status VARCHAR(50) DEFAULT 'CREATED',
  tracking_number VARCHAR(100),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

USE notification_db;
CREATE TABLE IF NOT EXISTS notifications (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT,
  type VARCHAR(100),
  message TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

USE review_db;
CREATE TABLE IF NOT EXISTS reviews (
  id INT AUTO_INCREMENT PRIMARY KEY,
  product_id INT NOT NULL,
  user_id INT NOT NULL,
  rating INT NOT NULL,
  comment TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
SQL

for svc in "${SERVICES[@]}"; do
cat > "services/$svc/Dockerfile" <<'DOCKER'
FROM node:20-alpine
WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev
COPY --chown=node:node . .
USER node
EXPOSE 3000
CMD ["node", "server.js"]
DOCKER

cat > "services/$svc/package.json" <<'PKG'
{
  "name": "mjcart-service",
  "version": "1.0.0",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "axios": "^1.7.9",
    "bcryptjs": "^2.4.3",
    "cors": "^2.8.5",
    "express": "^4.21.2",
    "http-proxy-middleware": "^3.0.3",
    "jsonwebtoken": "^9.0.2",
    "mysql2": "^3.11.5",
    "prom-client": "^15.1.3",
    "redis": "^4.7.0"
  }
}
PKG
done

cat > services/api-gateway/server.js <<'JS'
const express = require("express");
const cors = require("cors");
const { createProxyMiddleware } = require("http-proxy-middleware");
const client = require("prom-client");

const app = express();
const PORT = process.env.PORT || 3000;
app.use(cors());
client.collectDefaultMetrics();

const requests = new client.Counter({
  name: "api_gateway_http_requests_total",
  help: "Total HTTP requests handled by API Gateway",
  labelNames: ["method", "path", "status"]
});

app.use((req, res, next) => {
  res.on("finish", () => requests.inc({ method: req.method, path: req.path, status: String(res.statusCode) }));
  next();
});

app.get("/health", (req, res) => res.json({ service: "api-gateway", status: "ok" }));
app.get("/ready", (req, res) => res.json({ service: "api-gateway", ready: true }));
app.get("/metrics", async (req, res) => {
  res.set("Content-Type", client.register.contentType);
  res.end(await client.register.metrics());
});

function routeProxy(publicPrefix, internalPrefix, target) {
  app.use(publicPrefix, createProxyMiddleware({
    target,
    changeOrigin: true,
    pathRewrite: (path, req) => req.originalUrl.replace(publicPrefix, internalPrefix),
    on: {
      proxyReq: (proxyReq, req) => console.log(`Proxying ${req.method} ${req.originalUrl} -> ${target}${req.originalUrl.replace(publicPrefix, internalPrefix)}`),
      error: (err, req, res) => {
        console.error("Proxy error:", err.message);
        if (!res.headersSent) {
          res.statusCode = 502;
          res.setHeader("Content-Type", "application/json");
        }
        res.end(JSON.stringify({ error: "Service unavailable", detail: err.message }));
      }
    }
  }));
}

routeProxy("/api/auth", "/auth", process.env.AUTH_URL || "http://auth-service");
routeProxy("/api/users", "/users", process.env.USER_URL || "http://user-service");
routeProxy("/api/products", "/products", process.env.PRODUCT_URL || "http://product-service");
routeProxy("/api/inventory", "/inventory", process.env.INVENTORY_URL || "http://inventory-service");
routeProxy("/api/cart", "/cart", process.env.CART_URL || "http://cart-service");
routeProxy("/api/orders", "/orders", process.env.ORDER_URL || "http://order-service");
// No /api/payments route - this platform has no payment gateway (COD only).
routeProxy("/api/shipping", "/shipping", process.env.SHIPPING_URL || "http://shipping-service");
routeProxy("/api/notifications", "/notifications", process.env.NOTIFICATION_URL || "http://notification-service");
routeProxy("/api/reviews", "/reviews", process.env.REVIEW_URL || "http://review-service");

app.listen(PORT, () => console.log(`api-gateway running on port ${PORT}`));
JS

cat > services/auth-service/server.js <<'JS'
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
JS

cat > services/user-service/server.js <<'JS'
const express = require("express");
const cors = require("cors");
const mysql = require("mysql2/promise");
const client = require("prom-client");
const app = express();
const PORT = process.env.PORT || 3000;
app.use(cors()); app.use(express.json()); client.collectDefaultMetrics();
const requests = new client.Counter({ name: "user_service_http_requests_total", help: "Total HTTP requests", labelNames: ["method", "path", "status"] });
app.use((req, res, next) => { res.on("finish", () => requests.inc({ method: req.method, path: req.path, status: String(res.statusCode) })); next(); });
const pool = mysql.createPool({ host: process.env.MYSQL_HOST || "mysql", user: process.env.MYSQL_USER || "root", password: process.env.MYSQL_PASSWORD || "root123", database: "user_db", waitForConnections: true, connectionLimit: 10 });
app.get("/health", (req, res) => res.json({ service: "user-service", status: "ok" }));
app.get("/ready", async (req, res) => { try { await pool.query("SELECT 1"); res.json({ ready: true }); } catch (e) { res.status(500).json({ ready: false, error: e.message }); } });
app.get("/metrics", async (req, res) => { res.set("Content-Type", client.register.contentType); res.end(await client.register.metrics()); });
app.get("/users/:userId", async (req, res) => { const [rows] = await pool.execute("SELECT * FROM user_profiles WHERE user_id = ?", [req.params.userId]); res.json(rows[0] || null); });
app.put("/users/:userId", async (req, res) => { const { name, phone, address, city, country } = req.body; await pool.execute(`INSERT INTO user_profiles (user_id, name, phone, address, city, country) VALUES (?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE name=VALUES(name), phone=VALUES(phone), address=VALUES(address), city=VALUES(city), country=VALUES(country)`, [req.params.userId, name, phone, address, city, country]); res.json({ message: "profile saved" }); });
app.listen(PORT, () => console.log(`user-service running on ${PORT}`));
JS

cat > services/product-service/server.js <<'JS'
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
JS

cat > services/inventory-service/server.js <<'JS'
const express = require("express");
const cors = require("cors");
const mysql = require("mysql2/promise");
const client = require("prom-client");
const app = express(); const PORT = process.env.PORT || 3000;
app.use(cors()); app.use(express.json()); client.collectDefaultMetrics();
const requests = new client.Counter({ name: "inventory_service_http_requests_total", help: "Total HTTP requests", labelNames: ["method", "path", "status"] });
app.use((req, res, next) => { res.on("finish", () => requests.inc({ method: req.method, path: req.path, status: String(res.statusCode) })); next(); });
const pool = mysql.createPool({ host: process.env.MYSQL_HOST || "mysql", user: process.env.MYSQL_USER || "root", password: process.env.MYSQL_PASSWORD || "root123", database: "inventory_db", waitForConnections: true, connectionLimit: 10 });
app.get("/health", (req, res) => res.json({ service: "inventory-service", status: "ok" }));
app.get("/ready", async (req, res) => { try { await pool.query("SELECT 1"); res.json({ ready: true }); } catch (e) { res.status(500).json({ ready: false, error: e.message }); } });
app.get("/metrics", async (req, res) => { res.set("Content-Type", client.register.contentType); res.end(await client.register.metrics()); });
app.get("/inventory/:productId", async (req, res) => { const [rows] = await pool.execute("SELECT * FROM inventory WHERE product_id = ?", [req.params.productId]); res.json(rows[0] || { product_id: Number(req.params.productId), quantity: 0 }); });
app.post("/inventory/upsert", async (req, res) => { try { const { productId, quantity } = req.body; if (!productId) return res.status(400).json({ error: "productId is required" }); const qty = Number(quantity || 50); await pool.execute("INSERT INTO inventory (product_id, quantity) VALUES (?, ?) ON DUPLICATE KEY UPDATE quantity = VALUES(quantity)", [productId, qty]); res.status(201).json({ message: "inventory created or updated", productId, quantity: qty }); } catch (e) { res.status(500).json({ error: "inventory upsert failed", detail: e.message }); } });
app.post("/inventory/reserve", async (req, res) => { const { productId, quantity } = req.body; const qty = Number(quantity || 1); const [result] = await pool.execute("UPDATE inventory SET quantity = quantity - ? WHERE product_id = ? AND quantity >= ?", [qty, productId, qty]); if (result.affectedRows === 0) return res.status(400).json({ error: "insufficient stock", productId, quantity: qty }); res.json({ message: "inventory reserved", productId, quantity: qty }); });
app.listen(PORT, () => console.log(`inventory-service running on ${PORT}`));
JS

cat > services/cart-service/server.js <<'JS'
const express = require("express");
const cors = require("cors");
const redis = require("redis");
const client = require("prom-client");
const app = express(); const PORT = process.env.PORT || 3000;
app.use(cors()); app.use(express.json()); client.collectDefaultMetrics();
const requests = new client.Counter({ name: "cart_service_http_requests_total", help: "Total HTTP requests", labelNames: ["method", "path", "status"] });
app.use((req, res, next) => { res.on("finish", () => requests.inc({ method: req.method, path: req.path, status: String(res.statusCode) })); next(); });
const redisClient = redis.createClient({ url: `redis://${process.env.REDIS_HOST || "redis"}:6379` });
redisClient.on("error", err => console.log("Redis error:", err.message));
redisClient.connect().catch(err => console.log("Redis connect failed:", err.message));
const cartKey = userId => `cart:${userId}`;
app.get("/health", (req, res) => res.json({ service: "cart-service", status: "ok" }));
app.get("/ready", (req, res) => redisClient.isOpen ? res.json({ ready: true }) : res.status(500).json({ ready: false }));
app.get("/metrics", async (req, res) => { res.set("Content-Type", client.register.contentType); res.end(await client.register.metrics()); });
app.get("/cart/:userId", async (req, res) => { const data = await redisClient.get(cartKey(req.params.userId)); res.json(data ? JSON.parse(data) : []); });
app.post("/cart/add", async (req, res) => { const { userId, productId, name, price, quantity } = req.body; if (!userId || !productId) return res.status(400).json({ error: "userId and productId are required" }); const key = cartKey(userId); const data = await redisClient.get(key); const cart = data ? JSON.parse(data) : []; const existing = cart.find(item => Number(item.productId) === Number(productId)); if (existing) existing.quantity += Number(quantity || 1); else cart.push({ productId, name, price, quantity: Number(quantity || 1) }); await redisClient.set(key, JSON.stringify(cart), { EX: 86400 }); res.json(cart); });
app.post("/cart/clear", async (req, res) => { const { userId } = req.body; await redisClient.del(cartKey(userId)); res.json({ message: "cart cleared" }); });
app.listen(PORT, () => console.log(`cart-service running on ${PORT}`));
JS

cat > services/order-service/server.js <<'JS'
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
JS

cat > services/shipping-service/server.js <<'JS'
const express = require("express");
const cors = require("cors");
const mysql = require("mysql2/promise");
const client = require("prom-client");
const app = express(); const PORT = process.env.PORT || 3000;
app.use(cors()); app.use(express.json()); client.collectDefaultMetrics();
const requests = new client.Counter({ name: "shipping_service_http_requests_total", help: "Total HTTP requests", labelNames: ["method", "path", "status"] });
app.use((req, res, next) => { res.on("finish", () => requests.inc({ method: req.method, path: req.path, status: String(res.statusCode) })); next(); });
const pool = mysql.createPool({ host: process.env.MYSQL_HOST || "mysql", user: process.env.MYSQL_USER || "root", password: process.env.MYSQL_PASSWORD || "root123", database: "shipping_db", waitForConnections: true, connectionLimit: 10 });
app.get("/health", (req, res) => res.json({ service: "shipping-service", status: "ok" }));
app.get("/ready", async (req, res) => { try { await pool.query("SELECT 1"); res.json({ ready: true }); } catch (e) { res.status(500).json({ ready: false, error: e.message }); } });
app.get("/metrics", async (req, res) => { res.set("Content-Type", client.register.contentType); res.end(await client.register.metrics()); });
app.post("/shipping/create", async (req, res) => { const { orderId } = req.body; const trackingNumber = `SHIP-${Date.now()}`; await pool.execute("INSERT INTO shipments (order_id, status, tracking_number) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE status=VALUES(status), tracking_number=VALUES(tracking_number)", [orderId, "CREATED", trackingNumber]); res.status(201).json({ orderId, status: "CREATED", trackingNumber }); });
app.get("/shipping/:orderId", async (req, res) => { const [rows] = await pool.execute("SELECT * FROM shipments WHERE order_id = ?", [req.params.orderId]); res.json(rows[0] || null); });
app.listen(PORT, () => console.log(`shipping-service running on ${PORT}`));
JS

cat > services/notification-service/server.js <<'JS'
const express = require("express");
const cors = require("cors");
const mysql = require("mysql2/promise");
const client = require("prom-client");
const app = express(); const PORT = process.env.PORT || 3000;
app.use(cors()); app.use(express.json()); client.collectDefaultMetrics();
const requests = new client.Counter({ name: "notification_service_http_requests_total", help: "Total HTTP requests", labelNames: ["method", "path", "status"] });
app.use((req, res, next) => { res.on("finish", () => requests.inc({ method: req.method, path: req.path, status: String(res.statusCode) })); next(); });
const pool = mysql.createPool({ host: process.env.MYSQL_HOST || "mysql", user: process.env.MYSQL_USER || "root", password: process.env.MYSQL_PASSWORD || "root123", database: "notification_db", waitForConnections: true, connectionLimit: 10 });
app.get("/health", (req, res) => res.json({ service: "notification-service", status: "ok" }));
app.get("/ready", async (req, res) => { try { await pool.query("SELECT 1"); res.json({ ready: true }); } catch (e) { res.status(500).json({ ready: false, error: e.message }); } });
app.get("/metrics", async (req, res) => { res.set("Content-Type", client.register.contentType); res.end(await client.register.metrics()); });
app.post("/notifications/send", async (req, res) => { const { userId, type, message } = req.body; await pool.execute("INSERT INTO notifications (user_id, type, message) VALUES (?, ?, ?)", [userId || null, type || "INFO", message || "Notification"]); res.status(201).json({ sent: true, type, message }); });
app.get("/notifications", async (req, res) => { const [rows] = await pool.execute("SELECT * FROM notifications ORDER BY id DESC LIMIT 50"); res.json(rows); });
app.listen(PORT, () => console.log(`notification-service running on ${PORT}`));
JS

cat > services/review-service/server.js <<'JS'
const express = require("express");
const cors = require("cors");
const mysql = require("mysql2/promise");
const client = require("prom-client");
const app = express(); const PORT = process.env.PORT || 3000;
app.use(cors()); app.use(express.json()); client.collectDefaultMetrics();
const requests = new client.Counter({ name: "review_service_http_requests_total", help: "Total HTTP requests", labelNames: ["method", "path", "status"] });
app.use((req, res, next) => { res.on("finish", () => requests.inc({ method: req.method, path: req.path, status: String(res.statusCode) })); next(); });
const pool = mysql.createPool({ host: process.env.MYSQL_HOST || "mysql", user: process.env.MYSQL_USER || "root", password: process.env.MYSQL_PASSWORD || "root123", database: "review_db", waitForConnections: true, connectionLimit: 10 });
app.get("/health", (req, res) => res.json({ service: "review-service", status: "ok" }));
app.get("/ready", async (req, res) => { try { await pool.query("SELECT 1"); res.json({ ready: true }); } catch (e) { res.status(500).json({ ready: false, error: e.message }); } });
app.get("/metrics", async (req, res) => { res.set("Content-Type", client.register.contentType); res.end(await client.register.metrics()); });
app.post("/reviews", async (req, res) => { const { productId, userId, rating, comment } = req.body; const [result] = await pool.execute("INSERT INTO reviews (product_id, user_id, rating, comment) VALUES (?, ?, ?, ?)", [productId, userId, rating, comment]); res.status(201).json({ id: result.insertId, productId, userId, rating, comment }); });
app.get("/reviews/product/:productId", async (req, res) => { const [rows] = await pool.execute("SELECT * FROM reviews WHERE product_id = ? ORDER BY id DESC", [req.params.productId]); res.json(rows); });
app.listen(PORT, () => console.log(`review-service running on ${PORT}`));
JS

cat > frontend/package.json <<'JSON'
{
  "name": "mjcart-frontend",
  "version": "1.0.0",
  "scripts": {
    "dev": "vite --host 0.0.0.0",
    "build": "vite build",
    "preview": "vite preview --host 0.0.0.0"
  },
  "dependencies": {
    "@vitejs/plugin-react": "^4.3.4",
    "vite": "^6.0.5",
    "react": "^18.3.1",
    "react-dom": "^18.3.1"
  },
  "devDependencies": {}
}
JSON

cat > frontend/index.html <<'HTML'
<!doctype html>
<html>
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>MJ's Cart</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
HTML

cat > frontend/Dockerfile <<'DOCKER'
FROM node:20-alpine AS builder
WORKDIR /app
COPY package.json ./
RUN npm install
COPY . .
RUN npm run build

FROM nginx:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
DOCKER

cat > frontend/nginx.conf <<'NGINX'
server {
  listen 80;
  server_name _;
  root /usr/share/nginx/html;
  index index.html;

  location / {
    try_files $uri $uri/ /index.html;
  }

  location /health {
    return 200 "frontend ok\n";
    add_header Content-Type text/plain;
  }
}
NGINX

cat > frontend/src/main.jsx <<'JSX'
import React, { useEffect, useMemo, useState } from "react";
import { createRoot } from "react-dom/client";
import "./style.css";

function App() {
  const [products, setProducts] = useState([]);
  const [cart, setCart] = useState([]);
  const [orders, setOrders] = useState([]);
  const [notifications, setNotifications] = useState([]);
  const [reviews, setReviews] = useState([]);
  const [stock, setStock] = useState({});
  const [user, setUser] = useState(null);
  const [activePage, setActivePage] = useState("home");
  const [activeCategory, setActiveCategory] = useState("All");
  const [searchTerm, setSearchTerm] = useState("");
  const [message, setMessage] = useState("");
  const [cartOpen, setCartOpen] = useState(false);
  const [selectedProduct, setSelectedProduct] = useState(null);
  const [orderSuccess, setOrderSuccess] = useState(null);
  const fallbackImage = "https://dummyimage.com/700x450/e8f0fe/111827&text=Product+Image";
  const [form, setForm] = useState({ name: "MJ", email: "mj@example.com", password: "password123", review: "Excellent product" });
  const [newProduct, setNewProduct] = useState({ name: "iPhone 15 Pro", description: "Premium Apple smartphone with powerful camera", category: "Mobiles", price: "129999", image_url: "https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?auto=format&fit=crop&w=700&q=80" });

  async function api(path, options = {}) {
    const res = await fetch(`/api${path}`, { ...options, headers: { "Content-Type": "application/json", ...(options.headers || {}) }, body: options.body ? JSON.stringify(options.body) : undefined });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(data.error || data.detail || "API failed");
    return data;
  }
  function flash(text) { setMessage(typeof text === "string" ? text : JSON.stringify(text)); setTimeout(() => setMessage(""), 4000); }
  function price(value) { return Number(value || 0).toLocaleString("en-IN"); }
  function getCategory(product) { if (product.category) return product.category; const name = String(product.name || "").toLowerCase(); if (name.includes("laptop")) return "Laptops"; if (name.includes("mobile") || name.includes("phone") || name.includes("iphone") || name.includes("samsung")) return "Mobiles"; if (name.includes("mouse") || name.includes("keyboard") || name.includes("headphone") || name.includes("accessory") || name.includes("charger") || name.includes("cable")) return "Accessories"; return "Electronics"; }
  const enrichedProducts = useMemo(() => products.map(p => ({ ...p, category: getCategory(p), rating: "4.3", ratings: "1,245", discount: "15% off" })), [products]);
  const filteredProducts = useMemo(() => enrichedProducts.filter(p => (activeCategory === "All" || p.category === activeCategory) && (!searchTerm.trim() || `${p.name} ${p.description} ${p.category}`.toLowerCase().includes(searchTerm.trim().toLowerCase()))), [enrichedProducts, activeCategory, searchTerm]);
  const cartCount = cart.reduce((sum, item) => sum + Number(item.quantity), 0);
  const cartTotal = cart.reduce((sum, item) => sum + Number(item.price) * Number(item.quantity), 0);

  async function loadProducts() { try { setProducts(await api("/products")); flash("Products loaded from Product Service"); } catch (e) { flash(e.message); } }
  async function register() { try { const data = await api("/auth/register", { method: "POST", body: { name: form.name, email: form.email, password: form.password } }); setUser(data.user); flash("Account created successfully"); setActivePage("home"); } catch (e) { flash(e.message); } }
  async function login() { try { const data = await api("/auth/login", { method: "POST", body: { email: form.email, password: form.password } }); setUser(data.user); flash("Logged in successfully"); loadCart(data.user.id); loadOrders(data.user.id); setActivePage("home"); } catch (e) { flash(e.message); } }
  function logout() { setUser(null); setCart([]); setOrders([]); flash("Logged out successfully"); setActivePage("home"); }
  async function checkStock(productId) { try { const data = await api(`/inventory/${productId}`); setStock(prev => ({ ...prev, [productId]: data.quantity })); flash(`Stock available: ${data.quantity}`); } catch (e) { flash(e.message); } }
  async function addToCart(product, openCart = false) { if (!user) { flash("Please login before adding items to cart"); setActivePage("account"); return; } try { const data = await api("/cart/add", { method: "POST", body: { userId: user.id, productId: product.id, name: product.name, price: product.price, quantity: 1 } }); setCart(data); flash(`${product.name} added to cart`); if (openCart) setCartOpen(true); } catch (e) { flash(e.message); } }
  async function loadCart(userId = user?.id) { if (!userId) { flash("Please login to view cart"); return; } try { setCart(await api(`/cart/${userId}`)); flash("Cart loaded from Redis"); } catch (e) { flash(e.message); } }
  async function clearCart() { if (!user) return; try { await api("/cart/clear", { method: "POST", body: { userId: user.id } }); setCart([]); flash("Cart cleared"); } catch (e) { flash(e.message); } }
  async function checkout() { if (!user) { flash("Please login first"); setActivePage("account"); return; } if (cart.length === 0) { flash("Your cart is empty"); return; } try { const data = await api("/orders", { method: "POST", body: { userId: user.id, items: cart } }); await api("/cart/clear", { method: "POST", body: { userId: user.id } }); setCart([]); setOrderSuccess(data); setCartOpen(false); setActivePage("success"); loadOrders(user.id); loadNotifications(); flash(`Order placed successfully (Cash on Delivery). Order ID: ${data.orderId}`); } catch (e) { flash(e.message); } }
  async function loadOrders(userId = user?.id) { if (!userId) return; try { setOrders(await api(`/orders/${userId}`)); } catch (e) { flash(e.message); } }
  async function loadNotifications() { try { setNotifications(await api("/notifications")); } catch (e) { console.log(e.message); } }
  async function addReview(productId) { if (!user) { flash("Please login before adding review"); setActivePage("account"); return; } try { await api("/reviews", { method: "POST", body: { productId, userId: user.id, rating: 5, comment: form.review } }); flash("Review added successfully"); loadReviews(productId); } catch (e) { flash(e.message); } }
  async function loadReviews(productId) { try { setReviews(await api(`/reviews/product/${productId}`)); setActivePage("reviews"); } catch (e) { flash(e.message); } }
  async function addProduct() { try { const product = await api("/products", { method: "POST", body: { name: newProduct.name, description: newProduct.description, category: newProduct.category, price: Number(newProduct.price), image_url: newProduct.image_url } }); await api("/inventory/upsert", { method: "POST", body: { productId: product.id, quantity: 50 } }); flash("New product and stock added successfully"); await loadProducts(); setActiveCategory(newProduct.category); setActivePage("products"); } catch (e) { flash(e.message); } }
  function openCategory(category) { setActiveCategory(category); setActivePage("products"); }
  function openHome() { setActiveCategory("All"); setSearchTerm(""); setActivePage("home"); }
  useEffect(() => { loadProducts(); loadNotifications(); }, []);

  return <div className="premium-app">
    <header className="premium-header"><div className="brand-area" onClick={openHome}><div className="brand-logo">🛒</div><div><h1>MJ's Cart</h1><p>by MJ &middot; DevOps Microservices Project</p></div></div><div className="search-area"><input placeholder="Search for mobiles, laptops, accessories and more" value={searchTerm} onChange={e => { setSearchTerm(e.target.value); setActivePage("products"); }} /><button onClick={() => setActivePage("products")}>Search</button></div><div className="header-actions"><button onClick={() => setActivePage("account")}>{user ? `Hi, ${user.name}` : "Login"}</button><button onClick={() => setActivePage("orders")}>Orders</button><button className="cart-action" onClick={() => setCartOpen(true)}>Cart <span>{cartCount}</span></button></div></header>
    <nav className="premium-nav"><button onClick={openHome}>Home</button><button onClick={() => openCategory("Electronics")}>Electronics</button><button onClick={() => openCategory("Mobiles")}>Mobiles</button><button onClick={() => openCategory("Laptops")}>Laptops</button><button onClick={() => openCategory("Accessories")}>Accessories</button><button onClick={() => setActivePage("deals")}>Today Deals</button><button onClick={() => setActivePage("admin")}>Admin</button><button onClick={() => setActivePage("project")}>Project</button></nav>
    {message && <div className="toast">{message}</div>}
    <main className="premium-main">
      {activePage === "home" && <><section className="hero-premium"><div className="hero-left"><span className="eyebrow">MJ's Cart Microservices Project</span><h2>MJ's Cart E-Commerce Platform</h2><p>A real-time full-stack microservices project with React, API Gateway, Auth, Product, Inventory, Cart, Order, Shipping, Notification and Review services. Checkout is Cash-on-Delivery only - no payment gateway.</p><div className="hero-cta"><button onClick={() => setActivePage("products")}>Start Shopping</button><button className="outline-btn" onClick={() => setActivePage("project")}>View Architecture</button></div><div className="tech-tags"><span>React</span><span>Node.js</span><span>MySQL</span><span>Redis</span><span>Kubernetes</span><span>Prometheus</span></div></div><div className="hero-right"><div className="deal-card big"><p>Featured Deal</p><h3>Laptop Pro 15</h3><strong>₹89,999</strong><span>Free delivery + 15% off</span></div><div className="mini-deals"><div><p>Accessories</p><strong>From ₹1,499</strong></div><div><p>Cloud Native</p><strong>10+ Services</strong></div></div></div></section><section className="category-tiles"><div onClick={() => openCategory("Mobiles")}><span>📱</span><h3>Mobiles</h3><p>Smartphones and gadgets</p></div><div onClick={() => openCategory("Laptops")}><span>💻</span><h3>Laptops</h3><p>Developer-ready laptops</p></div><div onClick={() => openCategory("Accessories")}><span>🎧</span><h3>Accessories</h3><p>Keyboard, mouse, headphones</p></div><div onClick={() => setActivePage("project")}><span>☸️</span><h3>DevOps Project</h3><p>Kubernetes microservices</p></div></section><section className="stats-grid"><div className="stat-box"><h3>10+</h3><p>Microservices</p></div><div className="stat-box"><h3>{products.length}</h3><p>Products</p></div><div className="stat-box"><h3>{cartCount}</h3><p>Cart Items</p></div><div className="stat-box"><h3>{orders.length}</h3><p>Orders</p></div></section><section className="owner-banner"><div><h3>Built by MJ</h3><p>MJ's Cart is a real-time DevOps + Development project built to demonstrate production-style microservices on Kubernetes (kOps), with no payment gateway by design.</p></div><button onClick={() => setActivePage("project")}>Explore Project</button></section></>}
      {(activePage === "home" || activePage === "products" || activePage === "deals") && <section className="premium-card"><div className="section-heading"><div><h2>{activePage === "deals" ? "Today Deals" : activeCategory === "All" ? "Recommended Products" : `${activeCategory} Products`}</h2><p>Product cards are powered by Product Service, Inventory Service, Cart Service and Redis.</p></div><div className="heading-actions"><span>{filteredProducts.length} items</span><button onClick={loadProducts}>Reload Products</button></div></div><div className="filter-tabs">{["All", "Electronics", "Mobiles", "Laptops", "Accessories"].map(cat => <button key={cat} className={activeCategory === cat ? "active" : ""} onClick={() => setActiveCategory(cat)}>{cat}</button>)}</div>{filteredProducts.length === 0 ? <div className="empty-screen"><h3>No products found</h3><p>No products are available for <strong>{activeCategory}</strong>. Add products from the Admin page.</p><button onClick={() => setActivePage("admin")}>Add Product</button></div> : <div className="product-grid-premium">{filteredProducts.map(product => <article className="premium-product" key={product.id}><div className="product-img-box"><img src={product.image_url || fallbackImage} alt={product.name} onError={e => { e.currentTarget.src = fallbackImage; }} /><span className="product-ribbon">MJ's Pick</span><button className="quick-view" onClick={() => setSelectedProduct(product)}>Quick View</button></div><div className="product-data"><span className="product-category">{product.category}</span><h3>{product.name}</h3><p>{product.description}</p><div className="rating-line"><span>{product.rating} ★</span><small>{product.ratings} ratings</small></div><div className="price-area"><strong>₹{price(product.price)}</strong><small>{product.discount}</small></div><p className="delivery">Free delivery by tomorrow</p><div className="stock-status">Stock: {stock[product.id] ?? "Click check stock"}</div><div className="product-buttons"><button onClick={() => checkStock(product.id)}>Stock</button><button className="buy-btn" onClick={() => addToCart(product, true)}>Add Cart</button></div><div className="text-links"><button onClick={() => setSelectedProduct(product)}>Details</button><button onClick={() => loadReviews(product.id)}>Reviews</button></div></div></article>)}</div>}</section>}
      {activePage === "account" && <section className="premium-card two-col"><div className="login-box"><span className="eyebrow dark">Auth Service</span><h2>Login or Create Account</h2><p>This page is connected to Auth Service and stores users in MySQL.</p><input value={form.name} onChange={e => setForm({ ...form, name: e.target.value })} placeholder="Full Name" /><input value={form.email} onChange={e => setForm({ ...form, email: e.target.value })} placeholder="Email" /><input type="password" value={form.password} onChange={e => setForm({ ...form, password: e.target.value })} placeholder="Password" /><div className="form-buttons"><button className="buy-btn" onClick={register}>Register</button><button onClick={login}>Login</button>{user && <button className="danger" onClick={logout}>Logout</button>}</div></div><div className="profile-card"><h3>Profile</h3>{user ? <><div className="avatar">{user.name?.charAt(0)}</div><p><strong>Name:</strong> {user.name}</p><p><strong>Email:</strong> {user.email}</p><p><strong>Role:</strong> {user.role}</p><p><strong>Project:</strong> MJ's Cart Microservices Project</p></> : <div className="empty-mini"><h4>No user logged in</h4><p>Login to add cart items and place orders.</p></div>}</div></section>}
      {activePage === "orders" && <section className="premium-card"><div className="section-heading"><div><h2>My Orders</h2><p>Order Service communicates with Inventory, Shipping and Notification services (Cash on Delivery - no payment gateway).</p></div><button onClick={() => loadOrders()}>Reload Orders</button></div>{orders.length === 0 ? <div className="empty-screen"><h3>No orders yet</h3><p>Add products to cart and place your first order.</p><button onClick={() => setActivePage("products")}>Shop Now</button></div> : <div className="list-grid">{orders.map(order => <div className="order-card" key={order.id}><div><h3>Order #{order.id}</h3><p>Status: {order.status}</p><small>Created by Order Service</small></div><strong>₹{price(order.total_amount)}</strong></div>)}</div>}</section>}
      {activePage === "success" && <section className="success-screen"><div className="success-icon">✅</div><h2>Order Placed Successfully</h2><p>Your order has been created using Order, Inventory, Shipping and Notification services. Payment: Cash on Delivery.</p>{orderSuccess && <div className="success-details"><p><strong>Order ID:</strong> {orderSuccess.orderId}</p><p><strong>Status:</strong> {orderSuccess.status}</p><p><strong>Payment:</strong> {orderSuccess.paymentMethod}</p><p><strong>Total:</strong> ₹{price(orderSuccess.total)}</p></div>}<button onClick={() => setActivePage("orders")}>View Orders</button></section>}
      {activePage === "notifications" && <section className="premium-card"><div className="section-heading"><div><h2>Notifications</h2><p>Notification Service stores platform messages in MySQL.</p></div><button onClick={loadNotifications}>Reload</button></div>{notifications.length === 0 ? <div className="empty-screen"><h3>No notifications</h3><p>Place an order to generate notifications.</p></div> : <div className="list-grid">{notifications.map(n => <div className="notification-card" key={n.id}><h3>{n.type}</h3><p>{n.message}</p></div>)}</div>}</section>}
      {activePage === "reviews" && <section className="premium-card"><div className="section-heading"><div><h2>Product Reviews</h2><p>Review Service stores product reviews in MySQL.</p></div></div><input value={form.review} onChange={e => setForm({ ...form, review: e.target.value })} placeholder="Write review text" />{reviews.length === 0 ? <div className="empty-screen"><h3>No reviews loaded</h3><p>Click Reviews on a product card to load reviews.</p></div> : <div className="list-grid">{reviews.map(r => <div className="review-card" key={r.id}><h3>Product {r.product_id}</h3><p>Rating: {r.rating}/5</p><p>{r.comment}</p></div>)}</div>}</section>}
      {activePage === "admin" && <section className="premium-card two-col"><div className="login-box"><span className="eyebrow dark">Admin Product Service</span><h2>Add New Product</h2><p>This form creates product in MySQL and stock in Inventory Service.</p><input value={newProduct.name} onChange={e => setNewProduct({ ...newProduct, name: e.target.value })} placeholder="Product Name" /><input value={newProduct.description} onChange={e => setNewProduct({ ...newProduct, description: e.target.value })} placeholder="Product Description" /><select value={newProduct.category} onChange={e => setNewProduct({ ...newProduct, category: e.target.value })}><option value="Electronics">Electronics</option><option value="Mobiles">Mobiles</option><option value="Laptops">Laptops</option><option value="Accessories">Accessories</option></select><input value={newProduct.price} onChange={e => setNewProduct({ ...newProduct, price: e.target.value })} placeholder="Price" /><input value={newProduct.image_url} onChange={e => setNewProduct({ ...newProduct, image_url: e.target.value })} placeholder="Image URL" /><button className="buy-btn full" onClick={addProduct}>Add Product</button></div><div className="admin-preview"><h3>Product Preview</h3><img src={newProduct.image_url || fallbackImage} alt={newProduct.name} onError={e => { e.currentTarget.src = fallbackImage; }} /><span className="product-category">{newProduct.category}</span><h2>{newProduct.name}</h2><p>{newProduct.description}</p><strong>₹{price(newProduct.price)}</strong></div></section>}
      {activePage === "project" && <section className="premium-card"><span className="eyebrow dark">Built by MJ</span><h2>MJ's Cart Microservices Architecture</h2><p className="project-intro">This project is a real-time full-stack DevOps and microservices platform. It shows how a frontend connects to an API Gateway, which routes traffic to multiple backend microservices deployed on a self-managed Kubernetes cluster (kOps). There is no payment gateway anywhere in this design - checkout is Cash-on-Delivery only.</p><div className="architecture-box"><div>React Frontend</div><span>→</span><div>NGINX Ingress</div><span>→</span><div>API Gateway</div><span>→</span><div>Microservices</div><span>→</span><div>MySQL / Redis</div></div><div className="project-grid"><div><h3>Frontend</h3><p>React premium e-commerce UI with category pages, cart drawer and admin page.</p></div><div><h3>Backend</h3><p>Auth, Product, Inventory, Cart, Order, Shipping, Notification and Review services - no Payment Service.</p></div><div><h3>Database</h3><p>MySQL databases for service data and Redis for cart/cache use cases.</p></div><div><h3>DevOps</h3><p>Kubernetes (kOps), Ingress, Docker images, Prometheus, Grafana and alerting-ready metrics.</p></div></div><div className="signature-card"><h2>MJ's Cart Microservices Project</h2><p>Cloud | DevOps | Kubernetes (kOps) | Microservices | No Payment Gateway</p></div></section>}
    </main>
    {cartOpen && <div className="cart-overlay"><div className="cart-drawer"><div className="drawer-header"><h2>My Cart</h2><button onClick={() => setCartOpen(false)}>✕</button></div>{cart.length === 0 ? <div className="empty-screen small"><h3>Your cart is empty</h3><p>Add products to continue.</p><button onClick={() => { setCartOpen(false); setActivePage("products"); }}>Shop Products</button></div> : <><div className="drawer-items">{cart.map((item, i) => <div className="drawer-item" key={i}><div><h3>{item.name}</h3><p>Qty: {item.quantity}</p></div><strong>₹{price(Number(item.price) * Number(item.quantity))}</strong></div>)}</div><div className="drawer-summary"><p>Total Items: {cartCount}</p><h2>₹{price(cartTotal)}</h2><small>Payment: Cash on Delivery (COD) - no online payment gateway on this platform.</small><button className="buy-btn full" onClick={checkout}>Place Order (COD)</button><button className="clear-btn full" onClick={clearCart}>Clear Cart</button></div></>}</div></div>}
    {selectedProduct && <div className="modal-overlay"><div className="product-modal"><button className="modal-close" onClick={() => setSelectedProduct(null)}>✕</button><div className="modal-image"><img src={selectedProduct.image_url || fallbackImage} alt={selectedProduct.name} onError={e => { e.currentTarget.src = fallbackImage; }} /></div><div className="modal-info"><span className="product-category">{selectedProduct.category}</span><h2>{selectedProduct.name}</h2><p>{selectedProduct.description}</p><div className="rating-line"><span>4.3 ★</span><small>1,245 ratings</small></div><div className="price-area large"><strong>₹{price(selectedProduct.price)}</strong><small>15% off</small></div><p className="delivery">Free delivery by tomorrow</p><div className="stock-status">Stock: {stock[selectedProduct.id] ?? "Click check stock"}</div><div className="product-buttons"><button onClick={() => checkStock(selectedProduct.id)}>Check Stock</button><button className="buy-btn" onClick={() => addToCart(selectedProduct, true)}>Add to Cart</button></div><button className="review-btn" onClick={() => addReview(selectedProduct.id)}>Add Review</button></div></div></div>}
    <footer className="premium-footer"><div><h2>MJ's Cart</h2><p>by MJ</p></div><div><p>React + Node.js + API Gateway + MySQL + Redis + Kubernetes (kOps)</p><p>Production-style E-Commerce Microservices Project - No Payment Gateway (COD only)</p></div></footer>
  </div>;
}

createRoot(document.getElementById("root")).render(<App />);
JSX

cat > frontend/src/style.css <<'CSS'
*{box-sizing:border-box}body{margin:0;font-family:Inter,Arial,Helvetica,sans-serif;background:#eef2f7;color:#111827}button{border:none;cursor:pointer;font-weight:700;transition:.2s ease}button:hover{transform:translateY(-1px)}input,select{outline:none;border:1px solid #d7dde8}.premium-app{min-height:100vh}.premium-header{background:#0f1720;color:#fff;min-height:74px;display:grid;grid-template-columns:285px 1fr 330px;gap:18px;align-items:center;padding:10px 22px;position:sticky;top:0;z-index:100;box-shadow:0 3px 16px rgba(0,0,0,.25)}.brand-area{display:flex;align-items:center;gap:12px;cursor:pointer}.brand-logo{width:48px;height:48px;background:linear-gradient(135deg,#ffb300,#ff7a00);color:#111;display:grid;place-items:center;font-size:27px;border-radius:16px}.brand-area h1{margin:0;font-size:34px;letter-spacing:-1px}.brand-area p{margin:2px 0 0;font-size:12px;color:#cbd5e1}.search-area{height:46px;background:#fff;display:flex;border-radius:9px;overflow:hidden}.search-area input{flex:1;border:none;padding:0 16px;font-size:15px}.search-area button{width:115px;background:#febd69;color:#111}.header-actions{display:flex;justify-content:flex-end;gap:10px}.header-actions button{background:transparent;color:#fff;padding:10px 13px;border-radius:8px}.header-actions button:hover{background:rgba(255,255,255,.12)}.cart-action{background:#ff9f00!important;color:#111!important}.cart-action span{background:#111;color:#fff;border-radius:18px;padding:3px 9px;margin-left:7px}.premium-nav{background:#1f2937;display:flex;gap:8px;overflow-x:auto;padding:10px 22px;position:sticky;top:74px;z-index:90}.premium-nav button{background:transparent;color:#fff;padding:9px 13px;border-radius:8px;white-space:nowrap}.premium-nav button:hover{background:rgba(255,255,255,.14)}.toast{position:fixed;top:96px;right:22px;background:#047857;color:#fff;padding:14px 18px;border-radius:12px;z-index:200;box-shadow:0 12px 32px rgba(0,0,0,.22);max-width:420px}.premium-main{max-width:1420px;margin:0 auto;padding:24px}.hero-premium{display:grid;grid-template-columns:1.35fr .75fr;gap:26px;background:radial-gradient(circle at top left,rgba(255,255,255,.25),transparent 35%),linear-gradient(135deg,#2563eb,#0f46c9 60%,#072b80);color:#fff;border-radius:28px;padding:40px;min-height:360px;box-shadow:0 18px 46px rgba(37,99,235,.32);margin-bottom:24px}.eyebrow{display:inline-block;background:rgba(255,255,255,.16);padding:8px 14px;border-radius:999px;font-weight:800;margin-bottom:14px}.eyebrow.dark{background:#eef4ff;color:#2563eb}.hero-left h2{font-size:56px;max-width:860px;line-height:1.04;margin:0 0 16px;letter-spacing:-2px}.hero-left p{font-size:18px;line-height:1.7;max-width:790px;color:#eaf1ff}.hero-cta{display:flex;gap:14px;margin-top:22px;flex-wrap:wrap}.hero-cta button{padding:13px 22px;border-radius:12px;background:#ffb300;color:#111;font-size:15px}.outline-btn{background:#fff!important;color:#1d4ed8!important}.tech-tags{display:flex;flex-wrap:wrap;gap:10px;margin-top:24px}.tech-tags span{background:rgba(255,255,255,.14);border:1px solid rgba(255,255,255,.18);padding:7px 12px;border-radius:999px;font-size:13px;font-weight:700}.hero-right{display:grid;gap:16px;align-content:center}.deal-card.big{background:rgba(255,255,255,.14);border:1px solid rgba(255,255,255,.2);padding:26px;border-radius:22px;backdrop-filter:blur(8px)}.deal-card p{margin:0 0 6px;color:#dbeafe}.deal-card h3{margin:0 0 12px;font-size:32px}.deal-card strong{display:block;font-size:36px;margin-bottom:8px}.mini-deals{display:grid;grid-template-columns:1fr 1fr;gap:14px}.mini-deals div{background:#fff;color:#111827;border-radius:18px;padding:18px}.mini-deals p{margin:0 0 5px;color:#64748b}.category-tiles{display:grid;grid-template-columns:repeat(4,1fr);gap:18px;margin-bottom:22px}.category-tiles div{background:#fff;padding:22px;border-radius:20px;cursor:pointer;box-shadow:0 4px 16px rgba(15,23,32,.07);transition:.25s ease}.category-tiles div:hover{transform:translateY(-4px);box-shadow:0 12px 26px rgba(15,23,32,.12)}.category-tiles span{font-size:36px}.category-tiles h3{margin:12px 0 6px;font-size:22px}.category-tiles p{margin:0;color:#64748b}.stats-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:18px;margin-bottom:22px}.stat-box{background:#fff;padding:22px;border-radius:20px;box-shadow:0 4px 16px rgba(15,23,32,.07)}.stat-box h3{margin:0;font-size:38px;color:#2563eb}.stat-box p{margin:8px 0 0;color:#64748b}.owner-banner{background:linear-gradient(135deg,#111827,#1f2937);color:#fff;border-radius:22px;padding:24px;display:flex;justify-content:space-between;gap:18px;align-items:center;margin-bottom:24px}.owner-banner h3{margin:0 0 8px;font-size:28px}.owner-banner p{margin:0;color:#cbd5e1}.owner-banner button{background:#ffb300;color:#111;padding:12px 18px;border-radius:10px}.premium-card{background:#fff;border-radius:24px;padding:26px;margin-bottom:26px;box-shadow:0 4px 18px rgba(15,23,32,.08)}.section-heading{display:flex;justify-content:space-between;align-items:flex-start;gap:18px;margin-bottom:20px}.section-heading h2{margin:0 0 8px;font-size:36px;letter-spacing:-1px}.section-heading p{margin:0;color:#64748b}.heading-actions{display:flex;gap:12px;align-items:center;flex-wrap:wrap}.heading-actions span{background:#eef4ff;color:#2563eb;padding:9px 14px;border-radius:999px;font-weight:800}.heading-actions button,.section-heading button{background:#2563eb;color:#fff;padding:11px 15px;border-radius:10px}.filter-tabs{display:flex;gap:10px;flex-wrap:wrap;margin-bottom:22px}.filter-tabs button{background:#f1f5f9;color:#334155;padding:10px 15px;border-radius:999px}.filter-tabs button.active{background:#2563eb;color:#fff}.product-grid-premium{display:grid;grid-template-columns:repeat(auto-fill,minmax(290px,1fr));gap:24px}.premium-product{border:1px solid #e5e7eb;border-radius:22px;overflow:hidden;background:#fff;transition:.25s ease;display:flex;flex-direction:column}.premium-product:hover{transform:translateY(-5px);box-shadow:0 16px 34px rgba(15,23,32,.13)}.product-img-box{height:230px;background:#f8fafc;position:relative;overflow:hidden}.product-img-box img{width:100%;height:100%;object-fit:cover}.product-ribbon{position:absolute;top:14px;left:14px;background:#111827;color:#fff;font-size:12px;font-weight:800;padding:7px 10px;border-radius:999px}.quick-view{position:absolute;right:14px;bottom:14px;background:#fff;color:#111827;padding:8px 12px;border-radius:999px;box-shadow:0 4px 14px rgba(0,0,0,.16)}.product-data{padding:18px;flex:1;display:flex;flex-direction:column}.product-category{width:fit-content;background:#fff7ed;color:#c2410c;padding:6px 10px;border-radius:999px;font-size:12px;font-weight:800;margin-bottom:10px;display:inline-block}.product-data h3{margin:0 0 8px;font-size:25px;line-height:1.1}.product-data p{margin:0 0 10px;color:#64748b;line-height:1.5}.rating-line{display:flex;gap:10px;align-items:center;margin:8px 0}.rating-line span{background:#16a34a;color:#fff;padding:5px 8px;border-radius:7px;font-size:13px;font-weight:800}.rating-line small{color:#64748b}.price-area{display:flex;gap:12px;align-items:center;margin:10px 0}.price-area strong{font-size:28px}.price-area.large strong{font-size:40px}.price-area small{color:#15803d;font-weight:800}.delivery{color:#047857!important;font-weight:700;font-size:14px}.stock-status{background:#f8fafc;padding:10px;border-radius:10px;margin:10px 0 14px;color:#334155}.product-buttons{display:grid;grid-template-columns:1fr 1fr;gap:10px}.product-buttons button,.form-buttons button{background:#2563eb;color:#fff;padding:11px 12px;border-radius:10px}.buy-btn{background:#ff9f00!important;color:#111827!important}.text-links{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-top:10px}.text-links button{background:#eef4ff;color:#2563eb;padding:10px;border-radius:10px}.two-col{display:grid;grid-template-columns:1.2fr .8fr;gap:24px}.login-box,.profile-card,.admin-preview{background:#f8fafc;border-radius:20px;padding:24px;border:1px solid #e5e7eb}.login-box input,.login-box select,.premium-card input,.premium-card select,.drawer-summary input{width:100%;height:46px;border-radius:10px;padding:0 14px;margin:8px 0;font-size:15px;background:#fff}.form-buttons{display:flex;gap:10px;flex-wrap:wrap;margin-top:12px}.danger{background:#dc2626!important;color:#fff!important}.avatar{width:74px;height:74px;background:linear-gradient(135deg,#2563eb,#0f46c9);color:#fff;display:grid;place-items:center;border-radius:22px;font-size:34px;font-weight:900;margin-bottom:16px}.admin-preview img{width:100%;height:240px;object-fit:cover;border-radius:16px;background:#fff;margin-bottom:16px}.admin-preview strong{font-size:30px}.full{width:100%}.empty-screen{background:#f8fafc;border:1px dashed #cbd5e1;border-radius:18px;padding:38px;text-align:center}.empty-screen.small{padding:26px}.empty-screen button{background:#2563eb;color:#fff;padding:11px 16px;border-radius:10px}.list-grid{display:grid;gap:14px}.order-card,.notification-card,.review-card,.list-card{background:#f8fafc;border:1px solid #e5e7eb;border-radius:18px;padding:18px}.order-card{display:flex;justify-content:space-between;align-items:center}.order-card strong{font-size:26px}.success-screen{background:#fff;border-radius:28px;padding:60px 28px;text-align:center;box-shadow:0 4px 18px rgba(15,23,32,.08)}.success-icon{font-size:70px}.success-screen h2{font-size:40px;margin:14px 0}.success-screen p{color:#64748b}.success-details{background:#f8fafc;border-radius:16px;padding:18px;max-width:420px;margin:22px auto;text-align:left}.success-screen button{background:#2563eb;color:#fff;padding:12px 18px;border-radius:10px}.project-intro{color:#64748b;max-width:980px;line-height:1.7}.architecture-box{background:linear-gradient(135deg,#111827,#1f2937);color:#fff;border-radius:22px;padding:22px;display:flex;gap:12px;flex-wrap:wrap;align-items:center;margin:22px 0}.architecture-box div{background:rgba(255,255,255,.12);padding:12px 14px;border-radius:12px}.architecture-box span{color:#ffb300;font-size:20px;font-weight:900}.project-grid{display:grid;grid-template-columns:repeat(2,1fr);gap:18px}.project-grid div{background:#f8fafc;border-radius:18px;padding:20px;border:1px solid #e5e7eb}.signature-card{background:linear-gradient(135deg,#2563eb,#0f46c9);color:#fff;border-radius:22px;padding:24px;margin-top:22px}.cart-overlay{position:fixed;inset:0;background:rgba(15,23,32,.5);z-index:300;display:flex;justify-content:flex-end}.cart-drawer{width:430px;max-width:100%;height:100vh;background:#fff;padding:22px;overflow-y:auto;box-shadow:-10px 0 28px rgba(0,0,0,.2)}.drawer-header{display:flex;justify-content:space-between;align-items:center}.drawer-header button{background:#f1f5f9;color:#111827;width:38px;height:38px;border-radius:50%}.drawer-item{background:#f8fafc;border-radius:16px;padding:14px;margin-bottom:12px;display:flex;justify-content:space-between;gap:12px}.drawer-summary{border-top:1px solid #e5e7eb;padding-top:18px;margin-top:18px}.drawer-summary h2{font-size:34px}.clear-btn{background:#f1f5f9!important;color:#111827!important;padding:11px;border-radius:10px;margin-top:10px}.modal-overlay{position:fixed;inset:0;background:rgba(15,23,32,.6);z-index:320;display:grid;place-items:center;padding:22px}.product-modal{background:#fff;border-radius:26px;max-width:980px;width:100%;display:grid;grid-template-columns:1fr 1fr;position:relative;overflow:hidden}.modal-close{position:absolute;top:16px;right:16px;background:#f1f5f9;color:#111827;width:40px;height:40px;border-radius:50%;z-index:5}.modal-image{background:#f8fafc;min-height:460px}.modal-image img{width:100%;height:100%;object-fit:cover}.modal-info{padding:34px}.modal-info h2{font-size:40px;margin:12px 0}.review-btn{background:#eef4ff;color:#2563eb;width:100%;padding:12px;border-radius:10px;margin-top:12px}.premium-footer{background:#0f1720;color:#fff;display:grid;grid-template-columns:280px 1fr;gap:22px;padding:30px 24px;margin-top:30px}.premium-footer h2{margin:0}.premium-footer p{color:#cbd5e1}@media(max-width:1150px){.premium-header{grid-template-columns:1fr}.header-actions{justify-content:flex-start;flex-wrap:wrap}.premium-nav{top:auto;position:relative}.hero-premium,.two-col,.product-modal{grid-template-columns:1fr}.category-tiles,.stats-grid,.project-grid{grid-template-columns:repeat(2,1fr)}.owner-banner,.section-heading{flex-direction:column;align-items:flex-start}.premium-footer{grid-template-columns:1fr}}@media(max-width:700px){.premium-main{padding:12px}.premium-header{padding:12px}.brand-area h1{font-size:28px}.hero-premium{padding:24px;border-radius:20px}.hero-left h2{font-size:36px}.category-tiles,.stats-grid,.project-grid,.mini-deals{grid-template-columns:1fr}.premium-card{padding:18px}.section-heading h2{font-size:28px}.product-grid-premium{grid-template-columns:1fr}.cart-drawer{width:100%}.modal-info{padding:22px}.modal-image{min-height:300px}}
CSS

cat > k8s/namespace.yaml <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: $NAMESPACE
EOF

cat > k8s/mysql-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: mysql-secret
  namespace: $NAMESPACE
type: Opaque
stringData:
  MYSQL_ROOT_PASSWORD: "$MYSQL_ROOT_PASSWORD"
  MYSQL_USER: "root"
  MYSQL_PASSWORD: "$MYSQL_ROOT_PASSWORD"
  JWT_SECRET: "$JWT_SECRET"
EOF

cat > k8s/mysql-configmap.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: mysql-initdb
  namespace: $NAMESPACE
data:
  init.sql: |
EOF
sed 's/^/    /' database/init.sql >> k8s/mysql-configmap.yaml

cat > k8s/mysql.yaml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: mysql
  namespace: $NAMESPACE
spec:
  clusterIP: None
  selector:
    app: mysql
  ports:
  - name: mysql
    port: 3306
    targetPort: 3306
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
  namespace: $NAMESPACE
spec:
  serviceName: mysql
  replicas: 1
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        ports:
        - containerPort: 3306
          name: mysql
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: MYSQL_ROOT_PASSWORD
        volumeMounts:
        - name: mysql-data
          mountPath: /var/lib/mysql
        - name: mysql-init
          mountPath: /docker-entrypoint-initdb.d
        readinessProbe:
          exec:
            command: ["/bin/sh", "-c", "mysqladmin ping -h 127.0.0.1 -uroot -p\"\$MYSQL_ROOT_PASSWORD\""]
          initialDelaySeconds: 30
          periodSeconds: 10
      volumes:
      - name: mysql-init
        configMap:
          name: mysql-initdb
  volumeClaimTemplates:
  - metadata:
      name: mysql-data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 5Gi
EOF

cat > k8s/redis.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: $NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        ports:
        - containerPort: 6379
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 250m
            memory: 256Mi
---
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: $NAMESPACE
spec:
  selector:
    app: redis
  ports:
  - name: redis
    port: 6379
    targetPort: 6379
EOF

cat > k8s/backend.yaml <<EOF
EOF
for svc in "${SERVICES[@]}"; do
  if [ "$svc" = "api-gateway" ]; then
    EXTRA_ENV=""
  else
    EXTRA_ENV="        env:
        - name: MYSQL_HOST
          value: mysql
        - name: MYSQL_USER
          value: root
        - name: MYSQL_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: MYSQL_PASSWORD
        - name: REDIS_HOST
          value: redis
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: JWT_SECRET"
  fi
cat >> k8s/backend.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $svc
  namespace: $NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $svc
  template:
    metadata:
      labels:
        app: $svc
    spec:
      containers:
      - name: $svc
        image: $DOCKER_USER/mjcart-$svc:$IMAGE_TAG
        imagePullPolicy: Always
        ports:
        - containerPort: 3000
          name: http
$EXTRA_ENV
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 500m
            memory: 512Mi
        readinessProbe:
          httpGet:
            path: /ready
            port: 3000
          initialDelaySeconds: 15
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 20
---
apiVersion: v1
kind: Service
metadata:
  name: $svc
  namespace: $NAMESPACE
  labels:
    mjcart-monitor: "true"
spec:
  selector:
    app: $svc
  ports:
  - name: http
    port: 80
    targetPort: 3000
---
EOF
done

cat > k8s/frontend.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: $NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: $DOCKER_USER/mjcart-frontend:$IMAGE_TAG
        imagePullPolicy: Always
        ports:
        - containerPort: 80
          name: http
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 300m
            memory: 256Mi
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 20
          periodSeconds: 20
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: $NAMESPACE
  labels:
    mjcart-monitor: "true"
spec:
  selector:
    app: frontend
  ports:
  - name: http
    port: 80
    targetPort: 80
EOF

cat > k8s/ingress.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: mjcart-ingress
  namespace: $NAMESPACE
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-gateway
            port:
              number: 80
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend
            port:
              number: 80
EOF

cat > k8s/monitoring-optional.yaml <<EOF
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: mjcart-services
  namespace: $NAMESPACE
  labels:
    release: kube-prometheus-stack
spec:
  namespaceSelector:
    matchNames:
    - $NAMESPACE
  selector:
    matchLabels:
      mjcart-monitor: "true"
  endpoints:
  - port: http
    path: /metrics
    interval: 15s
EOF

cat > scripts/build-push.sh <<SH
#!/bin/bash
set -euo pipefail
DOCKER_USER="\${DOCKER_USER:-$DOCKER_USER}"
IMAGE_TAG="\${IMAGE_TAG:-$IMAGE_TAG}"
SERVICES=(api-gateway auth-service user-service product-service inventory-service cart-service order-service shipping-service notification-service review-service)
for svc in "\${SERVICES[@]}"; do
  echo "Building \$svc"
  docker build --no-cache -t "\$DOCKER_USER/mjcart-\$svc:\$IMAGE_TAG" "services/\$svc"
  docker push "\$DOCKER_USER/mjcart-\$svc:\$IMAGE_TAG"
done
echo "Building frontend"
docker build --no-cache -t "\$DOCKER_USER/mjcart-frontend:\$IMAGE_TAG" frontend
docker push "\$DOCKER_USER/mjcart-frontend:\$IMAGE_TAG"
SH
chmod +x scripts/build-push.sh

cat > scripts/deploy.sh <<SH
#!/bin/bash
set -euo pipefail
NAMESPACE="$NAMESPACE"
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/mysql-secret.yaml
kubectl apply -f k8s/mysql-configmap.yaml
kubectl apply -f k8s/mysql.yaml
kubectl apply -f k8s/redis.yaml
kubectl rollout status statefulset/mysql -n \$NAMESPACE --timeout=180s
kubectl apply -f k8s/backend.yaml
kubectl apply -f k8s/frontend.yaml
kubectl apply -f k8s/ingress.yaml
echo ">>> Optional: apply k8s/hpa.yaml and k8s/monitoring-optional.yaml once metrics-server / Prometheus Operator are installed"
kubectl get pods -n \$NAMESPACE
kubectl get svc -n \$NAMESPACE
kubectl get ingress -n \$NAMESPACE
SH
chmod +x scripts/deploy.sh

cat > scripts/verify.sh <<SH
#!/bin/bash
set -euo pipefail
NAMESPACE="$NAMESPACE"
kubectl get pods -n \$NAMESPACE
kubectl get endpoints api-gateway auth-service product-service notification-service -n \$NAMESPACE
kubectl logs -n \$NAMESPACE deploy/api-gateway --tail=30 || true
kubectl exec -it deploy/redis -n \$NAMESPACE -- redis-cli DEL products:list || true
SH
chmod +x scripts/verify.sh

# ---------------- kOps cluster lifecycle scripts ----------------
cat > scripts/create-kops-cluster.sh <<'SH'
#!/bin/bash
# MJ's Cart - kOps cluster creation.
# IMP: use bigger nodes (t3.large or larger) with 50GB disks - this platform
# runs 10 backend microservices + MySQL + Redis + NGINX Ingress + Prometheus/Grafana
# on top, so undersized nodes will show Pending/CrashLoopBackOff from resource
# pressure, not application bugs.
set -euo pipefail

: "${KOPS_STATE_STORE:?Set KOPS_STATE_STORE, e.g. export KOPS_STATE_STORE=s3://mjcart-kops-state-<yourid>}"

CLUSTER_NAME="${CLUSTER_NAME:-mjcart.k8s.local}"   # .k8s.local = gossip-based, no Route53 domain needed
ZONES="${ZONES:-ap-south-1a,ap-south-1b}"
NODE_SIZE="${NODE_SIZE:-t3.large}"
MASTER_SIZE="${MASTER_SIZE:-t3.large}"
NODE_COUNT="${NODE_COUNT:-3}"
VOLUME_SIZE="${VOLUME_SIZE:-50}"

echo ">>> Ensuring kOps state store bucket exists"
STATE_BUCKET=$(echo "$KOPS_STATE_STORE" | sed 's|s3://||')
aws s3api head-bucket --bucket "$STATE_BUCKET" 2>/dev/null || aws s3 mb "s3://$STATE_BUCKET"
aws s3api put-bucket-versioning --bucket "$STATE_BUCKET" --versioning-configuration Status=Enabled

echo ">>> Creating cluster spec: $CLUSTER_NAME"
# NOTE: --master-size/--master-count/--master-volume-size and --iam-role were
# removed/renamed in modern kOps (1.25+). Current kOps uses --control-plane-*
# and has no --iam-role flag at all (IAM is handled automatically per
# instance group). Using the current flag names below so this actually runs.
kops create cluster \
  --name="$CLUSTER_NAME" \
  --zones="$ZONES" \
  --node-count="$NODE_COUNT" \
  --node-size="$NODE_SIZE" \
  --control-plane-size="$MASTER_SIZE" \
  --control-plane-count=1 \
  --node-volume-size="$VOLUME_SIZE" \
  --control-plane-volume-size="$VOLUME_SIZE" \
  --networking=calico

echo ">>> Provisioning cluster on AWS (~10-15 min)"
kops update cluster --name "$CLUSTER_NAME" --yes

echo ">>> Waiting for cluster to validate"
kops validate cluster --name "$CLUSTER_NAME" --wait 15m

echo ">>> Cluster ready. Default StorageClass (needed by k8s/mysql.yaml PVC):"
kubectl get storageclass
SH
chmod +x scripts/create-kops-cluster.sh

cat > scripts/delete-kops-cluster.sh <<'SH'
#!/bin/bash
# Tear down the kOps cluster and its AWS resources. Does NOT delete the S3 state store bucket.
set -euo pipefail
: "${KOPS_STATE_STORE:?Set KOPS_STATE_STORE first}"
CLUSTER_NAME="${CLUSTER_NAME:-mjcart.k8s.local}"
NAMESPACE="${NAMESPACE:-mjcart}"

echo ">>> Deleting workloads first (releases ELBs/EBS volumes cleanly)"
kubectl delete namespace "$NAMESPACE" --ignore-not-found
kubectl delete namespace monitoring --ignore-not-found
kubectl delete namespace ingress-nginx --ignore-not-found

echo ">>> Deleting kOps cluster: $CLUSTER_NAME"
kops delete cluster --name "$CLUSTER_NAME" --yes
SH
chmod +x scripts/delete-kops-cluster.sh

# ---------------- docs/ ----------------
mkdir -p docs .github/workflows

cat > docs/ARCHITECTURE.md <<'EOF'
# MJ's Cart - Architecture

No payment gateway anywhere in this design. Checkout is Cash-on-Delivery
(COD) only: `order-service` sets `payment_method = "COD"` on every order and
never calls out to a payment provider.

```
Users -> Route 53 (optional) -> AWS ELB -> NGINX Ingress Controller
                                                |
                          +---------------------+---------------------+
                          |                                           |
                   Frontend Service (/)                     API Gateway Service (/api)
                   React + NGINX                             Node.js / Express
                                                                       |
                                    Backend microservices (ClusterIP, Deployments)
        +----------+----------+----------+-----------+----------+
        | Auth     | User     | Product  | Inventory | Cart     |
        +----------+----------+----------+-----------+----------+
        | Order    | Shipping | Notification | Review          |
        +----------+----------+----------+-----------+----------+
                                    |
                     MySQL StatefulSet (PVC)    Redis (cart + product cache)
                                    |
                    Prometheus (scrapes /metrics) -> Grafana
```

## Services

| Service | Owns | Notes |
|---|---|---|
| api-gateway | routing only | proxies `/api/*` to each service; no `/api/payments` route |
| auth-service | `auth_db` | register/login, JWT |
| user-service | `user_db` | profile CRUD |
| product-service | `product_db` | catalog, Redis-cached list |
| inventory-service | `inventory_db` | stock, reserve-on-checkout |
| cart-service | Redis only | per-user cart |
| order-service | `order_db` | checkout orchestration - COD only, no payment call |
| shipping-service | `shipping_db` | shipment + tracking number |
| notification-service | `notification_db` | order notifications |
| review-service | `review_db` | product reviews |

Each service exposes `/health`, `/ready`, and `/metrics` (Prometheus format).
EOF

cat > docs/API.md <<'EOF'
# MJ's Cart - API Gateway Routes

All requests go through the API Gateway at `/api/*`. There is intentionally
no `/api/payments` route.

| Route prefix | Backend service |
|---|---|
| `/api/auth` | auth-service |
| `/api/users` | user-service |
| `/api/products` | product-service |
| `/api/inventory` | inventory-service |
| `/api/cart` | cart-service |
| `/api/orders` | order-service |
| `/api/shipping` | shipping-service |
| `/api/notifications` | notification-service |
| `/api/reviews` | review-service |

## Checkout (COD only)

`POST /api/orders`
```json
{ "userId": 1, "items": [{ "productId": 1, "name": "Laptop Pro 15", "price": 89999, "quantity": 1 }] }
```
Response includes `"paymentMethod": "COD"` - there is no card field accepted
or stored anywhere in this API.
EOF

cat > docs/RUNBOOK.md <<'EOF'
# MJ's Cart - Runbook

## Local (docker compose / npm)
See main README "Run locally" section.

## kOps cluster
```bash
export KOPS_STATE_STORE=s3://mjcart-kops-state-<yourid>
./scripts/create-kops-cluster.sh
./scripts/build-push.sh
./scripts/deploy.sh
./scripts/verify.sh
```

## Common issues

- **Pods Pending**: nodes undersized. Re-check `NODE_SIZE`/`VOLUME_SIZE` used
  in `create-kops-cluster.sh` - this platform needs `t3.large`+ nodes.
- **MySQL StatefulSet stuck Pending**: check `kubectl get storageclass` - kOps
  doesn't ship a fixed StorageClass name the way EKS does; set
  `storageClassName` in `k8s/mysql.yaml` to whatever is marked `(default)`.
- **502 from api-gateway**: a backend pod isn't ready yet; check
  `kubectl get pods -n mjcart` and `kubectl logs deploy/<service> -n mjcart`.

## Teardown
```bash
./scripts/delete-kops-cluster.sh
```
EOF

cat > .github/workflows/ci.yml <<'EOF'
name: CI

on:
  push:
    branches: [main, "chore/**"]
  pull_request:
    branches: [main]

jobs:
  lint-and-build:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        service:
          - api-gateway
          - auth-service
          - user-service
          - product-service
          - inventory-service
          - cart-service
          - order-service
          - shipping-service
          - notification-service
          - review-service
    steps:
      - uses: actions/checkout@v4

      - name: Set up Node
        uses: actions/setup-node@v4
        with:
          node-version: "20"

      - name: Install deps (syntax + dependency resolution check)
        working-directory: services/${{ matrix.service }}
        run: npm install --omit=dev

      - name: Syntax check server.js
        working-directory: services/${{ matrix.service }}
        run: node --check server.js

      - name: Build Docker image (no push)
        run: docker build -t mjcart-${{ matrix.service }}:ci services/${{ matrix.service }}

  frontend-build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "20"
      - name: Install and build frontend
        working-directory: frontend
        run: |
          npm install
          npm run build
      - name: Build frontend Docker image (no push)
        run: docker build -t mjcart-frontend:ci frontend

  validate-k8s-manifests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Validate YAML syntax
        run: |
          pip install --quiet pyyaml
          python3 - <<'PY'
          import yaml, glob, sys
          failed = False
          for f in sorted(glob.glob("k8s/*.yaml")):
              try:
                  list(yaml.safe_load_all(open(f)))
                  print(f"OK   {f}")
              except Exception as e:
                  print(f"FAIL {f}: {e}")
                  failed = True
          sys.exit(1 if failed else 0)
          PY

  shellcheck-scripts:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run ShellCheck on scripts
        uses: ludeeus/action-shellcheck@master
        with:
          scandir: "./scripts"
          severity: warning
EOF

cat > README.md <<EOF
# MJ's Cart - E-Commerce Microservices Platform

**Author:** MJ (Jeevan Kumar Mamuduri) - [github.com/jeevanm84](https://github.com/jeevanm84)
**Payment gateway:** None, by design. Checkout is Cash-on-Delivery (COD) only.
**Cluster:** kOps (self-managed Kubernetes on EC2), not EKS.

## Generate the project

This README ships alongside \`create-mjcart.sh\`, the script that generates
everything below from scratch:

\`\`\`bash
export DOCKER_USER=$DOCKER_USER
export IMAGE_TAG=$IMAGE_TAG
export NAMESPACE=$NAMESPACE
./create-mjcart.sh
cd $PROJECT
\`\`\`

## Services (no payment-service)

api-gateway, auth-service, user-service, product-service, inventory-service,
cart-service, order-service, shipping-service, notification-service,
review-service, frontend. Each backend service exposes \`/health\`, \`/ready\`,
and \`/metrics\`. See \`docs/ARCHITECTURE.md\` and \`docs/API.md\` for details.

## Run locally (Docker required)

\`\`\`bash
# 1. Start MySQL + Redis
docker run -d --name mysql -e MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD -p 3306:3306 -v \$PWD/database/init.sql:/docker-entrypoint-initdb.d/init.sql mysql:8.0
docker run -d --name redis -p 6379:6379 redis:7-alpine

# 2. Run each service (separate terminals), e.g.
cd services/auth-service && npm install && MYSQL_HOST=localhost MYSQL_PASSWORD=$MYSQL_ROOT_PASSWORD JWT_SECRET=$JWT_SECRET node server.js

# 3. Run the frontend
cd frontend && npm install && npm run dev
\`\`\`

## Deploy on kOps

IMP: give the nodes a bigger instance type (\`t3.large\`+) with 50GB disks -
this platform runs 10 backend services + MySQL + Redis + NGINX Ingress +
Prometheus/Grafana on top.

\`\`\`bash
# 1. Create the cluster
export KOPS_STATE_STORE=s3://mjcart-kops-state-<your-unique-suffix>
./scripts/create-kops-cluster.sh

# 2. Build & push images
export DOCKER_USER=$DOCKER_USER
export IMAGE_TAG=$IMAGE_TAG
./scripts/build-push.sh

# 3. Install NGINX Ingress + (optional) Prometheus stack
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace

# 4. Deploy the platform
./scripts/deploy.sh

# 5. Verify
./scripts/verify.sh
kubectl get ingress -n $NAMESPACE
\`\`\`

## Teardown

\`\`\`bash
./scripts/delete-kops-cluster.sh
\`\`\`

## Resume Summary

Built and deployed MJ's Cart, a production-style e-commerce microservices
platform on a self-managed Kubernetes cluster (kOps) using React, Node.js,
MySQL, Redis, Docker, NGINX Ingress, Prometheus, and Grafana. Implemented an
API Gateway pattern to route frontend requests to 9 independent backend
microservices (Auth, User, Product, Inventory, Cart, Order, Shipping,
Notification, Review). Deployed MySQL as a StatefulSet with persistent
storage and Redis for cart/session caching and product-list caching.
Configured Kubernetes Deployments, Services, Secrets, ConfigMaps, Ingress,
readiness/liveness probes, resource limits, and Prometheus metrics on every
service. Deliberately excluded a payment gateway - checkout is
Cash-on-Delivery only, keeping the platform out of PCI card-data scope.

## Interview Explanation

In this project I designed a real-time e-commerce microservices application
called MJ's Cart. The user reaches the React frontend through an AWS load
balancer and an NGINX Ingress Controller running on a kOps-managed
Kubernetes cluster. The frontend calls backend APIs through an API Gateway,
which proxies traffic to independent microservices, each with its own MySQL
database and its own health/readiness/metrics endpoints. The Order Service
coordinates with Inventory, Shipping, and Notification services to complete
checkout - there is no Payment Service in this design, so an order is
placed as Cash-on-Delivery immediately after stock is reserved. The whole
platform is monitored with Prometheus and Grafana.
EOF

echo "MJ's Cart project generated successfully in: $PROJECT"
echo "Next: cd $PROJECT && export DOCKER_USER=$DOCKER_USER IMAGE_TAG=$IMAGE_TAG NAMESPACE=$NAMESPACE && ./scripts/build-push.sh"
