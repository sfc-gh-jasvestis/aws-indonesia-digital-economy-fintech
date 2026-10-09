-- Synthetic borrower-day observations for a fictional Indonesian digital lender.
-- Nothing is seeded as a prediction. Randomness is HASH-seeded, so every rebuild
-- is reproducible: per-borrower cash-flow stress cycles that show up first in
-- e-wallet inflows and then in missed instalments, a small default cohort,
-- weekly or fortnightly instalment schedules, a regional income shock, and
-- collection contacts.
USE DATABASE IDENTIFIER($DEMO_DB);
USE SCHEMA RAW;
USE WAREHOUSE IDENTIFIER($DEMO_WH);

CREATE TABLE RAW.BORROWERS AS
WITH borrowers AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS BORROWER_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 200))
), draws AS (
  SELECT BORROWER_INDEX,
         MOD(ABS(HASH(BORROWER_INDEX, 'score')), 1000000) / 1e6 AS U_SCORE,
         MOD(ABS(HASH(BORROWER_INDEX, 'book')), 1000000) / 1e6 AS U_BOOK,
         MOD(ABS(HASH(BORROWER_INDEX, 'size')), 1000000) / 1e6 AS U_SIZE,
         MOD(ABS(HASH(BORROWER_INDEX, 'interval')), 1000000) / 1e6 AS U_INTERVAL,
         MOD(ABS(HASH(BORROWER_INDEX, 'rate')), 1000000) / 1e6 AS U_RATE,
         MOD(ABS(HASH(BORROWER_INDEX, 'phase')), 1000000) / 1e6 AS U_PHASE,
         MOD(ABS(HASH(BORROWER_INDEX, 'period')), 1000000) / 1e6 AS U_PERIOD,
         MOD(ABS(HASH(BORROWER_INDEX, 'wallet')), 1000000) / 1e6 AS U_WALLET,
         MOD(ABS(HASH(BORROWER_INDEX, 'default')), 1000000) / 1e6 AS U_DEFAULT,
         MOD(ABS(HASH(BORROWER_INDEX, 'onset')), 1000000) / 1e6 AS U_ONSET
  FROM borrowers
)
SELECT 'BRW-' || LPAD(BORROWER_INDEX::VARCHAR, 4, '0') AS ID,
       'Synthetic borrower ' || LPAD(BORROWER_INDEX::VARCHAR, 4, '0') AS NAME,
       -- Deterministic spread (5 and 8 are coprime): every city and product is present.
       CASE MOD(BORROWER_INDEX, 5) WHEN 0 THEN 'Jakarta' WHEN 1 THEN 'Surabaya'
            WHEN 2 THEN 'Bandung' WHEN 3 THEN 'Medan' ELSE 'Makassar' END AS REGION,
       CASE MOD(BORROWER_INDEX, 8) WHEN 0 THEN 'Paylater' WHEN 1 THEN 'Paylater' WHEN 2 THEN 'Paylater'
            WHEN 3 THEN 'Cash Loan' WHEN 4 THEN 'Cash Loan' WHEN 5 THEN 'MSME Working Capital'
            WHEN 6 THEN 'Invoice Financing' ELSE 'Agri Productive' END AS CATEGORY,
       BORROWER_INDEX,
       -- Synthetic alternative-data score (0-100): e-wallet, e-commerce and bill-payment history.
       ROUND(35 + U_SCORE * 60, 0) AS ALT_DATA_SCORE,
       1 + FLOOR(U_BOOK * 24) AS MONTHS_ON_BOOK,
       ROUND(CASE MOD(BORROWER_INDEX, 8) WHEN 0 THEN 1500000 WHEN 1 THEN 1500000 WHEN 2 THEN 1500000
                  WHEN 3 THEN 6000000 WHEN 4 THEN 6000000 WHEN 5 THEN 45000000
                  WHEN 6 THEN 120000000 ELSE 25000000 END * (0.6 + 0.8 * U_SIZE), -3) AS PRINCIPAL_IDR,
       7 * (1 + FLOOR(U_INTERVAL * 2)) AS INSTALMENT_INTERVAL_DAYS,
       -- Base probability of missing an instalment: weaker scores miss more; ~12% are chronic.
       (0.02 + (1 - U_SCORE) * 0.10) * IFF(U_RATE > 0.88, 2.5, 1) AS BASE_MISS_RATE,
       U_PHASE AS STRESS_PHASE,
       30 + FLOOR(U_PERIOD * 30) AS STRESS_PERIOD_DAYS,
       ROUND(CASE MOD(BORROWER_INDEX, 8) WHEN 0 THEN 180000 WHEN 1 THEN 180000 WHEN 2 THEN 180000
                  WHEN 3 THEN 350000 WHEN 4 THEN 350000 WHEN 5 THEN 2400000
                  WHEN 6 THEN 5200000 ELSE 1300000 END * (0.7 + 0.6 * U_WALLET), -3) AS BASE_WALLET_INFLOW_IDR,
       -- About 7% of borrowers (more among weak scores) stop paying from a seeded onset day.
       IFF(U_DEFAULT < 0.03 + 0.08 * (1 - U_SCORE), 15 + FLOOR(U_ONSET * 65), NULL) AS DEFAULT_ONSET_DAY,
       'Active' AS STATUS
