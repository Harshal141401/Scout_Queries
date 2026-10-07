# Section 6: Data volumes & trends (built 2026-10-05; checks passed R020 / R021, F6.1 / F6.2 not yet run)

This is the Fusion version of the EBS report's Section 6.
- **6.1** shows six monthly bar charts.
- **6.2** is the master-data table, Active vs Total.

Both are ported from the EBS agent's `ebs_discover_data_volumes`, the final logic. The June drafts in `02_SQL_Existing/06_Data_Volumes_and_Trends/` were starting points only; the logic changes from them are listed below.

## Deliverables

| Report item | File | Window | Status |
|---|---|---|---|
| **6.1** Data volume trends by module (6 charts) | `F6.1_Data_Volume_Trends.sql` **v1.2** (v1.2: cancelled POs excluded by DOCUMENT_STATUS, R024) | **Dates entered:** the last 6 months of the entered window, never before the from-date; 2025-04-01 / 2026-03-31 gives Oct-25 → Mar-26. **Dates blank:** the last 6 months up to today; on 05-Oct-2026 that is May-26 → Oct-26, with October partial (user rule, after R022). | v1.0 ran with blank dates (R022, 4 months). v1.1 not run |
| **6.2** Master data (7 rows, Active / Total) | `F6.2_Master_Data.sql` v1.0 | Snapshot (run day) | Not run |
| Column check | `../00_Verify_First/V6_0_Columns_Check_Section_6.sql` v1.1 (adds PO DOCUMENT_STATUS) | none | ✅ R020 (v1.0): 18 / 18 ALL OK; no re-run needed |
| Code values + grain | `../00_Verify_First/V6_1_Code_Values_Section_6.sql` v1.0 | none | ✅ R021: all verdicts OK |
| Customer end dates | `../00_Verify_First/V6_2_Customer_End_Dates_Section_6.sql` v1.0 | none | Not run; run with F6.2 |

**Run order:** V6_0 → V6_1 (both done) → F6.1 (with the window dates) → F6.2 → V6_2. Use the same ledger / BU as the other sections. There is no Excel workbook for Section 6, the same as in EBS.

**Why V6_2:** R021 found STATUS A on every customer party, account and account site, so F6.2 rows 3–5 will read Active = Total. Fusion also keeps START_DATE / END_DATE on account sites and ACCOUNT_TERMINATION_DATE on accounts, which the EBS rule does not read. V6_2 counts rows that were end-dated before today but still say A. If there are any, F6.2 v1.1 adds the date test to rows 4 / 5.

## 6.1: the six charts

Output: `MODULE | MONTH | MONTH_LABEL | COUNT`, one row per module × month, with zero months included (36 rows for a 6-month chart).

| Chart | Fusion source | Date | Filter / scope |
|---|---|---|---|
| Sales Orders | DOO_HEADERS_ALL, one per order (revisions collapsed, the F4.2 rule) | ordered date | BU = ORG_ID; returns included (EBS 6.1 has no category filter) |
| Purchase Orders | PO_HEADERS_ALL | creation date | STANDARD, not cancelled (CANCEL_FLAG and, since v1.2, DOCUMENT_STATUS not CANCELED: Fusion never sets the flag, R024); procurement, requisition or bill-to BU in scope |
| Work Orders | WIE_WORK_ORDERS_B (EBS: WIP jobs) | creation date | inventory orgs of the ledger. EBS marks this chart unvalidated; same here. |
| Receivables Invoices | RA_CUSTOMER_TRX_ALL | transaction date | COMPLETE_FLAG = Y, BU = ORG_ID (all complete transactions, as in EBS) |
| Payables Invoices | AP_INVOICES_ALL | invoice date | not cancelled, BU = ORG_ID |
| GL Journals | GL_JE_HEADERS | creation date | posted (STATUS P), ledger scope |

**Logic changes from the June draft (14_S6.1):**
- **Window:** the dates were hard-coded (2026-01-01 → 2026-10-01) under Apr-25 → Sep-25 headings. The chart window now comes from the run's dates. With blank dates it is the last 6 months up to today (v1.1). This is the only query where blank dates do not mean the last 90 days.
- **Months:** months were matched on month number with no year, so Jan-26 and Jan-25 merged. They are now real calendar months.
- **Dates:** AP, AR and orders used the creation date. They now use the EBS business dates.
- **Parameters:** a blank ledger zeroed every chart. Blank now means the whole pod.
- **Purchase orders:** the draft had no BU scope and an extra "sourced from a requisition" filter that EBS doesn't have. It now uses the BU scope and drops that filter.
- **Sales orders:** draft revision rows were counted as extra orders. Revisions are now collapsed to one order.

