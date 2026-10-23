# Mutations: who tests the tests

A check is only useful if it can fail. Each line below is a deliberate defect,
applied to the fixed code or to the data, with the full suite run against it.
"Caught" means at least one check went red.

## Code mutations

| ID | Mutation | Caught by | Caught? |
|---|---|---|---|
| M1 | `refund_payment` ignores earlier refunds (back to the BUG-002 code) | DQ-000, DQ-005 | yes |
| M2 | `refund_payment` uses `>=` instead of `>`, so an exact full refund is rejected | DQ-000 (step S01-15) | yes |
| M3 | `daily_revenue` joins items and payments before adding up (back to the BUG-005 code) | DQ-006, DQ-007 | yes |
| M4 | `daily_revenue` also counts failed payments as revenue | DQ-006 | yes |
| M10 | `refund_payment` without the row lock (`FOR UPDATE`) | none yet | **no: known gap** |

M10 only shows up when two sessions refund the same payment at the same time.
A single-session suite cannot see it. The concurrency test planned with BUG-001 will cover it.

## Data mutations

| ID | Mutation | Caught by | Caught? |
|---|---|---|---|
| M5 | A scenario step returns a status different from the expected one | DQ-000 | yes |
| M6 | An item price changes after the order total was calculated | DQ-001 | yes |
| M7a | A fully paid order is marked `open` | DQ-002 | yes |
| M7b | An order with only a failed payment is marked `paid` | DQ-002 | yes |
| M8 | A refund is saved on a failed payment | DQ-003 | yes |
| M9 | Stock goes up by one unit with no matching order | DQ-004 | yes |

Each data mutation breaks only the rule it targets, so a red check points straight to the cause.
