-- ============================================================================
-- 11_TASK_PIPELINE.SQL — Task DAG for Fintech Lending Analytics
-- ============================================================================
USE DATABASE FINTECH_LENDING;
USE SCHEMA APP;

CREATE OR REPLACE TASK APP.TASK_REFRESH_PORTFOLIO
  WAREHOUSE = FINTECH_WH
  SCHEDULE = 'USING CRON 0 */2 * * * UTC'
  COMMENT = 'Refresh portfolio dashboard with latest repayment data'
AS
  SELECT 1; -- Replace with actual refresh logic

CREATE OR REPLACE TASK APP.TASK_SCORE_CREDIT
  WAREHOUSE = FINTECH_WH
  AFTER APP.TASK_REFRESH_PORTFOLIO
  COMMENT = 'Recalculate credit scores from alternative data features'
AS
  SELECT 1; -- Replace with actual refresh logic

CREATE OR REPLACE TASK APP.TASK_FORECAST_DEFAULT
  WAREHOUSE = FINTECH_WH
  AFTER APP.TASK_SCORE_CREDIT
  COMMENT = 'Run default probability forecast by cohort'
AS
  SELECT 1; -- Replace with actual refresh logic

ALTER TASK APP.TASK_FORECAST_DEFAULT RESUME;
ALTER TASK APP.TASK_SCORE_CREDIT RESUME;
ALTER TASK APP.TASK_REFRESH_PORTFOLIO RESUME;
