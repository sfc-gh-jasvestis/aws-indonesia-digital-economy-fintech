# Demo Script: Fintech Lending Analytics
## ~4-Minute Recorded Walkthrough
**Format**: Screen recording with voiceover
**Target**: Customer meeting / booth loop / social share
**Narrative**: "Snowflake enables financial inclusion through alternative credit scoring — Dynamic Tables maintain real-time loan portfolios, ML.FORECAST projects default probability, and Cortex AI generates personalized collection and disbursement strategies"
**Demo Mode**: Open app with `?demo=true` for presenter notes

---

## Two Personas

| Persona | Role | Tool | What they care about |
|---|---|---|---|
| **Adi Nugroho** | Chief Risk Officer | React App (SPCS) | NPL ratio, credit loss provisioning, portfolio concentration, OJK regulatory compliance |
| **Putri Maharani** | Credit Analytics Lead | Amazon QuickSight | Alternative data scoring, vintage analysis, collection efficiency, disbursement optimization |

---

## What's Built

| Layer | Component | Detail |
|---|---|---|
| **RAW** | 6 tables | BORROWERS (3000000), LOANS (8000000), REPAYMENTS (50000000), ALTERNATIVE_DATA (10000000), COLLECTIONS (2000000), REGULATORY_REPORTS (50) |
| **CURATED** | 4 Dynamic Tables | PORTFOLIO_DASHBOARD, CREDIT_SCORE_FEATURES, VINTAGE_ANALYSIS, COLLECTION_STRATEGY |
| **ML** | ML.FORECAST | Forecasting + anomaly detection |
| **AI** | COMPLETE, AI_CLASSIFY, SUMMARIZE | Classification + extraction |
| **Search** | Cortex Search | 50 documents indexed |
| **Agent** | LENDING_INTELLIGENCE_AGENT | Semantic View + Search tools |


---

## The Story

Indonesia has 92 million unbanked adults — the largest financial inclusion opportunity in Southeast Asia. A P2P fintech lender serves 3 million borrowers using alternative data for credit scoring (phone usage, e-commerce activity, social signals). With NPL trending toward OJK's 5% threshold and a deteriorating Q2 cohort, the CRO needs real-time portfolio visibility and ML-powered early warning — not monthly batch reports.

---

## Script

### [0:00–0:45] PORTFOLIO OVERVIEW

**Show**: Portfolio Overview tab

> "Rp 18 trillion outstanding across 3 million borrowers — 92% previously unbanked."

**Action**: Point at Rp 18T outstanding and 3M borrowers

### [0:45–1:30] CREDIT ANALYTICS

**Show**: Credit Analytics tab

> "Alternative data scoring uses 45 features — phone usage and e-commerce patterns most predictive."

**Action**: Show feature importance chart for credit model

### [1:30–2:15] COLLECTION INTELLIGENCE

**Show**: Collection Intelligence tab

> "2 million collection activities analyzed — SMS at 8am achieves 3.2x response rate vs afternoon."

**Action**: Show collection channel and timing optimization

### [2:15–3:00] ASK AI

**Show**: Ask AI tab

> "Adi asks: 'What's our current NPL ratio by product?'"

**Action**: Type NPL question

### [3:00–3:45] ARCHITECTURE & DATA

**Show**: Architecture & Data tab

> "Six Snowflake capabilities, six AWS services."

**Action**: Walk through architecture diagram


---

## Key Demo Differentiators

1. **ML.FORECAST for default probability projection** — Only demo using ML.FORECAST for fintech vintage curve and default prediction
2. **Alternative data credit scoring via Dynamic Tables** — 45 alternative data features (phone, e-commerce, social) processed in real-time
3. **AI-personalized collection strategies** — Cortex AI generates borrower-specific collection timing and messaging
4. **Indonesian fintech lending context** — 92M unbanked, OJK regulatory framework, P2P platform scale


---

## Demo Prep Checklist

### Data Verification
- [ ] `SELECT COUNT(*) FROM FINTECH_LENDING.RAW.BORROWERS` → 3000000
- [ ] `SELECT COUNT(*) FROM FINTECH_LENDING.RAW.LOANS` → 8000000
- [ ] `SELECT COUNT(*) FROM FINTECH_LENDING.RAW.REPAYMENTS` → 50000000

### ML Model Verification
- [ ] `SELECT COUNT(*) FROM FINTECH_LENDING.ML.DEFAULT_PROBABILITY_FORECAST_RESULTS` → >0

### AI/Agent Verification
- [ ] `SELECT COUNT(*) FROM FINTECH_LENDING.AI.BORROWER_CLASSIFICATION` → 3000000

