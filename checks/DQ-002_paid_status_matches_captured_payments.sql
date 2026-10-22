-- Rule: An order is 'paid' if and only if the sum of its captured payments equals its total_amount.
-- Risk: Goods are shipped without payment, or a paid order stays open.
-- Severity if violated: Critical
-- Related bug: none (baseline rule)
-- Output: one row per violation (zero rows = PASS). Suggested columns: order_ref, status, total_amount, captured_total
--
WITH captured AS (
    SELECT order_id,
           SUM(amount) AS captured_total
    FROM payments
    WHERE status = 'captured'
    GROUP BY order_id
)
SELECT o.order_ref,
       o.status,
       o.total_amount,
       COALESCE(c.captured_total, 0) AS captured_total
FROM orders o
LEFT JOIN captured c ON c.order_id = o.id
WHERE (o.status = 'paid'
       AND COALESCE(c.captured_total, 0) IS DISTINCT FROM o.total_amount)
   OR (o.status IS DISTINCT FROM 'paid'
       AND COALESCE(c.captured_total, 0) = o.total_amount)
ORDER BY o.order_ref;
