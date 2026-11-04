# Data Quality, Testing & Reconciliation

**Project:** Retail Analytics Engineering Platform  
**Stack:** Azure Blob Storage · Snowflake · dbt · Power BI  
**Scope:** Ingestion validation, dbt model tests, financial reconciliation, and known data-quality limitations.

> **Implementation status:** This document describes checks found in the uploaded dbt project and the `PROCESS_PENDING_AZURE_FILES()` Snowflake stored procedure shared with the project. Historical successful `dbt build` results were reported during development; this repository does not, by itself, include a current CI test report or prove that every check is passing in a live deployment.

## 1. Quality Objectives

The pipeline aims to:

- Prevent unverified or duplicate source files from being silently loaded.
- Maintain an identifiable origin for each ingested transaction line.
- Enforce model-level key uniqueness and required-field completeness.
- Preserve transaction counts and signed financial values from landing to fact.
- Detect source-to-fact discrepancies at the individual transaction-row level.
- Apply documented business rules consistently in analytical marts.

## 2. Quality Controls by Pipeline Layer

| Layer | Implemented control | What it checks |
|---|---|---|
| Azure-to-Snowflake ingestion | File-manifest status | Files move through `PENDING`, `LOADING`, `COMPLETED`, `FAILED`, or `REVIEW`. |
| Pre-load | File size and MD5 comparison | Manifest metadata matches current discovery metadata before loading. |
| Pre-load | Existing-row check | A file is sent for review if rows with the same `SOURCE_FILENAME` already exist in `RETAIL_INGESTION`. |
| Load | `COPY INTO` with `ON_ERROR = 'ABORT_STATEMENT'` | A load statement does not silently continue past a detected parsing error. |
| Load | Source lineage fields | `SOURCE_FILENAME`, `SOURCE_ROW_NUMBER`, and SHA-256 `SOURCE_ROW_ID` are populated by the copy query. |
| Post-load | Row-ID checks | A processed file must have at least one row, no null source IDs, and one distinct ID per loaded row. |
| dbt models | Generic YAML tests | Required fields, unique identifiers, valid RFM scores, and specified categories. |
| Financial reconciliation | Aggregate singular test | Landing and incremental fact row counts and signed financial totals agree. |
| Financial reconciliation | Row-level singular test | Source-row IDs and associated quantities, prices, and line values agree across layers. |

### Ingestion procedure flow

The provided `RETAIL_DB.LANDING.PROCESS_PENDING_AZURE_FILES()` JavaScript stored procedure:

1. Selects `PENDING` files from `INGESTION_FILE_MANIFEST`, joining to `AZURE_FILE_DISCOVERY`.
2. Compares recorded and discovered file size/MD5. Missing or mismatched values result in `REVIEW`.
3. Checks whether records with the same source filename already exist in `RETAIL_INGESTION`; if so, flags the file for `REVIEW`.
4. Marks a file `LOADING` and executes `COPY INTO RETAIL_DB.LANDING.RETAIL_INGESTION` from `@RETAIL_DB.LANDING.AZURE_RETAIL_STAGE` using the selected filename, configured CSV format, and `ON_ERROR = 'ABORT_STATEMENT'`.
5. Checks the copy status; verifies per-file row count, distinct source IDs, and null source IDs.
6. Marks the manifest `COMPLETED` with `ROWS_LOADED` or records the error as `FAILED`.

`SOURCE_ROW_ID` is computed as SHA-256 of the **source filename and file row number**. This makes the identifier repeatable for the same file/row, but means renaming or reordering a file can change the identity of its records. The procedure's existing-row check is a safeguard, **not** a guarantee of exactly-once ingestion or automatic rollback across all possible partial failures.

## 3. dbt Generic Model Tests

The dbt project uses `data_tests:` definitions in model `.yml` files. dbt runs these tests as part of `dbt build` or with `dbt test`.

### Dimensions

