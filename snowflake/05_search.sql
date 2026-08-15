-- ============================================================================
-- 05_SEARCH.SQL — Cortex Search for Fintech Lending Analytics
-- ============================================================================
USE DATABASE FINTECH_LENDING;
USE SCHEMA SEARCH;

CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH.REGULATORY_DOCS_SEARCH
  ON CONTENT
  ATTRIBUTES DOC_TYPE, REGULATION_REF
  WAREHOUSE = FINTECH_WH
  TARGET_LAG = '1 hour'
AS (
  SELECT * FROM RAW.REGULATORY_REPORTS
);
