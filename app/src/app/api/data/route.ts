import { NextResponse } from 'next/server';
import { demoPlatform } from '@/lib/platform';
import { executeQuery } from '@/lib/snowflake';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

export async function GET() {
  try {
    const [kpis, trend, products, borrowers, freshness, risk, holdout, forecast, live, liveSummary, anomalies, alerts] = await Promise.all([
      executeQuery<{ TITLE: string; DISPLAY: string; STATUS: string }>(
        'SELECT TITLE, DISPLAY, STATUS FROM CURATED.KPI_SUMMARY ORDER BY SORT_ORDER'),
      executeQuery<{ PERIOD: string; DUE: number | null; MISSED: number | null }>(`
        SELECT TO_CHAR(METRIC_DATE, 'YYYY-MM-DD') AS PERIOD,
               INSTALMENTS_DUE AS DUE, INSTALMENTS_MISSED AS MISSED
        FROM CURATED.TREND_ANALYSIS ORDER BY METRIC_DATE`),
      executeQuery<{ PRODUCT: string; DUE: number; MISSED: number }>(`
        SELECT PRODUCT, INSTALMENTS_DUE AS DUE, INSTALMENTS_MISSED AS MISSED
        FROM CURATED.PRODUCT_SUMMARY ORDER BY INSTALMENTS_MISSED DESC, INSTALMENTS_DUE DESC`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT ENTITY_ID, ENTITY_NAME, REGION, CATEGORY, ALT_DATA_SCORE, EVENT_COUNT, INSTALMENTS_DUE, INSTALMENTS_MISSED,
               ROUND(ON_TIME_RATE_PCT, 1) AS ON_TIME_RATE_PCT, LATEST_DPD, ROUND(LATEST_OUTSTANDING_IDR / 1e6, 2) AS OUTSTANDING_IDR_M
        FROM CURATED.PERFORMANCE_SUMMARY ORDER BY ENTITY_ID LIMIT 200`),
      executeQuery<{ RAW_WATERMARK: string | null; CURATED_WATERMARK: string | null }>(`
        SELECT (SELECT TO_CHAR(MAX(EVENT_DATE), 'YYYY-MM-DD') FROM RAW.LOAN_DAILY) AS RAW_WATERMARK,
               (SELECT TO_CHAR(MAX(METRIC_DATE), 'YYYY-MM-DD') FROM CURATED.TREND_ANALYSIS) AS CURATED_WATERMARK`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT ENTITY_ID, TO_CHAR(SCORED_AS_OF, 'YYYY-MM-DD') AS SCORED_AS_OF, MISS_PROB_14D, RISK_BAND
        FROM ML.MISS_RISK_SCORES ORDER BY MISS_PROB_14D DESC, ENTITY_ID LIMIT 50`),
      executeQuery<Record<string, string | number | null>>(
        'SELECT N, BASE_RATE, PRECISION_AT_50, RECALL_AT_50 FROM ML.MISS_RISK_HOLDOUT_METRICS'),
      executeQuery<Record<string, string | number | null>>(`
        SELECT TO_CHAR(FORECAST_DATE, 'YYYY-MM-DD') AS PERIOD, MISSED_COUNT, LOWER_BOUND, UPPER_BOUND
        FROM ML.MISSED_FORECAST ORDER BY FORECAST_DATE`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT BORROWER_ID, TO_CHAR(EVENT_TS, 'YYYY-MM-DD HH24:MI:SS') AS EVENT_TS, ROUND(AMOUNT_IDR, 0) AS AMOUNT_IDR,
               DAYS_PAST_DUE, STATUS, TO_CHAR(LOADED_AT, 'YYYY-MM-DD HH24:MI:SS TZH:TZM') AS LOADED_AT
        FROM RAW.LIVE_REPAYMENTS ORDER BY EVENT_TS DESC LIMIT 25`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT COUNT(*) AS N, COUNT_IF(STATUS = 'MISSED') AS MISSED,
               TO_CHAR(MAX(LOADED_AT), 'YYYY-MM-DD HH24:MI:SS TZH:TZM') AS LAST_LOADED,
               ROUND(MEDIAN(DATEDIFF('second', SENT_TS, CONVERT_TIMEZONE('UTC', LOADED_AT)::TIMESTAMP_NTZ)), 0) AS MEDIAN_LAG_S
        FROM RAW.LIVE_REPAYMENTS`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT ENTITY_ID, TO_CHAR(EVENT_DATE, 'YYYY-MM-DD') AS EVENT_DATE, ROUND(INFLOW_K_IDR, 0) AS INFLOW_K_IDR,
               ROUND(EXPECTED, 0) AS EXPECTED, ROUND(LOWER_BOUND, 0) AS LOWER_BOUND
        FROM ML.WALLET_INFLOW_ANOMALIES WHERE IS_ANOMALY AND INFLOW_K_IDR < LOWER_BOUND
        ORDER BY EVENT_DATE DESC, ENTITY_ID LIMIT 50`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT BORROWER_ID, TO_CHAR(EVENT_TS, 'YYYY-MM-DD HH24:MI:SS') AS EVENT_TS, ROUND(AMOUNT_IDR, 0) AS AMOUNT_IDR,
               DAYS_PAST_DUE, SOP_HINT
        FROM APP.ALERT_LOG ORDER BY ALERTED_AT DESC, EVENT_TS DESC LIMIT 25`),
    ]);
    const numberOrNull = (value: unknown): number | null => {
      if (value === null || value === undefined) return null;
      const numeric = Number(value);
      if (!Number.isFinite(numeric)) throw new Error('Non-numeric measure in curated contract');
      return numeric;
    };
    const watermark = freshness[0]?.CURATED_WATERMARK ?? null;
    const ageDays = watermark ? (Date.now() - Date.parse(`${watermark}T00:00:00Z`)) / 86400000 : null;
    return NextResponse.json({
      platform: demoPlatform(),
      kpiCards: kpis.map((row) => ({ title: row.TITLE, value: row.DISPLAY, status: row.STATUS })),
      timeseries: trend.map((row) => ({ period: row.PERIOD, due: numberOrNull(row.DUE), missed: numberOrNull(row.MISSED) })),
      categories: products.map((row) => ({ category: row.PRODUCT, due: numberOrNull(row.DUE), missed: numberOrNull(row.MISSED) })),
      entities: borrowers.map((row) => ({
        id: row.ENTITY_ID, name: row.ENTITY_NAME, region: row.REGION, category: row.CATEGORY,
        score: numberOrNull(row.ALT_DATA_SCORE), due: numberOrNull(row.INSTALMENTS_DUE),
        missed: numberOrNull(row.INSTALMENTS_MISSED), onTime: numberOrNull(row.ON_TIME_RATE_PCT),
        dpd: numberOrNull(row.LATEST_DPD), outstanding: numberOrNull(row.OUTSTANDING_IDR_M),
        events: numberOrNull(row.EVENT_COUNT),
      })),
      scoreRisk: borrowers.map((row) => ({
        name: row.ENTITY_NAME, score: numberOrNull(row.ALT_DATA_SCORE), missed: numberOrNull(row.INSTALMENTS_MISSED),
      })).filter((row) => row.score !== null && row.missed !== null),
      sourceWatermark: watermark,
      rawWatermark: freshness[0]?.RAW_WATERMARK ?? null,
      stale: ageDays === null || ageDays > 2,
      pipelineBehind: freshness[0]?.RAW_WATERMARK !== watermark,
      requestedAt: new Date().toISOString(),
      synthetic: true,
      risk: risk.map((row) => ({
        id: row.ENTITY_ID, scoredAsOf: row.SCORED_AS_OF,
        probability: numberOrNull(row.MISS_PROB_14D), band: row.RISK_BAND,
      })),
      holdout: holdout[0] ? {
        n: numberOrNull(holdout[0].N), baseRate: numberOrNull(holdout[0].BASE_RATE),
        precision: numberOrNull(holdout[0].PRECISION_AT_50), recall: numberOrNull(holdout[0].RECALL_AT_50),
      } : null,
      forecast: forecast.map((row) => ({
        period: row.PERIOD, value: numberOrNull(row.MISSED_COUNT),
        lower: numberOrNull(row.LOWER_BOUND), upper: numberOrNull(row.UPPER_BOUND),
      })),
      modelStatus: holdout[0] ? 'holdout_evaluated' : 'missing',
      live: live.map((row) => ({
        id: row.BORROWER_ID, eventTs: row.EVENT_TS, amount: numberOrNull(row.AMOUNT_IDR),
        dpd: numberOrNull(row.DAYS_PAST_DUE), status: row.STATUS, loadedAt: row.LOADED_AT,
      })),
      liveSummary: {
        n: numberOrNull(liveSummary[0]?.N), missed: numberOrNull(liveSummary[0]?.MISSED),
        lastLoaded: liveSummary[0]?.LAST_LOADED ?? null, medianLagSeconds: numberOrNull(liveSummary[0]?.MEDIAN_LAG_S),
      },
      anomalies: anomalies.map((row) => ({
        id: row.ENTITY_ID, date: row.EVENT_DATE, inflow: numberOrNull(row.INFLOW_K_IDR),
        expected: numberOrNull(row.EXPECTED), lower: numberOrNull(row.LOWER_BOUND),
      })),
      alerts: alerts.map((row) => ({
        id: row.BORROWER_ID, eventTs: row.EVENT_TS, amount: numberOrNull(row.AMOUNT_IDR),
        dpd: numberOrNull(row.DAYS_PAST_DUE), hint: row.SOP_HINT,
      })),
    }, { headers: { 'Cache-Control': 'no-store' } });
  } catch {
    return NextResponse.json({ error: 'Lending data is unavailable. Verify the core deployment and application role.' },
      { status: 503, headers: { 'Cache-Control': 'no-store' } });
  }
}
