"""Publish simulated instalment repayment events to Amazon Data Firehose (stream <prefix>-repayments).

Firehose batches the records into S3 (repayments/); Snowpipe loads them into RAW.LIVE_REPAYMENTS.
Borrower IDs come from RAW.BORROWERS (BRW-0000..BRW-0199). Values are seeded random.
"""
import argparse
import json
import random
import time
from datetime import datetime, timezone


def make_event(rng):
    missed = rng.random() < 0.1
    return {'borrower_id': f'BRW-{rng.randint(0, 199):04d}',
            'event_ts': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.%f')[:-3],
            'amount_idr': round(450000 * rng.lognormvariate(0, 0.6), -2),
            'days_past_due': rng.randint(1, 45) if missed else 0,
            'status': 'MISSED' if missed else 'PAID',
            'sent_ms': int(time.time() * 1000)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--region', default='us-west-2')
    ap.add_argument('--prefix', default='id-lending')
    ap.add_argument('--count', type=int, default=40)
    ap.add_argument('--seed', type=int)
    args = ap.parse_args()
    import boto3
    firehose = boto3.client('firehose', region_name=args.region)
    stream = f'{args.prefix}-repayments'
    rng = random.Random(args.seed)
    records = [{'Data': (json.dumps(make_event(rng)) + '\n').encode()} for _ in range(args.count)]
    for start in range(0, len(records), 500):
        out = firehose.put_record_batch(DeliveryStreamName=stream, Records=records[start:start + 500])
        if out['FailedPutCount']:
            raise RuntimeError(f"{out['FailedPutCount']} records were rejected by Firehose")
    print(f'published {args.count} repayment events to Firehose stream {stream}; S3 delivery buffers up to 60 s')


if __name__ == '__main__':
    main()
