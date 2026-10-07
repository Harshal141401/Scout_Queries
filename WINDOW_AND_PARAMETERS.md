# Window and parameters: which query takes which dates

**Discovery window for the Fusion report: Apr-25 to Mar-26** (decided 2026-10-05, also in `06_Run_Results/RUN_LOG.md` §6).

**Enter on every windowed query:**

| Parameter | Value |
|---|---|
| `p_from_date` | `2025-04-01` |
| `p_to_date` | `2026-03-31` (inclusive) |

**Date rules**
- The format is `YYYY-MM-DD`.
- If the dates are left blank, the windowed queries fall back to the **last 90 days up to today** (`TRUNC(SYSDATE) - 90`). That is *not* the discovery window.
- Every windowed query shares one identical window block (copied from F1), so the same two dates give the same period everywhere.

**Ledger and BU** (`p_ledger_id`, `p_bu_id`)
- Use the same values across every query of one report run.
- Blank means the whole pod.

---

## 1. Built queries: windowed or snapshot

### Use the window (enter the dates)

| Section | Query | What the window drives |
|---|---|---|
| Executive Summary | `F0_Executive_Summary` | Users who transacted, Active Modules. Ledgers, LEs and BUs are snapshot. |
| 1.1 | `F1_Active_Module_Inventory` | Module activity and users per module |
| 1.2 | `F1.2_Modules_No_Activity` | Modules with no activity in the window |
| 4.1 P2P | `F4.1_P2P_Flow` | Requisitions (creation date), POs (creation date), receipts (transaction date), AP invoices (invoice date), payments (check date) |
| 4.2 O2C | `F4.2_O2C_Flow` | Sales orders and RMA (ordered date), deliveries (first pickup date), AR transactions (transaction date), cash receipts (receipt date) |
| 4.3 R2R | `F4.3_R2R` | Posted journals (creation date), bank statements (creation date), frequency |
| 4.3 workbook | `F4.3_WB_GL_Journal_Sources` | Same population as F4.3 |
| 5.2 + workbook | `F5.2_Custom_Scheduled_Processes` | Executions (period), first / last run in the period (ESS start time, `PROCESSSTART`). The all-time columns ignore the window, as in EBS. |
| 5.2 caption | `F5.2_ESS_History_Coverage` | Only says whether the period is inside retained ESS history (Full / Partial / None). Use the same dates as F5.2. |
| 6.1 | `F6.1_Data_Volume_Trends` | **The last 6 months of the window**, by calendar month: 2025-04-01 / 2026-03-31 gives Oct-25 → Mar-26. Never before the entered from-date. **Exception to the 90-day default (user, 2026-10-05):** with the from-date blank, the chart is the 6 months ending in the to-date month (to-date blank = today, so the current month is partial). Each chart uses its own business date (ordered, creation, transaction or invoice date). |
| Check | `V0_3_Explain_Executive_Summary` | Same window as F0 |
| Check | `V1_1_Module_Activity_Evidence` | Same window as F1, plus 12 months of history ending with the window |

### Operational window from the run day (dates accepted but ignored)

