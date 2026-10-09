-- Validate the producer contract before building downstream objects.
USE DATABASE IDENTIFIER($DEMO_DB);
USE SCHEMA RAW;
USE WAREHOUSE IDENTIFIER($DEMO_WH);

EXECUTE IMMEDIATE $$
DECLARE
  violations INTEGER;
  invalid_source EXCEPTION (-20001, 'Synthetic source failed grain or measure validation');
BEGIN
  SELECT COUNT(*) INTO :violations FROM (
    SELECT ENTITY_ID, EVENT_DATE
    FROM RAW.LOAN_DAILY
    GROUP BY ENTITY_ID, EVENT_DATE HAVING COUNT(*) <> 1
    UNION ALL
    SELECT observation.ENTITY_ID, observation.EVENT_DATE
    FROM RAW.LOAN_DAILY observation
    LEFT JOIN RAW.BORROWERS borrower ON borrower.ID = observation.ENTITY_ID
    WHERE borrower.ID IS NULL OR observation.DAYS_PAST_DUE < 0
       OR observation.OUTSTANDING_IDR < 0 OR observation.WALLET_INFLOW_IDR < 0
       OR observation.INSTALMENT_MISSED > observation.INSTALMENT_DUE
       OR observation.AMOUNT_PAID_IDR > observation.AMOUNT_DUE_IDR
       OR observation.PROMISE_TO_PAY > observation.COLLECTION_CONTACT
  );
  IF (violations > 0) THEN
    RAISE invalid_source;
  END IF;
END;
$$;
