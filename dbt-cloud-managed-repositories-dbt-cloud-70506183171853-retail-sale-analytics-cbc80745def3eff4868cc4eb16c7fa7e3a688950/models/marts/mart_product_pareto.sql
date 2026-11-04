
WITH valid_sales AS (

    SELECT
        UPPER(TRIM(STOCKCODE)) AS PRODUCT_CODE,
        QUANTITY,
        UNIT_PRICE,
        QUANTITY * UNIT_PRICE AS LINE_REVENUE

    FROM {{ ref('fact_sale_incremental') }}

    WHERE QUANTITY > 0
      AND UNIT_PRICE > 0
      AND LEFT(TRIM(INVOICENO), 1) <> 'C'
      AND STOCKCODE IS NOT NULL

),

merchandise_sales AS (

    SELECT *
    FROM valid_sales

    WHERE PRODUCT_CODE NOT IN (
        'DOT',
        'POST',
        'C2',
        'AMAZONFEE',
        'BANK CHARGES',
        'M',
        'B',
        'D',
        'S',
        'PADS',
        'CRUK'
    )

    AND PRODUCT_CODE NOT LIKE 'GIFT_%'

),

product_revenue AS (

    SELECT
        PRODUCT_CODE,
        COUNT(*) AS SALES_ROWS,
        SUM(QUANTITY) AS UNITS_SOLD,
        SUM(LINE_REVENUE) AS PRODUCT_REVENUE

    FROM merchandise_sales

    GROUP BY PRODUCT_CODE

),

ranked_products AS (

    SELECT
        *,
        ROW_NUMBER() OVER (
            ORDER BY PRODUCT_REVENUE DESC, PRODUCT_CODE
        ) AS REVENUE_RANK,

        SUM(PRODUCT_REVENUE) OVER (
            ORDER BY PRODUCT_REVENUE DESC, PRODUCT_CODE
            ROWS BETWEEN UNBOUNDED PRECEDING
            AND CURRENT ROW
        ) AS CUMULATIVE_REVENUE,

        SUM(PRODUCT_REVENUE) OVER ()
            AS TOTAL_REVENUE

    FROM product_revenue

),

pareto_analysis AS (

    SELECT
        *,
        ROUND(
            PRODUCT_REVENUE * 100.0
            / NULLIF(TOTAL_REVENUE, 0),
            4
        ) AS REVENUE_SHARE_PCT,

        ROUND(
            CUMULATIVE_REVENUE * 100.0
            / NULLIF(TOTAL_REVENUE, 0),
            4
        ) AS CUMULATIVE_REVENUE_PCT

    FROM ranked_products

)

SELECT
    PRODUCT_CODE,
    SALES_ROWS,
    UNITS_SOLD,
    ROUND(PRODUCT_REVENUE, 2) AS PRODUCT_REVENUE,
    REVENUE_RANK,
    REVENUE_SHARE_PCT,
    CUMULATIVE_REVENUE_PCT,

    CASE
        WHEN CUMULATIVE_REVENUE_PCT <= 80
            THEN 'A'
        WHEN CUMULATIVE_REVENUE_PCT <= 95
            THEN 'B'
        ELSE 'C'
    END AS ABC_CATEGORY

FROM pareto_analysis
