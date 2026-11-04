
WITH valid_purchases AS (

    SELECT DISTINCT
        CUSTOMER_ID,
        DATE_TRUNC('MONTH', INVOICE_DATE)::DATE
            AS PURCHASE_MONTH

    FROM {{ ref('fact_sale_incremental') }}

    WHERE CUSTOMER_ID IS NOT NULL
      AND QUANTITY > 0
      AND UNIT_PRICE > 0
      AND LEFT(TRIM(INVOICENO), 1) <> 'C'

),

customer_cohorts AS (

    SELECT
        CUSTOMER_ID,
        MIN(PURCHASE_MONTH) AS COHORT_MONTH

    FROM valid_purchases
    GROUP BY CUSTOMER_ID

),

cohort_activity AS (

    SELECT
        c.COHORT_MONTH,
        p.PURCHASE_MONTH,
        DATEDIFF(
            'MONTH',
            c.COHORT_MONTH,
            p.PURCHASE_MONTH
        ) AS MONTH_NUMBER,
        COUNT(DISTINCT p.CUSTOMER_ID)
            AS ACTIVE_CUSTOMERS

    FROM valid_purchases p
    INNER JOIN customer_cohorts c
        ON p.CUSTOMER_ID = c.CUSTOMER_ID

    GROUP BY 1, 2, 3

),

cohort_sizes AS (

    SELECT
        COHORT_MONTH,
        COUNT(*) AS COHORT_SIZE

    FROM customer_cohorts
    GROUP BY COHORT_MONTH

)

SELECT
    a.COHORT_MONTH,
    a.PURCHASE_MONTH,
    a.MONTH_NUMBER,
    s.COHORT_SIZE,
    a.ACTIVE_CUSTOMERS,

    ROUND(
        a.ACTIVE_CUSTOMERS * 100.0
        / NULLIF(s.COHORT_SIZE, 0),
        2
    ) AS RETENTION_PCT

FROM cohort_activity a
INNER JOIN cohort_sizes s
    ON a.COHORT_MONTH = s.COHORT_MONTH
