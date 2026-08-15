-- ============================================================================
-- Fintech Lending Analytics
-- Alternative credit scoring for Indonesia's 92M unbanked population — ML.FORECAST predicts repayment trajectories, Dynamic Tables build real-time loan portfolios, and Cortex AI generates collection strategies.
-- ============================================================================
USE ROLE ACCOUNTADMIN;
CREATE DATABASE IF NOT EXISTS FINTECH_LENDING;
CREATE WAREHOUSE IF NOT EXISTS FINTECH_WH WAREHOUSE_SIZE = 'MEDIUM' AUTO_SUSPEND = 120 AUTO_RESUME = TRUE;
USE DATABASE FINTECH_LENDING;
CREATE SCHEMA IF NOT EXISTS RAW;
CREATE SCHEMA IF NOT EXISTS CURATED;
CREATE SCHEMA IF NOT EXISTS ML;
CREATE SCHEMA IF NOT EXISTS AI;
CREATE SCHEMA IF NOT EXISTS SEARCH;
CREATE SCHEMA IF NOT EXISTS APP;

USE WAREHOUSE FINTECH_WH;