| Model | Relevant implemented tests |
|---|---|
| `dim_customer` | `customer_key`, `customer_id`: `unique`, `not_null` |
| `dim_product` | `productkey`, `stockcode`: `unique`, `not_null` |
| `dim_invoice` | `invoice_key`, `invoiceno`: `unique`, `not_null` |
| `dim_date` | `date_key`, `date`: `unique`, `not_null`; `month`, `year`: `not_null` |
| `dim_country` | `country_key`, `country`: `unique`, `not_null` |

### Facts

- **`fact_sale_incremental`:** `SOURCE_ROW_ID` must be unique and not null. `INVOICE_KEY`, `PRODUCT_KEY`, `DATE_KEY`, and `COUNTRY_KEY` must not be null.
- **`fact_sales`:** invoice, product, date, country keys and the invoice/product business identifiers have `not_null` tests.
- **Customer keys:** Null customer references are possible in the dataset and are not universally rejected. This is intentional, not automatically a test failure.

### Analytics marts

| Model | Implemented test focus |
|---|---|
| `mart_monthly_revenue` | Required monthly metrics and dates; `MOM_GROWTH_PCT` may be null for unavailable or deliberately excluded comparisons. |
| `mart_customer_rfm` | Unique and non-null `CUSTOMER_ID`; required RFM metrics; `R_SCORE`, `F_SCORE`, `M_SCORE` must be in 1–5; segment in the documented set. |
| `mart_customer_cohorts` | Non-null cohort dates, month offset, cohort size, active-customer count, and retention percentage. |
| `mart_product_pareto` | Unique/non-null `PRODUCT_CODE` and `REVENUE_RANK`, required metrics; `ABC_CATEGORY` must be A, B, or C. |
| `mart_product_cancellation` | Unique/non-null `PRODUCT_CODE`; required sold/cancelled unit and value metrics. `CANCELLATION_RATE_PCT` is allowed to be null where sold units are zero. |

**Important distinction:** Standard `not_null`, `unique`, and `accepted_values` tests establish specific properties, but they **do not** independently verify every business rule, referential relationship, reasonable range, or financial formula.

## 4. Financial Reconciliation Tests

The export includes two dbt **singular tests** in `tests/`. A singular test passes when its SQL query returns **zero rows**.

### 4.1 Aggregate reconciliation

**File:** `tests/reconcile_landing_fact_financial.sql`

Compares `RETAIL_DB.LANDING.RETAIL_INGESTION` with `{{ ref('fact_sale_incremental') }}` for:

- Total row count.
- Total signed transaction value: `SUM(QUANTITY * UNIT_PRICE)`.

It returns a failure row when counts differ or the financial totals are distinct.

**Why this matters:** A transformation or join that drops/duplicates records, or changes signed transaction value, should be flagged.

**Limitation:** Aggregate reconciliation alone could miss offsetting errors, so the second test checks individual rows.

### 4.2 Source-row financial reconciliation

**File:** `tests/reconcile_source_row_financial.sql`

Uses a full outer join on `SOURCE_ROW_ID` and explicitly checks for the following issue types:

| Returned issue type | Meaning |
|---|---|
| `EXTRA_IN_FACT` | Fact row not found in landing. |
| `MISSING_IN_FACT` | Landing row not found in fact. |
| `QUANTITY_MISMATCH` | Quantity differs for the same source row. |
| `PRICE_MISMATCH` | Unit price differs for the same source row. |
| `VALUE_MISMATCH` | `QUANTITY * UNIT_PRICE` differs. |
| `DUPLICATE_IN_LANDING` | Repeated `SOURCE_ROW_ID` in landing. |
| `DUPLICATE_IN_FACT` | Repeated `SOURCE_ROW_ID` in fact. |
| `NULL_ID_IN_LANDING` | Null source row ID in landing. |
| `NULL_ID_IN_FACT` | Null source row ID in fact. |

**Why this matters:** The row-level test can identify record-specific discrepancies that are hidden by aggregate sums. `IS DISTINCT FROM` also makes comparison null-aware.

