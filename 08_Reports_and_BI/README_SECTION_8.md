# Section 8: Reports & BI inventory

**Status (2026-10-06):**
- v1.1 is built on the "Section 8 block v1.1". It follows checks R031–R035 and the user's decisions of 2026-10-06. Not yet run.
- v1.0 was never run. It is frozen in `06_Run_Results/query_snapshots`; its workbook query is in `retired/`.

This is the Fusion version of the EBS report's Section 8:
- **8.1 Report area by type:** BI Publisher reports by product area, OTBI, and the financial-reporting footprint. EBS: XML Publisher by module plus the FSG footprint.
- **8.2 Custom reports with and without recorded use:** two top-10 tables and a caption. Workbook WB9 lists what ran or was opened in the last 3 months.

Ported from the EBS agent's `ebs_discover_reports_bi` (tools.py 5644), the final logic.

## Files

| Report item | File | Version | Status |
|---|---|---|---|
| **8.1** Report area by type | `F8.1_Report_Area_by_Type.sql` | 1.2 (headings only) | v1.1 ran (R036, partial screenshot) |
| **8.2** Top 10 custom reports with recorded use | `F8.2a_Custom_Reports_Used.sql` | 1.1 | Not run |
| **8.2** Top 10 custom reports without recorded use | `F8.2b_Custom_Reports_Not_Used.sql` | 1.1 | Not run |
| **8.2** caption: counts, ESS history start, window, index date | `F8.2c_Custom_Reports_Totals.sql` | 1.2 (Note column removed: the output goes to Excel; the wording is in "Captions for the report" below) | Not run |
| **WB9** sheet 1: every scheduled-process job that ran (3 months) | `F8.2_WB1_Jobs_Run_Last_3_Months.sql` | 1.0 (new) | Not run |
| **WB9** sheet 2: reports opened from the FRC (3 months) | `F8.2_WB2_FRC_Opens_Last_3_Months.sql` | 1.0 (new) | Not run |
| Code values (pre-flight) | `../00_Verify_First/V8_1_Code_Values_Section_8.sql` | 1.1 | Not run: **run first** |
| Column check | `../00_Verify_First/V8_0_Columns_Check_Section_8.sql` (generated) | 1.1 | No re-run needed: every column was printed by R031 / R003, and ESS is proven by reads (R034 / R035) |

**Run order:** V8_1 v1.1 → F8.1 → F8.2c → F8.2a → F8.2b → F8.2_WB1 → F8.2_WB2.
- No dates are needed (operational windows); use the same ledger as the other sections, or blank.
- **Check V8_1 against the expected values below first.**

**One population.** The shared block and the **Section 8 block v1.1** are byte-identical in all seven queries. The block covers catalog objects, names, product areas, ESS runs and FRC opens. If a rule changes, change all seven.

## Decisions (user, 2026-10-06)

**8.1 headings (user, after R036):** plain report labels as in the EBS 8.1 query: Report Type · Product Area · Defined · Custom · **Run in Last 6 Months** (ESS runs, retained history) · **Opened in Last 6 Months** (Financial Reporting Center opens). BIP shows a space as `_` in its XML; the layout prints the final heading.

| Topic | Decision |
|---|---|
| Report use | **Two labelled columns:** "Ran (ESS history)" = runs of the report's job definition in the retained ESS history, and "Opened in FRC (6 mth)" = users whose last Financial Reporting Center open falls in the 6 months. Both are floors; the caption gives the ESS history start. |
| Custom product areas | **Option B:** Oracle family / product areas. A custom report filed in an Oracle folder stays in that area; every other custom report shows under its top-level client folder ("Custom: Reports", "Custom: Development" …). |
| Dashboards | **Count dashboards**, with pages alongside. The user asked for "the most ideal way for the migration document": the dashboard is the unit that is migrated, and its pages travel with it. |
| Financial reports Custom | **Filled** from the Custom folder (6 of 6). |
| Defaults, not objected to | OTBI "Ran" blank (OTBI is not run through ESS). WB9 sheet 1 = ESS jobs that ran (EBS parity). Account-groups row kept. 8.2 covers every custom report type. |

## Why "use" looks like this: the evidence

