-- Rule: Refunds exist only for payments with status 'captured'.
-- Risk: Money is returned for a payment that never happened.
-- Severity if violated: Critical
-- Related bug: none (baseline rule)
-- Output: one row per violation (zero rows = PASS). Suggested columns: refund_ref, payment_ref, payment_status
--
SELECT r.refund_ref,
       p.payment_ref,
       p.status AS payment_status
FROM refunds r
LEFT JOIN payments p ON p.id = r.payment_id
WHERE p.status IS DISTINCT FROM 'captured'
ORDER BY r.refund_ref;
