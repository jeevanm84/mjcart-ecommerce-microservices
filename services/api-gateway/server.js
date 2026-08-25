// api-gateway
// Central routing layer. Note there is intentionally NO /api/payments route -
// this platform has no payment gateway/service.
const express = require('express');
const cors = require('cors');
const { createProxyMiddleware } = require('http-proxy-middleware');

const app = express();
app.use(cors());
const PORT = process.env.PORT || 8080;

const routes = {
  '/api/auth':          process.env.AUTH_URL         || 'http://auth-service:4001',
  '/api/users':         process.env.USER_URL         || 'http://user-service:4002',
  '/api/products':      process.env.PRODUCT_URL      || 'http://product-service:4003',
  '/api/categories':    process.env.PRODUCT_URL      || 'http://product-service:4003',
  '/api/inventory':     process.env.INVENTORY_URL    || 'http://inventory-service:4004',
  '/api/cart':          process.env.CART_URL         || 'http://cart-service:4005',
  '/api/orders':        process.env.ORDER_URL        || 'http://order-service:4006',
  '/api/shipments':     process.env.SHIPPING_URL     || 'http://shipping-service:4007',
  '/api/notifications': process.env.NOTIFICATION_URL || 'http://notification-service:4008',
  '/api/reviews':       process.env.REVIEW_URL       || 'http://review-service:4009'
};

app.get('/health', (req, res) => res.json({ status: 'ok', service: 'api-gateway', routes: Object.keys(routes) }));

for (const [path, target] of Object.entries(routes)) {
  app.use(path, createProxyMiddleware({
    target,
    changeOrigin: true,
    pathRewrite: { [`^${path}`]: '' }
  }));
}

app.listen(PORT, () => console.log(`api-gateway listening on ${PORT}, routing: ${Object.keys(routes).join(', ')}`));
