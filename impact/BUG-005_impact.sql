-- Impact of BUG-005: days where the report shows a different gross revenue than the payments,
-- and the total revenue overstated by the report.
WITH paid AS (
  SELECT paid_at::date AS day, sum(amount) AS gross_revenue
  FROM payments
  WHERE status = 'captured'
  GROUP BY paid_at::date
)
SELECT count(*)                                              AS days_affected,
       coalesce(sum(v.gross_revenue - p.gross_revenue), 0.00) AS revenue_overstated
FROM daily_revenue v
JOIN paid p ON p.day = v.day
WHERE v.gross_revenue <> p.gross_revenue;
