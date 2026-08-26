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
