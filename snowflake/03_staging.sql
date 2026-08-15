-- ============================================================================
-- 03_STAGING.SQL — Generate synthetic data for Fintech Lending Analytics
-- Country: INDONESIA | Currency: IDR
-- ============================================================================
USE DATABASE FINTECH_LENDING;
USE SCHEMA RAW;

-- Data generation scripts are demo-specific.
-- See the handcrafted SQL in the aws-malaysia-semiconductor-yield demo for
-- the full pattern: GENERATOR + UNIFORM + LATERAL for distribution,
-- Cortex Complete for text generation, engineered key demo numbers.

-- Target row counts:
-- BORROWERS: 3,000,000 rows — Borrower profiles with demographics, alternative data, and credit scores
-- LOANS: 8,000,000 rows — Loan records with disbursement, repayment schedule, and status
-- REPAYMENTS: 50,000,000 rows — Individual repayment transactions with timing and amount
-- ALTERNATIVE_DATA: 10,000,000 rows — Phone usage, e-commerce activity, and social signals for scoring
-- COLLECTIONS: 2,000,000 rows — Collection activities, contact attempts, and resolution outcomes
-- REGULATORY_REPORTS: 50 rows — OJK regulatory submissions, audit reports, and compliance documentation
