
WITH valid_purchases AS (

    SELECT
        CUSTOMER_ID,
        INVOICENO,
        INVOICE_DATE,
        QUANTITY * UNIT_PRICE AS LINE_REVENUE

    FROM {{ ref('fact_sale_incremental') }}

    WHERE CUSTOMER_ID IS NOT NULL
      AND QUANTITY > 0
      AND UNIT_PRICE > 0
      AND LEFT(TRIM(INVOICENO), 1) <> 'C'

),

reference_date AS (

    SELECT
        MAX(INVOICE_DATE) AS AS_OF_DATE
    FROM {{ ref('fact_sale_incremental') }}

),

customer_metrics AS (

    SELECT
        p.CUSTOMER_ID,

        DATEDIFF(
            'DAY',
            MAX(p.INVOICE_DATE),
            MAX(r.AS_OF_DATE)
        ) AS RECENCY_DAYS,

        COUNT(DISTINCT p.INVOICENO)
            AS FREQUENCY,

        ROUND(SUM(p.LINE_REVENUE), 2)
            AS MONETARY_VALUE

    FROM valid_purchases p
    CROSS JOIN reference_date r

    GROUP BY p.CUSTOMER_ID

),

rfm_scores AS (

    SELECT
        *,

        6 - NTILE(5) OVER (
            ORDER BY RECENCY_DAYS
        ) AS R_SCORE,

        NTILE(5) OVER (
            ORDER BY FREQUENCY
        ) AS F_SCORE,

        NTILE(5) OVER (
            ORDER BY MONETARY_VALUE
        ) AS M_SCORE

    FROM customer_metrics

)

SELECT
    CUSTOMER_ID,
    RECENCY_DAYS,
    FREQUENCY,
    MONETARY_VALUE,
    R_SCORE,
    F_SCORE,
    M_SCORE,

    CONCAT(
        R_SCORE::VARCHAR,
        F_SCORE::VARCHAR,
        M_SCORE::VARCHAR
    ) AS RFM_SCORE,

    CASE
        WHEN R_SCORE >= 4
         AND F_SCORE >= 4
         AND M_SCORE >= 4
            THEN 'Champions'

        WHEN R_SCORE >= 3
         AND F_SCORE >= 4
            THEN 'Loyal Customers'

        WHEN R_SCORE <= 2
         AND F_SCORE >= 3
            THEN 'At Risk'

        WHEN R_SCORE >= 4
         AND F_SCORE <= 2
            THEN 'Recent Customers'

        ELSE 'Other Customers'
    END AS CUSTOMER_SEGMENT

FROM rfm_scores
