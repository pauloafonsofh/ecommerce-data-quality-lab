-- Impact of BUG-002: payments refunded for more than was paid, and the money lost.
WITH refunded AS (
  SELECT payment_id, sum(amount) AS refunded_total
  FROM refunds
  GROUP BY payment_id
)
SELECT count(*)                                         AS payments_over_refunded,
       coalesce(sum(r.refunded_total - p.amount), 0.00) AS excess_refunded
FROM payments p
JOIN refunded r ON r.payment_id = p.id
WHERE r.refunded_total > p.amount;
