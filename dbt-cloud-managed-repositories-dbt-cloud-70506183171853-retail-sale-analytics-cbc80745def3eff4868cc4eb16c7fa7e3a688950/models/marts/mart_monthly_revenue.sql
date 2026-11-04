
WITH monthly_revenue AS (

    SELECT
        DATE_TRUNC('MONTH', INVOICE_DATE)::DATE
            AS REVENUE_MONTH,

        COUNT(*) AS TRANSACTION_ROWS,

        SUM(QUANTITY * UNIT_PRICE)
            AS NET_REVENUE

    FROM {{ ref('fact_sale_incremental') }}

    GROUP BY 1

),

previous_month AS (

    SELECT
        REVENUE_MONTH,
        TRANSACTION_ROWS,
        NET_REVENUE,

        LAG(NET_REVENUE) OVER (
            ORDER BY REVENUE_MONTH
        ) AS PREVIOUS_MONTH_REVENUE

    FROM monthly_revenue

)

SELECT
    REVENUE_MONTH,
    TRANSACTION_ROWS,

    ROUND(NET_REVENUE, 2) AS NET_REVENUE,

    ROUND(PREVIOUS_MONTH_REVENUE, 2)
        AS PREVIOUS_MONTH_REVENUE,

    CASE
        WHEN PREVIOUS_MONTH_REVENUE IS NULL
            OR PREVIOUS_MONTH_REVENUE = 0
            THEN NULL

        -- January compares against partial December 2010
        WHEN REVENUE_MONTH = '2011-01-01'::DATE
            THEN NULL

        -- December 2011 is an incomplete month
        WHEN REVENUE_MONTH = '2011-12-01'::DATE
            THEN NULL

        ELSE ROUND(
            (
                NET_REVENUE - PREVIOUS_MONTH_REVENUE
            ) / ABS(PREVIOUS_MONTH_REVENUE) * 100,
            2
        )
    END AS MOM_GROWTH_PCT

FROM previous_month
