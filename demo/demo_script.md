# Indonesia Digital Lending

**Indonesia - Digital Lending**
Use case: Repayment risk and collections

> Repayment monitoring for 200 borrowers of a fictional Indonesian digital lender across 5 cities: dynamic tables, a holdout-evaluated missed-instalment classifier, a missed-instalment forecast, e-wallet inflow anomalies and grounded AI answers.

## Why Snowflake

- **Dynamic tables** reconcile instalments due, missed instalments, PAR 30 and promise-to-pay from RAW borrower data, with checks in `run_core.py`
- **Missed-instalment classification** gives a holdout-evaluated next-14-day probability per borrower
- **Missed-instalment forecast** projects 14 days of portfolio-wide missed instalments with prediction intervals, for collection-team staffing
- **Grounded AI**: the Cortex Agent (Analyst over a semantic view, plus Search over playbooks) shows its SQL and playbook citations
- **Live repayments**: a native simulator (Snowflake only) or Firehose, S3 and Snowpipe (AWS build), then an alert and email

## What is built

| | |
|---|---|
| Dimension table | `RAW.BORROWERS` (200 rows) |
| Fact table | `RAW.LOAN_DAILY` (18,000 borrower-days, 90 days) |
| Curated layer | `CURATED.KPI_SUMMARY`, `PERFORMANCE_SUMMARY`, `PRODUCT_SUMMARY`, `TREND_ANALYSIS` |
| ML | `ML.MISS_RISK_SCORES`, `ML.MISS_RISK_HOLDOUT_METRICS`, `ML.MISSED_FORECAST`, `ML.WALLET_INFLOW_ANOMALIES` |

Cities: Jakarta, Surabaya, Bandung, Medan, Makassar.
Loan products: Paylater, Cash Loan, MSME Working Capital, Invoice Financing, Agri Productive.

## KPI cards (live from `CURATED.KPI_SUMMARY`; no fallback values)

| Card | Value from the seeded data |
|---|---|
| On-time Repayment Rate | 84.5% |
| Instalments Due | 1,918 |
| Missed Instalments | 297 |
| PAR 30 | 7.0% |
| Outstanding (IDR bn) | 3.0 |
| Promise-to-Pay Rate | 45.9% |
| Borrowers | 200 |
| Document Coverage | 59.0% |
| Documents Pending | 114 |

Values are synthetic. A rebuild reproduces them because the data is HASH-seeded; dates are relative to the build day.

## Demo flow

1. Executive Cockpit: KPIs, daily instalments due against missed, instalments by product, borrower table
2. Predictive: holdout metrics, risk bands, 14-day missed-instalment forecast, e-wallet inflow drops
3. Collections: promise-to-pay rate, document coverage and pending documents, alternative-data score against missed instalments, then generate the action memo
4. Live Repayments: run `CALL APP.SIMULATE_REPAYMENTS(20)` (Snowflake only) or `python aws/publish_repayments.py --count 20` (AWS build). Then run `EXECUTE ALERT APP.LIVE_REPAYMENT_ALERT` and show the alert log and email.
5. Ask AI: the Cortex Agent answers metric questions through the semantic view and cites playbooks from Cortex Search. The SQL is shown.
6. QuickSight (AWS build): the same Snowflake tables through DIRECT_QUERY
7. Architecture: both builds side by side

## Talking points

- About one instalment in six is missed (84.5% on time). PAR 30 is 7.0% of outstanding, concentrated in a small cohort of borrowers who stopped paying.
- Invoice Financing carries the highest PAR 30 (9.8%); MSME Working Capital has the lowest on-time rate (79.2%). Makassar trails the other cities after a regional income shock in the synthetic data.
- E-wallet inflows fall before missed instalments in this data, which is why the inflow trend is a model feature and an anomaly signal.
- The risk model is evaluated on a time-based holdout: precision 0.34 and recall 0.22 at 0.5, against a 0.21 base rate. Present it as triage for collectors, not a credit decision.
- Borrowers already more than 30 days past due are excluded from training and evaluation, because their next missed instalment is not a prediction.

## Business impact

Use only the sourced references in `README.md` (Business Impact).
