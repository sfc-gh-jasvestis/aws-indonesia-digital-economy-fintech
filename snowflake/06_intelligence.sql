-- ============================================================================
-- 06_INTELLIGENCE.SQL - search, anomaly detection, semantic view, agent,
-- live-repayment alert and on-demand refresh DAG.
-- Run with snowflake/run_intelligence.py (substitutes validated __DEMO_DB__ /
-- __DEMO_WH__ / __ALERT_EMAIL__). Requires 00-05, plus 08 (Snowflake only) or
-- aws/setup_aws.py (AWS build) for RAW.LIVE_REPAYMENTS.
-- Alerts and tasks are created SUSPENDED; run them with EXECUTE ALERT / EXECUTE TASK.
-- ============================================================================
USE DATABASE __DEMO_DB__;
CREATE SCHEMA IF NOT EXISTS SEARCH;
CREATE SCHEMA IF NOT EXISTS APP;

-- ---------- Synthetic collections knowledge base (clearly synthetic SOPs) ----------
-- One internal playbook per product and delinquency stage. These are fictional
-- lender procedures, not statements of regulation.
CREATE OR REPLACE TABLE SEARCH.COLLECTION_DOCS AS
WITH products AS (SELECT DISTINCT CATEGORY FROM RAW.BORROWERS),
stages AS (
  SELECT * FROM VALUES (1, '1-7 DPD'), (2, '8-30 DPD'), (3, '31+ DPD') AS s(STAGE_ORDER, DPD_BUCKET)
)
SELECT
  'SOP-' || LPAD(ROW_NUMBER() OVER (ORDER BY p.CATEGORY, s.STAGE_ORDER)::VARCHAR, 3, '0') AS DOC_ID,
  'SOP' AS DOC_TYPE,
  p.CATEGORY,
  s.DPD_BUCKET,
  p.CATEGORY || ' - ' || s.DPD_BUCKET || ' collection playbook' AS TITLE,
  'Synthetic demo SOP for a fictional lender. Product: ' || p.CATEGORY || '. Stage: ' || s.DPD_BUCKET || '. '
  || 'Step 1: confirm the instalment is unpaid in the ledger and that no payment is in transit from a bank transfer or e-wallet. '
  || 'Step 2: ' || CASE s.STAGE_ORDER
       WHEN 1 THEN 'send an in-app reminder and a WhatsApp message with the virtual account number and the amount due; offer to reschedule the due date by up to 3 days once per loan.'
       WHEN 2 THEN 'call the borrower, record the reason for the missed payment (income drop, medical, business slowdown, dispute) and agree a promise-to-pay date within 7 days.'
       ELSE 'escalate to the senior collector, review the borrower''s 14-day missed-instalment risk score and e-wallet inflow trend, and propose a restructuring plan for credit-committee approval.'
     END
  || ' Step 3: ' || CASE p.CATEGORY
       WHEN 'Paylater' THEN 'pause new paylater purchases until the account is current.'
       WHEN 'Cash Loan' THEN 'do not offer a top-up loan while any instalment is overdue.'
       WHEN 'MSME Working Capital' THEN 'ask for the latest month of merchant sales and check whether working capital is tied up in stock.'
       WHEN 'Invoice Financing' THEN 'contact the buyer named on the financed invoice to confirm the expected payment date.'
       ELSE 'check the harvest calendar and the offtake contract; a late harvest may justify moving the due date to after the sale.'
     END
  || ' Step 4: log every contact with channel and outcome. Keep contact respectful, within business hours, and only with the borrower or contacts they authorised.' AS CONTENT
FROM products p CROSS JOIN stages s;

CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH.COLLECTION_SOP_SEARCH
  ON CONTENT
  ATTRIBUTES CATEGORY, DPD_BUCKET
  WAREHOUSE = __DEMO_WH__
  TARGET_LAG = '7 days'
AS (SELECT DOC_ID, TITLE, CATEGORY, DPD_BUCKET, CONTENT FROM SEARCH.COLLECTION_DOCS);

