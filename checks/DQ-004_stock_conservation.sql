-- Rule: For each product: received_qty - stock = total qty in order_items.
-- Risk: Stock is lost or created: overselling or phantom inventory.
-- Severity if violated: Critical
-- Related bug: none (baseline rule)
-- Output: one row per violation (zero rows = PASS). Suggested columns: sku, received_qty, stock, sold_qty
--
WITH sold AS (
    SELECT product_id,
           SUM(qty) AS sold_qty
    FROM order_items
    GROUP BY product_id
)
SELECT p.sku,
       i.received_qty,
       i.stock,
       COALESCE(s.sold_qty, 0) AS sold_qty
FROM products p
LEFT JOIN inventory i ON i.product_id = p.id
LEFT JOIN sold s      ON s.product_id = p.id
WHERE (i.received_qty - i.stock) IS DISTINCT FROM COALESCE(s.sold_qty, 0)
ORDER BY p.sku;
