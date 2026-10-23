# Test strategy

## Scope

The system under test is a small online store inside PostgreSQL 17:
orders, stock, payments, refunds and a daily revenue report.
The goal is to find **silent data defects**: results that look right but are wrong.

In scope: business rules on stored data, function results, and the revenue report.
Out of scope: user interface, HTTP APIs, performance and load.

## Approach

1. List the business rules first, without looking at the code.
2. Write one check per rule. A check is a SQL query that returns the rows that break the rule.
   Zero rows means PASS.
3. Run every check on a fresh database, with the same data, on every push (GitHub Actions).
4. When a check fails, write a defect report, fix the code in a pull request,
   and keep the check as a regression test.

Isolation level: READ COMMITTED (PostgreSQL default). Time zone: UTC.

## Rule catalog

| Rule | Description | How it is enforced | Check | Status |
|---|---|---|---|---|
| R01 | Every scenario step returns the expected status | check | DQ-000 | active |
| R02 | Order total = sum of qty x unit_price of its items | check | DQ-001 | active |
| R03 | An order is paid if and only if captured payments = order total | check | DQ-002 | active |
| R04 | Refunds exist only for captured payments | function + check | DQ-003 | active |
| R05 | Stock is conserved: received - stock = units sold | check | DQ-004 | active |
| R06 | Total refunded for a payment never exceeds the amount paid | function + check | DQ-005 | BUG-002 |
| R07 | Daily revenue report = independent sum of payments and refunds | check | DQ-006 | BUG-005 |
| R08 | Daily revenue report = hand-computed values for a known data set | check | DQ-007 | BUG-005 |
| R09 | One customer per tax ID, whatever the formatting | constraint + check | planned | BUG-003 |
| R10 | Imported order date = date written in the source file | check | planned | BUG-004 |
| R11 | Imported dates use a known format | check | planned | BUG-004 |
| R12 | Stock is never negative | constraint (`CHECK stock >= 0`) | none | prevented by design |

Other rules prevented by design (constraints, no check needed):
positive amounts and quantities, foreign keys, unique references
(`order_ref`, `payment_ref`, `refund_ref`, `sku`).

## Prevent or detect?

- **Rule about one row** (a value, a range, a format): use a constraint.
  The database rejects the bad row before it is saved.
- **Rule across rows or tables** (sums, totals, "paid if and only if"): a constraint cannot see other rows.
  The function must enforce it (with a row lock when two sessions can race),
  and a check detects any violation that still gets in, including old data.
- A constraint can be dropped in a migration. A check keeps watching.

## Risk

| Risk | Impact | Likelihood | Rules |
|---|---|---|---|
| Customer refunded more than paid | High (direct money loss) | Medium (partial refunds are common) | R06 |
| Revenue report overstates sales | High (wrong financial decisions) | High (every order with more than one item) | R07, R08 |
| Two customers buy the last unit | High (oversell, cancelled orders) | Medium (peak sales) | R05 |
| Duplicate customer records | Medium (split history, wrong limits) | Medium (manual typing) | R09 |
| Day and month swapped on import | Medium (wrong reports and deadlines) | Low (legacy import only) | R10, R11 |

The impact of each defect in rows and money comes from the queries in `impact/`, which run in CI.

## Who tests the tests

- A check that is not written yet returns one row (FAIL), never zero rows.
- An SQL error in a check is reported as ERROR and fails the run (exit code 2). It is never a PASS.
- Each check was proven against a deliberate data corruption (see `docs/mutations.md`).

## Exit criteria

- All checks PASS on `main` (CI green).
- Zero Critical rule violated.
- Every mutation in `docs/mutations.md` is caught by at least one check.
