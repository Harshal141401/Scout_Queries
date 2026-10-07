# Query map: which query produces which part of the report

All files are in `02_SQL_Phase2/`. Last updated 2026-10-07 (Section 10 built).

**Dates:** the discovery window is **Apr-25 to Mar-26**. `WINDOW_AND_PARAMETERS.md` lists which query takes the dates (`p_from_date = 2025-04-01`, `p_to_date = 2026-03-31`) and which are snapshots.

**How to read the file names**

| Prefix | Meaning | Goes in the report? |
|---|---|---|
| `F<section>` | Produces a **table in the report** | Yes |
| `F<section>_WB_…` / `…_Detail` | Produces **one sheet of an Excel workbook** | Yes, as an Excel download |
| `V…` | **Check query.** Run it before the F queries; it proves the tables and columns exist on the pod | No |

---

## Section 0: Executive Summary

| Report item | Query file | Status |
|---|---|---|
| The 5 headline cards | `00_Executive_Summary/F0_Executive_Summary.sql` | Ran 2026-09-30 on an **old** version (R001). Re-run needed. |

## Section 1: Module footprint & usage

| Report item | Query file | Status |
|---|---|---|
| 1.1 Active module inventory (table) | `01_Module_Footprint_and_Usage/F1_Active_Module_Inventory.sql` | Ran (R004): 13 modules. ⚠ Disputed: the consultant says 6 (C10). |
| 1.2 Modules with no activity (table) | `01_Module_Footprint_and_Usage/F1.2_Modules_No_Activity.sql` | Not run |

## Section 2: Enterprise structures & chart of accounts

| Report item | Query file | Status |
|---|---|---|
| 2.1 Ledger / legal entity / BU map (table) | `02_Enterprise_Structures_and_COA/F2.1_Ledger_LE_BU_Map.sql` | Not run |
| 2.1 workbook **Org Structure**, sheet 1 | `02_Enterprise_Structures_and_COA/F2.1_Org_Structure_Detail.sql` | Not run |
| 2.2 Chart of accounts structure (table) | `02_Enterprise_Structures_and_COA/F2.2_COA_Structure.sql` | Not run |
| 2.2 workbook **COA Segment Values**, sheet "Segment Values" | `02_Enterprise_Structures_and_COA/F2.2_COA_Segment_Values_Detail.sql` | Not run |
| 2.2 workbook **COA Segment Values**, sheet "Balancing Segment → Legal Entity" | `02_Enterprise_Structures_and_COA/F2.2_BSV_Legal_Entity_Detail.sql` | Not run |
| 2.2 workbook **COA Segment Values**, sheet "Cross-Validation Rules" | **not built yet**; waits on the V0_1 dump | — |

## Section 3: Configurations

| Report item | Query file | Status |
|---|---|---|
| 3.1 Setup area by module (table, 12 rows) | `03_Configurations/F3.1_Setup_Area_by_Module.sql` | Not run |
| 3.1 Asset books by class and status (small table under 3.1) | `03_Configurations/F3.1_Asset_Books_By_Class.sql` | Not run |
| 3.2 Descriptive flexfield deep-dive (table) | `03_Configurations/F3.2_DFF_Deep_Dive.sql` | Not run |

**3.1 workbook: Payment Terms** (2 sheets)

| Sheet | Query file |
|---|---|
| AP Payment Terms | `03_Configurations/F3.1_WB_Payment_Terms_AP.sql` |
| AR Payment Terms | `03_Configurations/F3.1_WB_Payment_Terms_AR.sql` |

**3.1 workbook: Setup Inventory** (10 sheets, one per row of the 3.1 table)

