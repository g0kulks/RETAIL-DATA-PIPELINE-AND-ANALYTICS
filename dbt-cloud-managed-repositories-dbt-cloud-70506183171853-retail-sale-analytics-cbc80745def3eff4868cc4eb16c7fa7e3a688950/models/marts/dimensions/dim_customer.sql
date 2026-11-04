
{{ config(materialized='table') }}

WITH customer_data AS (
    SELECT DISTINCT
        TRY_TO_NUMBER(
            NULLIF(TRIM(TO_VARCHAR(CUSTOMERID)), ''),
            38,
            0
        ) AS customer_id
    FROM RETAIL_DB.LANDING.LANDING_RETAIL
    WHERE CUSTOMERID IS NOT NULL
),

final AS (
    SELECT
        MD5(TO_VARCHAR(customer_id)) AS customer_key,
        customer_id
    FROM customer_data
    WHERE customer_id IS NOT NULL
)

SELECT
    customer_key,
    customer_id
FROM final
