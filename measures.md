# Power BI Measures & Metric Definitions

**Project:** Retail Analytics Engineering Platform  
**Reporting tool:** Microsoft Power BI  
**Warehouse:** Snowflake  
**Transformation layer:** dbt

> **Scope and provenance:** This document describes **13 reporting metrics/analyses** used in the project's two dashboard pages. They are **not asserted to be the exact 13 DAX expressions** in the finished `.pbix`: the PBIX or a DAX/Tabular Editor measure export was not available for inspection. Some metrics come from **precalculated dbt mart columns**, some may be **DAX measures**, and some are visual aggregations. Replace the illustrative DAX snippets with exported definitions before presenting this as an exact code inventory.

## 1. Model inputs and grain

- **Transaction fact:** `FACT_SALE_INCREMENTAL` (one source file row identified by `SOURCE_ROW_ID`; signed `QUANTITY` and `UNIT_PRICE`).
- **Dimensions:** `DIM_CUSTOMER`, `DIM_PRODUCT`, `DIM_INVOICE`, `DIM_DATE`, and `DIM_COUNTRY`.
- **Analytics marts:** `MART_MONTHLY_REVENUE`, `MART_CUSTOMER_RFM`, `MART_CUSTOMER_COHORTS`, `MART_PRODUCT_PARETO`, and `MART_PRODUCT_CANCELLATION`.
- The five marts are sourced from `fact_sale_incremental` in dbt. Some marts are intentionally **disconnected** in Power BI, which affects report slicer propagation.
- **All monetary results are GBP**, based on the project's reporting assumption; the source does not provide currency conversion data.

## 2. Metric catalog

| # | Metric or visual calculation | Definition / intended logic | Primary source | Reporting notes |
|---|---|---|---|---|
| 1 | **Net Revenue** | Sum of signed `QUANTITY × UNIT_PRICE` | `FACT_SALE_INCREMENTAL` | Dashboard benchmark **£9.75M**; negative quantities reduce revenue. |
| 2 | **Average Order Value (AOV)** | Net revenue divided by distinct invoices under consistent filters | Fact + invoice identifier | Dashboard benchmark **£470.27**. Confirm cancellation-invoice treatment in exported DAX. |
| 3 | **Missing Customer ID Rate** | Transaction rows with blank customer ID ÷ all relevant transaction rows × 100 | Fact | Dashboard benchmark **24.93%**; row-level, not customer-level. |
| 4 | **Month-over-Month Revenue Growth** | `(current-month revenue − previous-month revenue) ÷ previous-month revenue × 100` | `MART_MONTHLY_REVENUE.MOM_GROWTH_PCT` | Already stored on a 0–100 scale; the initial and intentionally excluded partial-period comparisons display blank. |
| 5 | **UK vs Non-UK Revenue** | Sum signed revenue grouped into United Kingdom and other countries | Fact + `DIM_COUNTRY`, or report grouping | Displayed approximately **£8.19M (84%)** UK and **£1.56M (16%)** Non-UK. |
| 6 | **Revenue Share by Country** | Country revenue ÷ total revenue in the relevant reporting context × 100 | Fact + `DIM_COUNTRY` | The denominator must be defined deliberately when country slicers are applied. |
| 7 | **AOV by Country** | Country-specific net revenue ÷ distinct country-specific invoice count | Fact + invoice/country dims | GBP formatted; country values depend on invoice/cancellation filtering. |
| 8 | **Net Revenue by Weekday** | Sum signed revenue by calendar weekday | Fact + `DIM_DATE` | Sort by weekday number, not alphabetically; Saturday may be absent. |
| 9 | **Average Revenue per Trading Day** | Weekday revenue ÷ distinct dates with qualifying transactions for that weekday | Fact + `DIM_DATE` | Keep distinct from total weekday revenue; verify the actual DAX denominator. |
| 10 | **Customers by RFM Segment** | Count distinct customers (or mart rows) per RFM segment | `MART_CUSTOMER_RFM.CUSTOMER_SEGMENT` | Confirmed report has **4,338** segmented customers over five displayed categories. |
| 11 | **Cohort Retention Rate** | `ACTIVE_CUSTOMERS ÷ COHORT_SIZE × 100` by cohort month and month index | `MART_CUSTOMER_COHORTS.RETENTION_PCT` | Already stored as percentage points (0–100); matrix heatmap uses this value. |
| 12 | **Cumulative Product Revenue Share / ABC** | Running sum of product revenue by descending rank ÷ total eligible product revenue × 100 | `MART_PRODUCT_PARETO.CUMULATIVE_REVENUE_PCT`, `ABC_CATEGORY` | A/B/C categories use cumulative revenue thresholds of **80% / 95%**. Positive merchandise sales only; not identical to total signed revenue. |
| 13 | **Product Unit Cancellation Rate** | `CANCELLED_UNITS ÷ SOLD_UNITS × 100`; blank when sold units are zero | `MART_PRODUCT_CANCELLATION.CANCELLATION_RATE_PCT` | Rates above 100% can be valid for the historic observation period; the dashboard may filter them from a comparison visual. |

