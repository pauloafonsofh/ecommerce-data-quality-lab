-- S03: a small data set with hand-computed revenue (BUG-005).
-- Days used: 2026-03-09 to 2026-03-11 (no other data on these days).
--
-- ORD-F1: 2 items (1 x 50.00 + 2 x 50.00 = 150.00), paid on 03-10 in two payments (100.00 + 50.00)
-- ORD-F2: 1 item  (1 x 80.00), created on 03-09, paid on 03-10 (80.00)
-- RF-F2:  refund of 30.00 on PAY-F2, on 03-11
-- ORD-F3: 1 item  (1 x 80.00), paid in two parts: 50.00 on 03-10 and 30.00 on 03-11
--
-- Rule: an order's items count once, on the day of its FIRST captured payment.
--
-- Expected daily_revenue (computed by hand):
--   2026-03-10: items_sold = 3 + 1 + 1 = 5, gross_revenue = 100 + 50 + 80 + 50 = 280.00, refunds = 0,     net = 280.00
--   2026-03-11: items_sold = 0,             gross_revenue = 30.00,                     refunds = 30.00, net = 0.00
--   2026-03-09: no row (an order created that day, but no payment and no refund)

INSERT INTO products (sku, name, unit_price) VALUES
  ('SKU-F1', 'Fixture item 50', 50.00),
  ('SKU-F2', 'Fixture item 80', 80.00);
INSERT INTO inventory (product_id, received_qty, stock)
SELECT id, 10, 10 FROM products WHERE sku IN ('SKU-F1', 'SKU-F2');

SELECT qa.expect('S03-01', 'OK', place_order('ORD-F1', '00000000002', 'SKU-F1', 1, '2026-03-10 09:00+00'));
SELECT qa.expect('S03-02', 'OK', place_order('ORD-F1', '00000000002', 'SKU-F1', 2, '2026-03-10 09:00+00'));
SELECT qa.expect('S03-03', 'OK', pay_order('PAY-F1A', 'ORD-F1', 100.00, 'captured', '2026-03-10 09:10+00'));
SELECT qa.expect('S03-04', 'OK', pay_order('PAY-F1B', 'ORD-F1',  50.00, 'captured', '2026-03-10 09:20+00'));

SELECT qa.expect('S03-05', 'OK', place_order('ORD-F2', '00000000003', 'SKU-F2', 1, '2026-03-09 18:00+00'));
SELECT qa.expect('S03-06', 'OK', pay_order('PAY-F2', 'ORD-F2', 80.00, 'captured', '2026-03-10 10:00+00'));

SELECT qa.expect('S03-07', 'OK', refund_payment('RF-F2', 'PAY-F2', 30.00, '2026-03-11 08:00+00'));

-- ORD-F3: one item, paid in two parts on two different days
SELECT qa.expect('S03-08', 'OK', place_order('ORD-F3', '00000000004', 'SKU-F2', 1, '2026-03-10 11:00+00'));
SELECT qa.expect('S03-09', 'OK', pay_order('PAY-F3A', 'ORD-F3', 50.00, 'captured', '2026-03-10 11:05+00'));
SELECT qa.expect('S03-10', 'OK', pay_order('PAY-F3B', 'ORD-F3', 30.00, 'captured', '2026-03-11 11:05+00'));
