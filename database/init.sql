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
