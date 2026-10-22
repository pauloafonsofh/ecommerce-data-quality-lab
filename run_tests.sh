#!/usr/bin/env bash
# Runs the whole data-quality suite against a fresh local database.
#
# Order: create database -> db/*.sql -> scenarios/*.sql -> checks/*.sql -> impact/*.sql
# A check is a query that returns the rows that break one business rule.
#   PASS  = the query returned 0 rows
#   FAIL  = the query returned 1 or more rows (each row is a violation)
#   ERROR = the query itself failed (an SQL error is never a PASS)
# Exit code: 0 = all PASS, 1 = at least one FAIL, 2 = at least one ERROR or a setup problem.

set -uo pipefail
shopt -s nullglob
cd "$(dirname "$0")" || exit 2

# --- Safety: this script only ever talks to a local server -------------------
# Drop every variable that could point psql to another server or database.
unset PGHOST PGHOSTADDR PGSERVICE PGSERVICEFILE PGDATABASE
readonly HOST=127.0.0.1
readonly DB=dq_lab                 # fixed name: the script never drops any other database
PSQL="${PSQL:-psql}"
PORT="${PGPORT:-5432}"
DB_USER="${PGUSER:-postgres}"
export PGCONNECT_TIMEOUT=5 PGCLIENTENCODING=UTF8
export PGOPTIONS='-c client_min_messages=warning'

die() { echo "ERROR: $*" >&2; exit 2; }

# psql with fixed options: no psqlrc (-X), never ask for a password (-w),
# stop at the first SQL error and return a non-zero code (ON_ERROR_STOP).
run_psql() {
  local db=$1; shift
  "$PSQL" -X -w -q -h "$HOST" -p "$PORT" -U "$DB_USER" -d "$db" -v ON_ERROR_STOP=1 "$@"
}

command -v "$PSQL" > /dev/null 2>&1 \
  || die "psql not found ('$PSQL'). Add PostgreSQL's bin folder to PATH or set PSQL=/path/to/psql."

# The unset above is what keeps us local: PGHOSTADDR, for example, would win over -h.
# Now just confirm that the local server answers before changing anything.
run_psql postgres -tAc 'SELECT 1' > /dev/null \
  || die "cannot connect to PostgreSQL on $HOST:$PORT as $DB_USER"

echo "psql client : $("$PSQL" --version)"
echo "server      : $(run_psql postgres -tAc 'SELECT version()')"
echo

# --- Fresh database ------------------------------------------------------------
# WITH (FORCE) closes other open connections to dq_lab (for example, a SQL client).
run_psql postgres -c "DROP DATABASE IF EXISTS $DB WITH (FORCE)" || die "cannot drop $DB"
run_psql postgres -c "CREATE DATABASE $DB TEMPLATE template0 ENCODING 'UTF8' LOCALE 'C'" \
  || die "cannot create $DB"
# Same time zone and date style everywhere, so results do not depend on the machine.
run_psql postgres -c "ALTER DATABASE $DB SET timezone = 'UTC'" \
  -c "ALTER DATABASE $DB SET datestyle = 'ISO, MDY'" || die "cannot configure $DB"

# --- Load the system, the data and the scenarios ------------------------------
for f in db/*.sql scenarios/*.sql; do
  run_psql "$DB" -f "$f" > /dev/null || die "failed to load $f"
done

# --- Run the checks -----------------------------------------------------------
rm -rf results && mkdir -p results
exit_code=0
n_pass=0; n_fail=0; n_error=0
summary_rows=""

printf '%-8s %-52s %10s  %s\n' "ID" "Rule" "Violations" "Status"
printf '%-8s %-52s %10s  %s\n' "--" "----" "----------" "------"

for f in checks/*.sql; do
  name=$(basename "$f" .sql)          # DQ-001_order_total_matches_items
  id=${name%%_*}                      # DQ-001
  rule=${name#*_}; rule=${rule//_/ }  # order total matches items

  # Checks run read-only: a check can never change the data the next check sees.
  if PGOPTIONS="$PGOPTIONS -c default_transaction_read_only=on" \
       run_psql "$DB" -tA -f "$f" > "results/$id.txt" 2> "results/$id.err"; then
    rows=$(wc -l < "results/$id.txt" | tr -d ' ')   # one line = one violating row
    if [ "$rows" -eq 0 ]; then
      status=PASS; n_pass=$((n_pass + 1))
    else
      status=FAIL; n_fail=$((n_fail + 1))
      [ "$exit_code" -lt 1 ] && exit_code=1
    fi
  else
    rows='-'; status=ERROR; n_error=$((n_error + 1)); exit_code=2
  fi

  printf '%-8s %-52s %10s  %s\n' "$id" "$rule" "$rows" "$status"
  if [ "$status" = FAIL ]; then
    head -n 5 "results/$id.txt" | sed 's/^/           | /'
  elif [ "$status" = ERROR ]; then
    head -n 3 "results/$id.err" | sed 's/^/           ! /'
  fi
  summary_rows+="| $id | $rule | $rows | $status |"$'\n'
done

echo
echo "Checks: $((n_pass + n_fail + n_error)) total, $n_pass PASS, $n_fail FAIL, $n_error ERROR"

# --- Impact queries: how many rows and how much money each defect affects -----
impact_text=""
for f in impact/*.sql; do
  name=$(basename "$f" .sql)
  echo
  echo "== Impact: $name"
  if out=$(run_psql "$DB" -f "$f" 2>&1); then
    echo "$out"
    impact_text+="#### $name"$'\n```\n'"$out"$'\n```\n'
  else
    echo "$out"; echo "ERROR: impact query $f failed" >&2; exit_code=2
  fi
done

# --- GitHub Actions job summary (only when running in CI) ---------------------
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "### Data-quality checks"
    echo
    echo "| ID | Rule | Violations | Status |"
    echo "|---|---|---|---|"
    printf '%s' "$summary_rows"
    echo
    echo "**$n_pass PASS, $n_fail FAIL, $n_error ERROR**"
    if [ -n "$impact_text" ]; then
      echo
      echo "### Impact"
      printf '%s' "$impact_text"
    fi
  } >> "$GITHUB_STEP_SUMMARY"
fi

exit "$exit_code"
