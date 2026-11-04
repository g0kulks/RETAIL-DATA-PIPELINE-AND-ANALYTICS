
{{ config(materialized='table') }}

WITH source_sales AS (

    SELECT
        SOURCE_ROW_ID AS source_row_id,

        NULLIF(TRIM(TO_VARCHAR(INVOICE_NO)), '') AS invoiceno,
        NULLIF(TRIM(TO_VARCHAR(STOCK_CODE)), '') AS stockcode,
        TRY_TO_NUMBER(CUSTOMER_ID) AS customer_id,
        NULLIF(TRIM(TO_VARCHAR(COUNTRY)), '') AS country,

        TRY_TO_TIMESTAMP_NTZ(
            TRIM(TO_VARCHAR(INVOICE_DATE)),
            'DD-MM-YYYY HH24:MI'
        )::DATE AS invoice_date,

        TRY_TO_NUMBER(QUANTITY) AS quantity,
        UNIT_PRICE::NUMBER(12,2) AS unit_price

    FROM RETAIL_DB.LANDING.RETAIL_INGESTION

)

SELECT
    inv.INVOICE_KEY,
    cust.CUSTOMER_KEY,
    prod.PRODUCTKEY AS PRODUCT_KEY,
    dt.DATE_KEY,
    cntry.COUNTRY_KEY,

    inv.INVOICENO,
    prod.STOCKCODE,
    s.customer_id,
    s.invoice_date,
    s.quantity,
    s.unit_price,
    s.source_row_id

FROM source_sales s

LEFT JOIN RETAIL_DB.DBT_GKS.DIM_INVOICE inv
    ON s.invoiceno = inv.invoiceno

LEFT JOIN RETAIL_DB.DBT_GKS.DIM_CUSTOMER cust
    ON s.customer_id = cust.customer_id

LEFT JOIN RETAIL_DB.DBT_GKS.DIM_PRODUCT prod
    ON s.stockcode = prod.stockcode

LEFT JOIN RETAIL_DB.DBT_GKS.DIM_DATE dt
    ON s.invoice_date = dt.date

LEFT JOIN RETAIL_DB.DBT_GKS.DIM_COUNTRY cntry
    ON s.country = cntry.country
