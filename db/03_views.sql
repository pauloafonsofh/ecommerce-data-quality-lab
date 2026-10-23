-- System under test: daily revenue report.
-- gross_revenue: captured payments, by payment day (UTC)
-- items_sold:    items of each order, counted once, on the day of its FIRST captured payment
-- refunds:       refunds, by refund day
-- net_revenue:   gross_revenue - refunds
CREATE VIEW daily_revenue AS
-- Add up payments and items separately BEFORE joining them:
-- joining row by row would repeat each payment once per item (and each item once per payment).
WITH gross_by_day AS (
  SELECT paid_at::date AS day, sum(amount) AS gross_revenue
  FROM payments
  WHERE status = 'captured'
  GROUP BY paid_at::date
),
first_paid_day AS (
  -- one day per order, even when it is paid in several parts on several days
  SELECT order_id, min(paid_at)::date AS day
  FROM payments
  WHERE status = 'captured'
  GROUP BY order_id
),
items_by_order AS (
  SELECT order_id, sum(qty) AS qty
  FROM order_items
  GROUP BY order_id
),
items_by_day AS (
  SELECT f.day, sum(coalesce(i.qty, 0)) AS items_sold
  FROM first_paid_day f
  LEFT JOIN items_by_order i ON i.order_id = f.order_id
  GROUP BY f.day
),
refunds_by_day AS (
  SELECT refunded_at::date AS day, sum(amount) AS refunds
  FROM refunds
  GROUP BY refunded_at::date
)
SELECT coalesce(g.day, r.day)                                        AS day,
       coalesce(i.items_sold, 0)::bigint                             AS items_sold,
       coalesce(g.gross_revenue, 0.00)                               AS gross_revenue,
       coalesce(r.refunds, 0.00)                                     AS refunds,
       coalesce(g.gross_revenue, 0.00) - coalesce(r.refunds, 0.00)   AS net_revenue
FROM gross_by_day g
LEFT JOIN items_by_day i ON i.day = g.day
FULL OUTER JOIN refunds_by_day r ON r.day = g.day;