-- ---------- E-wallet inflow anomaly detection (train first 75 days, detect last 15) ----------
CREATE OR REPLACE VIEW ML.WALLET_INFLOW_SERIES AS
SELECT ENTITY_ID, EVENT_DATE::TIMESTAMP_NTZ AS TS, (WALLET_INFLOW_IDR / 1000)::FLOAT AS INFLOW_K_IDR
FROM RAW.LOAN_DAILY;
CREATE OR REPLACE VIEW ML.WALLET_INFLOW_TRAIN AS
SELECT * FROM ML.WALLET_INFLOW_SERIES WHERE TS < (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.WALLET_INFLOW_SERIES);
CREATE OR REPLACE VIEW ML.WALLET_INFLOW_DETECT AS
SELECT * FROM ML.WALLET_INFLOW_SERIES WHERE TS >= (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.WALLET_INFLOW_SERIES);

CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION ML.WALLET_INFLOW_ANOMALY_MODEL(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.WALLET_INFLOW_TRAIN'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'INFLOW_K_IDR',
  LABEL_COLNAME => '');

CREATE OR REPLACE TABLE ML.WALLET_INFLOW_ANOMALIES AS
SELECT SERIES::VARCHAR AS ENTITY_ID, TS::DATE AS EVENT_DATE, Y AS INFLOW_K_IDR, FORECAST AS EXPECTED,
       LOWER_BOUND, UPPER_BOUND, IS_ANOMALY, PERCENTILE
