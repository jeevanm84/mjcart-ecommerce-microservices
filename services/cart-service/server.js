const express = require('express');
const { createClient } = require('redis');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());
const PORT = process.env.PORT || 4005;

const redisClient = createClient({ url: `redis://${process.env.REDIS_HOST || 'redis'}:6379` });
redisClient.on('error', (err) => console.error('Redis error', err));
redisClient.connect().catch(console.error);

const cartKey = (userId) => `cart:${userId}`;

app.get('/health', (req, res) => res.json({ status: 'ok', service: 'cart-service' }));

app.get('/cart/:userId', async (req, res) => {
  const data = await redisClient.get(cartKey(req.params.userId));
  res.json(data ? JSON.parse(data) : { items: [] });
});

app.post('/cart/:userId/items', async (req, res) => {
  const { productId, quantity, price, name } = req.body;
  const data = await redisClient.get(cartKey(req.params.userId));
  const cart = data ? JSON.parse(data) : { items: [] };
  const existing = cart.items.find(i => i.productId === productId);
  if (existing) existing.quantity += quantity;
  else cart.items.push({ productId, quantity, price, name });
  await redisClient.set(cartKey(req.params.userId), JSON.stringify(cart), { EX: 60 * 60 * 24 * 7 });
  res.status(201).json(cart);
});

app.delete('/cart/:userId/items/:productId', async (req, res) => {
  const data = await redisClient.get(cartKey(req.params.userId));
  const cart = data ? JSON.parse(data) : { items: [] };
  cart.items = cart.items.filter(i => String(i.productId) !== req.params.productId);
  await redisClient.set(cartKey(req.params.userId), JSON.stringify(cart));
  res.json(cart);
});

app.delete('/cart/:userId', async (req, res) => {
  await redisClient.del(cartKey(req.params.userId));
  res.json({ cleared: true });
});

app.listen(PORT, () => console.log(`cart-service listening on ${PORT}`));
