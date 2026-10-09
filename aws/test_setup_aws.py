import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from publish_repayments import make_event
from setup_aws import firehose_request, ident, names


class SetupAwsTests(unittest.TestCase):
    def test_names_are_scoped_to_prefix_account_region(self):
        n = names('id-lending', '123456789012', 'us-west-2')
        self.assertEqual(n['bucket'], 'id-lending-123456789012-us-west-2')
        self.assertEqual(n['storage_int'], 'ID_LENDING_S3_INT')
        self.assertEqual(n['firehose_stream'], 'id-lending-repayments')

    def test_rejects_unsafe_identifiers(self):
        for bad in ['DB; DROP', 'a-b', '1abc', '']:
            with self.assertRaises(ValueError):
                ident(bad)

    def test_firehose_request_matches_aws_schema(self):
        import botocore.session
        from botocore.validate import validate_parameters
        n = names('id-lending', '123456789012', 'us-west-2')
        req = firehose_request(n, n['bucket'], 'arn:aws:iam::123456789012:role/id-lending-firehose-s3')
        model = botocore.session.get_session().get_service_model('firehose')
        validate_parameters(req, model.operation_model('CreateDeliveryStream').input_shape)
        dest = req['ExtendedS3DestinationConfiguration']
        self.assertEqual(dest['Prefix'], 'repayments/')
        self.assertFalse(dest['ErrorOutputPrefix'].startswith('repayments/'))

    def test_repayment_event_matches_pipe_columns(self):
        import random
        rng = random.Random(7)
        events = [make_event(rng) for _ in range(200)]
        self.assertEqual(set(events[0]), {'borrower_id', 'event_ts', 'amount_idr', 'days_past_due', 'status', 'sent_ms'})
        for event in events:
            self.assertRegex(event['borrower_id'], r'^BRW-0(0\d\d|1\d\d)$')
            self.assertIn(event['status'], ('MISSED', 'PAID'))
            self.assertEqual(event['status'] == 'PAID', event['days_past_due'] == 0)


if __name__ == '__main__':
    unittest.main()
