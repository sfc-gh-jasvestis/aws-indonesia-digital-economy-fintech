# Fintech Lending Analytics

**Indonesia - Digital Economy & E-Commerce**
Use case: Fintech Lending & Credit Scoring

> Alternative credit scoring for Indonesia's 92M unbanked population — ML.FORECAST predicts repayment trajectories, Dynamic Tables build real-time loan portfolios, and Cortex AI generates collection strategies.

## Why Snowflake

Snowflake enables financial inclusion through alternative credit scoring — Dynamic Tables maintain real-time loan portfolios, ML.FORECAST projects default probability, and Cortex AI generates personalized collection and disbursement strategies

- **ML.FORECAST for default probability projection** - Only demo using ML.FORECAST for fintech vintage curve and default prediction
- **Alternative data credit scoring via Dynamic Tables** - 45 alternative data features (phone, e-commerce, social) processed in real-time
- **AI-personalized collection strategies** - Cortex AI generates borrower-specific collection timing and messaging
- **Indonesian fintech lending context** - 92M unbanked, OJK regulatory framework, P2P platform scale

## What is deployed

| | |
|---|---|
| Database | `ID_DIGITAL_ECONOMY_FINTECH` |
| Service | `ID_DIGITAL_ECONOMY_FINTECH_APP` |
| Compute pool | `SEA_DEMOS_INDONESIA_POOL` |
| Dimension table | `RAW.REGULATORY_REPORTS` (20 rows) |
| Fact table | `RAW.REPAYMENTS` (250,000 rows, 90 days) |
| Curated layer | `CURATED.PERFORMANCE_SUMMARY`, `CURATED.TREND_ANALYSIS`, `CURATED.KPI_SUMMARY` |
| Currency | IDR (Rp) |

Regions in play: Jakarta, North Sumatra, Riau, East Kalimantan, Sulawesi
Segments: Payday Loan, Merchant Cash Advance, BNPL, Multiguna

Dynamic tables are created suspended and refreshed on demand:

```bash
./refresh_demo_data.sh ID_DIGITAL_ECONOMY_FINTECH
```

## KPI cards

Every card below is served live from `CURATED.KPI_SUMMARY`. The app keeps the
original literal as a fallback, so it still renders if Snowflake is unreachable.

| Card | Value | Backed by |
|---|---|---|
| AUM (Total) | `Rp 12.4T` | total across Regulatory Reports |
| Active Users | `8.2M` | total across Regulatory Reports |
| NPL Ratio | `2.1%` | average per event |
| Transactions (MTD) | `47M` | total across Regulatory Reports |
| Approval Rate | `34%` | average per event |
| Avg Ticket Size | `Rp 4.2M` | average per event |
| Collection Rate | `97.8%` | average per event |


## Demo flow

1. Portfolio Overview
2. Credit Analytics
3. Collection Intelligence
4. Ask AI
5. Architecture & Data

## Talking points

- **3M borrowers** - 92% previously unbanked
- **Rp 18T outstanding** - loan portfolio across personal and productive loans
- **4.2% NPL** - non-performing loan ratio (OJK threshold: 5%)
- **45 features** - alternative data signals for credit scoring
- **87% collection** - collection efficiency rate

## Business impact

- Indonesia has 92 million unbanked adults — second largest globally after India (World Bank Findex)
- Indonesian P2P lending industry disbursed Rp 82 trillion in 2023 across 102 platforms (OJK)
- Alternative data scoring increases approval rates by 30-50% vs traditional bureau-only (CGAP)
- AI-optimized collections improve recovery rates by 20-35% in emerging market lending (McKinsey Banking)

---
Generated from `generator/demo_specs/aws-indonesia-digital-economy-fintech.json`. Do not hand-edit: run
`python3 generator/gen_repo_docs.py aws-indonesia-digital-economy-fintech` instead.
