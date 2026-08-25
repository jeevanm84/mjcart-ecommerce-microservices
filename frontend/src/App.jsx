import React, { useState, useEffect } from 'react';

const API = '/api';
// Demo-only fake user id (no real session/auth wiring in this UI layer)
const USER_ID = 1;

function useFetch(url, deps = []) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  useEffect(() => {
    setLoading(true);
    fetch(url).then(r => r.json()).then(d => { setData(d); setLoading(false); }).catch(() => setLoading(false));
  }, deps);
  return { data, loading };
}

function Header({ tab, setTab, cartCount }) {
  return (
    <header className="header">
      <div className="brand">MJ's Cart</div>
      <nav>
        <button className={tab === 'products' ? 'active' : ''} onClick={() => setTab('products')}>Shop</button>
        <button className={tab === 'cart' ? 'active' : ''} onClick={() => setTab('cart')}>Cart ({cartCount})</button>
        <button className={tab === 'orders' ? 'active' : ''} onClick={() => setTab('orders')}>Orders</button>
      </nav>
    </header>
  );
}

function ProductGrid({ onAddToCart }) {
  const [category, setCategory] = useState('');
  const { data: products, loading } = useFetch(`${API}/products${category ? `?category=${category}` : ''}`, [category]);
  const categories = ['Mobiles', 'Laptops', 'Electronics', 'Accessories'];

  return (
    <div>
      <div className="filters">
        <button className={category === '' ? 'active' : ''} onClick={() => setCategory('')}>All</button>
        {categories.map(c => (
          <button key={c} className={category === c ? 'active' : ''} onClick={() => setCategory(c)}>{c}</button>
        ))}
      </div>
      {loading ? <p>Loading products…</p> : (
        <div className="grid">
          {(products || []).map(p => (
            <div className="card" key={p.id}>
              <div className="card-img-placeholder">{p.category}</div>
              <h3>{p.name}</h3>
              <p className="desc">{p.description}</p>
              <p className="price">${Number(p.price).toFixed(2)}</p>
              <button onClick={() => onAddToCart(p)}>Add to Cart</button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

function CartView({ refreshKey, onCheckout }) {
  const { data: cart, loading } = useFetch(`${API}/cart/${USER_ID}`, [refreshKey]);
  const items = cart?.items || [];
  const total = items.reduce((s, i) => s + i.price * i.quantity, 0);

  const removeItem = async (productId) => {
    await fetch(`${API}/cart/${USER_ID}/items/${productId}`, { method: 'DELETE' });
    onCheckout(null); // triggers a refresh
  };

  return (
    <div>
      <h2>Your Cart</h2>
      {loading ? <p>Loading…</p> : items.length === 0 ? <p>Cart is empty.</p> : (
        <>
          {items.map(i => (
            <div className="cart-row" key={i.productId}>
              <span>{i.name} × {i.quantity}</span>
              <span>${(i.price * i.quantity).toFixed(2)}</span>
              <button onClick={() => removeItem(i.productId)}>Remove</button>
            </div>
          ))}
          <div className="cart-total">Total: ${total.toFixed(2)}</div>
          <p className="cod-note">Payment: Cash on Delivery (COD) only — no online payment gateway on this platform.</p>
          <button className="checkout-btn" onClick={() => onCheckout(items)}>Place Order (COD)</button>
        </>
      )}
    </div>
  );
}

function OrdersView() {
  const { data: orders, loading } = useFetch(`${API}/orders/user/${USER_ID}`);
  return (
    <div>
      <h2>Your Orders</h2>
      {loading ? <p>Loading…</p> : (orders || []).length === 0 ? <p>No orders yet.</p> : (
        <table className="orders-table">
          <thead><tr><th>Order #</th><th>Status</th><th>Payment</th><th>Total</th></tr></thead>
          <tbody>
            {(orders || []).map(o => (
              <tr key={o.id}>
                <td>{o.id}</td><td>{o.status}</td><td>{o.payment_method}</td><td>${Number(o.total_amount).toFixed(2)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}

export default function App() {
  const [tab, setTab] = useState('products');
  const [cartRefresh, setCartRefresh] = useState(0);
  const [cartCount, setCartCount] = useState(0);

  const addToCart = async (product) => {
    await fetch(`${API}/cart/${USER_ID}/items`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ productId: product.id, quantity: 1, price: product.price, name: product.name })
    });
    setCartRefresh(r => r + 1);
    setCartCount(c => c + 1);
  };

  const checkout = async (items) => {
    if (!items) { setCartRefresh(r => r + 1); return; }
    const payload = {
      user_id: USER_ID,
      items: items.map(i => ({ productId: i.productId, quantity: i.quantity, price: i.price, name: i.name }))
    };
    const res = await fetch(`${API}/orders`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload)
    });
    if (res.ok) {
      await fetch(`${API}/cart/${USER_ID}`, { method: 'DELETE' });
      setCartCount(0);
      setCartRefresh(r => r + 1);
      setTab('orders');
    } else {
      alert('Checkout failed — one or more items may be out of stock.');
    }
  };

  return (
    <div className="app">
      <Header tab={tab} setTab={setTab} cartCount={cartCount} />
      <main>
        {tab === 'products' && <ProductGrid onAddToCart={addToCart} />}
        {tab === 'cart' && <CartView refreshKey={cartRefresh} onCheckout={checkout} />}
        {tab === 'orders' && <OrdersView />}
      </main>
      <footer>MJ's Cart — e-commerce microservices demo on Kubernetes (no payment gateway)</footer>
    </div>
  );
}
