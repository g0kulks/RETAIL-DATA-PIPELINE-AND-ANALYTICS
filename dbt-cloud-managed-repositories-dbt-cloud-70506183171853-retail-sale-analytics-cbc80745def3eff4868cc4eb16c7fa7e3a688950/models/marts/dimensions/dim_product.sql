
{{ config(materialized='table') }}

WITH product_data AS (
    SELECT
        NULLIF(TRIM(TO_VARCHAR(STOCKCODE)), '') AS stockcode,
        NULLIF(TRIM(TO_VARCHAR(DESCRIPTION)), '') AS description
    FROM RETAIL_DB.LANDING.LANDING_RETAIL
),

unique_products AS (
    SELECT
        stockcode,
        MAX(description) AS description
    FROM product_data
    WHERE stockcode IS NOT NULL
    GROUP BY stockcode
)

SELECT
    stockcode,
    description,
    MD5(stockcode) AS productkey
FROM unique_products
