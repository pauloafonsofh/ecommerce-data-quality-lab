-- System under test: daily revenue report.
-- gross_revenue: captured payments, by payment day (UTC)
-- items_sold:    items of the orders that had a captured payment that day
-- refunds:       refunds, by refund day
-- net_revenue:   gross_revenue - refunds
CREATE VIEW daily_revenue AS
WITH sales AS (
  SELECT p.paid_at::date AS day,
         sum(oi.qty)     AS items_sold,
         sum(p.amount)   AS gross_revenue
  FROM orders o
  JOIN order_items oi ON oi.order_id = o.id
  JOIN payments p     ON p.order_id = o.id
  WHERE p.status = 'captured'
  GROUP BY p.paid_at::date
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
