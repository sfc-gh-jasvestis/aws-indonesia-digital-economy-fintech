-- ============================================================================
-- 07_SEMANTIC_VIEW.SQL — Semantic View for Fintech Lending Analytics
-- ============================================================================
USE DATABASE FINTECH_LENDING;
USE SCHEMA APP;

CREATE OR REPLACE SEMANTIC VIEW APP.LENDING_ANALYTICS
  COMMENT = 'Fintech lending portfolio, credit scoring, collections, and regulatory analytics'
AS
  TABLES (
    CURATED.PORTFOLIO_DASHBOARD AS portfolio_dashboard,CURATED.CREDIT_SCORE_FEATURES AS credit_score_features,CURATED.VINTAGE_ANALYSIS AS vintage_analysis,CURATED.COLLECTION_STRATEGY AS collection_strategy
  );
