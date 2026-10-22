-- Test support. This is NOT part of the system under test.
-- Scenarios call qa.expect() to record the status each function returned.
-- Check DQ-000 lists every step whose actual status differs from the expected one.

CREATE SCHEMA qa;

CREATE TABLE qa.scenario_results (
  step     text PRIMARY KEY,  -- e.g. 'S01-03'
  expected text NOT NULL,     -- status the business rule requires
  actual   text               -- status the function really returned
);

CREATE FUNCTION qa.expect(p_step text, p_expected text, p_actual text)
RETURNS void
LANGUAGE sql
AS $$
  INSERT INTO qa.scenario_results (step, expected, actual)
  VALUES (p_step, p_expected, p_actual);
$$;