FROM TABLE(ML.WALLET_INFLOW_ANOMALY_MODEL!DETECT_ANOMALIES(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.WALLET_INFLOW_DETECT'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'INFLOW_K_IDR'));

-- ---------- Semantic view ----------
CREATE OR REPLACE SEMANTIC VIEW APP.LENDING_ANALYTICS
  TABLES (
    borrowers AS CURATED.PERFORMANCE_SUMMARY PRIMARY KEY (ENTITY_ID)
      COMMENT = 'One row per borrower, 90-day totals and latest delinquency',
    risk AS ML.MISS_RISK_SCORES PRIMARY KEY (ENTITY_ID)
      COMMENT = 'Latest next-14-day missed-instalment probability per borrower',
    products AS CURATED.PRODUCT_SUMMARY PRIMARY KEY (PRODUCT)
      COMMENT = 'Instalments due, missed instalments, outstanding and PAR 30 by loan product',
    daily AS CURATED.TREND_ANALYSIS PRIMARY KEY (METRIC_DATE)
      COMMENT = 'Portfolio-wide totals per day'
  )
  RELATIONSHIPS (risk_borrower AS risk (ENTITY_ID) REFERENCES borrowers)
  FACTS (
    borrowers.due_f AS INSTALMENTS_DUE,
    borrowers.missed_f AS INSTALMENTS_MISSED,
    borrowers.paid_idr_f AS AMOUNT_PAID_IDR,
    borrowers.contacts_f AS COLLECTION_CONTACTS,
    borrowers.ptp_f AS PROMISES_TO_PAY,
    borrowers.outstanding_f AS LATEST_OUTSTANDING_IDR,
    borrowers.dpd_f AS LATEST_DPD,
    borrowers.score_f AS ALT_DATA_SCORE,
    risk.miss_prob_f AS MISS_PROB_14D,
    products.product_due_f AS INSTALMENTS_DUE,
    products.product_missed_f AS INSTALMENTS_MISSED,
    products.product_outstanding_f AS OUTSTANDING_IDR,
    products.product_par30_f AS PAR30_PCT,
    daily.day_due_f AS INSTALMENTS_DUE,
    daily.day_missed_f AS INSTALMENTS_MISSED,
    daily.day_30dpd_f AS BORROWERS_30_DPD
  )
  DIMENSIONS (
    borrowers.borrower_id AS ENTITY_ID WITH SYNONYMS = ('borrower', 'customer id', 'entity'),
    borrowers.borrower_name AS ENTITY_NAME,
    borrowers.city AS REGION WITH SYNONYMS = ('city', 'region', 'area') COMMENT = 'Indonesian city where the borrower is based',
    borrowers.product AS CATEGORY WITH SYNONYMS = ('loan product', 'product', 'segment'),
    risk.risk_band AS RISK_BAND COMMENT = 'High >= 0.5, Medium >= 0.25, else Low',
    risk.scored_as_of AS SCORED_AS_OF,
    products.product_name AS PRODUCT WITH SYNONYMS = ('loan type'),
    daily.metric_date AS METRIC_DATE
  )
  METRICS (
    borrowers.num_borrowers AS COUNT(borrowers.borrower_id)
      WITH SYNONYMS = ('entities', 'number of borrowers', 'borrower count', 'how many borrowers'),
    borrowers.on_time_repayment_rate_pct AS 100 * (SUM(borrowers.due_f) - SUM(borrowers.missed_f)) / NULLIF(SUM(borrowers.due_f), 0)
      COMMENT = 'Instalments paid on time / instalments due',
    borrowers.total_instalments_due AS SUM(borrowers.due_f) WITH SYNONYMS = ('instalments due', 'installments due'),
    borrowers.total_missed_instalments AS SUM(borrowers.missed_f) WITH SYNONYMS = ('missed payments', 'missed installments'),
    borrowers.total_collected_idr AS SUM(borrowers.paid_idr_f) WITH SYNONYMS = ('repayments collected'),
    borrowers.total_outstanding_idr AS SUM(borrowers.outstanding_f) WITH SYNONYMS = ('outstanding', 'loan book'),
    borrowers.promise_to_pay_rate_pct AS 100 * SUM(borrowers.ptp_f) / NULLIF(SUM(borrowers.contacts_f), 0)
      COMMENT = 'Promises to pay / collection contacts',
    borrowers.avg_alt_data_score AS AVG(borrowers.score_f),
    borrowers.max_days_past_due AS MAX(borrowers.dpd_f),
    risk.avg_miss_prob AS AVG(risk.miss_prob_f),
    products.product_instalments_due AS SUM(products.product_due_f),
    products.product_missed_instalments AS SUM(products.product_missed_f),
    products.product_outstanding_idr AS SUM(products.product_outstanding_f),
    products.product_par30_pct AS AVG(products.product_par30_f) COMMENT = 'Share of outstanding more than 30 days past due, per product',
    daily.daily_instalments_due AS SUM(daily.day_due_f),
    daily.daily_missed_instalments AS SUM(daily.day_missed_f),
    daily.daily_borrowers_30_dpd AS SUM(daily.day_30dpd_f)
  )
  COMMENT = 'Synthetic Indonesian digital lending analytics (demo)';

-- ---------- Cortex Agent ----------
CREATE OR REPLACE AGENT APP.COLLECTIONS_AGENT
  COMMENT = 'Collections assistant over a synthetic Indonesian digital lender'
  FROM SPECIFICATION
$$
models:
  orchestration: claude-sonnet-4-5
instructions:
  response: "Answer only from tool results. State that data is synthetic. Give borrower IDs and numbers with units (IDR, %)."
  orchestration: "Use lending_analyst for borrowers, instalments due, missed instalments, on-time repayment, outstanding, PAR 30, promise-to-pay, products, cities and risk. Use sop_search for collection procedures."
tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: lending_analyst
      description: "Borrowers, instalments due and missed, on-time repayment rate, outstanding (IDR), PAR 30, promise-to-pay rate, products, cities and 14-day missed-instalment risk scores"
  - tool_spec:
      type: cortex_search
      name: sop_search
      description: "Synthetic collection playbooks by loan product and delinquency stage"
tool_resources:
  lending_analyst:
    semantic_view: __DEMO_DB__.APP.LENDING_ANALYTICS
    execution_environment:
      type: warehouse
      warehouse: __DEMO_WH__
  sop_search:
    name: __DEMO_DB__.SEARCH.COLLECTION_SOP_SEARCH
    max_results: 3
    id_column: DOC_ID
    title_column: TITLE
$$;

-- ---------- Live-repayment alert ----------
CREATE TABLE IF NOT EXISTS APP.ALERT_LOG (
  ALERTED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(), BORROWER_ID VARCHAR,
  EVENT_TS TIMESTAMP_NTZ, AMOUNT_IDR FLOAT, DAYS_PAST_DUE NUMBER, SOP_HINT VARCHAR);

CREATE OR REPLACE NOTIFICATION INTEGRATION ID_LENDING_EMAIL_INT
  TYPE = EMAIL ENABLED = TRUE ALLOWED_RECIPIENTS = ('__ALERT_EMAIL__');

CREATE OR REPLACE PROCEDURE APP.LOG_LIVE_ALERTS()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
  n NUMBER;
BEGIN
  INSERT INTO APP.ALERT_LOG (BORROWER_ID, EVENT_TS, AMOUNT_IDR, DAYS_PAST_DUE, SOP_HINT)
    SELECT t.BORROWER_ID, t.EVENT_TS, t.AMOUNT_IDR, t.DAYS_PAST_DUE,
           'Check ' || b.CATEGORY || ' ' || CASE WHEN t.DAYS_PAST_DUE <= 7 THEN '1-7 DPD'
                                                  WHEN t.DAYS_PAST_DUE <= 30 THEN '8-30 DPD' ELSE '31+ DPD' END
           || ' playbook; current risk band ' || COALESCE(r.RISK_BAND, 'n/a')
    FROM RAW.LIVE_REPAYMENTS t
    JOIN RAW.BORROWERS b ON b.ID = t.BORROWER_ID
    LEFT JOIN ML.MISS_RISK_SCORES r ON r.ENTITY_ID = t.BORROWER_ID
    WHERE t.STATUS = 'MISSED'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.BORROWER_ID = t.BORROWER_ID AND l.EVENT_TS = t.EVENT_TS);
  n := SQLROWCOUNT;
  IF (n > 0) THEN
    CALL SYSTEM$SEND_EMAIL('ID_LENDING_EMAIL_INT', '__ALERT_EMAIL__',
      '[Demo] Missed instalment alert',
      'New missed instalments logged in APP.ALERT_LOG: ' || :n || '. Data is synthetic.');
  END IF;
  RETURN n;
END;
$$;

CREATE OR REPLACE ALERT APP.LIVE_REPAYMENT_ALERT
  WAREHOUSE = __DEMO_WH__
  SCHEDULE = '5 MINUTE'
  IF (EXISTS (
    SELECT 1 FROM RAW.LIVE_REPAYMENTS t
    WHERE t.STATUS = 'MISSED'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.BORROWER_ID = t.BORROWER_ID AND l.EVENT_TS = t.EVENT_TS)))
  THEN CALL APP.LOG_LIVE_ALERTS();