- **The catalog index cannot measure use (R033).** LAST_ACCESSED_DATE equals LAST_MODIFIED_DATE on all 5,456 items. It records edits and Oracle redeployments (2026-01-16, 2026-07-10), never opens.
- **ESS history is readable (R034), but only from 2026-09-21 on this pod (R035), 15 days.**
  - Older history did exist: the FRC log still points at ESS request 997,980, which is gone.
  - Oracle reportedly purges ESS history after about 60 days (an Oracle A-Team blog, seen only in search summaries).
  - 15 days suggests the pod was refreshed around 21 September. That would fit business transactions stopping in late September and the catalog index being rebuilt on 24 September. **Confirm with the pod administrator.**
  - **Corroborated by R038 (Section 9):** the pod's `iamoqy-dev1` application identities were created on 2026-09-21 / 22.
  - On any Fusion pod, **a 6-month run count is not available from SQL.**
- **What ESS shows (R035):** 8 catalog BI Publisher reports ran (3 custom, 14 runs; 5 Oracle, 10 runs).
  - The exact `JobDefinition://` match is complete (no case variants, no unmatched BIP jobs).
  - One custom job definition is shared by two catalog copies, so its runs show on both (Note column).
- **What the FRC log shows (R033):** 9 opens in 6 months, covering 4 custom financial reports, 1 Oracle analysis and 1 Oracle BI Publisher report, by 3 users.
- **Not recorded anywhere this report user can read:** online runs from the BI catalog (no BI Publisher scheduler tables, no usage tracking; R031).
- **Run definitions:**
  - A "run" = an ESS request with PROCESSSTART (it started, whatever the outcome), as EBS counts ACTUAL_START_DATE.
  - Schedule parents never start and are not runs.
  - The ESS state names come from lookup BEN_ESS_REQ_STATE (R035).

## The v1.1 rules (Section 8 block)

| Rule | Detail | Evidence |
|---|---|---|
| Population | Shared catalog, types BIP / Analysis / Dashboard / FR. `/Shared Folders/` is read as `/shared/`. Personal folders and placeholders are left out. | R032 (FR path), R033 F |
| Object grain | One row per report, analysis or financial report. **A dashboard = the parent folder of its page rows, or the row itself when it sits in a `_portal` folder.** | R033 D, R035 J: custom 57 / Oracle 875 |
| Escaped `/` | `\/` inside a name is protected with `CHR(31)` while paths are split | R033 H, R035 J (19 analyses, 2 dashboard rows) |
| Names | `GL_FRC_REPORTS_TL.REPORT_DISPLAY_NAME`, session language then US. Dashboards are named after their folder. | R033 H: every item has one |
| Custom | under `/shared/Custom/` (the Section 5 marker) | R017, R032 |
| Product area | decision B (above) | R032 D |
| Ran (ESS history) | runs (PROCESSSTART) of the report's job definition in the 6-month window, which ESS covers only from its history start | R034 / R035 |
| Opened in FRC (6 mth) | users whose last FRC open falls in the 6 months; a page open counts for its dashboard | R033 G |

## 8.1 EBS → Fusion mapping

| EBS (30-Sep report, Vision) | Fusion v1.1 |
|---|---|
| XML Publisher by module: Defined / Custom / Run (6 mth) | BI Publisher by product area (decision B): Defined / Custom / **Ran (ESS history)** / **Opened in FRC (6 mth)**, plus a total row |
| *(none)* | OTBI analyses; OTBI dashboards (with page count). Ran blank; Opened from the FRC log. |
| FSG Financial Statement Reports | Financial reports (Financial Reporting Web Studio): 6, Custom 6, Opened 4 |
| FSG Report / Row / Column / Content / Display Sets, unused Axis Sets | **No Fusion row.** Fusion has no FSG (R031: no `RG_REPORT*` object). Stated in the caption. |
| *(none)* | Account groups (ledgers in scope): 21 |

**8.2:**
- The EBS "ran" and "not run" tables become "with recorded use" and "without recorded use".
- EBS "Runs (all time)" and "Enabled" have no Fusion source: ESS keeps only recent history, and catalog items have no enabled flag.
- Status never says "never run".

**WB9:**
- Sheet 1 mirrors the EBS workbook: every scheduled-process job that ran in 3 months, with product, job type, BI Publisher report, custom flag, times run and submitters.
- Sheet 2 lists Financial Reporting Center opens.