| Sheet | Query file | Expands 3.1 row |
|---|---|---|
| AR Transaction Types | `03_Configurations/F3.1_WB_Setup_01_AR_Transaction_Types.sql` | row 3 |
| AR Transaction Sources | `03_Configurations/F3.1_WB_Setup_02_AR_Transaction_Sources.sql` | row 4 |
| GL Journal Sources | `03_Configurations/F3.1_WB_Setup_03_GL_Journal_Sources.sql` | row 5 |
| GL Journal Categories | `03_Configurations/F3.1_WB_Setup_04_GL_Journal_Categories.sql` | row 6 |
| PO Document Types | `03_Configurations/F3.1_WB_Setup_05_PO_Document_Types.sql` | row 7 |
| Item Templates | `03_Configurations/F3.1_WB_Setup_06_Item_Templates.sql` | row 8 |
| Subinventories | `03_Configurations/F3.1_WB_Setup_07_Subinventories.sql` | row 9 |
| CE Bank Accounts | `03_Configurations/F3.1_WB_Setup_08_CE_Bank_Accounts.sql` | row 10 |
| CST Cost Books | `03_Configurations/F3.1_WB_Setup_09_CST_Cost_Books.sql` | row 11 |
| FA Asset Books | `03_Configurations/F3.1_WB_Setup_10_FA_Asset_Books.sql` | row 12 |

Rows 1 and 2 of the 3.1 table (payment terms) are expanded in the Payment Terms workbook above, not here.

**3.2 workbook: Descriptive Flexfields** (1 sheet)

| Sheet | Query file |
|---|---|
| Descriptive Flexfields | `03_Configurations/F3.2_WB_Descriptive_Flexfields.sql` |

## Section 4: Business processes

| Report item | Query file | Status |
|---|---|---|
| 4.1 Procure-to-pay (P2P) flow (table) | `04_Business_Processes/F4.1_P2P_Flow.sql` **v1.3** | v1.2 ran with **blank dates** (R015: last 90 days, not the report window). v1.3 (R024): cancelled POs now excluded by DOCUMENT_STATUS. Windowed run needed. |
| 4.2 Order-to-cash (O2C) flow (table) | `04_Business_Processes/F4.2_O2C_Flow.sql` | Not run |
| 4.3 Record-to-report (R2R) (table) | `04_Business_Processes/F4.3_R2R.sql` | Not run |
| 4.3 workbook **GL Journal Sources**, sheet 1 | `04_Business_Processes/F4.3_WB_GL_Journal_Sources.sql` | Not run |
| 4.4 Other process areas (table) | `04_Business_Processes/F4.4_Other_Process_Areas.sql` | Not run |
| 4.5 Costing method assessment (table) | `04_Business_Processes/F4.5_Costing_Method.sql` | Not run |

Run every Section 4 query with the **same parameters as F1** (same window and scope).

## Section 5: Customizations (CEMLI)

**Final set (2026-10-05).** By the user's decision, 5.1 = **the 5 CEMLI cards finalized earlier**. Details: [`05_Customizations/README_SECTION_5.md`](05_Customizations/README_SECTION_5.md). Runs: R016–R019.

| Report item | Query file | Status |
|---|---|---|
| 5.1 CEMLI summary: ESS · BIP Reports · OTBI Reports · BIP Templates · Approval Rules | `05_Customizations/F5.1_Extensions_Summary.sql` **v2.1** (2026-10-06) | Not run. Card 3 at dashboard grain (35 + 57 = 92, not 374); card 1 note gives the ESS history start. Expected 2 · 196 · 92 · 106 · 36. |
| 5.2 Custom scheduled processes (the report shows the first 10 rows) | `05_Customizations/F5.2_Custom_Scheduled_Processes.sql` v1.1 | ⚠ PROCESSSTART is proven (R035), but **ESS history starts 2026-09-21, so the discovery window has no coverage (C73)**: its period columns would read 0. Decide with the user before running. |
| 5.2 workbook **Custom Scheduled Processes**, sheet 1 (all rows) | same file | as above |
| 5.2 caption: how far back ESS history goes | `05_Customizations/F5.2_ESS_History_Coverage.sql` v1.0 | as above |

## Section 6: Data volumes & trends