> **Do not sum percentage fields across months, products, or cohorts.** Select the desired row or calculate a properly weighted ratio from the underlying numerators and denominators.

## 3. Illustrative DAX patterns — not verified PBIX code

The following are **examples** of how selected metrics could be implemented in Power BI. They are **not copied from the finished report**, and column/measure names must be verified against the model before use.

### Net Revenue

```dax
Net Revenue =
SUMX (
    'FACT_SALE_INCREMENTAL',
    'FACT_SALE_INCREMENTAL'[QUANTITY]
        * 'FACT_SALE_INCREMENTAL'[UNIT_PRICE]
)
```

### Missing Customer ID Rate

```dax
Missing Customer ID Rate =
DIVIDE (
    CALCULATE (
        COUNTROWS ( 'FACT_SALE_INCREMENTAL' ),
        ISBLANK ( 'FACT_SALE_INCREMENTAL'[CUSTOMER_ID] )
    ),
    COUNTROWS ( 'FACT_SALE_INCREMENTAL' )
)
```

This example returns **0–1** and must use a standard percentage format. By contrast, the `*_PCT` columns produced by the dbt marts above are generally **0–100** values and should use a custom display format like `0.0"%"` to avoid multiplying the displayed percentage by 100 again.

### Distinct-Invoice AOV

```dax
Average Order Value =
DIVIDE (
    [Net Revenue],
    DISTINCTCOUNT ( 'FACT_SALE_INCREMENTAL'[INVOICENO] )
)
```

The exact live measure should be checked, particularly whether negative or cancellation-only invoices are included in the denominator. The illustration may not reproduce £470.27 until the original business rules are applied.

## 4. Dashboard coverage

### Retail Sales Overview

- KPI cards: Net Revenue, AOV, Missing Customer ID Rate.
- Monthly Revenue & MoM Growth: `MART_MONTHLY_REVENUE` revenue and growth series.
- UK vs Non-UK Revenue; country revenue share and AOV.
- Revenue by Weekday and Average Revenue per Trading Day by Weekday.

### Customer & Product Intelligence

- RFM segment counts from `MART_CUSTOMER_RFM`.
- Cohort retention matrix from `MART_CUSTOMER_COHORTS`.
- Product Pareto and ABC ranking from `MART_PRODUCT_PARETO`.
- Unit cancellation rate comparison from `MART_PRODUCT_CANCELLATION`.

## 5. Validation reference and caveats

| Validation item | Expected / observed reference | Notes |
|---|---|---|
| Original ingested rows | **541,909** | This is a source count, not necessarily the row count of every filtered mart. |
| Signed total revenue | **Approx. £9.75M** | Compare against Snowflake using `SUM(QUANTITY * UNIT_PRICE)` and the same filtering context. |
| AOV | **£470.27** | Validate against the exact invoice denominator in the saved measure. |
| Missing customer ID rate | **24.93%** | Count blank source customer IDs over transaction rows. |
| RFM customer segments | **4,338 customers** | Five segments in the completed report; unknown customers are excluded. |

**Design cautions**

1. **Disconnected marts:** Slicers from dimensions do not automatically filter disconnected marts. Describe independent visuals clearly and avoid claiming a global filter affects all charts.
2. **Partial months:** The dataset starts in December 2010 and ends in December 2011; month-on-month growth intentionally excludes comparisons involving partial periods as configured in the dbt mart.
3. **Cancellation rates:** Cancellations can refer to sales outside the selected period; product-level cancellation rates can exceed 100%.
4. **Cancellation versus signed revenue:** Pareto uses eligible positive merchandise sales, whereas total Net Revenue includes negative quantities; totals should not be expected to match.
5. **Refresh:** A successful Power BI Desktop refresh is not evidence that scheduled Power BI Service refresh has been configured.

## 6. How to capture the exact Power BI measures

For a code-accurate version of this document, export the measures from the **completed PBIX** using Power BI Desktop's model view/measure formula bar or a compatible model metadata tool such as Tabular Editor. For each measure, record:

- Exact measure name and full DAX expression
- Home table and referenced columns
- Output format (GBP, decimal or percentage)
- The visual(s) that use it
- Reconciliation result, where applicable

Replace the illustrative DAX above with the exported expressions and amend the metric catalog if the PBIX has a different count or set of actual measures.

---

**Related documentation:** [`../docs/data_model.md`](../docs/data_model.md) · [`../docs/data_quality.md`](../docs/data_quality.md)
