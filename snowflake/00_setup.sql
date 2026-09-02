-- Generated from generator/demo_specs/aws-indonesia-digital-economy-fintech.json
-- Regenerate with: python3 generator/gen_repo_docs.py aws-indonesia-digital-economy-fintech
-- This is the schema that is actually deployed for ID_DIGITAL_ECONOMY_FINTECH.

-- ID_DIGITAL_ECONOMY_FINTECH  (Fintech Lending Analytics)
-- generated from generator/demo_specs/aws-indonesia-digital-economy-fintech.json - do not hand-edit
CREATE DATABASE IF NOT EXISTS ID_DIGITAL_ECONOMY_FINTECH;
CREATE SCHEMA IF NOT EXISTS ID_DIGITAL_ECONOMY_FINTECH.RAW;
CREATE SCHEMA IF NOT EXISTS ID_DIGITAL_ECONOMY_FINTECH.CURATED;
CREATE SCHEMA IF NOT EXISTS ID_DIGITAL_ECONOMY_FINTECH.APP;
USE DATABASE ID_DIGITAL_ECONOMY_FINTECH;

-- 5 real regions; entity names carry their region so the two always agree
