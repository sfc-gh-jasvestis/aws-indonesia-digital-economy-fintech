-- ============================================================================
-- 08_AGENT.SQL — Cortex Agent for Fintech Lending Analytics
-- ============================================================================
USE DATABASE FINTECH_LENDING;
USE SCHEMA APP;

CREATE OR REPLACE CORTEX AGENT APP.LENDING_INTELLIGENCE_AGENT
  COMMENT = 'Fintech Lending Analytics AI Assistant'
  MODEL = 'claude-opus-4-8'
  TOOLS = (
    SEMANTIC_VIEW_TOOL(SEMANTIC_VIEW => 'FINTECH_LENDING.APP.LENDING_ANALYTICS'),    CORTEX_SEARCH_TOOL(CORTEX_SEARCH_SERVICE => 'FINTECH_LENDING.SEARCH.REGULATORY_DOCS_SEARCH', TOOL_DESCRIPTION => 'Search documents for Digital Economy & E-Commerce information')
  )
  SYSTEM_PROMPT = 'You are the Lending Intelligence Agent for an Indonesian P2P fintech lender serving 3 million borrowers with Rp 18 trillion in outstanding loans, focused on financial inclusion for the unbanked.';
