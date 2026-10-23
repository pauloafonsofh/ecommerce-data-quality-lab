-- Rule: daily_revenue matches the hand-computed values of scenario S03: 2026-03-10 -> items 4, gross 230.00, refunds 0, net 230.00; 2026-03-11 -> items 0, gross 0, refunds 30.00, net -30.00.
-- Risk: The revenue report overstates or understates sales, so financial decisions use wrong numbers.
-- Severity if violated: Major
-- Related bug: BUG-005
-- Output: one row per violation (zero rows = PASS). Suggested columns: day, column, expected, actual
--
WITH expected AS (
    SELECT *
    FROM (VALUES
        (DATE '2026-03-10', 4, 230.00,  0.00, 230.00),
        (DATE '2026-03-11', 0,   0.00, 30.00, -30.00)
    ) AS t(day, items_sold, gross_revenue, refunds, net_revenue)
),
comparison AS (
    SELECT e.day, 1 AS ord, 'items_sold' AS col,
           e.items_sold::numeric AS expected, v.items_sold::numeric AS actual
    FROM expected e LEFT JOIN daily_revenue v ON v.day = e.day
    UNION ALL
    SELECT e.day, 2, 'gross_revenue',
           e.gross_revenue::numeric, v.gross_revenue::numeric
    FROM expected e LEFT JOIN daily_revenue v ON v.day = e.day
    UNION ALL
    SELECT e.day, 3, 'refunds',
           e.refunds::numeric, v.refunds::numeric
    FROM expected e LEFT JOIN daily_revenue v ON v.day = e.day
    UNION ALL
    SELECT e.day, 4, 'net_revenue',
           e.net_revenue::numeric, v.net_revenue::numeric
    FROM expected e LEFT JOIN daily_revenue v ON v.day = e.day
)
SELECT day,
       col AS "column",
       expected,
       actual
FROM comparison
WHERE actual IS DISTINCT FROM expected
ORDER BY day, ord;
