-- S02: two partial refunds on the same payment (BUG-002).
-- Payment PAY-B002 = 100.00. First refund 60.00 is fine.
-- Second refund 60.00 would bring the total refunded to 120.00, so it must be rejected.
-- Day used: 2026-02-25 (no other data on this day).

-- Fixture product priced at exactly 100.00
INSERT INTO products (sku, name, unit_price) VALUES ('SKU-B002', 'Gift card 100', 100.00);
INSERT INTO inventory (product_id, received_qty, stock)
SELECT id, 10, 10 FROM products WHERE sku = 'SKU-B002';

SELECT qa.expect('S02-01', 'OK', place_order('ORD-B002', '00000000001', 'SKU-B002', 1, '2026-02-25 10:00+00'));
SELECT qa.expect('S02-02', 'OK', pay_order('PAY-B002', 'ORD-B002', 100.00, 'captured', '2026-02-25 10:05+00'));
SELECT qa.expect('S02-03', 'OK',                  refund_payment('RF-B002-1', 'PAY-B002', 60.00, '2026-02-26 09:00+00'));
SELECT qa.expect('S02-04', 'REFUND_EXCEEDS_PAID', refund_payment('RF-B002-2', 'PAY-B002', 60.00, '2026-02-26 09:30+00'));
