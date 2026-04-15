-- ============================================================
-- One-time database setup: create indexes on join key columns.
--
-- The Olist Kaggle SQLite database ships without any indexes,
-- which makes the larger analytical queries (especially those
-- joining the 1M-row geolocation table) impractically slow.
-- ============================================================

-- Geolocation: joined to sellers and customers via zip prefix
CREATE INDEX IF NOT EXISTS idx_geo_zip 
    ON geolocation(geolocation_zip_code_prefix);

-- Sellers and customers: joined to geolocation via zip prefix
CREATE INDEX IF NOT EXISTS idx_sellers_zip 
    ON sellers(seller_zip_code_prefix);
CREATE INDEX IF NOT EXISTS idx_customers_zip 
    ON customers(customer_zip_code_prefix);

-- Customers: joined to orders via customer_id
CREATE INDEX IF NOT EXISTS idx_customers_id 
    ON customers(customer_id);

-- Orders: filtered by status, joined by customer_id
CREATE INDEX IF NOT EXISTS idx_orders_status 
    ON orders(order_status);
CREATE INDEX IF NOT EXISTS idx_orders_customer 
    ON orders(customer_id);

-- Order items: joined to orders, sellers, and products
CREATE INDEX IF NOT EXISTS idx_order_items_order 
    ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_seller 
    ON order_items(seller_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product 
    ON order_items(product_id);

-- Reviews: joined to orders
CREATE INDEX IF NOT EXISTS idx_reviews_order 
    ON order_reviews(order_id);

-- Products: joined to category translation
CREATE INDEX IF NOT EXISTS idx_products_category 
    ON products(product_category_name);