-- ---------- On-demand refresh DAG (suspended; run with EXECUTE TASK APP.TASK_REFRESH_CURATED) ----------
CREATE OR REPLACE PROCEDURE APP.REFRESH_CURATED()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN
  ALTER DYNAMIC TABLE CURATED.PERFORMANCE_SUMMARY REFRESH;
  ALTER DYNAMIC TABLE CURATED.TREND_ANALYSIS REFRESH;
  ALTER DYNAMIC TABLE CURATED.PRODUCT_SUMMARY REFRESH;
  ALTER DYNAMIC TABLE CURATED.KPI_SUMMARY REFRESH;
  RETURN 'refreshed';
END;
$$;

CREATE OR REPLACE TASK APP.TASK_REFRESH_CURATED
  WAREHOUSE = __DEMO_WH__
AS
  CALL APP.REFRESH_CURATED();

CREATE OR REPLACE TASK APP.TASK_RESCORE_RISK
  WAREHOUSE = __DEMO_WH__
  AFTER APP.TASK_REFRESH_CURATED
AS
  CREATE OR REPLACE TABLE ML.MISS_RISK_SCORES COPY GRANTS AS
  WITH latest AS (
    SELECT * FROM ML.REPAYMENT_FEATURES QUALIFY ROW_NUMBER() OVER (PARTITION BY ENTITY_ID ORDER BY EVENT_DATE DESC) = 1
  ), p AS (
    SELECT ENTITY_ID, EVENT_DATE,
           ML.MISS_RISK_MODEL!PREDICT(INPUT_DATA => OBJECT_CONSTRUCT(
             'CATEGORY', CATEGORY, 'ALT_DATA_SCORE', ALT_DATA_SCORE, 'MONTHS_ON_BOOK', MONTHS_ON_BOOK,
             'DAYS_PAST_DUE', DAYS_PAST_DUE, 'WALLET_7D_VS_30D', WALLET_7D_VS_30D,
             'APP_SESSIONS_7D', APP_SESSIONS_7D, 'MISSED_30D', MISSED_30D)) AS PRED
    FROM latest
  )
  SELECT ENTITY_ID, EVENT_DATE AS SCORED_AS_OF, ROUND(PRED:probability:MISS::FLOAT, 4) AS MISS_PROB_14D,
         CASE WHEN PRED:probability:MISS::FLOAT >= 0.5 THEN 'High'
              WHEN PRED:probability:MISS::FLOAT >= 0.25 THEN 'Medium' ELSE 'Low' END AS RISK_BAND,
         CURRENT_TIMESTAMP() AS SCORED_AT
  FROM p;