## Expected values on this pod (from R032–R035; not targets)

| Output | Expected |
|---|---|
| F8.1 BI Publisher total | Defined 1,570 · Custom 196 · Ran 8 · Opened 1 |
| F8.1 OTBI analyses | 2,457 · 35 · — · 1 |
| F8.1 OTBI dashboards | 932 (1,423 pages) · 57 · — · 0 |
| F8.1 financial reports | 6 · 6 · — · 4 |
| F8.1 account groups | 21 |
| F8.1 BI Publisher rows | Oracle areas (84 hold Oracle BI Publisher reports) + the client-folder rows (V8_1 C0 gives the count) + total |
| F8.2a | 7 rows: YEU Gross Revenue Report (10 runs); YEU Billing And Credit Memo Report in two copies (2 runs, shared job); 4 financial reports |
| F8.2b | 10 of 287 |
| F8.2c | 294 · 7 · 287 · 3 · 4 · 196 · 35 · 57 · 339 · 6 · 106 · 2026-09-21 |
| WB1 | 121 job definitions, 29,473 runs (as of R035), 2 custom |
| WB2 | 4 rows |
| F5.1 v2.1 | card 1 = 2 · card 2 = 196 · card 3 = 35 + 57 = **92** · card 4 = 106 · card 5 = 36 |

ESS counts grow every day; compare them only within a run.

## Checks (RUN_LOG C58–C73)

| Check | Status |
|---|---|
| C58 V8_0 v1.0 ALL OK | ✅ R031 (v1.1: no re-run needed) |
| C59 FR counted | ✅ fixed in v1.1 (path rule) |
| C60 / C68 custom ties to F5.1 cards 2 / 3 / 4 | V8_1 v1.1 E1 must read 196 / 92 / 106 |
| C61 F8.2c: With + Without = Custom; types sum to Custom | v1.1, not run |
| C62 F8.2a rows = min(10, With); F8.2b rows = min(10, Without) | v1.1, not run |
| C63 WB1 rows = V8_1 D0 job definitions run in 3 mth; WB2 rows = FRC opens in 3 mth | v1.1, not run |
| C64 F8.1 BI Publisher rows sum to the total; row count = V8_1 C0 | v1.1, not run |
| C65 / C70 / C72 ESS readable; PROCESSSTART proven; history 15 days | ✅ / ✅ / stated in every caption |
| C66 / C67 / C69 / C71 | ✅ (index ≠ use; dashboard grain; no data models; FR opened 4) |
| C73 F5.2 period columns have no ESS coverage for the discovery window | open (Section 5) |

## Captions for the report (Fusion wording of EBS Appendix A, row 8)

- **Ran (ESS history)** counts reports run as scheduled processes, from ESS request history. This pod keeps that history only from 2026-09-21 (the caption prints the date). Fusion keeps no 6-month run log.
- **Opened in FRC (6 mth)** counts reports opened from the Financial Reporting Center in the last six months. Online runs from the BI catalog are not recorded, so both columns are floors.
- **BI Publisher** = BI Publisher reports in the shared catalog. **Product area** = the catalog's family / product folder. Custom reports filed in the client's own folders show under "Custom: <folder>".
- **Custom** = under `/shared/Custom/`. Personal folders are not counted.
- **Dashboards** are counted as dashboards; their pages are shown alongside.
- **Financial reports** are Financial Reporting Web Studio reports. They are pod-wide: the catalog has no chart of accounts on them. Fusion has no FSG row, column, content, display or axis sets. Smart View queries live in users' workbooks.
- **8.2** status never says "never run": an empty history means only that nothing is on record in the retained history.

## Known limits

- **ESS history is short**: 15 days on this pod, and about 60 days reportedly at most. Run the discovery on the production pod, or soon after a refresh, to see more.
- **Online runs are invisible.** BI Publisher and OTBI reports run online from the catalog leave no readable trace.
- **A shared job definition** gives its runs to every catalog copy that carries it. ESS request properties (V5_2b) could tell which copy ran.
- **SVC**, most likely the account this discovery runs under, appears among the FRC opens (3) and ESS submitters (185). Its activity is counted like anyone else's.
- **Financial reports are pod-wide.** The catalog index has no chart of accounts, unlike EBS FSG.
