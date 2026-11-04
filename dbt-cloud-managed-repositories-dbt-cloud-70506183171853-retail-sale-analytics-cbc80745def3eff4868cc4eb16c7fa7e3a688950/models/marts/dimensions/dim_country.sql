
{{ config(materialized='table') }}

WITH country_data AS (
    SELECT DISTINCT
        NULLIF(TRIM(TO_VARCHAR(COUNTRY)), '') AS country
    FROM RETAIL_DB.LANDING.LANDING_RETAIL
),

cleaned_countries AS (
    SELECT country
    FROM country_data
    WHERE country IS NOT NULL
)

SELECT
    MD5(country) AS country_key,
    country
FROM cleaned_countries
