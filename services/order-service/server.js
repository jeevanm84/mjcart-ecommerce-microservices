// order-service
// This platform has NO payment gateway. Checkout is Cash-on-Delivery (COD) only:
// no card data, no payment provider, no transaction/webhook handling anywhere.
const express = require('express');
const mysql = require('mysql2/promise');
const axios = require('axios');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());
const PORT = process.env.PORT || 4006;

const INVENTORY_URL = process.env.INVENTORY_URL || 'http://inventory-service:4004';
const SHIPPING_URL = process.env.SHIPPING_URL || 'http://shipping-service:4007';
const NOTIFICATION_URL = process.env.NOTIFICATION_URL || 'http://notification-service:4008';

const pool = mysql.createPool({
  host: process.env.DB_HOST || 'mysql',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || 'rootpass',
  database: 'order_db',
  waitForConnections: true,
  connectionLimit: 5
});

app.get('/health', (req, res) => res.json({ status: 'ok', service: 'order-service' }));

// Checkout flow: reserve stock -> create order (status PLACED, payment_method COD)
// -> create shipment -> send notification. No payment step.
app.post('/orders', async (req, res) => {
  const { user_id, items } = req.body; // items: [{productId, quantity, price, name}]
  if (!user_id || !items || !items.length) {
    return res.status(400).json({ error: 'user_id and items are required' });
  }

  try {
    for (const item of items) {
      await axios.post(`${INVENTORY_URL}/stock/${item.productId}/reserve`, { quantity: item.quantity });
    }
  } catch (err) {
    return res.status(409).json({ error: 'stock reservation failed', detail: err.response?.data || err.message });
  }

  const total = items.reduce((sum, i) => sum + i.price * i.quantity, 0);

  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    const [orderResult] = await conn.query(
      'INSERT INTO orders (user_id, status, payment_method, total_amount) VALUES (?, ?, ?, ?)',
      [user_id, 'PLACED', 'COD', total]
    );
    const orderId = orderResult.insertId;
    for (const item of items) {
      await conn.query(
        'INSERT INTO order_items (order_id, product_id, quantity, price) VALUES (?, ?, ?, ?)',
        [orderId, item.productId, item.quantity, item.price]
      );
    }
    await conn.commit();

    // Best-effort downstream calls; order is already committed either way.
    try { await axios.post(`${SHIPPING_URL}/shipments`, { orderId, userId: user_id }); } catch (e) { console.error('shipping call failed', e.message); }
    try { await axios.post(`${NOTIFICATION_URL}/notify`, { userId: user_id, type: 'ORDER_PLACED', orderId }); } catch (e) { console.error('notification call failed', e.message); }

    res.status(201).json({ orderId, status: 'PLACED', payment_method: 'COD', total_amount: total });
  } catch (err) {
    await conn.rollback();
    res.status(500).json({ error: 'order creation failed', detail: err.message });
  } finally {
    conn.release();
  }
});

app.get('/orders/:id', async (req, res) => {
  const [orders] = await pool.query('SELECT * FROM orders WHERE id = ?', [req.params.id]);
  if (!orders.length) return res.status(404).json({ error: 'not found' });
  const [items] = await pool.query('SELECT * FROM order_items WHERE order_id = ?', [req.params.id]);
  res.json({ ...orders[0], items });
});

app.get('/orders/user/:userId', async (req, res) => {
  const [orders] = await pool.query('SELECT * FROM orders WHERE user_id = ? ORDER BY created_at DESC', [req.params.userId]);
  res.json(orders);
});

app.put('/orders/:id/status', async (req, res) => {
  const { status } = req.body; // PLACED -> CONFIRMED -> SHIPPED -> DELIVERED / CANCELLED
  await pool.query('UPDATE orders SET status = ? WHERE id = ?', [status, req.params.id]);
  res.json({ updated: true, status });
});

app.listen(PORT, () => console.log(`order-service listening on ${PORT}`));