## 6.2: master data

Output: `Entity | Active | Total`.

| Entity | Fusion source | Active means | Scope |
|---|---|---|---|
| Suppliers | POZ_SUPPLIERS | not end-dated. ENABLED_FLAG is "OBSOLETE" in Fusion (Oracle doc), so unlike EBS it is not used. | pod |
| Supplier sites | POZ_SUPPLIER_SITES_ALL_M, one per VENDOR_SITE_ID | INACTIVE_DATE empty or in the future | pod |
| Customer parties | HZ_PARTIES that own a customer account | STATUS A | pod |
| Customer accounts | HZ_CUST_ACCOUNTS | STATUS A | pod |
| Customer sites | HZ_CUST_ACCT_SITES_ALL, one per site | STATUS A | pod |
| Items | EGP_SYSTEM_ITEMS_B, one per item, **templates excluded** | enabled in at least one org | pod |
| Internal bank accounts | CE_BANK_ACCOUNTS, INTERNAL | not end-dated | the F3.1 rule: with a ledger or BU entered, only accounts used by an in-scope BU |

**Caption to print under the table, as in EBS:** "Bank account scope: internal accounts used by the in-scope business units (whole pod when no ledger / BU is entered). Each account is counted once. Active means not end-dated; Total includes end-dated accounts."

**Logic changes from the June draft (15_S6.2), following the EBS review of 2026-09-10:**
- **Rows:** Employees and BOM are dropped. Supplier sites, Customer accounts and Customer sites are added.
- **Customers:** the draft counted every organization party, which includes suppliers, banks and legal entities. It now counts parties that own a customer account.
- **Bank accounts:** the draft counted every CE bank account with no INTERNAL filter and no BU scope. It now counts internal accounts only, scoped like F3.1. *Correction after R021:* on this pod CE_BANK_ACCOUNTS holds only INTERNAL accounts (6); Fusion keeps supplier and customer bank accounts in IBY_EXT_BANK_ACCOUNTS. So the filter removes nothing here and only the BU scope can change the count. The F6.2 header comment that says "incl. external ones" will be corrected at its next version.
- **Items:** templates are now excluded, and DISTINCT is replaced by GROUP BY.
- **Output:** the draft returned a text label. It now has numeric Active and Total columns.

## Checks to reconcile (RUN_LOG C42–C45)

| Check | What must hold |
|---|---|
| C42 | V6_0: every row ALL OK. ✅ R020 |
| C43 | V6_1 verdicts B0 / D0 / E0 OK. Grain block F shows the rows-vs-keys ratios. ✅ R021 |
| C44 | F6.2 Internal bank accounts **Active** = F3.1 row 10 (same parameters) |
| C45 | With F4.x run on the chart's 6 months: chart 5 sum = F4.1 AP invoices; chart 6 sum = F4.3 GL journals; chart 1 sum = F4.2 Sales Orders + RMA |
| C46 | F6.2 pod-wide rows = R021: Supplier sites Total 2,578 · Customer parties 284 / 284 · accounts 285 / 285 · sites 1,096 / 1,096 · Items Active = Total, 10,347–10,359 · banks ≤ 6 |
| C47 | V6_2 A0 / B0 OK (no end-dated customer account or site still says STATUS A) |

## What R021 showed (pod facts)

- **Sales orders:** 11,703 DOO header rows hold 6,988 orders, so 40% of the rows are revisions. At least 1,077 orders were never submitted (drafts). They are counted when their ordered date falls in the window, as in F4.2. EBS also counts unbooked orders.
- **Items:** templates are 12 rows of EGP_SYSTEM_ITEMS_B, all with ENABLED_FLAG empty. Every other row has ENABLED_FLAG Y, so the EBS "enabled" rule gives Active = Total. EBS Vision shows the same (6,769 / 6,769). Mirrored as is; using Fusion's item status instead would change the metric in both reports.
- **Sites:** supplier sites and customer account sites have one row per key, so the F3.1 Payment Terms AP sheet counts per site, as intended.
