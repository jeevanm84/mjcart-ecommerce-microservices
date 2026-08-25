-- MJ's Cart - E-Commerce Microservices Platform
-- Each microservice owns its own database (database-per-service pattern)
-- NOTE: No payment_db / payment tables - this platform has NO payment gateway.
-- Orders are placed with payment_method = 'COD' (Cash on Delivery) only.

CREATE DATABASE IF NOT EXISTS auth_db;
CREATE DATABASE IF NOT EXISTS user_db;
CREATE DATABASE IF NOT EXISTS product_db;
CREATE DATABASE IF NOT EXISTS inventory_db;
CREATE DATABASE IF NOT EXISTS order_db;
CREATE DATABASE IF NOT EXISTS review_db;

-- ===================== auth_db =====================
USE auth_db;
CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(150) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  role VARCHAR(20) DEFAULT 'customer',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ===================== user_db =====================
USE user_db;
CREATE TABLE IF NOT EXISTS profiles (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  name VARCHAR(150),
  phone VARCHAR(20),
  address VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ===================== product_db =====================
USE product_db;
CREATE TABLE IF NOT EXISTS categories (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS products (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(150) NOT NULL,
  description VARCHAR(500),
  category VARCHAR(100),
  price DECIMAL(10,2) NOT NULL,
  image_url VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO categories (name) VALUES ('Mobiles'),('Laptops'),('Electronics'),('Accessories')
  ON DUPLICATE KEY UPDATE name = VALUES(name);

INSERT INTO products (name, description, category, price, image_url) VALUES
 ('MJ Phone X12', 'Flagship smartphone, 128GB', 'Mobiles', 699.00, '/img/phone-x12.jpg'),
 ('MJ Book Pro 14', '14-inch laptop, 16GB RAM', 'Laptops', 1299.00, '/img/book-pro-14.jpg'),
 ('MJ Buds Air', 'Wireless earbuds', 'Accessories', 79.00, '/img/buds-air.jpg'),
 ('MJ SmartWatch S1', 'Fitness smartwatch', 'Electronics', 149.00, '/img/watch-s1.jpg'),
 ('MJ Power Bank 20K', '20000mAh fast charging', 'Accessories', 39.00, '/img/powerbank.jpg');

-- ===================== inventory_db =====================
USE inventory_db;
CREATE TABLE IF NOT EXISTS stock (
  product_id INT PRIMARY KEY,
  quantity INT NOT NULL DEFAULT 0
);

INSERT INTO stock (product_id, quantity) VALUES
 (1, 50), (2, 25), (3, 100), (4, 40), (5, 80)
  ON DUPLICATE KEY UPDATE quantity = VALUES(quantity);

-- ===================== order_db =====================
-- payment_method is always 'COD' - no gateway, no card/txn data stored anywhere.
USE order_db;
CREATE TABLE IF NOT EXISTS orders (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  status VARCHAR(30) DEFAULT 'PLACED',
  payment_method VARCHAR(20) DEFAULT 'COD',
  total_amount DECIMAL(10,2) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS order_items (
  id INT AUTO_INCREMENT PRIMARY KEY,
  order_id INT NOT NULL,
  product_id INT NOT NULL,
  quantity INT NOT NULL,
  price DECIMAL(10,2) NOT NULL
);

-- ===================== review_db =====================
USE review_db;
CREATE TABLE IF NOT EXISTS reviews (
  id INT AUTO_INCREMENT PRIMARY KEY,
  product_id INT NOT NULL,
  user_id INT NOT NULL,
  rating INT NOT NULL,
  comment VARCHAR(500),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
