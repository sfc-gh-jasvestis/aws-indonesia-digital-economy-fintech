-- ============================================================================
-- 08_native_repayments.sql - Snowflake-only build: live repayment feed without AWS.
-- Creates RAW.LIVE_REPAYMENTS (same columns as the Snowpipe target created by
-- aws/setup_aws.py) and APP.SIMULATE_REPAYMENTS(N), which inserts synthetic
-- instalment events with the same value ranges and ~10% MISSED rate as
-- aws/publish_repayments.py. Rows are inserted directly; this simulates a
-- repayment feed and is not Snowpipe Streaming.
-- Run before 06_intelligence.sql (the alert reads RAW.LIVE_REPAYMENTS).
-- Idempotent: safe to run in the AWS build too.
-- ============================================================================
CREATE SCHEMA IF NOT EXISTS RAW;
CREATE SCHEMA IF NOT EXISTS APP;

CREATE TABLE IF NOT EXISTS RAW.LIVE_REPAYMENTS (
  BORROWER_ID VARCHAR, EVENT_TS TIMESTAMP_NTZ, AMOUNT_IDR FLOAT, DAYS_PAST_DUE NUMBER,
  STATUS VARCHAR, SENT_TS TIMESTAMP_NTZ, SOURCE_FILE VARCHAR,
  LOADED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP());

CREATE OR REPLACE PROCEDURE APP.SIMULATE_REPAYMENTS(N NUMBER)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN
  IF (N < 1 OR N > 1000) THEN
    RETURN 0;
  END IF;
  INSERT INTO RAW.LIVE_REPAYMENTS (BORROWER_ID, EVENT_TS, AMOUNT_IDR, DAYS_PAST_DUE, STATUS, SENT_TS, SOURCE_FILE)
    WITH g AS (
      SELECT 'BRW-' || LPAD(UNIFORM(0, 199, RANDOM())::VARCHAR, 4, '0') AS BORROWER_ID,
             UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) < 0.1 AS IS_MISSED,
             SYSDATE() AS TS, SEQ4() AS I
      FROM TABLE(GENERATOR(ROWCOUNT => 1000))
    )
    -- NORMAL() needs a constant mean, so the amount is scaled outside it.
    SELECT BORROWER_ID, TS,
           ROUND(450000 * EXP(NORMAL(0, 0.6, RANDOM())), -2),
           IFF(IS_MISSED, UNIFORM(1, 45, RANDOM()), 0),
           IFF(IS_MISSED, 'MISSED', 'PAID'), TS, 'APP.SIMULATE_REPAYMENTS'
    FROM g
    WHERE I < :N;
  RETURN SQLROWCOUNT;
END;
$$;

-- Optional continuous feed for longer demos (suspended; RESUME to start, SUSPEND after).
CREATE OR REPLACE TASK APP.TASK_SIMULATE_REPAYMENTS
  WAREHOUSE = __DEMO_WH__
  SCHEDULE = '1 MINUTE'
AS
  CALL APP.SIMULATE_REPAYMENTS(5);
