
{{ config(materialized='table') }}

WITH invoice_data AS (
    SELECT DISTINCT
        NULLIF(TRIM(TO_VARCHAR(INVOICENO)), '') AS invoiceno
    FROM RETAIL_DB.LANDING.LANDING_RETAIL
),

cleaned_invoices AS (
    SELECT invoiceno
    FROM invoice_data
    WHERE invoiceno IS NOT NULL
)

SELECT
    MD5(invoiceno) AS invoice_key,
    invoiceno
FROM cleaned_invoices
