-- ============================================================================
-- 10_ALERTS_NOTIFICATIONS.SQL — Alerts for Fintech Lending Analytics
-- ============================================================================
USE DATABASE FINTECH_LENDING;
USE SCHEMA APP;

-- Notification integration (email)
CREATE OR REPLACE NOTIFICATION INTEGRATION aws_indonesia_digital_economy_fintech_EMAIL_INT
  TYPE = EMAIL
  ENABLED = TRUE
  ALLOWED_RECIPIENTS = ('jonathan.asvestis@snowflake.com');

-- Alert: NPL_THRESHOLD_ALERT
CREATE OR REPLACE ALERT APP.NPL_THRESHOLD_ALERT
  WAREHOUSE = FINTECH_WH
  SCHEDULE = '5 MINUTE'
  COMMENT = 'NPL ratio exceeds 5% threshold — credit tightening review needed'
IF (EXISTS (
  SELECT 1 FROM CURATED.PORTFOLIO_DASHBOARD
  WHERE 1=1 -- Condition: 30-day NPL ratio exceeds 5% for any product
))
THEN
  CALL SYSTEM$SEND_EMAIL(
    'aws_indonesia_digital_economy_fintech_EMAIL_INT',
    'jonathan.asvestis@snowflake.com',
    '[ALERT] Fintech Lending Analytics: NPL ratio exceeds 5% threshold — credit tightening review needed',
    'NPL ratio exceeds 5% threshold — credit tightening review needed'
  );

ALTER ALERT APP.NPL_THRESHOLD_ALERT RESUME;

-- Alert: CONCENTRATION_ALERT
CREATE OR REPLACE ALERT APP.CONCENTRATION_ALERT
  WAREHOUSE = FINTECH_WH
  SCHEDULE = '5 MINUTE'
  COMMENT = 'Portfolio concentration risk — single sector exceeds 25%'
IF (EXISTS (
  SELECT 1 FROM CURATED.PORTFOLIO_DASHBOARD
  WHERE 1=1 -- Condition: Single sector exposure exceeds 25% of portfolio
))
THEN
  CALL SYSTEM$SEND_EMAIL(
    'aws_indonesia_digital_economy_fintech_EMAIL_INT',
    'jonathan.asvestis@snowflake.com',
    '[ALERT] Fintech Lending Analytics: Portfolio concentration risk — single sector exceeds 25%',
    'Portfolio concentration risk — single sector exceeds 25%'
  );

ALTER ALERT APP.CONCENTRATION_ALERT RESUME;