These measure use of the system, which is operational history, not a business date, as in EBS (the agent's `_logwin_cte`). Leave the dates blank.

| Section | Query | Window |
|---|---|---|
| 8.1 | `F8.1_Report_Area_by_Type` v1.1 | "Ran (ESS history)" and "Opened in FRC (6 mth)": `ADD_MONTHS(TRUNC(SYSDATE), -6)` up to the end of today. Defined / Custom are a snapshot; account groups follow `:p_ledger_id`. |
| 8.2 | `F8.2a` / `F8.2b` / `F8.2c` v1.1 | the same 6 months (one byte-identical Section 8 block) |
| 8.2 workbook | `F8.2_WB1_Jobs_Run_Last_3_Months`, `F8.2_WB2_FRC_Opens_Last_3_Months` | `ADD_MONTHS(TRUNC(SYSDATE), -3)` up to now |
| Checks | `V8_1_Code_Values_Section_8` v1.1, `V8_2`, `V8_3` | the same windows |
| 10.2 rows 11 / 12 | `F10.2_Database_and_Infrastructure` v1.0 (Average Scheduled Process Load, peak / off-peak) | `SYSDATE - 90` up to the run moment, as the EBS agent (`>= SYSDATE - 90`). The rows print the span the ESS history actually covers (from 2026-09-21 on this pod). |
| Check | `V10_1_Code_Values_Section_10` v1.0 | the same 90 days (same Section 10 block) |

**ESS keeps only recent history: from 2026-09-21 on this pod (R035), and reportedly about 60 days at most on any pod.**
- Every ESS count covers only the retained part of its window; F8.2c prints the start.
- Section 5.2's discovery-window counts have **no** ESS coverage on this pod (C73).
- The catalog index's LAST_ACCESSED_DATE is not used anywhere: it equals LAST_MODIFIED_DATE (R033).

### Snapshot (dates accepted but ignored; counts are as of the run day)

| Section | Queries |
|---|---|
| 2.1 / 2.2 | `F2.1_Ledger_LE_BU_Map`, `F2.1_Org_Structure_Detail`, `F2.2_COA_Structure`, `F2.2_COA_Segment_Values_Detail`, `F2.2_BSV_Legal_Entity_Detail` |
| 3.1 | `F3.1_Setup_Area_by_Module`, `F3.1_Asset_Books_By_Class`, all 12 `F3.1_WB_*` sheets |
| 3.2 | `F3.2_DFF_Deep_Dive`, `F3.2_WB_Descriptive_Flexfields` |
| 4.4 | `F4.4_Other_Process_Areas` (items, assets, projects) |
| 4.5 | `F4.5_Costing_Method` |
| 5.1 | `F5.1_Extensions_Summary` (counts as of the run day) |
| 6.2 | `F6.2_Master_Data` (active as of the run day) |
| 7.1 | `F7.1_Open_Transactions`, `F7.1_WB_Open_Transactions_By_BU` (open as of the run day; no window, as in EBS) |
| 9.1 | `F9.1_Security_Footprint` (pod-wide; the binds are accepted and ignored) |
| 10.1 / 10.2 / 10.3 | `F10.1_Release_and_Update_Level`, `F10.2_Database_and_Infrastructure` rows 1–10, `F10.3_Fusion_Pod_Posture` (pod-wide; the binds are accepted and ignored) |
| Checks | `V0_0`, `V0_1`, `V0_2`, `V1_2`, `V3_0`, `V3_1`, `V4_0`, `V4_1`, `V5_0`, `V5_1`, `V5_2a`, `V5_2b`, `V5_3`, `V5_4`, `V5_5`, `V6_0`, `V6_1`, `V6_2`, `V7_0`, `V7_1`, `V8_0`, `V9_1`, `V10_0`, `V10_2a`–`V10_2f` |

**All-time on purpose (EBS rule):**
- `JOURNALS_POSTED` on the GL Journal Sources and GL Journal Categories sheets (`F3.1_WB_Setup_03` / `_04`)
- `DOCUMENTS_USING` and `MASTER_DEFAULTS` on the payment-terms sheets (`F3.1_WB_Payment_Terms_AP` / `_AR`)

These answer "defined vs ever used", not "used in the window".

**`p_custom_prefix`** is accepted everywhere and **used nowhere** since F5.1 / F5.2 v1.1 (2026-10-05).
- Section 5 identifies custom objects by Fusion's own markers: the `/oracle/apps/ess/custom/` path, the `/shared/Custom/` catalog folder, the `ORA_` role prefix, and "created by a user account".
- V5_1 block D still prints the job-naming convention the client uses, for the migration document.

---

## 2. Sections not built yet: the window each will need (from the EBS logic)

| Section | Window rule to build | For Apr-25 to Mar-26 this means |
|---|---|---|
| *(5.1 and 5.2 are built: see §1)* | | |
| *(6.1 and 6.2 are built: see §1)* | | |
| *(7.1 is built: see §1)* | | |
| *(8.1 and 8.2 are built: see §1, operational window)* | | |
| *(9.1 is built: see §1, snapshot)* | | |
| *(10.1–10.3 are built: see §1; the 10.2 load rows use the last 90 days from the run moment)* | | |

Every section is now built. Any later query that takes the discovery window uses the same `win` block and parameters as F1. The operational windows (8.x, 10.2 rows 11 / 12) are measured from the run day, and their headers say so.
