WITH landing AS (
    SELECT
        COUNT(*) AS row_count,
        SUM(QUANTITY * UNIT_PRICE) AS total_value
    FROM RETAIL_DB.LANDING.RETAIL_INGESTION
),

fact AS (
    SELECT
        COUNT(*) AS row_count,
        SUM(QUANTITY * UNIT_PRICE) AS total_value
    FROM {{ ref('fact_sale_incremental') }}
)

SELECT
    l.row_count AS landing_rows,
    f.row_count AS fact_rows,
    l.total_value AS landing_value,
    f.total_value AS fact_value,
    f.total_value - l.total_value AS financial_difference
FROM landing l
CROSS JOIN fact f
WHERE
    l.row_count <> f.row_count
    OR l.total_value IS DISTINCT FROM f.total_value