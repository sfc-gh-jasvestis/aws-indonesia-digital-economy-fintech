-- ============================================================================
-- 04_DYNAMIC_TABLES.SQL — Curated layer for Fintech Lending Analytics
-- ============================================================================
USE DATABASE FINTECH_LENDING;
USE SCHEMA CURATED;

-- PORTFOLIO_DASHBOARD: Real-time loan portfolio metrics: NPL, PAR, disbursement rate, collection efficiency
-- Source: LOANS, REPAYMENTS, COLLECTIONS
CREATE OR REPLACE DYNAMIC TABLE CURATED.PORTFOLIO_DASHBOARD
  TARGET_LAG = '5 minutes'
  WAREHOUSE = FINTECH_WH
AS
SELECT * FROM RAW.LOANS;
-- TODO: Replace with actual join/aggregation logic per demo

-- CREDIT_SCORE_FEATURES: Alternative data feature engineering for credit scoring model input
-- Source: BORROWERS, ALTERNATIVE_DATA
CREATE OR REPLACE DYNAMIC TABLE CURATED.CREDIT_SCORE_FEATURES
  TARGET_LAG = '5 minutes'
  WAREHOUSE = FINTECH_WH
AS
SELECT * FROM RAW.BORROWERS;
-- TODO: Replace with actual join/aggregation logic per demo

-- VINTAGE_ANALYSIS: Loan cohort vintage curves for credit loss estimation
-- Source: LOANS, REPAYMENTS
CREATE OR REPLACE DYNAMIC TABLE CURATED.VINTAGE_ANALYSIS
  TARGET_LAG = '5 minutes'
  WAREHOUSE = FINTECH_WH
AS
SELECT * FROM RAW.LOANS;
-- TODO: Replace with actual join/aggregation logic per demo

-- COLLECTION_STRATEGY: Borrower-level collection priority scoring and optimal contact strategy
-- Source: LOANS, COLLECTIONS, REPAYMENTS
CREATE OR REPLACE DYNAMIC TABLE CURATED.COLLECTION_STRATEGY
  TARGET_LAG = '5 minutes'
  WAREHOUSE = FINTECH_WH
AS
SELECT * FROM RAW.LOANS;
-- TODO: Replace with actual join/aggregation logic per demo

