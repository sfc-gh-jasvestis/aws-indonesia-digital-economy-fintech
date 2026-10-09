import { NextResponse } from 'next/server';
import { executeQuery } from '@/lib/snowflake';
import { demoPlatform } from '@/lib/platform';

export const dynamic = 'force-dynamic';

// Only these fixed, read-only queries can run. The model never writes SQL; it
// only summarises rows returned here, so every answer is traceable to data.
const INTENTS: Record<string, { match: RegExp; sql: string }> = {
  borrowers: {
    match: /borrower|missed|overdue|delinquen|worst|highest|dpd/i,
    sql: `SELECT ENTITY_ID, ENTITY_NAME, REGION, CATEGORY, INSTALMENTS_DUE, INSTALMENTS_MISSED, LATEST_DPD,
       ROUND(ON_TIME_RATE_PCT, 1) AS ON_TIME_RATE_PCT, ROUND(LATEST_OUTSTANDING_IDR / 1e6, 2) AS OUTSTANDING_IDR_M
FROM CURATED.PERFORMANCE_SUMMARY
QUALIFY DENSE_RANK() OVER (ORDER BY LATEST_DPD DESC) <= 3
ORDER BY LATEST_DPD DESC, INSTALMENTS_MISSED DESC, ENTITY_ID`,
  },
  products: {
    match: /product|paylater|loan type|msme|invoice|agri|why/i,
    sql: `SELECT PRODUCT, BORROWER_COUNT, INSTALMENTS_DUE, INSTALMENTS_MISSED, ROUND(ON_TIME_RATE_PCT, 1) AS ON_TIME_RATE_PCT,
       ROUND(OUTSTANDING_IDR / 1e9, 2) AS OUTSTANDING_IDR_BN, ROUND(PAR30_PCT, 1) AS PAR30_PCT
FROM CURATED.PRODUCT_SUMMARY ORDER BY INSTALMENTS_MISSED DESC`,
  },
  kpis: {
    match: /.*/,
    sql: `SELECT TITLE, DISPLAY, SOURCE_WATERMARK FROM CURATED.KPI_SUMMARY ORDER BY SORT_ORDER`,
  },
};

const DEFINITIONS =
  'On-time repayment rate = instalments paid on time / instalments due. PAR 30 = share of outstanding principal on borrowers more than 30 days past due (DPD), on the latest day. ' +
  'Promise-to-pay rate = promises to pay / collection contacts. Amounts are in Indonesian rupiah (IDR). ' +
  'All data is synthetic demo data.';

// provider 'cortex' = Snowflake AI_COMPLETE; 'bedrock' = Amazon Bedrock Claude
// via the external-access UDF APP.BEDROCK_GENERATE (aws/setup_aws.py).
async function summarise(question: string, rows: unknown[], provider: 'cortex' | 'bedrock' = 'cortex'): Promise<string> {
  const prompt =
    'You are a consumer-lending credit risk analyst. Answer ONLY from the JSON rows and definitions below. ' +
    'If the rows do not answer the question, say so. Do not invent numbers. Keep it under 120 words.\n' +
    `Definitions: ${DEFINITIONS}\nRows: ${JSON.stringify(rows)}\nQuestion: ${question}`;
  const out = await executeQuery<{ R: string }>(
    provider === 'bedrock' ? 'SELECT APP.BEDROCK_GENERATE(?) AS R' : `SELECT AI_COMPLETE('claude-sonnet-4-5', ?) AS R`,
    [prompt],
  );
  const raw = String(out[0]?.R ?? '').trim();
  // AI_COMPLETE returns a JSON string literal; decode it when present.
  try {
    const parsed = JSON.parse(raw);
    return typeof parsed === 'string' ? parsed : raw;
  } catch {
    return raw;
  }
}

export async function POST(req: Request) {
  let body: any;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }
  const question = typeof body?.question === 'string' ? body.question.trim().slice(0, 2000) : '';
  const memo = body?.mode === 'memo';
  if (!memo && !question) return NextResponse.json({ error: 'Question required' }, { status: 400 });

  try {
    if (memo) {
      const provider = demoPlatform() === 'aws' ? 'bedrock' : 'cortex';
      const [kpis, borrowers, products, risk, bands] = await Promise.all([
        executeQuery(INTENTS.kpis.sql),
        executeQuery(INTENTS.borrowers.sql),
        executeQuery(INTENTS.products.sql),
        executeQuery(`SELECT ENTITY_ID, ROUND(MISS_PROB_14D, 2) AS MISS_PROB_14D, RISK_BAND
FROM ML.MISS_RISK_SCORES ORDER BY MISS_PROB_14D DESC, ENTITY_ID LIMIT 5`),
        executeQuery(`SELECT RISK_BAND, COUNT(*) AS BORROWERS FROM ML.MISS_RISK_SCORES GROUP BY RISK_BAND`),
      ]);
      const rows = { kpis, mostDelinquentBorrowers: borrowers, products, top5ByRisk: risk, borrowersPerRiskBand: bands };
      const answer = await summarise(
        'Draft a short action memo for the Chief Risk Officer with 3 prioritised collection and credit actions, citing the figures.',
        [rows],
        provider,
      );
      return NextResponse.json({ answer, sources: rows, provider: provider === 'bedrock' ? 'Amazon Bedrock (Claude Sonnet 4.5)' : 'Snowflake Cortex AI_COMPLETE (claude-sonnet-4-5)', draft: true, synthetic: true });
    }
    const key = Object.keys(INTENTS).find((k) => INTENTS[k].match.test(question))!;
    const rows = await executeQuery(INTENTS[key].sql);
    const answer = await summarise(question, rows);
    return NextResponse.json({ answer, sql: INTENTS[key].sql, sources: rows, synthetic: true });
  } catch (err) {
    console.error('ask route failed', err);
    return NextResponse.json({ error: 'AI service unavailable' }, { status: 503 });
  }
}
