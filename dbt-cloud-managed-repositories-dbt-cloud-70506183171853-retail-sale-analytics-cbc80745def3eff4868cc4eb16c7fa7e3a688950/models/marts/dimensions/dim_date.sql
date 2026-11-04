
{{ config(materialized='table') }}

WITH source_dates AS (
    SELECT DISTINCT
        TRY_TO_TIMESTAMP_NTZ(
            TRIM(TO_VARCHAR(INVOICEDATE)),
            'DD-MM-YYYY HH24:MI'
        )::DATE AS date_value
    FROM RETAIL_DB.LANDING.LANDING_RETAIL
),

valid_dates AS (
    SELECT DISTINCT date_value
    FROM source_dates
    WHERE date_value IS NOT NULL
)

SELECT
    MD5(TO_VARCHAR(date_value, 'YYYY-MM-DD')) AS date_key,
    date_value AS date,
    MONTH(date_value) AS month,
    YEAR(date_value) AS year
FROM valid_dates
