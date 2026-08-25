const express = require('express');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());
const PORT = process.env.PORT || 4008;

// Mock notifications - logs + in-memory history (swap in SES/SNS/etc later if needed)
const history = [];

app.get('/health', (req, res) => res.json({ status: 'ok', service: 'notification-service' }));

app.post('/notify', (req, res) => {
  const { userId, type, orderId } = req.body;
  const note = { userId, type, orderId, sentAt: new Date().toISOString() };
  history.push(note);
  console.log(`[notification] user=${userId} type=${type} order=${orderId}`);
  res.status(201).json(note);
});

app.get('/notifications/user/:userId', (req, res) => {
  res.json(history.filter(n => String(n.userId) === req.params.userId));
});

app.listen(PORT, () => console.log(`notification-service listening on ${PORT}`));
