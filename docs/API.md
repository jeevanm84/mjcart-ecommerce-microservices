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