Built 2026-10-05, ported from the EBS agent's `ebs_discover_data_volumes`. Details and the changes from the June drafts are in [`06_Data_Volumes_and_Trends/README_SECTION_6.md`](06_Data_Volumes_and_Trends/README_SECTION_6.md).

| Report item | Query file | Status |
|---|---|---|
| 6.1 Data volume trends by module (6 monthly charts, last 6 months of the window; blank dates = last 6 months up to today) | `06_Data_Volumes_and_Trends/F6.1_Data_Volume_Trends.sql` **v1.2** | v1.0 ran with blank dates (R022); v1.2 (blank-date rule + PO cancellation from DOCUMENT_STATUS) not run |
| 6.2 Master data (7 rows, Active / Total) | `06_Data_Volumes_and_Trends/F6.2_Master_Data.sql` v1.0 | Not run |

## Section 7: Open transactions snapshot

Built 2026-10-05, ported from the EBS agent's `ebs_discover_open_transactions` (8 classes, as in the 30-Sep report). Details, the Fusion differences and the changes from the June draft are in [`07_Open_Transactions/README_SECTION_7.md`](07_Open_Transactions/README_SECTION_7.md).

| Report item | Query file | Status |
|---|---|---|
| 7.1 Open transactions summary (10 rows: Open Item / Count / Value; snapshot, no window) | `07_Open_Transactions/F7.1_Open_Transactions.sql` **v1.3** | Not run; **checks pass (R029 / R030)**. v1.1 / v1.3 fixed row 1 (R024: PO link; R026: transfer orders); v1.2 added on-hand and open work orders (EBS v3). Expected with blank parameters (C52): 4 · 864 · 213 · 628 / 22,349,328.67 · 0 · 6,972 · 642 / 25,157,042.57 · 10 / 33,636.61 · 4,509 · 132. |
| 7.1 workbook WB8 **Open Transactions by BU** (BU x 10 classes, zeros included; sums to 7.1) | `07_Open_Transactions/F7.1_WB_Open_Transactions_By_BU.sql` **v1.3** | Not run (3 BUs, so 30 rows with blank parameters) |

## Section 8: Reports & BI inventory

Built 2026-10-05; **v1.1 rebuilt 2026-10-06** after checks R031–R035 and the user's decisions. It is ported from the EBS agent's `ebs_discover_reports_bi`; details in [`08_Reports_and_BI/README_SECTION_8.md`](08_Reports_and_BI/README_SECTION_8.md).
- **Window:** operational, from the run day (6 months; workbook 3 months). Leave the dates blank.
- **ESS keeps history only from 2026-09-21 on this pod (R035)**, so "Ran" covers just that retained history.

| Report item | Query file | Status |
|---|---|---|
| 8.1 Report area by type: BI Publisher by product area (decision B) + total, OTBI analyses / dashboards (dashboard grain), financial reports, account groups. Columns Defined / Custom / Run in Last 6 Months / Opened in Last 6 Months | `08_Reports_and_BI/F8.1_Report_Area_by_Type.sql` **v1.2** (headings as EBS: Run in Last 6 Months / Opened in Last 6 Months) | v1.1 ran (R036, partial screenshot): need the XML export |
| 8.2 Top 10 custom reports WITH recorded use (ESS runs or FRC opens) | `08_Reports_and_BI/F8.2a_Custom_Reports_Used.sql` **v1.1** | Not run |
| 8.2 Top 10 custom reports WITHOUT recorded use | `08_Reports_and_BI/F8.2b_Custom_Reports_Not_Used.sql` **v1.1** | Not run |
| 8.2 caption: counts, ESS history start, window, index date | `08_Reports_and_BI/F8.2c_Custom_Reports_Totals.sql` **v1.2** (Note column removed for the Excel workbook) | Not run |
| 8.2 workbook WB9, sheet 1: every scheduled-process job that ran in 3 months (EBS parity) | `08_Reports_and_BI/F8.2_WB1_Jobs_Run_Last_3_Months.sql` v1.0 (new) | Not run |
| 8.2 workbook WB9, sheet 2: reports opened from the Financial Reporting Center in 3 months | `08_Reports_and_BI/F8.2_WB2_FRC_Opens_Last_3_Months.sql` v1.0 (new) | Not run |

