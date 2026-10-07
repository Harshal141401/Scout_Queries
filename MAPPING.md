# Scout Fusion → Fusion Discovery: report, query and data model map

This folder holds every query and BIP data model behind the Fusion → Fusion discovery report, sorted by report section.
- **Nothing in it was rewritten.** The `.sql` and section `README` files are byte copies of the developed set (`02_SQL_Phase2/`, 93 files). The data models are extracted byte for byte from the BIP catalog export `Scout.catalog` (catalog folder `/users/svc/Scout`, 30 data models). Every copy was checked by md5 against its source.
- This file is the only new document.

## How the folder is organised

| Path | What it holds |
|---|---|
| `00_Executive_Summary/` … `10_Technical_Infrastructure/` | One folder per report section: the section's queries (`.sql`), its README where one exists, and `data_models/`. |
| `<section>/data_models/<name>.xdm/_datamodel.xdm` | A BIP data model as stored in the catalog (XML, with each data set's SQL). Three also hold `sample.xml`, the sample data BIP saved with the data model. |
| `00_Verify_First/` | Check queries, run before the report queries. They are not part of the report and have no data model in the catalog (they were run as temporary data models). |
| `bip_catalog/Scout.catalog` | The original BIP archive, unchanged. Import it with Catalog > Unarchive in BI Publisher. |
| `QUERY_MAP.md`, `WINDOW_AND_PARAMETERS.md`, `SECTIONS_0_2_REVIEW.md` | Developed notes, copied as they are: run order, which query takes the dates, and the Sections 0–2 review. |
| `08_Reports_and_BI/retired/` | One superseded workbook query (never run), kept for history. |

**How to read the tables:**
- **Report output** says where the result appears: a table in the report, a caption, or an Excel sheet.
- **Sheet** numbers count the data sheets of a workbook. Each workbook also has an About sheet (run parameters and the reconciliation), which has no query.
- **Data model vs file** compares the SQL saved in the catalog with the `.sql` file. BIP adds a blank first line and an indent when it stores SQL; that is ignored.

---

## 1. Report map: section → query → data model → Excel sheet

| Section | Report output | Query file | Data model · data set (Scout catalog) | Excel workbook | Sheet | Data model vs file |
|---|---|---|---|---|---|---|
| **0 Executive Summary** | Report table: the 5 headline cards | [`F0_Executive_Summary.sql`](00_Executive_Summary/F0_Executive_Summary.sql) | `0_Executive_Summary_DM.xdm` · Executive_Summary | No (report table) | — | ⚠ **Older:** the data model holds F0 **v1** (16 modules typed in the SQL, the version that ran as R001). The file is shared block **v3.1**. |
| **1.1** Active module inventory | Report table | [`F1_Active_Module_Inventory.sql`](01_Module_Footprint_and_Usage/F1_Active_Module_Inventory.sql) | `1.1_Active_Module_Inventory_DM.xdm` · Active Module Inventory | No | — | Same as the file (v3.1). The data model also stores `sample.xml` (see section 5). |
| **1.2** Modules with no activity | Report table | [`F1.2_Modules_No_Activity.sql`](01_Module_Footprint_and_Usage/F1.2_Modules_No_Activity.sql) | `1.2_Dormant_modules_DM.xdm` · Dormant Modules | No | — | Same as the file (v3.1) |
| **2.1** Ledger / legal entity / BU map | Report table | [`F2.1_Ledger_LE_BU_Map.sql`](02_Enterprise_Structures_and_COA/F2.1_Ledger_LE_BU_Map.sql) | `2.1_ledger_Mapping.xdm` · Ledger_Mapping | No | — | Same as the file (v1.0) |
| **2.1** Org structure detail | Excel sheet | [`F2.1_Org_Structure_Detail.sql`](02_Enterprise_Structures_and_COA/F2.1_Org_Structure_Detail.sql) | `2.1_Org_Structure_Details.xdm` · Org_Structure_details | **WB1** `Fusion_Discovery_2_1_Org_Structure.xlsx` | **Sheet 1 of 1:** Org Structure | Same as the file (v1.0) |
| **2.2** Chart of accounts structure | Report table | [`F2.2_COA_Structure.sql`](02_Enterprise_Structures_and_COA/F2.2_COA_Structure.sql) | `2.2_COA_Structure.xdm` · COA_Structure | No | — | Same as the file (v1.1) |
| **2.2** COA segment values | Excel sheet | [`F2.2_COA_Segment_Values_Detail.sql`](02_Enterprise_Structures_and_COA/F2.2_COA_Segment_Values_Detail.sql) | `2.2_Segment_Value_Details.xdm` · Segment_Value | **WB2** `Fusion_Discovery_2_2_COA_Segment_Values.xlsx` | **Sheet 1 of 3:** Segment Values | Same as the file (v1.0) |
| **2.2** Balancing segment → legal entity | Excel sheet | [`F2.2_BSV_Legal_Entity_Detail.sql`](02_Enterprise_Structures_and_COA/F2.2_BSV_Legal_Entity_Detail.sql) | **Not in the catalog** | **WB2** (as above) | **Sheet 2 of 3:** Balancing Segment → Legal Entity | No data model yet |
| **2.2** Cross-validation rules | Excel sheet | *not built* | — | **WB2** (as above) | **Sheet 3 of 3:** Cross-Validation Rules | Planned; no query yet |
| **3.1** Setup area by module | Report table | [`F3.1_Setup_Area_by_Module.sql`](03_Configurations/F3.1_Setup_Area_by_Module.sql) | `3.1_Setup_Area_By_Module.xdm` · Setup_Area | No | — | Same code as the file (v1.0); the data model's header comment is shorter |
| **3.1** Asset books by class and status | Report table (under 3.1) | [`F3.1_Asset_Books_By_Class.sql`](03_Configurations/F3.1_Asset_Books_By_Class.sql) | `3.1_Asset_Books_by_Class.xdm` · Asset_Books | No | — | Same as the file (v1.0) |
| **3.1** AP payment terms | Excel sheet | [`F3.1_WB_Payment_Terms_AP.sql`](03_Configurations/F3.1_WB_Payment_Terms_AP.sql) | `3.1_Payment_terms.xdm` · Payment_terms_1 | **WB3** `Fusion_Discovery_3_1_Payment_Terms.xlsx` | **Sheet 1 of 2:** AP Payment Terms | Same as the file (v1.0) |
| **3.1** AR payment terms | Excel sheet | [`F3.1_WB_Payment_Terms_AR.sql`](03_Configurations/F3.1_WB_Payment_Terms_AR.sql) | `3.1_Payment_terms.xdm` · Payment_Terms_2 | **WB3** (as above) | **Sheet 2 of 2:** AR Payment Terms | Same as the file (v1.0) |
| **3.1** Setup inventory | Excel sheet | [`F3.1_WB_Setup_01_AR_Transaction_Types.sql`](03_Configurations/F3.1_WB_Setup_01_AR_Transaction_Types.sql) | **Not in the catalog** | **WB4** `Fusion_Discovery_3_1_Setup_Inventory.xlsx` | **Sheet 1 of 10:** AR Transaction Types | No data model yet |
| **3.1** Setup inventory | Excel sheet | [`F3.1_WB_Setup_02_AR_Transaction_Sources.sql`](03_Configurations/F3.1_WB_Setup_02_AR_Transaction_Sources.sql) | **Not in the catalog** | **WB4** | **Sheet 2 of 10:** AR Transaction Sources | No data model yet |
| **3.1** Setup inventory | Excel sheet | [`F3.1_WB_Setup_03_GL_Journal_Sources.sql`](03_Configurations/F3.1_WB_Setup_03_GL_Journal_Sources.sql) | **Not in the catalog** | **WB4** | **Sheet 3 of 10:** GL Journal Sources | No data model yet |
| **3.1** Setup inventory | Excel sheet | [`F3.1_WB_Setup_04_GL_Journal_Categories.sql`](03_Configurations/F3.1_WB_Setup_04_GL_Journal_Categories.sql) | **Not in the catalog** | **WB4** | **Sheet 4 of 10:** GL Journal Categories | No data model yet |
| **3.1** Setup inventory | Excel sheet | [`F3.1_WB_Setup_05_PO_Document_Types.sql`](03_Configurations/F3.1_WB_Setup_05_PO_Document_Types.sql) | **Not in the catalog** | **WB4** | **Sheet 5 of 10:** PO Document Types | No data model yet |
| **3.1** Setup inventory | Excel sheet | [`F3.1_WB_Setup_06_Item_Templates.sql`](03_Configurations/F3.1_WB_Setup_06_Item_Templates.sql) | **Not in the catalog** | **WB4** | **Sheet 6 of 10:** Item Templates | No data model yet |
| **3.1** Setup inventory | Excel sheet | [`F3.1_WB_Setup_07_Subinventories.sql`](03_Configurations/F3.1_WB_Setup_07_Subinventories.sql) | **Not in the catalog** | **WB4** | **Sheet 7 of 10:** Subinventories | No data model yet |
| **3.1** Setup inventory | Excel sheet | [`F3.1_WB_Setup_08_CE_Bank_Accounts.sql`](03_Configurations/F3.1_WB_Setup_08_CE_Bank_Accounts.sql) | **Not in the catalog** | **WB4** | **Sheet 8 of 10:** CE Bank Accounts | No data model yet |
| **3.1** Setup inventory | Excel sheet | [`F3.1_WB_Setup_09_CST_Cost_Books.sql`](03_Configurations/F3.1_WB_Setup_09_CST_Cost_Books.sql) | **Not in the catalog** | **WB4** | **Sheet 9 of 10:** CST Cost Books | No data model yet |
| **3.1** Setup inventory | Excel sheet | [`F3.1_WB_Setup_10_FA_Asset_Books.sql`](03_Configurations/F3.1_WB_Setup_10_FA_Asset_Books.sql) | **Not in the catalog** | **WB4** | **Sheet 10 of 10:** FA Asset Books | No data model yet |
| **3.2** Descriptive flexfield deep-dive | Report table | [`F3.2_DFF_Deep_Dive.sql`](03_Configurations/F3.2_DFF_Deep_Dive.sql) | `3.2_DFF_Deep_dive.xdm` · DFF_Deep_dive | No | — | Same as the file (v1.0) |
| **3.2** Descriptive flexfields | Excel sheet | [`F3.2_WB_Descriptive_Flexfields.sql`](03_Configurations/F3.2_WB_Descriptive_Flexfields.sql) | `3.2_DFF_Excel.xdm` · DFF_WB | **WB5** `Fusion_Discovery_3_2_Flexfields.xlsx` | **Sheet 1 of 1:** Descriptive Flexfields | Same code as the file (v1.0); the data model's header comment is shorter |
| **4.1** Procure-to-pay (P2P) flow | Report table | [`F4.1_P2P_Flow.sql`](04_Business_Processes/F4.1_P2P_Flow.sql) | `4.1_P2P_Flow.xdm` · P2P_flow | No | — | ⚠ **Older:** v1.2 in the data model; the file is **v1.3** (cancelled POs read from DOCUMENT_STATUS) |
| **4.2** Order-to-cash (O2C) flow | Report table | [`F4.2_O2C_Flow.sql`](04_Business_Processes/F4.2_O2C_Flow.sql) | `4.2_O2C_Flow.xdm` · O2C-Flow | No | — | Same as the file (v1.1) |
| **4.3** Record-to-report (R2R) | Report table | [`F4.3_R2R.sql`](04_Business_Processes/F4.3_R2R.sql) | `4.3_R2R.xdm` · R2R | No | — | Same as the file (v1.1) |
| **4.3** GL journal sources | Excel sheet | [`F4.3_WB_GL_Journal_Sources.sql`](04_Business_Processes/F4.3_WB_GL_Journal_Sources.sql) | `4.3_Gl_Journal_Sources.xdm` · Gl_journal | **WB6** `Fusion_Discovery_4_3_GL_Journal_Sources.xlsx` | **Sheet 1 of 1:** GL Journal Sources | Same as the file (v1.0) |
| **4.4** Other process areas | Report table | [`F4.4_Other_Process_Areas.sql`](04_Business_Processes/F4.4_Other_Process_Areas.sql) | `4.4_Other_Process_Areas.xdm` · other_process_areas | No | — | Same as the file (v1.1) |
| **4.5** Costing method assessment | Report table | [`F4.5_Costing_Method.sql`](04_Business_Processes/F4.5_Costing_Method.sql) | `4.5_Costing_Method_Assessment.xdm` · Costing_Method_assessment | No | — | Same as the file (v1.1) |
| **5.1** CEMLI summary (5 cards) | Report table | [`F5.1_Extensions_Summary.sql`](05_Customizations/F5.1_Extensions_Summary.sql) | `5.1_CEMLI_Summary.xdm` · CEMLI | No | — | Same as the file (v2.1) |
| **5.2** Custom scheduled processes | Report table (first 10 rows) **and** Excel sheet (all rows): one query | [`F5.2_Custom_Scheduled_Processes.sql`](05_Customizations/F5.2_Custom_Scheduled_Processes.sql) | `5.2_Scheduled_Processes.xdm` · Schedule-Processes | **WB7** `Fusion_Discovery_5_2_Custom_Scheduled_Processes.xlsx` | **Sheet 1 of 1:** Custom Scheduled Processes | Same as the file (v1.1) |
| **5.2** ESS history coverage | Report caption, and the WB7 About sheet line | [`F5.2_ESS_History_Coverage.sql`](05_Customizations/F5.2_ESS_History_Coverage.sql) | **Not in the catalog** | **WB7** (as above) | About sheet | No data model yet |
| **6.1** Data volume trends (6 charts) | Report charts | [`F6.1_Data_Volume_Trends.sql`](06_Data_Volumes_and_Trends/F6.1_Data_Volume_Trends.sql) | `6.1_Data_Trends_And_Volume.xdm` · data_Volume_and_trends | No | — | ⚠ **Older:** v1.1 in the data model; the file is **v1.2** (cancelled POs read from DOCUMENT_STATUS). The data model also stores `sample.xml`. |
| **6.2** Master data | Report table | [`F6.2_Master_Data.sql`](06_Data_Volumes_and_Trends/F6.2_Master_Data.sql) | `6.2_Master_Data.xdm` · Master_Data | No | — | Same as the file (v1.0) |
| **7.1** Open transactions summary | Report table | [`F7.1_Open_Transactions.sql`](07_Open_Transactions/F7.1_Open_Transactions.sql) | `7.1_Open_Transaction_Snapshot.xdm` · open_transactions | No | — | Same as the file (v1.3). The data model also stores `sample.xml`. |
| **7.1** Open transactions by business unit | Excel sheet | [`F7.1_WB_Open_Transactions_By_BU.sql`](07_Open_Transactions/F7.1_WB_Open_Transactions_By_BU.sql) | `7.1_Open_Transaction_By_BU.xdm` · Open_Transaction | **WB8** `Fusion_Discovery_7_1_Open_Transactions_By_BU.xlsx` | **Sheet 1 of 1:** Open Transactions by BU | Same as the file (v1.3) |
| **8.1** Report area by type | Report table | [`F8.1_Report_Area_by_Type.sql`](08_Reports_and_BI/F8.1_Report_Area_by_Type.sql) | `8.1_Report_Area_By_Type.xdm` · Report_Inventory_By_Type | No | — | Same as the file (v1.2) |
| **8.2** Top 10 custom reports with recorded use | Report table | [`F8.2a_Custom_Reports_Used.sql`](08_Reports_and_BI/F8.2a_Custom_Reports_Used.sql) | `8.2_Custom_Reports.xdm` · Custom-Reports_Run | No | — | Same as the file (v1.1) |
| **8.2** Top 10 custom reports without recorded use | Report table | [`F8.2b_Custom_Reports_Not_Used.sql`](08_Reports_and_BI/F8.2b_Custom_Reports_Not_Used.sql) | `8.2_Custom_Reports.xdm` · Custom_Reports_NotRun | No | — | Same as the file (v1.1) |
| **8.2** Custom report totals | Report caption | [`F8.2c_Custom_Reports_Totals.sql`](08_Reports_and_BI/F8.2c_Custom_Reports_Totals.sql) | `8.2_Custom_Reports.xdm` · total_custom_reports | No | — | ⚠ **Older:** v1.1 in the data model (still has the Note column); the file is **v1.2** (Note column removed) |
| **8.2** Jobs run in the last 3 months | Excel sheet | [`F8.2_WB1_Jobs_Run_Last_3_Months.sql`](08_Reports_and_BI/F8.2_WB1_Jobs_Run_Last_3_Months.sql) | `8.2_Jobs_FRC_Runs.xdm` · Custom-Reports | **WB9** `Fusion_Discovery_8_2_Reports_Run_Last_3_Months.xlsx` | **Sheet 1 of 2:** Jobs Run | Same as the file (v1.0). The data set is named "Custom-Reports" but lists every job that ran. |
| **8.2** Reports opened from the Financial Reporting Center | Excel sheet | [`F8.2_WB2_FRC_Opens_Last_3_Months.sql`](08_Reports_and_BI/F8.2_WB2_FRC_Opens_Last_3_Months.sql) | `8.2_Jobs_FRC_Runs.xdm` · FRC_Opens | **WB9** (as above) | **Sheet 2 of 2:** Financial Reporting Center Opens | Same as the file (v1.0) |
| **9.1** Security footprint | Report table | [`F9.1_Security_Footprint.sql`](09_Security/F9.1_Security_Footprint.sql) | `9.1_Security_Footprint.xdm` · Security Footprint | No | — | Same as the file (v1.1) |
| **10.1** Fusion release and update level | Report table | [`F10.1_Release_and_Update_Level.sql`](10_Technical_Infrastructure/F10.1_Release_and_Update_Level.sql) | `10.1_Release.xdm` · Release | No | — | Same as the file (v1.1) |
| **10.2** Database and infrastructure footprint | Report table | [`F10.2_Database_and_Infrastructure.sql`](10_Technical_Infrastructure/F10.2_Database_and_Infrastructure.sql) | `10.2_Database_and_Infrastructure.xdm` · Database_Infrastructure | No | — | Same as the file (v1.1) |
| **10.3** Fusion pod posture (Fusion only) | Report table | [`F10.3_Fusion_Pod_Posture.sql`](10_Technical_Infrastructure/F10.3_Fusion_Pod_Posture.sql) | **Not in the catalog** | No | — | No data model yet |

**Totals:**
- 47 report queries; 34 have a data model in the catalog and 13 do not yet.
- 9 Excel workbooks with 22 data sheets: 21 have a query, and the Cross-Validation Rules sheet is planned.

## 2. Excel workbooks and their sheets

| Workbook | File | Section | Data sheets | Sheet → query |
|---|---|---|---|---|
| WB1 | `Fusion_Discovery_2_1_Org_Structure.xlsx` | 2.1 | 1 | 1 Org Structure → `F2.1_Org_Structure_Detail.sql` |
| WB2 | `Fusion_Discovery_2_2_COA_Segment_Values.xlsx` | 2.2 | 3 | 1 Segment Values → `F2.2_COA_Segment_Values_Detail.sql` · 2 Balancing Segment → Legal Entity → `F2.2_BSV_Legal_Entity_Detail.sql` · 3 Cross-Validation Rules → *not built* |
| WB3 | `Fusion_Discovery_3_1_Payment_Terms.xlsx` | 3.1 | 2 | 1 AP Payment Terms → `F3.1_WB_Payment_Terms_AP.sql` · 2 AR Payment Terms → `F3.1_WB_Payment_Terms_AR.sql` |
| WB4 | `Fusion_Discovery_3_1_Setup_Inventory.xlsx` | 3.1 | 10 | 1 AR Transaction Types → `F3.1_WB_Setup_01_…` · 2 AR Transaction Sources → `_02_…` · 3 GL Journal Sources → `_03_…` · 4 GL Journal Categories → `_04_…` · 5 PO Document Types → `_05_…` · 6 Item Templates → `_06_…` · 7 Subinventories → `_07_…` · 8 CE Bank Accounts → `_08_…` · 9 CST Cost Books → `_09_…` · 10 FA Asset Books → `_10_…` (sheet *n* = rows 3–12 of the 3.1 table) |
| WB5 | `Fusion_Discovery_3_2_Flexfields.xlsx` | 3.2 | 1 | 1 Descriptive Flexfields → `F3.2_WB_Descriptive_Flexfields.sql` |
| WB6 | `Fusion_Discovery_4_3_GL_Journal_Sources.xlsx` | 4.3 | 1 | 1 GL Journal Sources → `F4.3_WB_GL_Journal_Sources.sql` |
| WB7 | `Fusion_Discovery_5_2_Custom_Scheduled_Processes.xlsx` | 5.2 | 1 | 1 Custom Scheduled Processes → `F5.2_Custom_Scheduled_Processes.sql` (the About sheet prints `F5.2_ESS_History_Coverage.sql`) |
| WB8 | `Fusion_Discovery_7_1_Open_Transactions_By_BU.xlsx` | 7.1 | 1 | 1 Open Transactions by BU → `F7.1_WB_Open_Transactions_By_BU.sql` |
| WB9 | `Fusion_Discovery_8_2_Reports_Run_Last_3_Months.xlsx` | 8.2 | 2 | 1 Jobs Run → `F8.2_WB1_Jobs_Run_Last_3_Months.sql` · 2 Financial Reporting Center Opens → `F8.2_WB2_FRC_Opens_Last_3_Months.sql` |

Every sheet reconciles to the report number it expands (see each section README and `QUERY_MAP.md`).

## 3. Check queries (`00_Verify_First/`, not in the report)

Run these before the report queries of their section. None has a data model in the Scout catalog: they were run as temporary data models, and their outputs are logged in the development run log.

| Check query | Checks |
|---|---|
| `V0_0_Registry_Columns_Check.sql` | Registry columns for F0, F1, F1.2 |
| `V0_1_Verify_Objects_Columns_Sections_0_2.sql` · `V0_2_Verify_Data_Rules_Sections_0_2.sql` | Objects, columns and data rules of Sections 0–2 |
| `V0_3_Explain_Executive_Summary.sql` | What sits behind each executive-summary card |
| `V1_1_Module_Activity_Evidence.sql` · `V1_2_Find_Offering_Enablement_Objects.sql` | Evidence for the active-module count (1.1) |
| `V3_0_Columns_Check_Section_3_1.sql` · `V3_1_Columns_Check_Section_3_Workbooks.sql` | Section 3 columns (3.1 table, workbooks, 3.2) |
| `V4_0_Columns_Check_Section_4.sql` · `V4_1_Code_Values_Section_4.sql` | Section 4 columns and code values |
| `V5_0_Columns_Check_Section_5.sql` · `V5_1_Code_Values_Section_5.sql` | Section 5 columns and code values |
| `V5_2a_ESS_History_Read_Test.sql` · `V5_2b_ESS_Property_Read_Test.sql` · `V5_2c_ESS_Column_Discovery.sql` · `V5_3_MDS_Discovery.sql` · `V5_4_ESS_Code_Values.sql` · `V5_5_Roles_Approvals_Detail.sql` | Scheduled-process (ESS) history, MDS, roles and approvals, for 5.1 / 5.2 |
| `V6_0_Columns_Check_Section_6.sql` · `V6_1_Code_Values_Section_6.sql` · `V6_2_Customer_End_Dates_Section_6.sql` | Section 6 columns, code values, customer end dates |
| `V7_0_Columns_Check_Section_7.sql` · `V7_1_Code_Values_Section_7.sql` | Section 7 columns and code values |
| `V8_0_Columns_Check_Section_8.sql` · `V8_1_Code_Values_Section_8.sql` · `V8_2_Used_And_Grain_Diagnostic_Section_8.sql` · `V8_3_ESS_Run_Facts_Section_8.sql` | Section 8 columns, code values, report-use and scheduled-process run facts |
| `V9_1_Code_Values_Section_9.sql` | Section 9 code values |
| `V10_0_Columns_Check_Section_10.sql` · `V10_1_Code_Values_Section_10.sql` | Section 10 columns and code values |
| `V10_2a_Release_Read_Test.sql` … `V10_2f_DB_Catalog_Read_Test.sql` | Section 10 read tests (release record, database NLS settings, database version, platform string, database options, database catalog views) |

`08_Reports_and_BI/retired/F8.2_WB_Reports_Used_Last_3_Months.sql` is the first version of the WB9 query. It was never run and was replaced by `F8.2_WB1` / `F8.2_WB2`.

## 4. Data models in the Scout catalog (30 data models, 34 data sets)

All data models use the data source **ApplicationDB_FSCM** and take the parameters `p_ledger_id` and `p_bu_id`; 6.1 also takes `p_from_date` and `p_to_date`.

| Data model | Section folder | Data sets | Sample data | Last modified (catalog) |
|---|---|---|---|---|
| `0_Executive_Summary_DM.xdm` | 00 | Executive_Summary | — | 2026-10-01 07:29 |
| `1.1_Active_Module_Inventory_DM.xdm` | 01 | Active Module Inventory | `sample.xml` | 2026-10-01 07:31 |
| `1.2_Dormant_modules_DM.xdm` | 01 | Dormant Modules | — | 2026-10-01 09:02 |
| `2.1_ledger_Mapping.xdm` | 02 | Ledger_Mapping | — | 2026-10-01 07:27 |
| `2.1_Org_Structure_Details.xdm` | 02 | Org_Structure_details | — | 2026-10-01 09:39 |
| `2.2_COA_Structure.xdm` | 02 | COA_Structure | — | 2026-10-01 09:45 |
| `2.2_Segment_Value_Details.xdm` | 02 | Segment_Value | — | 2026-10-01 10:40 |
| `3.1_Setup_Area_By_Module.xdm` | 03 | Setup_Area | — | 2026-10-05 05:08 |
| `3.1_Asset_Books_by_Class.xdm` | 03 | Asset_Books | — | 2026-10-05 05:09 |
| `3.1_Payment_terms.xdm` | 03 | Payment_terms_1, Payment_Terms_2 | — | 2026-10-05 06:08 |
| `3.2_DFF_Deep_dive.xdm` | 03 | DFF_Deep_dive | — | 2026-10-05 07:12 |
| `3.2_DFF_Excel.xdm` | 03 | DFF_WB | — | 2026-10-05 07:14 |
| `4.1_P2P_Flow.xdm` | 04 | P2P_flow | — | 2026-10-05 08:33 |
| `4.2_O2C_Flow.xdm` | 04 | O2C-Flow | — | 2026-10-05 08:41 |
| `4.3_R2R.xdm` | 04 | R2R | — | 2026-10-05 08:43 |
| `4.3_Gl_Journal_Sources.xdm` | 04 | Gl_journal | — | 2026-10-05 08:44 |
| `4.4_Other_Process_Areas.xdm` | 04 | other_process_areas | — | 2026-10-05 08:47 |
| `4.5_Costing_Method_Assessment.xdm` | 04 | Costing_Method_assessment | — | 2026-10-05 08:50 |
| `5.1_CEMLI_Summary.xdm` | 05 | CEMLI | — | 2026-10-06 05:57 |
| `5.2_Scheduled_Processes.xdm` | 05 | Schedule-Processes | — | 2026-10-05 13:35 |
| `6.1_Data_Trends_And_Volume.xdm` | 06 | data_Volume_and_trends | `sample.xml` | 2026-10-05 13:59 |
| `6.2_Master_Data.xdm` | 06 | Master_Data | — | 2026-10-05 14:19 |
| `7.1_Open_Transaction_Snapshot.xdm` | 07 | open_transactions | `sample.xml` | 2026-10-05 15:20 |
| `7.1_Open_Transaction_By_BU.xdm` | 07 | Open_Transaction | — | 2026-10-05 15:22 |
| `8.1_Report_Area_By_Type.xdm` | 08 | Report_Inventory_By_Type | — | 2026-10-06 05:51 |
| `8.2_Custom_Reports.xdm` | 08 | Custom-Reports_Run, Custom_Reports_NotRun, total_custom_reports | — | 2026-10-06 06:07 |
| `8.2_Jobs_FRC_Runs.xdm` | 08 | Custom-Reports, FRC_Opens | — | 2026-10-06 05:56 |
| `9.1_Security_Footprint.xdm` | 09 | Security Footprint | — | 2026-10-06 11:34 |
| `10.1_Release.xdm` | 10 | Release | — | 2026-10-07 06:52 |
| `10.2_Database_and_Infrastructure.xdm` | 10 | Database_Infrastructure | — | 2026-10-07 06:56 |

## 5. Check before pushing

1. **Four data models hold older SQL than their `.sql` file.** Re-paste the file into the data model if the two must match:

   | Data model | Data model has | File has |
   |---|---|---|
   | `0_Executive_Summary_DM` | F0 v1 | v3.1 |
   | `4.1_P2P_Flow` | v1.2 | v1.3 |
   | `6.1_Data_Trends_And_Volume` | v1.1 | v1.2 |
   | `8.2_Custom_Reports` (total_custom_reports) | F8.2c v1.1 | v1.2 |

2. **Thirteen report queries have no data model in the catalog yet:**
   - the 10 Setup Inventory sheets (WB4)
   - `F2.2_BSV_Legal_Entity_Detail`
   - `F5.2_ESS_History_Coverage`
   - `F10.3_Fusion_Pod_Posture`
3. **Client data is in some files.** Push to a private repository, or remove these first:
   - **The three `sample.xml` files hold real output from the client pod**, saved by BIP as sample data. Each is a check-query result, not report data:
     - 1.1 holds the module-activity evidence query, **including client users' login names**.
     - 6.1 and 7.1 hold record counts and statuses.
   - **Some query comments and section READMEs quote pod findings** (record counts, a ledger id, client report and role names, user names).
   - **`bip_catalog/Scout.catalog`** carries the pod's host name and catalog URL in its header.
