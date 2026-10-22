-- Rule: orders.total_amount equals the sum of qty x unit_price of its order_items.
-- Risk: The customer is charged a different amount than the items in the cart.
-- Severity if violated: Critical
-- Related bug: none (baseline rule)
-- Output: one row per violation (zero rows = PASS). Suggested columns: order_ref, total_amount, items_total, difference
--
WITH items AS (
    SELECT order_id,
           SUM(qty * unit_price) AS items_total
    FROM order_items
    GROUP BY order_id
)
SELECT o.order_ref,
       o.total_amount,
       COALESCE(i.items_total, 0)                  AS items_total,
       o.total_amount - COALESCE(i.items_total, 0) AS difference
FROM orders o
LEFT JOIN items i ON i.order_id = o.id
WHERE o.total_amount IS DISTINCT FROM COALESCE(i.items_total, 0)
ORDER BY o.order_ref;
