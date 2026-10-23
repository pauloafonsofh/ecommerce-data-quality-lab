-- Rule: For every day, daily_revenue (items_sold, gross_revenue, refunds) equals the same numbers computed directly from order_items, payments and refunds.
-- Risk: The revenue report overstates or understates sales, so financial decisions use wrong numbers.
-- Severity if violated: Major
-- Related bug: BUG-005
-- Output: one row per violation (zero rows = PASS). Suggested columns: day, report_items, real_items, report_gross, real_gross, report_refunds, real_refunds
--
WITH gross_by_day AS (
    -- gross revenue: captured payments by payment day
    SELECT paid_at::date AS day,
           SUM(amount)   AS gross_revenue
    FROM payments
    WHERE status = 'captured'
    GROUP BY paid_at::date
),
paid_orders_by_day AS (
    -- each order counted once per day, even with 2+ captured payments that day
    SELECT DISTINCT
           order_id,
           paid_at::date AS day
    FROM payments
    WHERE status = 'captured'
),
items_by_order AS (
    SELECT order_id,
           SUM(qty) AS qty
    FROM order_items
    GROUP BY order_id
),
items_by_day AS (
    SELECT po.day,
           SUM(COALESCE(io.qty, 0)) AS items_sold
    FROM paid_orders_by_day po
    LEFT JOIN items_by_order io ON io.order_id = po.order_id
    GROUP BY po.day
),
refunds_by_day AS (
    SELECT refunded_at::date AS day,
           SUM(amount)       AS refunds
    FROM refunds
    GROUP BY refunded_at::date
),
calculated AS (
    SELECT COALESCE(g.day, r.day)          AS day,
           COALESCE(i.items_sold, 0)       AS items_sold,
           COALESCE(g.gross_revenue, 0)    AS gross_revenue,
           COALESCE(r.refunds, 0)          AS refunds
    FROM gross_by_day g
    LEFT JOIN items_by_day i    ON i.day = g.day
    FULL OUTER JOIN refunds_by_day r ON r.day = g.day
)
SELECT COALESCE(v.day, c.day) AS day,
       v.items_sold           AS view_items_sold,
       c.items_sold           AS calc_items_sold,
       v.gross_revenue        AS view_gross_revenue,
       c.gross_revenue        AS calc_gross_revenue,
       v.refunds              AS view_refunds,
       c.refunds              AS calc_refunds
FROM daily_revenue v
FULL OUTER JOIN calculated c ON c.day = v.day
WHERE v.items_sold    IS DISTINCT FROM c.items_sold
   OR v.gross_revenue IS DISTINCT FROM c.gross_revenue
   OR v.refunds       IS DISTINCT FROM c.refunds
ORDER BY 1;
