# Retail Analytics Engineering Platform

**End-to-end retail data engineering and business intelligence using Azure, Snowflake, dbt, and Power BI.**

An engineering-focused portfolio project that transforms historical retail transactions into reliable, analytics-ready data models and interactive business dashboards.

**Tech stack:** Azure Blob Storage · Snowflake · dbt Cloud · SQL · Power BI

---

## Table of Contents

- [Overview](#overview)
- [Selected Dashboard Results](#selected-dashboard-results)
- [Data Visualization](#data-visualization)
- [Data Architecture](#data-architecture)
- [Data Modelling](#data-modelling)
- [Prerequisites](#prerequisites)
- [How to Run This Project](#how-to-run-this-project)
- [Lessons Learned](#lessons-learned)
- [Contact](#contact)

---

## Overview

Retail businesses need trusted data to understand revenue performance, customer retention, product contribution, and cancellations. This project demonstrates an end-to-end analytics workflow, from cloud file ingestion through dimensional modelling and reporting.

The pipeline ingests the **Online Retail dataset** (541,909 transaction rows, December 2010 – December 2011) into Snowflake, transforms it with dbt, validates the financial results, and exposes curated models to Power BI.

## Selected Dashboard Results

| Metric | Result |
|---|---|
| Source transaction rows | 541,909 |
| Net revenue (signed quantity × unit price) | £9.75M |
| Average order value | £470.27 |
| Missing customer ID rate | 24.93% |

> These are historical project results, not live retail metrics.

## Data Visualization

The Power BI report contains two pages.

### Page 1 — Retail Sales Overview

- Net revenue, average order value, and missing customer ID rate
- Monthly revenue and month-over-month growth
- UK vs. international revenue and revenue share by country
- Average order value by country and weekday revenue patterns

<!-- TODO: Export the finished Power BI page into docs/images/ and uncomment the line below.
![Retail Sales Overview](docs/images/retail-sales-overview.png)
-->

### Page 2 — Customer & Product Intelligence

- RFM customer segmentation
- Customer cohort retention
- Product Pareto / ABC analysis
- Product cancellation analysis

<!-- TODO: Export the finished Power BI page into docs/images/ and uncomment the line below.
![Customer & Product Intelligence](docs/images/customer-product-intelligence.png)
-->

## Data Architecture

<!-- TODO: Add the architecture diagram to docs/images/ and uncomment the line below.
![Current retail analytics architecture](docs/images/architecture.png)
-->

### Why these tools?

| Tool | Role |
|---|---|
| **Azure Blob Storage** | Cloud landing location for the source CSV |
| **Snowflake** | Data loading, warehouse storage, and SQL processing |
| **dbt** | Modular transformations, model dependencies, documentation, and data-quality tests |
| **Power BI** | Turns curated data into business-facing dashboards |

### Current source design

The five dimensions read from `RETAIL_DB.LANDING.LANDING_RETAIL`, while `FACT_SALE_INCREMENTAL` reads transaction rows from `RETAIL_DB.LANDING.RETAIL_INGESTION` and joins to those dimensions through dbt `ref()` references.

This is the existing implementation; the two landing tables have not been consolidated.

## Data Modelling

| Layer | Models |
|---|---|
| **Dimensions** | `dim_customer`, `dim_product`, `dim_invoice`, `dim_date`, `dim_country` |
| **Facts** | `fact_sale_incremental`, `fact_sales` |
| **Analytics marts** | `mart_monthly_revenue`, `mart_customer_rfm`, `mart_customer_cohorts`, `mart_product_pareto`, `mart_product_cancellation` |

The incremental fact uses `SOURCE_ROW_ID` as its unique key and a dbt `merge` configuration. Because the SQL excludes already-loaded row IDs on incremental runs, normal execution is effectively insert-only.

### Orchestration

- **02:00 UTC** — Snowflake ingestion
- **03:00 UTC** — dbt build

Cloud job settings are not included in the dbt export and will need separate evidence or documentation.

## Prerequisites

To reproduce the transformation layer, you need:

- A **Snowflake** account with permission to create and query tables/views, and access to the required `RETAIL_DB` objects.
- An **Azure Blob Storage** container with the Online Retail source file, plus a configured Snowflake storage integration, external stage, and load process.
- The two Snowflake landing tables expected by the existing SQL, with the appropriate column names:
  - `RETAIL_DB.LANDING.RETAIL_INGESTION`
  - `RETAIL_DB.LANDING.LANDING_RETAIL`
- **dbt Cloud** or **dbt Core** with the Snowflake adapter, configured with valid Snowflake credentials and an appropriate target schema.
- **Power BI Desktop** and Snowflake access to reproduce the report.

> **Before running:** The exported dbt repository contains transformations and tests, but it does not contain all Snowflake ingestion scripts, credentials, Power BI report assets, or cloud job configuration. The full pipeline cannot yet be reproduced from this repository alone.

## How to Run This Project

The following steps cover the available dbt transformation code and describe the external setup needed for the rest of the pipeline.

1. **Prepare the source data.**
   Upload the historical Online Retail CSV to Azure Blob Storage. Configure the Snowflake external stage, file format, and `COPY INTO` workflow, then populate the required landing tables. The ingestion SQL and exact infrastructure configuration must be supplied separately.

2. **Configure Snowflake access.**
   Confirm that `RETAIL_DB.LANDING.RETAIL_INGESTION` and `RETAIL_DB.LANDING.LANDING_RETAIL` are populated and readable by the dbt role.

3. **Open the dbt project.**
   Use the exported dbt project (its `dbt_project.yml` currently declares the internal project name `my_new_project`). Configure a Snowflake connection in dbt Cloud or an appropriate local dbt profile.

4. **Install dependencies and build the models.**
   From the dbt project root, run:

   ```bash
   dbt deps
   dbt build
   ```

5. **Review test results.**
   Check the model tests and the custom financial reconciliation tests:

   - `tests/reconcile_landing_fact_financial.sql`
   - `tests/reconcile_source_row_financial.sql`

   The tests compare source/fact counts, values, and individual source-row consistency. A successful `dbt build` should complete without test failures.

6. **Generate dbt documentation (optional).**

   ```bash
   dbt docs generate
   dbt docs serve
   ```

7. **Connect Power BI.**
   Load the fact, dimensions, and analytics marts from Snowflake, recreate or open the report, and verify the published dashboard measures against Snowflake.

8. **Validate key outputs.**
   Check the 541,909 source rows and reconcile signed net revenue to approximately £9.75M under the same filters and calculation rules.

> **Scheduling note:** The configured Snowflake and dbt Cloud schedules are managed outside the exported dbt SQL files. Set these up separately if automating a new deployment.

## Lessons Learned

### What worked well

- **Separation of responsibilities:** Azure handles file storage, Snowflake handles warehousing, dbt handles SQL transformation and testing, and Power BI handles presentation.
- **Modular analytics:** Reusable fact and dimension models support multiple retail questions without duplicating business logic in each dashboard.
- **Data-quality validation:** Financial reconciliation tests help detect row-count and revenue discrepancies between landing and fact layers.
- **Business-oriented modelling:** RFM, cohort retention, ABC analysis, and cancellations connect engineering work to practical retail decisions.

### Challenges and improvements for a future iteration

- **Consistent source design:** Consolidate or explicitly synchronize `LANDING_RETAIL` and `RETAIL_INGESTION` to reduce lineage ambiguity.
- **Incremental updates:** Extend the fact logic to handle changed existing source rows, not only new `SOURCE_ROW_ID` values.
- **Historical-data limitations:** Treat partial months and cancellations carefully; some product cancellation rates can exceed 100% when sales and cancellations do not align within the period.
- **Reporting interactions:** Some standalone analytics marts are intentionally disconnected from the central Power BI model, so slicer behaviour needs to be documented and tested.
- **Reproducibility:** Export ingestion scripts, environment setup instructions, job configuration evidence, and report assets so another engineer can run the full solution independently.

## Contact

**Portfolio author:** Gokul K S

- **LinkedIn:** _Add your public LinkedIn profile URL_
- **GitHub:** _Add your GitHub profile or repository URL_

Feedback, technical questions, and collaboration opportunities are welcome.

---

**Data source:** historical Online Retail transactional dataset.

> **Security note:** Do not commit Snowflake credentials, Azure tokens, dbt Cloud secrets, or other private connection details. Verify dataset redistribution permissions before uploading the raw CSV.
