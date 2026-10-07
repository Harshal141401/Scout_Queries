# Section 5: Customizations (CEMLI), final set (2026-10-05)

**User decision, 2026-10-05:** 5.1 keeps **only the five CEMLI cards finalized earlier** for the Fusion → Fusion report: same labels and same column names as the June draft `12_S5.1_CEMLI_Summary.sql`. Each card now uses the rule verified on this pod.

Pod runs: R016–R019 in `06_Run_Results/RUN_LOG.md`.

## Deliverables

| Report item | File | Version | Status |
|---|---|---|---|
| **5.1** CEMLI summary (5 cards) | `F5.1_Extensions_Summary.sql` | **2.1** (2026-10-06) | Not run. Card 3 counts dashboards (35 + 57 = 92); card 1 note gives the ESS history start. Expected 2 · 196 · 92 · 106 · 36. |
| **5.2** Custom scheduled processes (report: first 10 rows) + workbook WB7 (all rows) | `F5.2_Custom_Scheduled_Processes.sql` | 1.1 | ⚠ PROCESSSTART proven (R035), but **ESS history starts 2026-09-21: no coverage for the discovery window (C73)**. Decide before running. |
| **5.2** caption: how far back ESS history goes | `F5.2_ESS_History_Coverage.sql` | 1.0 | as above |

## The five cards

| # | CEMLI Category | Rule | Last measured on this pod |
|---|---|---|---|
| 1 | Custom Scheduled Processes (ESS) | ESS request history: job definitions under `/oracle/apps/ess/custom/`, one per definition (rule identical to F5.2) | **2** (R035): a floor, since ESS keeps history only from 2026-09-21 |
| 2 | Custom BIP Reports | GL_FRC_REPORTS_B: type BIP, path under `/shared/Custom/` | 196 (R017) |
| 3 | Custom OTBI Reports | Analysis + **Dashboard at dashboard grain** (v2.1: a page's parent folder, escaped `/` handled) | **92 = 35 + 57** (R035). The 339 counted in R017 are pages. |
| 4 | Custom BIP Templates | card-2 reports that carry an ESS job definition (`BIP_REPORT_JOB_DEFINITION`) | 106 by the same rule (R032, V8_1 G1); F5.1 v2.0 not run |
| 5 | Workflow / Approval Rule Customizations | POR_AMX_RULES: active, not the sandbox copy | 36, of which 9 are unnamed defaults (R017 / R019) |

**Output columns:** CEMLI Category | Count | Source / Notes. A card whose source returns no rows shows a blank count, never 0.

**Card 4, in plain terms.** Oracle's catalog index has no template column. The June rule (kept) counts custom BIP reports that are registered as scheduled processes. If the migration document needs the BIP layout templates themselves, that list must come from the BI catalog.

## Run order

1. ~~**V5_2a**~~ ✅ **R034 (2026-10-06): ESS request history is readable.**
   - A BIP XML export leaves out NULL columns. Its one row was a request that never started, so PROCESSSTART (which F5.2 / F5.2b / V5_4 count on) is not proven yet (C70).
2. ~~V8_3~~ ✅ **R035:** PROCESSSTART exists, but **ESS history starts on 2026-09-21** (15 days).
3. **Next: F5.1 v2.1** (built 2026-10-06), run with the Section 8 batch.
4. **F5.2 / F5.2b: decide first (C73).** The discovery window Apr-25 → Mar-26 has no ESS coverage on this pod, so every period count would read 0, which is not a measurement. The options are:
   - F5.2b reports coverage "None" and F5.2 shows only all-retained-history counts;
   - or run 5.2 on the production pod, where history may be longer (Oracle reportedly purges after about 60 days).

## Measured, but not CEMLI cards

These were measured in R017–R019 and are kept in RUN_LOG and the v1.4 snapshot. They are not part of 5.1 by the user's decision:

| Item | Value |
|---|---|
| Custom roles | 71 (all client roles) |
| DFF segments | 85 |
| Custom lookup types | 14 |
| Custom value sets | 45 (user-account rule) |
| User-defined accounting methods | 1 |
| Custom enabled alerts | 32 |
| Published sandboxes | 36 |
| BI items in personal folders | 299 |

Roles belong naturally in Section 9 (security), and flexfields, lookups and value sets in Section 3.

## Open notes

- **C40 (Section 3):** the implementation identity CON.VERSION is not in PER_USERS, so F3.2's "edited by a user account" rule misses its edits.
- **From Section 8's checks (R032, 2026-10-06), same catalog index and rule:**
  - **Card 4 expected = 106** (C68): custom BIP reports with BIP_REPORT_JOB_DEFINITION.
  - **Card 3 grain (C67):** resolved by R033 / R035. The Dashboard rows are pages; custom = 57 dashboards holding 339 pages. Built into F5.1 v2.1.
  - **Card 2 grain (C69):** resolved by R033. All BIP items are `.xdo` reports (no data models), so card 2 stays 196.