**Scope:** Both reconciliation tests use `RETAIL_INGESTION` as the transaction source. They do **not** independently establish whether the five dimensions sourced from `LANDING_RETAIL` are synchronized with `RETAIL_INGESTION`.

## 5. Business Rule and Metric Validation

For reporting, compare Power BI outputs with the same underlying dbt/Snowflake logic and filters, not with unrelated gross-sales figures.

| Report area | Rule / validation consideration |
|---|---|
| Net revenue | Signed sum of `QUANTITY * UNIT_PRICE`; negative quantities reduce revenue. |
| Monthly MoM | Historical data includes partial reporting periods; growth is intentionally blank for some months. |
| RFM | Valid positive purchases; excludes missing customer IDs, cancellations, non-positive quantities/prices. Scores are constrained to 1–5. |
| Customer cohorts | Tracks customers from first valid purchase month; excludes invalid/cancellation purchases by model rules. |
| Pareto / ABC | Based on positive eligible merchandise revenue, not necessarily the same denominator as total signed net revenue. |
| Product cancellations | Unit cancellation rate can exceed 100% where cancellations exceed observed sales. Null is expected if sold units are zero. |

### Historical reconciliation reference

During development, the project reported:

- **541,909** source transaction rows.
- Approximately **£9.75 million** signed net revenue.
- Approximately **£470.27** average order value in Power BI.
- **24.93%** missing customer ID rate.

These are historical benchmark values, not assertions about the current Snowflake account. Use a new `dbt build` plus targeted Snowflake and Power BI checks to confirm the current state before publication.

## 6. How to Run and Review the Checks

From the **dbt project root** with a valid Snowflake connection:

```bash
dbt debug
dbt build
dbt test
```

You can also run the singular financial checks specifically:

```bash
dbt test --select reconcile_landing_fact_financial reconcile_source_row_financial
```

To generate documentation:

```bash
dbt docs generate
```

**Review checklist:**

1. Confirm `dbt build` completes with no failing tests.
2. Review failures by model, column, and test name if a build fails.
3. Verify both singular reconciliation tests return no failure rows.
4. Confirm any recent Azure source file is marked `COMPLETED` only after post-load validation.
5. Refresh Power BI and reconcile the headline KPIs to the warehouse using consistent definitions.
6. Keep sanitized build/test output as optional evidence in `docs/evidence/` (never commit tokens or connection secrets).

## 7. Known Gaps and Future Improvements

These are improvement opportunities, **not features claimed to exist today**:

- **Referential integrity tests:** Add dbt `relationships` tests for fact foreign keys against dimension primary keys, with intentional handling for missing customers.
- **Source consistency:** Validate that `LANDING_RETAIL` and `RETAIL_INGESTION` contain compatible business identifiers; consider one governed canonical source in a future iteration.
- **Source freshness:** Add appropriate source declarations and freshness monitoring if using continuously arriving data.
- **Stronger business assertions:** Add range or expression tests, e.g. cohort active customers ≤ cohort size and expected RFM/ABC invariants, after agreeing the precise rules.
- **Change-data handling:** The incremental fact currently excludes existing `SOURCE_ROW_ID`s on incremental runs. A future version could support changed source rows and controlled reprocessing.
- **CI/CD evidence:** Add a sanitized example test run or workflow once automated validation is configured and verified.
- **Failure recovery:** Document and test rerun behaviour following a failed/partially applied file load.

## 8. Source Files Reviewed

- `models/marts/dimensions/*.yml` — dimension and fact generic tests.
- `models/marts/*.yml` — analytics mart generic tests.
- `tests/reconcile_landing_fact_financial.sql` — aggregate source-to-fact reconciliation.
- `tests/reconcile_source_row_financial.sql` — source-row-level reconciliation.
- `RETAIL_DB.LANDING.PROCESS_PENDING_AZURE_FILES()` — stored procedure supplied in the project conversation (not present in the dbt ZIP).

For the modelling architecture, see [`data_model.md`](data_model.md). For the project introduction, see [`README.md`](../README.md).
