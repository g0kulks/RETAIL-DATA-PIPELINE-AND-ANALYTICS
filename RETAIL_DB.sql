create or replace database RETAIL_DB;

create or replace schema RETAIL_DB.DBT_GKS;

create or replace TRANSIENT TABLE RETAIL_DB.DBT_GKS.DIM_COUNTRY (
	COUNTRY_KEY VARCHAR(32),
	COUNTRY VARCHAR(16777216)
);
create or replace TRANSIENT TABLE RETAIL_DB.DBT_GKS.DIM_CUSTOMER (
	CUSTOMER_KEY VARCHAR(32),
	CUSTOMER_ID NUMBER(38,0)
);
create or replace TRANSIENT TABLE RETAIL_DB.DBT_GKS.DIM_DATE (
	DATE_KEY VARCHAR(32),
	DATE DATE,
	MONTH NUMBER(2,0),
	YEAR NUMBER(4,0)
);
create or replace TRANSIENT TABLE RETAIL_DB.DBT_GKS.DIM_INVOICE (
	INVOICE_KEY VARCHAR(32),
	INVOICENO VARCHAR(16777216)
);
create or replace TRANSIENT TABLE RETAIL_DB.DBT_GKS.DIM_PRODUCT (
	STOCKCODE VARCHAR(16777216),
	DESCRIPTION VARCHAR(16777216),
	PRODUCTKEY VARCHAR(32)
);
create or replace TRANSIENT TABLE RETAIL_DB.DBT_GKS.FACT_SALES (
	INVOICE_KEY VARCHAR(32),
	CUSTOMER_KEY VARCHAR(32),
	PRODUCT_KEY VARCHAR(32),
	DATE_KEY VARCHAR(32),
	COUNTRY_KEY VARCHAR(32),
	INVOICENO VARCHAR(16777216),
	STOCKCODE VARCHAR(16777216),
	CUSTOMER_ID NUMBER(38,0),
	INVOICE_DATE DATE,
	QUANTITY NUMBER(38,0),
	UNIT_PRICE NUMBER(12,2),
	SOURCE_ROW_ID VARCHAR(16777216)
);
create or replace TRANSIENT TABLE RETAIL_DB.DBT_GKS.FACT_SALE_INCREMENTAL (
	INVOICE_KEY VARCHAR(32),
	CUSTOMER_KEY VARCHAR(32),
	PRODUCT_KEY VARCHAR(32),
	DATE_KEY VARCHAR(32),
	COUNTRY_KEY VARCHAR(32),
	INVOICENO VARCHAR(16777216),
	STOCKCODE VARCHAR(16777216),
	CUSTOMER_ID NUMBER(38,0),
	INVOICE_DATE DATE,
	QUANTITY NUMBER(38,0),
	UNIT_PRICE NUMBER(12,2),
	SOURCE_ROW_ID VARCHAR(16777216)
);
create or replace view RETAIL_DB.DBT_GKS.MART_CUSTOMER_COHORTS(
	COHORT_MONTH,
	PURCHASE_MONTH,
	MONTH_NUMBER,
	COHORT_SIZE,
	ACTIVE_CUSTOMERS,
	RETENTION_PCT
) as (
    
WITH valid_purchases AS (

    SELECT DISTINCT
        CUSTOMER_ID,
        DATE_TRUNC('MONTH', INVOICE_DATE)::DATE
            AS PURCHASE_MONTH

    FROM RETAIL_DB.dbt_gks.fact_sale_incremental

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
  )
/* {"app": "dbt", "dbt_cloud_environment_id": "70506183165341", "dbt_cloud_job_id": "70506183143853", "dbt_cloud_project_id": "70506183175506", "dbt_cloud_run_id": "70506184114414", "dbt_version": "2.0.0", "invocation_id": "01a1a47f-de95-7bb1-98ef-ede69429344a", "node_id": "model.my_new_project.mart_customer_cohorts", "profile_name": "user", "target_name": "default"} */;
create or replace view RETAIL_DB.DBT_GKS.MART_CUSTOMER_RFM(
	CUSTOMER_ID,
	RECENCY_DAYS,
	FREQUENCY,
	MONETARY_VALUE,
	R_SCORE,
	F_SCORE,
	M_SCORE,
	RFM_SCORE,
	CUSTOMER_SEGMENT
) as (
    
WITH valid_purchases AS (

    SELECT
        CUSTOMER_ID,
        INVOICENO,
        INVOICE_DATE,
        QUANTITY * UNIT_PRICE AS LINE_REVENUE

    FROM RETAIL_DB.dbt_gks.fact_sale_incremental

    WHERE CUSTOMER_ID IS NOT NULL
      AND QUANTITY > 0
      AND UNIT_PRICE > 0
      AND LEFT(TRIM(INVOICENO), 1) <> 'C'

),

reference_date AS (

    SELECT
        MAX(INVOICE_DATE) AS AS_OF_DATE
    FROM RETAIL_DB.dbt_gks.fact_sale_incremental

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
  )
/* {"app": "dbt", "dbt_cloud_environment_id": "70506183165341", "dbt_cloud_job_id": "70506183143853", "dbt_cloud_project_id": "70506183175506", "dbt_cloud_run_id": "70506184114414", "dbt_version": "2.0.0", "invocation_id": "01a1a47f-de95-7bb1-98ef-ede69429344a", "node_id": "model.my_new_project.mart_customer_rfm", "profile_name": "user", "target_name": "default"} */;
create or replace view RETAIL_DB.DBT_GKS.MART_MONTHLY_REVENUE(
	REVENUE_MONTH,
	TRANSACTION_ROWS,
	NET_REVENUE,
	PREVIOUS_MONTH_REVENUE,
	MOM_GROWTH_PCT
) as (
    
WITH monthly_revenue AS (

    SELECT
        DATE_TRUNC('MONTH', INVOICE_DATE)::DATE
            AS REVENUE_MONTH,

        COUNT(*) AS TRANSACTION_ROWS,

        SUM(QUANTITY * UNIT_PRICE)
            AS NET_REVENUE

    FROM RETAIL_DB.dbt_gks.fact_sale_incremental

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
  )
/* {"app": "dbt", "dbt_cloud_environment_id": "70506183165341", "dbt_cloud_job_id": "70506183143853", "dbt_cloud_project_id": "70506183175506", "dbt_cloud_run_id": "70506184114414", "dbt_version": "2.0.0", "invocation_id": "01a1a47f-de95-7bb1-98ef-ede69429344a", "node_id": "model.my_new_project.mart_monthly_revenue", "profile_name": "user", "target_name": "default"} */;
create or replace view RETAIL_DB.DBT_GKS.MART_PRODUCT_CANCELLATION(
	PRODUCT_CODE,
	SOLD_UNITS,
	CANCELLED_UNITS,
	CANCELLATION_VALUE,
	CANCELLATION_INVOICES,
	CANCELLATION_RATE_PCT
) as (
    
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

    FROM RETAIL_DB.dbt_gks.fact_sale_incremental

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
  )
/* {"app": "dbt", "dbt_cloud_environment_id": "70506183165341", "dbt_cloud_job_id": "70506183143853", "dbt_cloud_project_id": "70506183175506", "dbt_cloud_run_id": "70506184114414", "dbt_version": "2.0.0", "invocation_id": "01a1a47f-de95-7bb1-98ef-ede69429344a", "node_id": "model.my_new_project.mart_product_cancellation", "profile_name": "user", "target_name": "default"} */;
create or replace view RETAIL_DB.DBT_GKS.MART_PRODUCT_PARETO(
	PRODUCT_CODE,
	SALES_ROWS,
	UNITS_SOLD,
	PRODUCT_REVENUE,
	REVENUE_RANK,
	REVENUE_SHARE_PCT,
	CUMULATIVE_REVENUE_PCT,
	ABC_CATEGORY
) as (
    
WITH valid_sales AS (

    SELECT
        UPPER(TRIM(STOCKCODE)) AS PRODUCT_CODE,
        QUANTITY,
        UNIT_PRICE,
        QUANTITY * UNIT_PRICE AS LINE_REVENUE

    FROM RETAIL_DB.dbt_gks.fact_sale_incremental

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
  )
/* {"app": "dbt", "dbt_cloud_environment_id": "70506183165341", "dbt_cloud_job_id": "70506183143853", "dbt_cloud_project_id": "70506183175506", "dbt_cloud_run_id": "70506184114414", "dbt_version": "2.0.0", "invocation_id": "01a1a47f-de95-7bb1-98ef-ede69429344a", "node_id": "model.my_new_project.mart_product_pareto", "profile_name": "user", "target_name": "default"} */;
create or replace schema RETAIL_DB.LANDING;

create or replace TABLE RETAIL_DB.LANDING.AZURE_FILE_DISCOVERY (
	SOURCE_FILENAME VARCHAR(16777216),
	FILE_SIZE_BYTES NUMBER(38,0),
	FILE_MD5 VARCHAR(16777216),
	FILE_LAST_MODIFIED TIMESTAMP_TZ(9),
	DISCOVERED_AT TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP()
);
create or replace TABLE RETAIL_DB.LANDING.INGESTION_FILE_MANIFEST (
	SOURCE_FILENAME VARCHAR(16777216) NOT NULL,
	FILE_STATUS VARCHAR(16777216) NOT NULL DEFAULT 'PENDING',
	ROWS_LOADED NUMBER(38,0) DEFAULT 0,
	FIRST_SEEN_AT TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
	COMPLETED_AT TIMESTAMP_NTZ(9),
	ERROR_MESSAGE VARCHAR(16777216),
	FILE_SIZE_BYTES NUMBER(38,0),
	FILE_MD5 VARCHAR(16777216),
	FILE_LAST_MODIFIED TIMESTAMP_TZ(9)
);
create or replace TABLE RETAIL_DB.LANDING.LANDING_RETAIL (
	INVOICENO VARCHAR(16777216),
	STOCKCODE VARCHAR(16777216),
	DESCRIPTION VARCHAR(16777216),
	QUANTITY NUMBER(38,0),
	INVOICEDATE VARCHAR(16777216),
	UNITPRICE NUMBER(38,0),
	CUSTOMERID NUMBER(38,0),
	COUNTRY VARCHAR(16777216)
);
create or replace TABLE RETAIL_DB.LANDING.RETAIL_INGESTION (
	INVOICE_NO VARCHAR(16777216),
	STOCK_CODE VARCHAR(16777216),
	DESCRIPTION VARCHAR(16777216),
	QUANTITY NUMBER(38,0),
	INVOICE_DATE VARCHAR(16777216),
	UNIT_PRICE NUMBER(12,2),
	CUSTOMER_ID NUMBER(38,0),
	COUNTRY VARCHAR(16777216),
	SOURCE_FILENAME VARCHAR(16777216),
	SOURCE_ROW_NUMBER NUMBER(38,0),
	SOURCE_ROW_ID VARCHAR(16777216),
	INGESTED_AT TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP()
);
CREATE OR REPLACE FILE FORMAT RETAIL_DB.LANDING.RETAIL_CSV_FORMAT
	SKIP_HEADER = 1
	FIELD_OPTIONALLY_ENCLOSED_BY = '\"'
	NULL_IF = ('', 'NULL', 'null')
	ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
;
CREATE OR REPLACE FILE FORMAT RETAIL_DB.LANDING.RETAIL_CSV_FORMAT_UTF8
	SKIP_HEADER = 1
	FIELD_OPTIONALLY_ENCLOSED_BY = '\"'
	NULL_IF = ('', 'NULL', 'null')
	ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
	REPLACE_INVALID_CHARACTERS = TRUE
;
CREATE OR REPLACE PROCEDURE RETAIL_DB.LANDING.PROCESS_PENDING_AZURE_FILES()
RETURNS VARCHAR
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS '
var processed = 0;
var failed = 0;
var skipped = 0;

function q(value) {
    return "''" + String(value).replace(/''/g, "''''") + "''";
}

var pending = snowflake.createStatement({
    sqlText: `
        SELECT m.SOURCE_FILENAME, m.FILE_SIZE_BYTES, m.FILE_MD5,
               d.FILE_SIZE_BYTES, d.FILE_MD5
        FROM RETAIL_DB.LANDING.INGESTION_FILE_MANIFEST m
        LEFT JOIN RETAIL_DB.LANDING.AZURE_FILE_DISCOVERY d
          ON m.SOURCE_FILENAME = d.SOURCE_FILENAME
        WHERE m.FILE_STATUS = ''PENDING''
        ORDER BY m.SOURCE_FILENAME
    `
}).execute();

while (pending.next()) {
    var filename = pending.getColumnValue(1);
    var manifestSize = pending.getColumnValue(2);
    var manifestMd5 = pending.getColumnValue(3);
    var discoveredSize = pending.getColumnValue(4);
    var discoveredMd5 = pending.getColumnValue(5);
    var f = q(filename);

    try {
        if (
            manifestSize === null || manifestMd5 === null ||
            discoveredSize === null || discoveredMd5 === null ||
            Number(manifestSize) !== Number(discoveredSize) ||
            String(manifestMd5) !== String(discoveredMd5)
        ) {
            snowflake.createStatement({
                sqlText: `
                    UPDATE RETAIL_DB.LANDING.INGESTION_FILE_MANIFEST
                    SET FILE_STATUS = ''REVIEW'',
                        ERROR_MESSAGE = ''Missing or mismatched file metadata''
                    WHERE SOURCE_FILENAME = ${f}
                      AND FILE_STATUS = ''PENDING''
                `
            }).execute();
            skipped++;
            continue;
        }

        var existing = snowflake.createStatement({
            sqlText: `
                SELECT COUNT(*)
                FROM RETAIL_DB.LANDING.RETAIL_INGESTION
                WHERE SOURCE_FILENAME = ${f}
            `
        }).execute();
        existing.next();

        if (Number(existing.getColumnValue(1)) > 0) {
            snowflake.createStatement({
                sqlText: `
                    UPDATE RETAIL_DB.LANDING.INGESTION_FILE_MANIFEST
                    SET FILE_STATUS = ''REVIEW'',
                        ERROR_MESSAGE =
                          ''Rows already exist for this file; reconcile before retry''
                    WHERE SOURCE_FILENAME = ${f}
                      AND FILE_STATUS = ''PENDING''
                `
            }).execute();
            skipped++;
            continue;
        }

        snowflake.createStatement({
            sqlText: `
                UPDATE RETAIL_DB.LANDING.INGESTION_FILE_MANIFEST
                SET FILE_STATUS = ''LOADING'', ERROR_MESSAGE = NULL
                WHERE SOURCE_FILENAME = ${f}
                  AND FILE_STATUS = ''PENDING''
            `
        }).execute();

        var copy = snowflake.createStatement({
            sqlText: `
                COPY INTO RETAIL_DB.LANDING.RETAIL_INGESTION
                (
                    INVOICE_NO, STOCK_CODE, DESCRIPTION, QUANTITY,
                    INVOICE_DATE, UNIT_PRICE, CUSTOMER_ID, COUNTRY,
                    SOURCE_FILENAME, SOURCE_ROW_NUMBER, SOURCE_ROW_ID
                )
                FROM (
                    SELECT
                        $1::VARCHAR,
                        $2::VARCHAR,
                        $3::VARCHAR,
                        $4::NUMBER,
                        $5::VARCHAR,
                        $6::NUMBER(12,2),
                        TRY_TO_NUMBER($7)::NUMBER(38,0),
                        $8::VARCHAR,
                        REGEXP_SUBSTR(METADATA$FILENAME, ''[^/]+$''),
                        METADATA$FILE_ROW_NUMBER,
                        SHA2(
                            CONCAT(
                                REGEXP_SUBSTR(METADATA$FILENAME, ''[^/]+$''),
                                ''|'',
                                METADATA$FILE_ROW_NUMBER::VARCHAR
                            ),
                            256
                        )
                    FROM @RETAIL_DB.LANDING.AZURE_RETAIL_STAGE
                )
                FILES = (${f})
                FILE_FORMAT = (
                    FORMAT_NAME =
                      ''RETAIL_DB.LANDING.RETAIL_CSV_FORMAT_UTF8''
                )
                ON_ERROR = ''ABORT_STATEMENT''
            `
        }).execute();

        var status = '''';
        while (copy.next()) {
            status = String(copy.getColumnValue(2));
        }

        if (status !== ''LOADED'' && status !== ''LOAD_SKIPPED'') {
            throw new Error(''Unexpected COPY status: '' + status);
        }

        var verify = snowflake.createStatement({
            sqlText: `
                SELECT COUNT(*),
                       COUNT(DISTINCT SOURCE_ROW_ID),
                       COUNT_IF(SOURCE_ROW_ID IS NULL)
                FROM RETAIL_DB.LANDING.RETAIL_INGESTION
                WHERE SOURCE_FILENAME = ${f}
            `
        }).execute();
        verify.next();

        var total = Number(verify.getColumnValue(1));
        var unique = Number(verify.getColumnValue(2));
        var nulls = Number(verify.getColumnValue(3));

        if (total === 0 || total !== unique || nulls !== 0) {
            throw new Error(
                ''Post-load validation failed: total='' + total +
                '', unique='' + unique + '', null='' + nulls
            );
        }

        snowflake.createStatement({
            sqlText: `
                UPDATE RETAIL_DB.LANDING.INGESTION_FILE_MANIFEST
                SET FILE_STATUS = ''COMPLETED'',
                    ROWS_LOADED = ${total},
                    COMPLETED_AT = CURRENT_TIMESTAMP(),
                    ERROR_MESSAGE = NULL
                WHERE SOURCE_FILENAME = ${f}
            `
        }).execute();

        processed++;
    } catch (err) {
        snowflake.createStatement({
            sqlText: `
                UPDATE RETAIL_DB.LANDING.INGESTION_FILE_MANIFEST
                SET FILE_STATUS = ''FAILED'',
                    ERROR_MESSAGE = ${q(err.message)}
                WHERE SOURCE_FILENAME = ${f}
            `
        }).execute();
        failed++;
    }
}

return ''Completed: '' + processed +
       ''; failed: '' + failed +
       ''; sent for review: '' + skipped + ''.'';
';
CREATE OR REPLACE PROCEDURE RETAIL_DB.LANDING.REFRESH_AZURE_FILE_DISCOVERY()
RETURNS VARCHAR
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS '
try {
    // List files in the existing Azure external stage.
    var listStmt = snowflake.createStatement({
        sqlText: "LIST @RETAIL_DB.LANDING.AZURE_RETAIL_STAGE"
    });

    listStmt.execute();
    var listQueryId = listStmt.getQueryId();

    // Merge the listing into the discovery table.
    var mergeSql = `
        MERGE INTO RETAIL_DB.LANDING.AZURE_FILE_DISCOVERY d
        USING (
            SELECT
                REGEXP_SUBSTR("name", ''[^/]+$'') AS SOURCE_FILENAME,
                "size"::NUMBER AS FILE_SIZE_BYTES,
                "md5"::VARCHAR AS FILE_MD5,
                TRY_TO_TIMESTAMP_TZ(
                    "last_modified",
                    ''DY, DD MON YYYY HH24:MI:SS TZD''
                ) AS FILE_LAST_MODIFIED
            FROM TABLE(RESULT_SCAN(''${listQueryId}''))
            WHERE "name" IS NOT NULL
        ) s
        ON d.SOURCE_FILENAME = s.SOURCE_FILENAME

        WHEN MATCHED THEN UPDATE SET
            d.FILE_SIZE_BYTES = s.FILE_SIZE_BYTES,
            d.FILE_MD5 = s.FILE_MD5,
            d.FILE_LAST_MODIFIED = s.FILE_LAST_MODIFIED,
            d.DISCOVERED_AT = CURRENT_TIMESTAMP()

        WHEN NOT MATCHED THEN INSERT (
            SOURCE_FILENAME,
            FILE_SIZE_BYTES,
            FILE_MD5,
            FILE_LAST_MODIFIED
        )
        VALUES (
            s.SOURCE_FILENAME,
            s.FILE_SIZE_BYTES,
            s.FILE_MD5,
            s.FILE_LAST_MODIFIED
        )
    `;

    snowflake.createStatement({sqlText: mergeSql}).execute();

    return ''Azure file discovery refreshed successfully.'';
} catch (err) {
    return ''Azure file discovery failed: '' + err.message;
}
';
CREATE OR REPLACE PROCEDURE RETAIL_DB.LANDING.REGISTER_NEW_AZURE_FILES()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS '
BEGIN
    MERGE INTO RETAIL_DB.LANDING.INGESTION_FILE_MANIFEST m
    USING (
        SELECT
            d.SOURCE_FILENAME,
            d.FILE_SIZE_BYTES,
            d.FILE_MD5,
            d.FILE_LAST_MODIFIED
        FROM RETAIL_DB.LANDING.AZURE_FILE_DISCOVERY d
        LEFT JOIN RETAIL_DB.LANDING.INGESTION_FILE_MANIFEST existing
            ON existing.SOURCE_FILENAME = d.SOURCE_FILENAME
        WHERE existing.SOURCE_FILENAME IS NULL
    ) d
    ON m.SOURCE_FILENAME = d.SOURCE_FILENAME

    WHEN NOT MATCHED THEN INSERT (
        SOURCE_FILENAME,
        FILE_STATUS,
        ROWS_LOADED,
        FILE_SIZE_BYTES,
        FILE_MD5,
        FILE_LAST_MODIFIED,
        ERROR_MESSAGE
    )
    VALUES (
        d.SOURCE_FILENAME,
        ''PENDING'',
        0,
        d.FILE_SIZE_BYTES,
        d.FILE_MD5,
        d.FILE_LAST_MODIFIED,
        NULL
    );

    RETURN ''New Azure files registered. No data files were loaded.'';
END;
';
CREATE OR REPLACE PROCEDURE RETAIL_DB.LANDING.RUN_RETAIL_INGESTION()
RETURNS VARCHAR
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS '
function runSql(sql) {
    return snowflake.createStatement({sqlText: sql}).execute();
}

// 1. Refresh the Azure file listing.
var discovery = runSql(
    "CALL RETAIL_DB.LANDING.REFRESH_AZURE_FILE_DISCOVERY()"
);
discovery.next();

var discoveryMessage = String(discovery.getColumnValue(1));

if (discoveryMessage.indexOf(''failed'') >= 0) {
    throw new Error(
        ''Discovery failed: '' + discoveryMessage
    );
}

// 2. Register newly discovered files.
var registration = runSql(
    "CALL RETAIL_DB.LANDING.REGISTER_NEW_AZURE_FILES()"
);
registration.next();

// 3. Process pending files.
var loader = runSql(
    "CALL RETAIL_DB.LANDING.PROCESS_PENDING_AZURE_FILES()"
);
loader.next();

var loaderMessage = String(loader.getColumnValue(1));

// 4. Gate downstream processing on manifest status.
var check = runSql(`
    SELECT
        COUNT_IF(FILE_STATUS = ''COMPLETED'') AS COMPLETED_FILES,
        COUNT_IF(FILE_STATUS = ''PENDING'') AS PENDING_FILES,
        COUNT_IF(FILE_STATUS = ''LOADING'') AS LOADING_FILES,
        COUNT_IF(FILE_STATUS = ''FAILED'') AS FAILED_FILES,
        COUNT_IF(FILE_STATUS = ''REVIEW'') AS REVIEW_FILES
    FROM RETAIL_DB.LANDING.INGESTION_FILE_MANIFEST
`);
check.next();

var completed = Number(check.getColumnValue(1));
var pendingCount = Number(check.getColumnValue(2));
var loading = Number(check.getColumnValue(3));
var failedCount = Number(check.getColumnValue(4));
var review = Number(check.getColumnValue(5));

if (
    pendingCount > 0 ||
    loading > 0 ||
    failedCount > 0 ||
    review > 0
) {
    return ''INGESTION_NOT_READY_FOR_DBT. '' +
           ''Loader: '' + loaderMessage +
           ''; completed='' + completed +
           '', pending='' + pendingCount +
           '', loading='' + loading +
           '', failed='' + failedCount +
           '', review='' + review +
           ''. Investigate the manifest before running dbt.'';
}

return ''INGESTION_READY_FOR_DBT. '' +
       ''Loader: '' + loaderMessage +
       ''; completed files='' + completed +
       ''. Ingestion checks passed; dbt has not been run.'';
';
create or replace task RETAIL_DB.LANDING.DAILY_RETAIL_INGESTION_TASK
	warehouse=SNOWFLAKE_LEARNING_WH
	schedule='USING CRON 0 2 * * * UTC'
	as CALL RETAIL_DB.LANDING.RUN_RETAIL_INGESTION();
create or replace schema RETAIL_DB.MART;

create or replace schema RETAIL_DB.PUBLIC;

create or replace schema RETAIL_DB.STAGING;