v1.0 is superseded and was never run: its "Used" read LAST_ACCESSED_DATE, which equals LAST_MODIFIED_DATE (R033). Its workbook query is in `08_Reports_and_BI/retired/`.

---

## Section 9: Security & segregation of duties

See `09_Security/README_SECTION_9.md`.

| Report item | File | Status |
|---|---|---|
| 9.1 Security footprint: Users, Roles (Metric / Value; snapshot, pod-wide) | `09_Security/F9.1_Security_Footprint.sql` **v1.1** (Users = login names, R038) | Not run. Expected (R038): Users **114**, Roles **511** |

---

## Section 10: Technical infrastructure & patch posture

Built 2026-10-07 (v1.0), ported from the EBS agent's `ebs_discover_tech_infrastructure`. See [`10_Technical_Infrastructure/README_SECTION_10.md`](10_Technical_Infrastructure/README_SECTION_10.md).
- **User decisions (2026-10-06):**
  - Keep all 22 EBS rows; a row Fusion cannot measure carries an "Oracle-managed (SaaS)" fixed text.
  - Add Fusion-specific rows that are useful (10.3).
  - EBS title kept; the EBS row "Recommended Fusion Pre-Migration Patch" becomes "Recommended Pre-Migration Update".
- **Window:** the load rows use the last 90 days from the run moment (operational); everything else is a snapshot. No dates needed; pod-wide.

