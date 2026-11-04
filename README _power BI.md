# Power BI — Retail Sales and Customer Intelligence

**Project:** [Retail Analytics Engineering Platform](../README.md)  
**Data source:** Snowflake, transformed with dbt  
**Report:** Two-page interactive Power BI dashboard

## Overview

This Power BI reporting layer turns the project's curated Snowflake fact, dimensions, and dbt analytics marts into retail performance and customer/product intelligence. The dashboard answers four practical questions:

1. How much net revenue did the business generate, and how did it change over time?
2. Which markets and weekdays contributed most to sales?
3. How do customer segments and acquisition cohorts perform?
4. Which products drive revenue, and where are cancellations concentrated?

The underlying Online Retail dataset is **historical** (December 2010–December 2011). These are portfolio analytics rather than live business results.

### Key report outputs

| KPI | Validated report value | Interpretation |
|---|---:|---|
| Net Revenue | **£9.75M** | Signed quantity × unit price, including negative transactions |
| Average Order Value | **£470.27** | Revenue per order under the report's invoice-counting rules |
| Missing Customer ID Rate | **24.93%** | Share of source transaction rows without a customer identifier |
| RFM Customer Population | **4,338** | Customers represented in the report's five RFM segments |

> Totals are rounded for display. Verify figures against Snowflake under the same filters; see [measures.md](measures.md) and [data quality documentation](../docs/data_quality.md).

## Dashboard Pages

### Page 1 — Retail Sales Overview

The sales page brings together:

- **KPI cards:** Net Revenue, Average Order Value and Missing Customer ID Rate.
- **Monthly Revenue & MoM Growth:** Revenue columns and monthly growth line across the dataset's 13 calendar months.
- **UK vs Non-UK Revenue:** Revenue split between the United Kingdom and international markets.
- **Revenue Share by Country:** Ranked market contributions.
- **Average Order Value by Country:** Order-size comparison between markets.
- **Net Revenue by Weekday:** Sales distribution over days of the week.
- **Average Revenue per Trading Day by Weekday:** Comparison of daily averages rather than only total weekday volume.


<img width="1202" height="686" alt="Screenshot 2026-11-04 201926" src="https://github.com/user-attachments/assets/f297ca32-ae04-4d0e-b69c-4174082b0f0b" />

### Page 2 — Customer & Product Intelligence

This page focuses on customer behaviour and product performance:

- **RFM Segmentation:** Customers grouped by recency, purchase frequency and monetary value.
- **Cohort Retention Heatmap:** Retention by acquisition month and months since first purchase.
- **Product Pareto / ABC Analysis:** Revenue contribution and cumulative share across products.
- **Product Cancellation Analysis:** Unit cancellation rates, with dashboard-level eligibility filters for comparable products.


<img width="1202" height="681" alt="Screenshot 2026-11-04 201949" src="https://github.com/user-attachments/assets/6bd2ca65-b0a2-4ed1-894b-4d89c958c05c" />



## Data Model and Snowflake Inputs

The central reporting model uses the incremental transaction fact alongside five conformed dimensions. The project also loads specialised dbt marts for more complex analyses.

| Type | Snowflake / dbt object | Role in the report |
|---|---|---|
| Fact | `FACT_SALE_INCREMENTAL` | Transaction-level quantity, price and dimension keys |
| Dimension | `DIM_CUSTOMER` | Customer attributes and identity |
| Dimension | `DIM_PRODUCT` | Product grouping and identifiers |
| Dimension | `DIM_INVOICE` | Invoice identifiers |
| Dimension | `DIM_DATE` | Calendar and weekday analysis |
| Dimension | `DIM_COUNTRY` | Market attribution |
| Mart | `MART_MONTHLY_REVENUE` | Monthly revenue and MoM growth |
| Mart | `MART_CUSTOMER_RFM` | RFM segments |
| Mart | `MART_CUSTOMER_COHORTS` | Cohort retention |
| Mart | `MART_PRODUCT_PARETO` | Product revenue ranks and ABC categories |
| Mart | `MART_PRODUCT_CANCELLATION` | Sold/cancelled units and cancellation rates |

### Relationships and filtering

- The five dimensions relate to the transaction fact using their respective dimension keys.
- The RFM mart is connected to the customer dimension; the Pareto and cancellation marts have product-level relationships in the existing model.
- The monthly revenue and cohort marts are **disconnected** in the report model. As a result, not all dimension slicers propagate to those visuals.
- This is an intentional property of the existing implementation, **not** a claim that every page filter affects every chart. Test interactions before publishing a modified report.

