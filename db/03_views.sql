-- System under test: daily revenue report.
-- gross_revenue: captured payments, by payment day (UTC)
-- items_sold:    items of the orders that had a captured payment that day
-- refunds:       refunds, by refund day
-- net_revenue:   gross_revenue - refunds
CREATE VIEW daily_revenue AS
-- Add up items and payments separately BEFORE joining them:
-- joining row by row would repeat each payment once per item (and each item once per payment).
WITH items_by_order AS (
  SELECT order_id, sum(qty) AS qty
  FROM order_items
  GROUP BY order_id
),
payments_by_order_day AS (
  SELECT order_id, paid_at::date AS day, sum(amount) AS amount
  FROM payments
  WHERE status = 'captured'
  GROUP BY order_id, paid_at::date
),
sales AS (
  SELECT p.day,
         sum(coalesce(i.qty, 0)) AS items_sold,
         sum(p.amount)           AS gross_revenue
  FROM payments_by_order_day p
  LEFT JOIN items_by_order i ON i.order_id = p.order_id
  GROUP BY p.day
),
refunds_by_day AS (
  SELECT refunded_at::date AS day,
         sum(amount)       AS refunds
  FROM refunds
  GROUP BY refunded_at::date
)
SELECT coalesce(s.day, r.day)                                  AS day,
       coalesce(s.items_sold, 0)::bigint                       AS items_sold,
       coalesce(s.gross_revenue, 0)                            AS gross_revenue,
       coalesce(r.refunds, 0)                                  AS refunds,
       coalesce(s.gross_revenue, 0) - coalesce(r.refunds, 0)   AS net_revenue
FROM sales s
FULL OUTER JOIN refunds_by_day r ON r.day = s.day;