| Report item | Query file | Status |
|---|---|---|
| 10.1 Fusion release & update level (Parameter / Value, 10 EBS rows) | `10_Technical_Infrastructure/F10.1_Release_and_Update_Level.sql` **v1.1** (comment-only; v1.0 hit BIP's `&` lexical prompt, R039) | Not run. Run after V10_2a / V10_2c / V10_2d (it reads AD_PRODUCT_GROUPS, PRODUCT_COMPONENT_VERSION, DBMS_UTILITY.PORT_STRING). |
| 10.2 Database & infrastructure footprint (Parameter / Value, 12 EBS rows; rows 11 / 12 = scheduled-process load) | `10_Technical_Infrastructure/F10.2_Database_and_Infrastructure.sql` **v1.1** (comment-only) | Not run. Run after V10_2b and V10_1. |
| 10.3 Fusion pod posture (Fusion only, 4 rows: installed languages, default user time zone, sandboxes not yet published, ESS history retained) | `10_Technical_Infrastructure/F10.3_Fusion_Pod_Posture.sql` **v1.1** (comment-only) | Not run. Run after V10_1. |

---

## Check queries (not in the report)

| Check query | Run before | Status |
|---|---|---|
| `00_Verify_First/V0_0_Registry_Columns_Check.sql` | F0, F1, F1.2 | ✅ Ran (R003): ALL OK |
| `00_Verify_First/V0_1_Verify_Objects_Columns_Sections_0_2.sql` | everything in Sections 0–2 | Not run |
| `00_Verify_First/V0_2_Verify_Data_Rules_Sections_0_2.sql` | everything in Sections 0–2 | Not run |
| `00_Verify_First/V0_3_Explain_Executive_Summary.sql` | Optional, after F0: lists what sits behind each card | Not run |
| `00_Verify_First/V1_1_Module_Activity_Evidence.sql` | Investigates the 13 vs 6 dispute (C10) | ✅ Ran 2026-10-01 (logged as **R040**: found as sample data in the Scout catalog). Users per module = F1 (C11 closed); 13 Active + 3 Dormant (FLA and FUN tables share one application) |
| `00_Verify_First/V1_2_Find_Offering_Enablement_Objects.sql` | Investigates the 13 vs 6 dispute (C10) | Not run |
| `00_Verify_First/V3_0_Columns_Check_Section_3_1.sql` | the 3.1 table and asset books table | ✅ Covered by R006; no separate run needed |
| `00_Verify_First/V3_1_Columns_Check_Section_3_Workbooks.sql` | all Section 3 workbook sheets and 3.2 | ✅ Ran (R006): 41 of 41 ALL OK |
| `00_Verify_First/V4_0_Columns_Check_Section_4.sql` **v1.2** | all Section 4 queries (generated from their column references; v1.2 adds PO_HEADERS_ALL.DOCUMENT_STATUS) | Not run |
| `00_Verify_First/V4_1_Code_Values_Section_4.sql` | all Section 4 queries: prints the code values they filter on (run after V4_0) | Not run |
| `00_Verify_First/V5_0_Columns_Check_Section_5.sql` | Section 5. v1.1 ran (R016). **v1.5** = 12 objects / 37 columns for the final set; no re-run needed (ESS is settled by V5_2a). | ⚠ **Ran v1.1 (R016): 13 / 15 ALL OK. ESS not visible.** Block C proved the Alerts Composer, sandbox and MDS columns. v1.2 needs no re-run on this pod. |
| `00_Verify_First/V5_2a_ESS_History_Read_Test.sql` / `V5_2b_ESS_Property_Read_Test.sql` | F5.2, F5.2b, V5_4 and F5.1 row 20. `SELECT * … ROWNUM <= 1`. **An error is a valid result**: it means not readable. A row means readable, but an XML export leaves out NULL columns, so its headings are not the full list (R034). | ✅ **V5_2a R034: readable** (45 columns shown; PROCESSSTART not shown). V5_2b not run: **next** |
| `00_Verify_First/V5_2c_ESS_Column_Discovery.sql` v1.0 | Every ESS_REQUEST_HISTORY column filled for any kind of request: `SELECT *`, the latest request per STATE × JOBTYPE. Cannot fail on a name. | Not needed any more: V8_3 (R035) read PROCESSSTART / PROCESSEND by name. Keep for other pods. |
| `00_Verify_First/V5_3_MDS_Discovery.sql` | F5.1 row 20 from MDS, plus a possible page-customizations row. Shows partitions, custom ESS job-definition documents, customization documents by layer and creator, and the tip-version rule. | Not run |
| `00_Verify_First/V5_4_ESS_Code_Values.sql` | F5.2 / F5.2b. V5_1 v1.1's ESS blocks A–H, moved. **Run only if V5_2a returns a row** (it did, R034). Reads PROCESSSTART and ESS_REQUEST_PROPERTY: run after V5_2b / V5_2c / V8_3. | Not run |
| `00_Verify_First/V5_5_Roles_Approvals_Detail.sql` | F5.1 rows 30 / 40 / 10–14 / 61. Lists every non-ORA_ role and every approval rule with creator type, the catalog user folders, and the visible XLA definition objects. | ✅ Ran (R019): roles 71 and rules 36 confirmed; CON.VERSION finding |
| `00_Verify_First/V6_0_Columns_Check_Section_6.sql` v1.1 | F6.1, F6.2, V6_1: 18 objects / 51 columns, generated from the queries (v1.1 adds PO DOCUMENT_STATUS, proven in R020's list) | ✅ R020 (v1.0): 18 / 18 ALL OK; no re-run needed |
| `00_Verify_First/V6_1_Code_Values_Section_6.sql` | F6.1, F6.2 (run after V6_0). TCA status values, AR complete flag, item flags, bank classification, PO type / GL status / order submitted flag, and the grain (rows vs keys) | ✅ R021: all verdicts OK |
| `00_Verify_First/V6_2_Customer_End_Dates_Section_6.sql` | F6.2 rows 4 / 5: customer accounts and account sites end-dated before today that still say STATUS A (R021 found STATUS A on every row) | Not run; run with F6.2 |
| `00_Verify_First/V7_0_Columns_Check_Section_7.sql` **v1.3** | F7.1, F7.1_WB, V7_1: 18 objects / 88 columns, generated from the queries | R023 (v1.0) / R025 (v1.2) / R029 ALL OK. R029's version can't be read from its output (V7_0 never prints its need list); the 3 v1.3 columns are proven by R030. Done. |
| `00_Verify_First/V7_1_Code_Values_Section_7.sql` **v1.3** | F7.1, F7.1_WB (run after V7_0). Every stored status each row tests, with whether F7.1 counts it; requisition order links (PO / transfer order); on-hand pairs and stock owner; work-order system statuses; inventory org -> BU; currency mix; prepayments; receipt sign; scope loss; BUs | R024 (v1.0) / R026 (v1.2) each found a row 1 defect (fixed). ✅ **R030 (v1.3):** row 1 = 4, consigned stock 0, all other blocks as R026. Done. |
| `00_Verify_First/V8_0_Columns_Check_Section_8.sql` **v1.1** | Section 8 v1.1: 10 objects / 28 columns, generated by `colrefs.py --v0 --skip ESS_REQUEST_HISTORY` (the dictionary cannot describe ESS; R034 / R035 prove its columns by reads) | ✅ v1.0 R031: 9 / 9 ALL OK. **v1.1: no re-run needed** (every column printed by R031 / R003) |
| `00_Verify_First/V8_1_Code_Values_Section_8.sql` **v1.1** | Section 8 v1.1 pre-flight (same block as the F8 files): population and dashboard grain, names, product-area rows (decision B), ESS history / runs / FRC opens per type, every object with recorded use, F5.1 v2.1 card cross-checks | Not run: **run first** (v1.0 ran as R032) |
| `00_Verify_First/V8_2_Used_And_Grain_Diagnostic_Section_8.sql` v1.0 | Section 8 v1.1 decisions (run alone, no binds): bulk-access days / minutes, last access vs last modified, five candidate "Used" rules, dashboard pages, BIP file types (data models?), the 6 FR reports under the proposed path rule, the per-user access log, GL_FRC_REPORTS_TL display names | ✅ **R033:** access = modified on 100% (no usage signal); dashboards = pages (custom 58 dashboards); all BIP `.xdo`; FR rule OK; TL names complete |
| `00_Verify_First/V8_3_ESS_Run_Facts_Section_8.sql` v1.0 | Section 8 v1.1 and F5.2: ESS states / request types / job types, PROCESSSTART range, catalog BIP reports ↔ ESS runs, 3-month workbook preview, submitters, FRC log vs ESS, escape-aware dashboard count | ✅ **R035:** PROCESSSTART exists; **ESS history only from 2026-09-21**; 8 catalog BIP reports ran (3 custom); dashboards custom 57 / Oracle 875 |
| `00_Verify_First/V9_1_Code_Values_Section_9.sql` **v1.2** (v1.0 ran as R037, v1.1 as R038: one Oracle application identity held by two accounts that can sign in → F9.1 v1.1 counts login names; v1.2 carries that block) | F9.1 pre-flight (same Section 9 block): user accounts per active / suspended / date state / person with "counted Y/N", HR-terminated, duplicate user names, non-person accounts listed; roles per active flag x type flags x code class, by code class. No V9_0: every column was printed by R006 / R016. | v1.0 (R037) and v1.1 (R038) ran; v1.2 optional |
| `00_Verify_First/V10_0_Columns_Check_Section_10.sql` v1.0 | Section 10: 14 objects / 56 columns, generated by `colrefs.py --v0 --skip ESS_REQUEST_HISTORY` from F10.1–F10.3 and V10_1, plus a candidate block (ord 50+) for the EBS-only objects (`V_$*`, `DBA_*`, `AD_*`, `PATCH_*`, `ASK_DEPLOYED_*`) | Not run: **run first** |
| `00_Verify_First/V10_1_Code_Values_Section_10.sql` v1.0 | F10.2 / F10.3 pre-flight (Section 10 block v1.0): ESS history, window and coverage, the clock behind PROCESSSTART (UTC verdict), all 24 hours under the F10.2 rule and the EBS rule, never-started requests; languages; the FND_TIMEZONE profile values and stored levels; sandbox states with "counted Y/N"; every measured row as printed | Not run (after V10_0) |
| `00_Verify_First/V10_2a`–`V10_2f` read tests v1.0 | One per risky source: a AD_PRODUCT_GROUPS (release), b NLS_DATABASE_PARAMETERS, c PRODUCT_COMPONENT_VERSION, d DBMS_UTILITY.PORT_STRING, e V$OPTION, f the ten database catalog views behind the "Oracle-managed" rows (expected to fail). **An error is a valid result**: send it. | Not run |
| `00_Verify_First/V5_1_Code_Values_Section_5.sql` **v1.2** ✅ ran (R017): markers agree; sandbox table and empty AAD source found | F5.1. Prints BI catalog folders and type codes, role-code prefixes and role-type flags, approval-rule flags, alert flags (P), the three sandbox tables (Q), and the user-account rule checked against Oracle's seed and type markers. No ESS (moved to V5_4). | Not run |

---

## Run order

1. **Sections 0–2:** V0_1 → V0_2 → F0 → F1 → F1.2 → F2.1 → F2.1 Org Structure → F2.2 → F2.2 Segment Values → F2.2 BSV
2. **Section 1 dispute:** V1_1 → V1_2
4. **Section 4:** V4_0 → V4_1 → F4.1 → F4.2 → F4.3 → F4.3 workbook → F4.4 → F4.5
3. **Section 3:** ~~V3_0 → V3_1~~ (passed: R006) → F3.1 → F3.1 Asset Books → the 12 workbook sheets (2 Payment Terms + 10 Setup Inventory) → F3.2 → F3.2 workbook
5. **Section 5:** ~~V5_0~~ (R016) → ~~V5_1~~ (R017) → ~~V5_5~~ (R019) → ~~V5_2a~~ (R034) → ~~V8_3~~ (R035) → **F5.1 v2.1** (with the Section 8 batch). F5.2 / F5.2b wait on a decision: no ESS coverage for the discovery window (C73).
6. **Section 6:** V6_0 → V6_1 (both done: R020 / R021) → F6.1 (window dates) → F6.2 → V6_2.
7. **Section 7:** checks done (R029 / R030). **Next: F7.1 v1.3 → F7.1_WB v1.3** (same ledger / BU; no dates needed). Earlier checks: R023 / R024 (v1.0), R025 / R026 (v1.2).
8. **Section 8 v1.1:** **V8_1 v1.1** → F8.1 → F8.2c → F8.2a → F8.2b → F8.2_WB1 → F8.2_WB2 (dates blank; ledger only matters for F8.1's account-groups row). Earlier checks: R031–R035. V8_0 v1.1 needs no re-run.
9. **Section 9:** ~~V9_1 v1.0~~ (R037) → ~~V9_1 v1.1~~ (R038) → **F9.1 v1.1** (no dates; parameters don't change the result; expected 114 / 511). C75 closed; C76 fixed; C74 / C77 are the user's call (defaults kept).
10. **Section 10:** **V10_0** → V10_2a → V10_2b → V10_2c → V10_2d → V10_2e → V10_2f (each its own data set; an error is a valid result) → V10_1 → F10.3 → F10.2 (if V10_2b passed) → F10.1 (if V10_2a / c / d passed). No dates; parameters blank.

**Rules for every run:**
- Run each check query first. Every row must say **ALL OK**.
- Use the **same parameters** for a section's table and its workbook sheets. With parameters left blank, the query covers the whole pod.
- Send back every output with the parameters you used. Each one is logged in `06_Run_Results/RUN_LOG.md`.
