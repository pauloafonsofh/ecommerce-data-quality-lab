-- S01: baseline behaviour of every function (normal paths and rejections).
-- Each call goes through qa.expect(step, expected status, actual status).
-- Check DQ-000 lists the steps where the actual status differs.
-- Day used: 2026-02-20 (no seed data on this day).

-- Customers
SELECT qa.expect('S01-01', 'OK',             register_customer('00000000099', 'Ana Test', 'ana@example.test'));
SELECT qa.expect('S01-02', 'ALREADY_EXISTS', register_customer('00000000099', 'Ana Test', 'ana@example.test'));

-- Orders: ORD-S01-1 = 2 x SKU-001 (19.90) + 1 x SKU-002 (49.90) = 89.70
SELECT qa.expect('S01-03', 'OK',               place_order('ORD-S01-1', '00000000099', 'SKU-001', 2,    '2026-02-20 10:00+00'));
SELECT qa.expect('S01-04', 'OK',               place_order('ORD-S01-1', '00000000099', 'SKU-002', 1,    '2026-02-20 10:00+00'));
SELECT qa.expect('S01-05', 'OUT_OF_STOCK',     place_order('ORD-S01-2', '00000000099', 'SKU-003', 1000, '2026-02-20 10:00+00'));
SELECT qa.expect('S01-06', 'UNKNOWN_CUSTOMER', place_order('ORD-S01-3', '99999999999', 'SKU-001', 1,    '2026-02-20 10:00+00'));
SELECT qa.expect('S01-07', 'UNKNOWN_PRODUCT',  place_order('ORD-S01-3', '00000000099', 'SKU-404', 1,    '2026-02-20 10:00+00'));
SELECT qa.expect('S01-08', 'INVALID_QTY',      place_order('ORD-S01-4', '00000000099', 'SKU-001', 0,    '2026-02-20 10:00+00'));

-- Payments: a failed attempt, then the full amount
SELECT qa.expect('S01-09', 'OK',                     pay_order('PAY-S01-F', 'ORD-S01-1', 89.70, 'failed',   '2026-02-20 11:00+00'));
SELECT qa.expect('S01-10', 'OK',                     pay_order('PAY-S01-1', 'ORD-S01-1', 89.70, 'captured', '2026-02-20 11:05+00'));
SELECT qa.expect('S01-11', 'AMOUNT_EXCEEDS_BALANCE', pay_order('PAY-S01-O', 'ORD-S01-1', 1.00,  'captured', '2026-02-20 11:10+00'));
SELECT qa.expect('S01-12', 'ORDER_NOT_FOUND',        pay_order('PAY-S01-X', 'ORD-NOPE',  1.00,  'captured', '2026-02-20 11:10+00'));
SELECT qa.expect('S01-13', 'ORDER_CLOSED',           place_order('ORD-S01-1', '00000000099', 'SKU-001', 1, '2026-02-20 12:00+00'));

-- Refunds: 10.00, then exactly the remaining 79.70 (a full refund must be accepted)
SELECT qa.expect('S01-14', 'OK',                   refund_payment('RF-S01-1', 'PAY-S01-1', 10.00, '2026-02-21 09:00+00'));
SELECT qa.expect('S01-15', 'OK',                   refund_payment('RF-S01-2', 'PAY-S01-1', 79.70, '2026-02-21 09:30+00'));
SELECT qa.expect('S01-16', 'PAYMENT_NOT_CAPTURED', refund_payment('RF-S01-3', 'PAY-S01-F', 5.00,  '2026-02-21 10:00+00'));
SELECT qa.expect('S01-17', 'PAYMENT_NOT_FOUND',    refund_payment('RF-S01-4', 'PAY-NOPE',  5.00,  '2026-02-21 10:00+00'));

-- An order belongs to one customer: nobody else can add items to it.
-- ORD-0008 is an open order of customer 00000000008 (its only payment failed).
SELECT qa.expect('S01-18', 'ORDER_NOT_YOURS', place_order('ORD-0008', '00000000099', 'SKU-001', 1, '2026-02-22 10:00+00'));
