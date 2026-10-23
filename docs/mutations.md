# Mutations: who tests the tests

A check is only useful if it can fail. Each line below is a deliberate defect,
applied to the fixed code or to the data, with the full suite run against it.
"Caught" means at least one check went red.

**How to reproduce one:** apply the change, run `./run_tests.sh` (expect exit 1 and the checks listed),
then undo it with `git checkout .` (for data mutations, delete the scenario file you created).

## Code mutations

| ID | Mutation | How to apply | Caught by | Caught? |
|---|---|---|---|---|
| M1 | `refund_payment` ignores earlier refunds (back to the BUG-002 code) | In `db/02_functions.sql`, change `IF v_refunded + p_amount > v_paid` to `IF p_amount > v_paid` | DQ-000, DQ-005 | yes |
| M2 | `refund_payment` rejects an exact full refund | In the same line, change `>` to `>=` | DQ-000 (step S01-15) | yes |
| M3 | `daily_revenue` joins items and payments before adding up (back to the BUG-005 code) | `git show d0690a5:db/03_views.sql > db/03_views.sql` | DQ-006, DQ-007 | yes |
| M4 | `daily_revenue` also counts failed payments as revenue | In `db/03_views.sql`, delete `WHERE status = 'captured'` from `gross_by_day` | DQ-006 | yes |
| M12 | `daily_revenue` counts an order's items on every day it is paid | `git show 93ed2d5:db/03_views.sql > db/03_views.sql` | DQ-006, DQ-007 | yes |
| M10 | `refund_payment` without the row lock | In `db/02_functions.sql`, delete `FOR UPDATE` after `WHERE payment_ref = p_payment_ref` | none yet | **no: known gap** |
| M11 | `pay_order` without the row lock | In `db/02_functions.sql`, delete `FOR UPDATE` after `WHERE order_ref = p_order_ref` | none yet | **no: known gap** |

M10 and M11 only show up when two sessions work on the same row at the same time.
A single-session suite cannot see them. The concurrency test planned with BUG-001 will cover them.

## Data mutations

To apply one, save the SQL in a new file `scenarios/Z99_mutation.sql`. It runs after the other scenarios.

| ID | Mutation | SQL | Caught by | Caught? |
|---|---|---|---|---|
| M5 | A scenario step returns a status different from the expected one | `INSERT INTO qa.scenario_results VALUES ('Z-01', 'OK', 'OUT_OF_STOCK');` | DQ-000 | yes |
| M6 | An item price changes after the order total was calculated | `UPDATE order_items SET unit_price = unit_price + 1 WHERE order_id = (SELECT id FROM orders WHERE order_ref = 'ORD-0001');` | DQ-001 | yes |
| M7a | A fully paid order is marked `open` | `UPDATE orders SET status = 'open' WHERE order_ref = 'ORD-0002';` | DQ-002 | yes |
| M7b | An order with only a failed payment is marked `paid` | `UPDATE orders SET status = 'paid' WHERE order_ref = 'ORD-0008';` | DQ-002 | yes |
| M8 | A refund is saved on a failed payment | `INSERT INTO refunds (refund_ref, payment_id, amount, refunded_at) SELECT 'RF-BAD', id, 5.00, paid_at FROM payments WHERE payment_ref = 'PAY-0008';` | DQ-003 | yes |
| M9 | Stock goes up by one unit with no matching order | `UPDATE inventory SET stock = stock + 1 WHERE product_id = (SELECT id FROM products WHERE sku = 'SKU-001');` | DQ-004 | yes |

Each data mutation breaks only the rule it targets, so a red check points straight to the cause.
