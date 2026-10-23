-- Rule: For each payment, the sum of all its refunds is never greater than the payment amount.
-- Risk: The customer gets back more money than they paid (direct money loss).
-- Severity if violated: Critical
-- Related bug: BUG-002
-- Output: one row per violation (zero rows = PASS). Suggested columns: payment_ref, amount, refunded_total, excess
--
WITH refunded AS (
    SELECT payment_id,
           SUM(amount) AS refunded_total
    FROM refunds
    GROUP BY payment_id
)
SELECT p.payment_ref,
       p.amount,
       r.refunded_total,
       r.refunded_total - p.amount AS excess
FROM payments p
JOIN refunded r ON r.payment_id = p.id
WHERE r.refunded_total > p.amount
ORDER BY p.payment_ref;
