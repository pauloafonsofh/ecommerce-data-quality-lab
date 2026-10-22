-- Rule: Every scenario step returns the status the business rule expects (table qa.scenario_results).
-- Risk: A function accepts what it should reject, or rejects what it should accept.
-- Severity if violated: High
-- Related bug: none (baseline rule)
-- Output: one row per violation (zero rows = PASS). Suggested columns: step, expected, actual
--
SELECT step, expected, actual
FROM qa.scenario_results
WHERE actual IS DISTINCT FROM expected
ORDER BY step;
