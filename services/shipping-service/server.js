const express = require('express');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());
const PORT = process.env.PORT || 4007;

// In-memory demo store (swap for a real DB/table if you extend this)
const shipments = new Map();
let nextId = 1;

app.get('/health', (req, res) => res.json({ status: 'ok', service: 'shipping-service' }));

app.post('/shipments', (req, res) => {
  const { orderId, userId } = req.body;
  const id = nextId++;
  const shipment = {
    id, orderId, userId,
    status: 'PROCESSING',
    trackingNumber: `MJC-${Date.now()}-${id}`,
    createdAt: new Date().toISOString()
  };
  shipments.set(id, shipment);
  res.status(201).json(shipment);
});

app.get('/shipments/order/:orderId', (req, res) => {
  const match = [...shipments.values()].filter(s => String(s.orderId) === req.params.orderId);
  res.json(match);
});

app.put('/shipments/:id/status', (req, res) => {
  const shipment = shipments.get(Number(req.params.id));
  if (!shipment) return res.status(404).json({ error: 'not found' });
  shipment.status = req.body.status;
  res.json(shipment);
});

app.listen(PORT, () => console.log(`shipping-service listening on ${PORT}`));