FROM draws;

CREATE TABLE RAW.LOAN_DAILY AS
WITH days AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS DAY_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 90))
), base AS (
  SELECT b.ID AS ENTITY_ID, b.BORROWER_INDEX, b.CATEGORY, b.REGION, b.PRINCIPAL_IDR,
         b.INSTALMENT_INTERVAL_DAYS, b.BASE_MISS_RATE, b.BASE_WALLET_INFLOW_IDR,
         COALESCE(d.DAY_INDEX >= b.DEFAULT_ONSET_DAY, FALSE) AS DEFAULTED,
         COALESCE(d.DAY_INDEX >= b.DEFAULT_ONSET_DAY - 10, FALSE) AS PRE_DEFAULT,
         d.DAY_INDEX,
         DATEADD('day', d.DAY_INDEX - 89, CURRENT_DATE()) AS EVENT_DATE,
         MOD(d.DAY_INDEX + b.BORROWER_INDEX * 3, b.INSTALMENT_INTERVAL_DAYS) = 0 AS IS_DUE,
         -- Cash-flow stress cycle in [0, 1]; a 15-day regional income shock in Makassar.
         LEAST(1, 0.5 + 0.5 * SIN(2 * PI() * (d.DAY_INDEX / b.STRESS_PERIOD_DAYS + b.STRESS_PHASE))
               + IFF(b.REGION = 'Makassar' AND d.DAY_INDEX BETWEEN 48 AND 62, 0.35, 0)) AS STRESS,
         MOD(ABS(HASH(b.ID, d.DAY_INDEX, 'pay')), 1000000) / 1e6 AS U_PAY,
         MOD(ABS(HASH(b.ID, d.DAY_INDEX, 'wallet')), 1000000) / 1e6 AS U_WALLET,
         MOD(ABS(HASH(b.ID, d.DAY_INDEX, 'sessions')), 1000000) / 1e6 AS U_SESSIONS,
         MOD(ABS(HASH(b.ID, d.DAY_INDEX, 'contact')), 1000000) / 1e6 AS U_CONTACT,
         MOD(ABS(HASH(b.ID, d.DAY_INDEX, 'ptp')), 1000000) / 1e6 AS U_PTP,
         MOD(ABS(HASH(b.ID, d.DAY_INDEX, 'channel')), 1000000) / 1e6 AS U_CHANNEL
  FROM RAW.BORROWERS b CROSS JOIN days d
), dues AS (
  SELECT *,
         IFF(IS_DUE, 1, 0) AS INSTALMENT_DUE,
         IFF(IS_DUE AND (DEFAULTED OR U_PAY < LEAST(0.9, BASE_MISS_RATE * (0.2 + 2.6 * STRESS))), 1, 0) AS INSTALMENT_MISSED
  FROM base
), streaks AS (
  -- Consecutive missed instalments form one delinquency streak; a paid instalment cures it.
  SELECT *,
         SUM(IFF(IS_DUE AND INSTALMENT_MISSED = 0, 1, 0))
           OVER (PARTITION BY ENTITY_ID ORDER BY DAY_INDEX ROWS UNBOUNDED PRECEDING) AS PAID_GROUP
  FROM dues
), streak_start AS (
  SELECT *,
         MIN(IFF(INSTALMENT_MISSED = 1, DAY_INDEX, NULL))
           OVER (PARTITION BY ENTITY_ID, PAID_GROUP) AS STREAK_START_DAY
  FROM streaks
), dpd AS (
  SELECT *,
         LAST_VALUE(IFF(IS_DUE, INSTALMENT_MISSED, NULL)) IGNORE NULLS
           OVER (PARTITION BY ENTITY_ID ORDER BY DAY_INDEX ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS LAST_DUE_MISSED,
         LAST_VALUE(IFF(IS_DUE, STREAK_START_DAY, NULL)) IGNORE NULLS
           OVER (PARTITION BY ENTITY_ID ORDER BY DAY_INDEX ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS LAST_STREAK_START
  FROM streak_start
), measured AS (
  SELECT *,
         IFF(LAST_DUE_MISSED = 1, DAY_INDEX - LAST_STREAK_START, 0) AS DAYS_PAST_DUE,
         ROUND(PRINCIPAL_IDR * INSTALMENT_INTERVAL_DAYS / 180 * 1.08, -2) AS INSTALMENT_IDR
  FROM dpd
)
SELECT ENTITY_ID || '-' || TO_CHAR(EVENT_DATE, 'YYYYMMDD') AS EVENT_ID,
       ENTITY_ID, EVENT_DATE,
       INSTALMENT_DUE, INSTALMENT_MISSED,
       INSTALMENT_DUE * INSTALMENT_IDR AS AMOUNT_DUE_IDR,
       (INSTALMENT_DUE - INSTALMENT_MISSED) * INSTALMENT_IDR AS AMOUNT_PAID_IDR,
       DAYS_PAST_DUE,
       ROUND(PRINCIPAL_IDR * GREATEST(0.15, 1 - DAY_INDEX / 200), -3) AS OUTSTANDING_IDR,
       -- Collection contact on delinquent days (1-60 DPD); promise to pay on some contacts.
       IFF(DAYS_PAST_DUE BETWEEN 1 AND 60 AND U_CONTACT < 0.35, 1, 0) AS COLLECTION_CONTACT,
       IFF(DAYS_PAST_DUE BETWEEN 1 AND 60 AND U_CONTACT < 0.35 AND U_PTP < 0.75 - 0.5 * STRESS, 1, 0) AS PROMISE_TO_PAY,
       CASE WHEN NOT (DAYS_PAST_DUE BETWEEN 1 AND 60 AND U_CONTACT < 0.35) THEN 'None'
            WHEN DAYS_PAST_DUE <= 7 THEN IFF(U_CHANNEL < 0.6, 'App push', 'WhatsApp')
            WHEN DAYS_PAST_DUE <= 30 THEN IFF(U_CHANNEL < 0.5, 'WhatsApp', 'Phone call')
            ELSE IFF(U_CHANNEL < 0.7, 'Phone call', 'Field visit') END AS COLLECTION_CHANNEL,
       -- Leading indicator: e-wallet inflows fall with cash-flow stress, and sharply ~10 days before default.
       ROUND(BASE_WALLET_INFLOW_IDR * IFF(PRE_DEFAULT, 0.35, 1) * (1.3 - 0.9 * STRESS) * (0.75 + 0.5 * U_WALLET), -3) AS WALLET_INFLOW_IDR,
       ROUND(2 + 6 * (1 - STRESS) * U_SESSIONS + 2 * U_SESSIONS) AS APP_SESSIONS,
       CURRENT_TIMESTAMP() AS LOADED_AT
FROM measured;

-- e-KYC and underwriting document coverage per borrower (snapshot).
CREATE TABLE RAW.BORROWER_DOCUMENTS AS
SELECT ID AS ENTITY_ID,
       CASE CATEGORY WHEN 'Paylater' THEN 'Identity selfie check' WHEN 'Cash Loan' THEN 'Proof of income'
                     WHEN 'MSME Working Capital' THEN 'Business licence'
                     WHEN 'Invoice Financing' THEN 'Buyer invoice' ELSE 'Harvest offtake contract' END AS DOC_TYPE,
       1 + MOD(ABS(HASH(ID, 'req')), 3) AS REQUIRED_QTY,
       MOD(ABS(HASH(ID, 'file')), 4) AS ON_FILE_QTY,
       IFF(MOD(ABS(HASH(ID, 'file')), 4) < 1 + MOD(ABS(HASH(ID, 'req')), 3),
           MOD(ABS(HASH(ID, 'pending')), 3), 0) AS PENDING_QTY,
       CURRENT_DATE() AS SNAPSHOT_DATE
FROM RAW.BORROWERS;
