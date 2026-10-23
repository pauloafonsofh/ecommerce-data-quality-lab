-- Deterministic seed data: historical orders that are already consistent.
-- No random() and no now(): every run creates exactly the same rows.
-- Each seed order has ONE item and ONE payment.
-- Dates: 2026-01-01 to 2026-02-09 (UTC).

-- 5 products
INSERT INTO products (sku, name, unit_price) VALUES
  ('SKU-001', 'Notebook sleeve',  19.90),
  ('SKU-002', 'Wireless mouse',   49.90),
  ('SKU-003', 'Mechanical keyboard', 99.00),
  ('SKU-004', 'USB-C dock',      150.00),
  ('SKU-005', '27-inch monitor', 299.00);

-- 20 customers. tax_id = '000000000' + 2 digits: fictional, never a valid CPF.
INSERT INTO customers (tax_id, name, email)
SELECT '000000000' || lpad(i::text, 2, '0'),
       'Customer ' || i,
       'customer' || i || '@example.test'
FROM generate_series(1, 20) AS i;

-- 40 orders: customer = ((i-1) % 20) + 1, product = ((i-1) % 5) + 1, qty = (i % 3) + 1
INSERT INTO orders (order_ref, customer_id, created_at, status, total_amount)
SELECT 'ORD-' || lpad(i::text, 4, '0'),
       c.id,
       timestamptz '2026-01-01 10:00:00+00' + (i - 1) * interval '1 day',
       CASE WHEN i % 8 = 0 THEN 'open' ELSE 'paid' END,   -- every 8th payment failed
       ((i % 3) + 1) * p.unit_price
FROM generate_series(1, 40) AS i
JOIN customers c ON c.tax_id = '000000000' || lpad((((i - 1) % 20) + 1)::text, 2, '0')
JOIN products  p ON p.sku    = 'SKU-' || lpad((((i - 1) % 5) + 1)::text, 3, '0');

INSERT INTO order_items (order_id, product_id, qty, unit_price)
SELECT o.id, p.id, (i % 3) + 1, p.unit_price
FROM generate_series(1, 40) AS i
JOIN orders   o ON o.order_ref = 'ORD-' || lpad(i::text, 4, '0')
JOIN products p ON p.sku       = 'SKU-' || lpad((((i - 1) % 5) + 1)::text, 3, '0');

-- One payment per order, 2 hours after the order. Every 8th payment failed.
INSERT INTO payments (payment_ref, order_id, amount, status, paid_at)
SELECT 'PAY-' || lpad(i::text, 4, '0'),
       o.id,
       o.total_amount,
       CASE WHEN i % 8 = 0 THEN 'failed' ELSE 'captured' END,
       o.created_at + interval '2 hours'
FROM generate_series(1, 40) AS i
JOIN orders o ON o.order_ref = 'ORD-' || lpad(i::text, 4, '0');

-- A partial refund of 10.00 on every 5th payment, when it is captured, one day later.
INSERT INTO refunds (refund_ref, payment_id, amount, refunded_at)
SELECT 'RF-' || lpad(i::text, 4, '0'),
       pay.id,
       10.00,
       pay.paid_at + interval '1 day'
FROM generate_series(1, 40) AS i
JOIN payments pay ON pay.payment_ref = 'PAY-' || lpad(i::text, 4, '0')
WHERE i % 5 = 0 AND pay.status = 'captured';

-- Inventory: 100 units received per product, minus what the seed orders reserved.
INSERT INTO inventory (product_id, received_qty, stock)
SELECT p.id,
       100,
       100 - coalesce((SELECT sum(oi.qty) FROM order_items oi WHERE oi.product_id = p.id), 0)
FROM products p;