For a more detailed explanation of model grain and lineage, see [`docs/data_model.md`](../docs/data_model.md).

## Metric Definitions and Formatting

The main report KPIs and analytics metrics are documented in **[measures.md](measures.md)**. It includes definitions, source references, formatting expectations and illustrative DAX snippets.

**Important distinctions:**

- `Net Revenue` includes negative transaction quantities; it is not equivalent to gross positive product sales.
- Several dbt columns ending in `_PCT` already store percent **points** on a **0–100** scale. In Power BI, a custom format such as `0.0"%"` prevents accidental multiplication by 100.
- The report's **December 2010** and **December 2011** periods are incomplete; month-over-month comparisons involving partial periods require caution. The dbt monthly mart intentionally leaves the relevant growth values blank.
- Some product cancellation rates can legitimately exceed 100% because sales and cancellations may fall in different periods. A filtered Top 10 visual does not alter the underlying source data.
- The documented 13 reporting metrics/analyses are **not verified as the exact inventory of 13 DAX measures**, since no PBIX measure export has been supplied.

## How to Open or Rebuild the Report

> **Current repository status:** The `.pbix` file and screenshots are **not included in this documentation package**. If they are uploaded later, update this section and the screenshot references to match.

1. **Prepare Snowflake.** Ensure the project's dbt models have been built and verified. The central fact, dimensions and five analytics marts should be accessible to the reporting role.
2. **Open Power BI Desktop.** Use **Get Data → Snowflake** and provide the Snowflake server hostname and warehouse or connection information appropriate for your environment. Authenticate using your approved account method.
3. **Load the required tables or views.** Select the fact, dimensions and relevant marts. Confirm data types for dates, amounts, IDs and numeric percentage-point fields.
4. **Review model relationships.** Recreate the dimensional relationships and any intentionally independent marts as described above; do not automatically relate tables solely because they share a similarly named column.
5. **Create or import the calculations.** Use the actual report's DAX measures where available. The patterns in `measures.md` are documentation examples and must not be assumed to reproduce the existing PBIX exactly.
6. **Recreate the two dashboard pages.** Use the visual inventory above and replace placeholder screenshots with images of your finished report.
7. **Refresh and validate.** Compare source rows, revenue, AOV and missing-customer rate against the same Snowflake sources, definitions and filters.
8. **Save the report.** Keep the `.pbix` as an editable local backup; decide separately whether its size and connection configuration make it suitable for public GitHub distribution.

### Refresh and deployment

The upstream pipeline has a reported Snowflake ingestion schedule at **02:00 UTC** and dbt Cloud build schedule at **03:00 UTC**. These are **upstream workflows**, not a Power BI Service refresh schedule. A desktop refresh alone does not establish an automated Power BI Service refresh.

The README does not claim that the report is publicly hosted or that Power BI Service scheduled refresh has been configured.

## Validation Checklist

- [ ] All required Snowflake tables/views are available and queryable.
- [ ] Net revenue reconciles to approximately **£9.75M** using the signed revenue definition.
- [ ] AOV reconciles to **£470.27** under the report's invoice logic.
- [ ] Missing customer ID rate reconciles to **24.93%**.
- [ ] Month labels are chronological and retain both **Dec 2010** and **Dec 2011**.
- [ ] Percentage-point metrics do not display 100× too large.
- [ ] RFM segments exclude blank categories as intended.
- [ ] Cross-filter and slicer behaviour is checked, particularly for disconnected marts.
- [ ] Both dashboard screenshots match the finished `.pbix`.
- [ ] No credentials, private connection details or secrets are present in public files.

These checks are suggested publication criteria; unchecked items are **not** claims of failure or of completed validation.

## Limitations and Future Enhancements

- The source is a static historical dataset rather than a live production feed.
- Standalone dbt marts can require separate filtering logic for cross-page interactivity.
- The report's exact DAX expressions should be exported from the final PBIX to make the measure inventory code-accurate.
- Power BI Service deployment and scheduled-refresh evidence could be added as a later extension.
- Additional drill-through pages, explicit measure tables and usability testing could improve the report, but are not required to demonstrate the existing analytics pipeline.

## Related Documentation

- [Project overview](../README.md)
- [Power BI metric catalog](measures.md)
- [Data model](../docs/data_model.md)
- [Data-quality strategy](../docs/data_quality.md)

---

**Security:** Do not commit Snowflake passwords, Azure secrets, tokens, private account details or unreviewed connection settings. Review any `.pbix` before making it public.

