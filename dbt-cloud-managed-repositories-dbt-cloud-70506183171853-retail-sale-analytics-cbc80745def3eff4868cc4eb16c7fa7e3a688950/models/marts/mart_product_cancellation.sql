
WITH product_transactions AS (

    SELECT
        UPPER(TRIM(STOCKCODE)) AS PRODUCT_CODE,
        INVOICENO,
        QUANTITY,
        UNIT_PRICE,

        CASE
            WHEN LEFT(TRIM(INVOICENO), 1) = 'C'
                 AND QUANTITY < 0
            THEN ABS(QUANTITY)
            ELSE 0
        END AS CANCELLED_UNITS,

        CASE
            WHEN LEFT(TRIM(INVOICENO), 1) <> 'C'
                 AND QUANTITY > 0
                 AND UNIT_PRICE > 0
            THEN QUANTITY
            ELSE 0
        END AS SOLD_UNITS,

        CASE
            WHEN LEFT(TRIM(INVOICENO), 1) = 'C'
                 AND QUANTITY < 0
            THEN ABS(QUANTITY * UNIT_PRICE)
            ELSE 0
        END AS CANCELLATION_VALUE

    FROM {{ ref('fact_sale_incremental') }}

    WHERE STOCKCODE IS NOT NULL

),

product_aggregation AS (

    SELECT
        PRODUCT_CODE,

        SUM(SOLD_UNITS) AS SOLD_UNITS,
        SUM(CANCELLED_UNITS) AS CANCELLED_UNITS,

        ROUND(
            SUM(CANCELLATION_VALUE), 2
        ) AS CANCELLATION_VALUE,

        COUNT(DISTINCT CASE
            WHEN LEFT(TRIM(INVOICENO), 1) = 'C'
                 AND QUANTITY < 0
            THEN INVOICENO
        END) AS CANCELLATION_INVOICES

    FROM product_transactions

    GROUP BY PRODUCT_CODE

)

SELECT
    PRODUCT_CODE,
    SOLD_UNITS,
    CANCELLED_UNITS,
    CANCELLATION_VALUE,
    CANCELLATION_INVOICES,

    ROUND(
        CANCELLED_UNITS * 100.0 /
        NULLIF(SOLD_UNITS, 0),
        2
    ) AS CANCELLATION_RATE_PCT

FROM product_aggregation
