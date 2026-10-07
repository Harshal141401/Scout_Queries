# Section 10: Technical infrastructure & patch posture

**Status (2026-10-07):** built, not run.
- F10.1 v1.0 was tried once (**R039**): BIP asked for a "lexical reference" before running, because a header comment held an `&`.
- **F10.1 / F10.2 / F10.3 are now v1.1** (comment-only; no `&` anywhere). The checks are v1.0.
- Run the checks first (run order below). The next run number is R040.

This is the Fusion version of the EBS report's Section 10 (EBS PDF pages 20–21):
- **10.1 Fusion release & update level:** the 10 EBS rows of "10.1 EBS release & patch level".
- **10.2 Database & infrastructure footprint:** the 12 EBS rows.
- **10.3 Fusion pod posture:** 4 Fusion-only rows, added at the user's request.

Ported from the EBS agent's `ebs_discover_tech_infrastructure` (tools.py 5920–6155), the final logic. The EBS SQL pack has no Section 10 file, so the agent code is the only EBS source.

## Decisions (user, 2026-10-06)

| Topic | Decision |
|---|---|
| Rows Fusion cannot measure | **Keep all 22 EBS rows** in EBS order, with Fusion labels where Fusion has a term. A row Fusion cannot measure carries an honest fixed text such as "Oracle-managed (SaaS): not visible to customers", as the agent does for its rows SQL cannot answer (`_TECH_NOT_SQL`). |
| Fusion-only rows | "Fusion specific, the information should be useful." Built as table 10.3 with 4 rows. Each one is something the target pod must match or finish before a Fusion → Fusion migration (below). |
| Title and wording | **EBS title kept** ("Technical infrastructure & patch posture"). 10.1 is "Fusion release & update level". The EBS row "Recommended Fusion Pre-Migration Patch" becomes **"Recommended Pre-Migration Update"**. |

**Wording note on row 10.1 / 10.** The chosen option read "Bring the source and target pods to the same quarterly update before migrating setup, sandboxes or data." Oracle's documentation asks for more than the update, and sandboxes are not migrated themselves; their published configurations are. So v1.0 prints:
- "Bring the source and target pods to the same quarterly update and **patch level** before migrating setup, **configurations** or data."
- Revert to the original text if you prefer it; it is one literal in F10.1.

The sources behind it:
- *Migrate Your Configurations* (Configuration Set Migration, 26A): "Make sure that the source and target environments are of the same release, with the same standard and one-off patches applied to both environments."
- *Best Practices for Migrating Setup Data from Test to Production* (26B): "the Oracle Fusion Applications Cloud revision of both source and target environments must be the same."

## Files

| Report item | File | Version | Status |
|---|---|---|---|
| **10.1** Fusion release & update level (Parameter · Value, 10 rows) | `F10.1_Release_and_Update_Level.sql` | 1.1 (v1.0 hit the `&` prompt, R039) | Not run. Reads AD_PRODUCT_GROUPS, PRODUCT_COMPONENT_VERSION and DBMS_UTILITY.PORT_STRING: run after V10_2a / c / d. |
| **10.2** Database & infrastructure footprint (Parameter · Value, 12 rows) | `F10.2_Database_and_Infrastructure.sql` | 1.1 (comment-only) | Not run. Reads NLS_DATABASE_PARAMETERS: run after V10_2b and V10_1. |
| **10.3** Fusion pod posture (Parameter · Value, 4 rows) | `F10.3_Fusion_Pod_Posture.sql` | 1.1 (comment-only) | Not run. Run after V10_1. |
| Column check (generated) | `../00_Verify_First/V10_0_Columns_Check_Section_10.sql` | 1.0 | Not run: **run first**. 14 objects / 56 columns, plus a candidate block for the EBS-only objects. |
| Code values (pre-flight) | `../00_Verify_First/V10_1_Code_Values_Section_10.sql` | 1.0 | Not run. Same Section 10 block as F10.2 / F10.3. |
| Read tests, one per risky source | `../00_Verify_First/V10_2a` … `V10_2f` | 1.0 | Not run. **An error is a valid result**: send it. |

**One population.** The "Section 10 block v1.0" (ESS load and span, languages, default time zone, sandboxes, and the printed texts) is byte-identical in F10.2, F10.3 and V10_1: md5 of the block `8105f194…`. If a rule changes, change all three. F10.1 shares no population with them and carries only the shared scope block v3.1.

## Run order

No dates are needed: the load rows use the last 90 days from the run moment, and everything else is a snapshot. Leave the ledger and BU blank (Section 10 is pod-wide; the binds do not change anything).

1. **V10_0.**
   - Every object row should say ALL OK.
   - Rows 1, 2 and 9 (AD_PRODUCT_GROUPS, PRODUCT_COMPONENT_VERSION, NLS_DATABASE_PARAMETERS) may say NOT VISIBLE. The dictionary is blind to some readable objects (ESS, R016 / R034), so their read tests decide.
   - The candidate block (ord 50+) shows which `V_$` / `DBA_` / `AD_` / `PATCH_` / `ASK_DEPLOYED_` objects the report user can see.
2. **The read tests, each as its own data set:**

   | Test | Reads | Decides |
   |---|---|---|
   | V10_2a | AD_PRODUCT_GROUPS | F10.1 rows 1 and 9 |
   | V10_2b | NLS_DATABASE_PARAMETERS | F10.2 rows 8 and 9 |
   | V10_2c | PRODUCT_COMPONENT_VERSION | F10.1 row 5 |
   | V10_2d | DBMS_UTILITY.PORT_STRING | F10.1 row 7 |
   | V10_2e | V$OPTION | F10.2 row 6 |
   | V10_2f | the ten catalog views behind the "Oracle-managed" rows; expected to fail | proves those rows' fixed texts |

3. **V10_1**, once V10_0 shows ALL OK for its objects.
4. **F10.3**, then **F10.2** (if V10_2b passed), then **F10.1** (if V10_2a, V10_2c and V10_2d passed).

If a read test fails, send the result before running the F query that needs it. v1.1 then replaces that source with a fixed text.

## 10.1 EBS → Fusion mapping

| # | EBS row (30-Sep report, Vision value) | Fusion row | Fusion source / value |
|---|---|---|---|
| 1 | EBS Release: Oracle E-Business Suite 12.2.14 (`FND_PRODUCT_GROUPS.RELEASE_NAME`) | **Fusion Release** | `AD_PRODUCT_GROUPS.RELEASE_NAME`, latest row, as "Oracle Fusion Cloud Applications <release>". Not in Oracle's table docs; a 2022 Fusion blog reads it (V10_2a). Manual cross-check: Settings and Actions > About This Application. |
| 2 | AD Patch Level: C.16 (`AD_TRACKABLE_ENTITIES` ad) | AD Patch Level | Fixed: "Not applicable in Fusion SaaS: Oracle applies the quarterly updates and maintenance patches; there is no customer-run AD patching." |
| 3 | TXK Codelevel: C.16 | TXK Codelevel | Fixed: "Not applicable in Fusion SaaS: Oracle manages the technology stack; there is no TXK code level." |
| 4 | Technology Stack (agent placeholder) | Technology Stack | Fixed: "Oracle-managed (SaaS): not visible to customers." |
| 5 | Database Version: Oracle Database 19c (19.24) (`V$INSTANCE`, then `PRODUCT_COMPONENT_VERSION`) | Database Version | `PRODUCT_COMPONENT_VERSION` (PUBLIC by default): the stored product name plus the first two parts of VERSION_FULL, printed as "<product name> (<major>.<release update>)". The product name already carries the "19c" letter, so the agent's letter map is not needed. |
| 6 | Application Tier OS (placeholder) | Application Tier OS | Fixed: "Oracle-managed (SaaS): not visible to customers." |
| 7 | Database Tier OS: Linux x86 64-bit, platform family (`V$DATABASE.PLATFORM_NAME`) | Database Tier OS | `DBMS_UTILITY.PORT_STRING` (PUBLIC by default; V$DATABASE needs a catalog privilege, V10_2f), platform family only, as EBS. |
| 8 | Outstanding Critical Patches (placeholder) | Outstanding Critical Patches | Fixed: "Oracle-managed (SaaS): Oracle applies critical patches; not determinable from SQL." |
| 9 | Last Full Patching Cycle: June 2025, a proxy (latest `AD_ADOP_SESSION_PATCHES.END_DATE`) | Last Full Patching Cycle | The month `AD_PRODUCT_GROUPS` was last updated, also a proxy. **Check it against the pod's quarterly-update calendar (C85)** before it goes in the report. |
| 10 | Recommended Fusion Pre-Migration Patch: "Apply latest AD-TXK Delta release update before data extraction" | **Recommended Pre-Migration Update** | Fixed (user decision, wording note above): release and patch parity of source and target pods. |

## 10.2 EBS → Fusion mapping

| # | EBS row (Vision value) | Fusion row | Fusion source / value |
|---|---|---|---|
| 1 | Total Database Size: 213.2 GB (`DBA_DATA_FILES` + `DBA_TEMP_FILES`) | Total Database Size | Fixed: "Oracle-managed (SaaS): database size is not visible to customers." V10_2f is the proof. Every Fusion object is visible to the report user only as a FUSION view (R016 / R031), so not even a statistics-based estimate exists. |
| 2 | APPS Schema Size: 1.4 GB (`DBA_SEGMENTS`, owner APPS) | **FUSION Schema Size** | Fixed: "Oracle-managed (SaaS): schema size is not visible to customers." The Fusion application schema is FUSION. |
| 3 | Annual Data Growth Rate (placeholder) | Annual Data Growth Rate | Fixed: the EBS text, plus "database size is not visible in Fusion SaaS". |
| 4 | RAC Configuration: single instance (`V$PARAMETER`, `GV$INSTANCE`) | RAC Configuration | Fixed: "Oracle-managed (SaaS): not visible to customers." |
| 5 | Data Guard Setup: none (`V$DATABASE`, `V$DATAGUARD_CONFIG`) | Data Guard Setup | Fixed, as row 4. |
| 6 | Available DB options / detected pack usage (`V$OPTION`, `DBA_FEATURE_USAGE_STATISTICS`) | Available DB options / detected pack usage | Fixed in v1.0. If V10_2e shows V$OPTION readable, v1.1 lists the options as EBS does. |
| 7 | Custom Tablespaces: none (XX* / *CUSTOM* in `DBA_TABLESPACES`) | Custom Tablespaces | Fixed: "None: customers cannot create tablespaces or other database objects in Fusion SaaS." |
| 8 | Database Character Set: AL32UTF8 (`NLS_DATABASE_PARAMETERS`) | Database Character Set | `NLS_DATABASE_PARAMETERS.NLS_CHARACTERSET` (PUBLIC by default; V10_2b). |
| 9 | NLS Language: American English (AMERICAN_AMERICA.AL32UTF8) | NLS Language | The same three parameters, in the EBS format. The name comes from `FND_LANGUAGES_TL.DESCRIPTION` (matched on `FND_LANGUAGES_B.NLS_LANGUAGE`) instead of the agent's fixed name list; an unmatched language falls back to its own name in initial capitals, as the agent does. |
| 10 | Backup Strategy: no RMAN history visible (`V$RMAN_BACKUP_JOB_DETAILS`) | Backup Strategy | Fixed: "Oracle-managed (SaaS): Oracle runs the backups; backup history is not visible to customers." |
| 11 | Average Concurrent Manager Load (Peak): 283 requests in peak hour (10:00, last 90d) | **Average Scheduled Process Load (Peak)** | ESS runs per hour of day (rules below), printed as "<runs> runs in peak hour (<hh>:00 UTC, about <runs per day> a day; ESS history <first run> to <last run>)". |
| 12 | Average Concurrent Manager Load (Off-Peak): 176 requests in quietest active hour (21:00, last 90d) | **Average Scheduled Process Load (Off-Peak)** | The quietest hour that has any run, same format. |

## 10.3 Fusion pod posture (Fusion only)

| # | Row | Source | Why it is useful for Fusion → Fusion |
|---|---|---|---|
| 1 | Installed Languages | `FND_LANGUAGES_B` with INSTALLED_FLAG B (base) or I (installed), named from `FND_LANGUAGES_TL` (session language, else US; `FND_LANGUAGES_VL` keeps the session language only) | The target pod needs the same languages for translated setup data, lookups and reports to move. |
| 2 | Default User Time Zone | Site value of profile **FND_TIMEZONE** ("Default User Time Zone"; Setup and Maintenance, Manage Administrator Profile Values) in `FND_PROFILE_OPTION_VALUES`, named from `FND_TIMEZONES_TL` | Every user starts from it; the target should match so dates and times read the same. |
| 3 | Sandboxes Not Yet Published | `ADF_SB_SANDBOXES`: never published (no PUBLISH_DATE) and not destroyed (deleted), with the published count | Configuration Set Migration needs sandbox configurations complete and published: "Make sure that all Page Composer configurations made in sandboxes are complete and published." On the target: "delete or publish any sandboxes in the target environment that have Application Composer enabled before you begin your migration." R017: 4 not yet published, 36 published. |
| 4 | Scheduled Process History Retained | First and last ESS submission, requests and runs | Every run count in Sections 5, 8 and 10 is bounded by it (from 2026-09-21 on this pod, R035). |

**Considered and left out:**
- **Ledger base currencies:** already in 2.1 (the F2.1 Currency column).
- **Environment type** (production / test): no SQL source was found. V10_0's candidate block shows whether `ASK_DEPLOYED_*` (pod URLs) is visible.
- **Site regional formats** (territory, currency, date format profiles): low value for the migration. They can be added like row 2.

## The load rows (F10.2 rows 11 / 12)

| Rule | Detail |
|---|---|
| Population | Every ESS request (`ESS_REQUEST_HISTORY`). ENTERPRISE_ID 1 and DELETED N on all rows (R035 H), so nothing is filtered. |
| A run | A request with PROCESSSTART: it started, whatever the outcome. This matches Section 8's runs and the EBS ACTUAL_START_DATE. |
| Window | PROCESSSTART on or after SYSDATE − 90 (EBS: SYSDATE − 90), from the run moment, not the discovery window |
| Peak / off-peak | Runs grouped by the hour of PROCESSSTART. Peak = the busiest hour; off-peak = the quietest hour with any run. A tie goes to the later hour (EBS `KEEP (DENSE_RANK LAST …)`). |
| The count | The total in that hour of day over the covered span, as EBS prints it. Fusion adds "about N a day" (the total divided by the days covered), so pods with different retained history compare. |
| Span | "last 90 days" when the history covers them. Otherwise "ESS history <first run> to <last run>". This pod: from 2026-09-21. |
| Clock | Hours are read as stored and labelled UTC. **V10_1 A2 proves the clock** from the stored type and the database clock (C80). |
| Differences from EBS | EBS also counts requests that never started, at their request date (`NVL(ACTUAL_START_DATE, REQUEST_DATE)`). In ESS these are mostly schedule parents (REQUESTTYPE 2), which never run themselves, so F10.2 leaves them out. V10_1 A3 / A4 print both rules side by side; R035 had 188 never-started requests out of 29,661. |

## Sources (Oracle documentation, fetched 2026-10-06 / 07)

- **FND_LANGUAGES_B** (Applications Common 26A, `fndlanguagesb-16252.html`): PK LANGUAGE_CODE; NLS_LANGUAGE, NLS_TERRITORY, INSTALLED_FLAG (not null), ACTIVATION_STATUS ("tracks the status of languages in the process of activation").
- **FND_LANGUAGES_TL** (`fndlanguagestl-30681.html`): PK LANGUAGE_CODE + LANGUAGE; DESCRIPTION. **FND_LANGUAGES_VL** (`fndlanguagesvl-6489.html`) filters `T.LANGUAGE = USERENV('LANG')`.
- **FND_PROFILE_OPTIONS_B** (`fndprofileoptionsb-12469.html`): PK APPLICATION_ID + PROFILE_OPTION_ID + ENTERPRISE_ID; PROFILE_OPTION_NAME; seed-set unique keys.
- **FND_PROFILE_OPTION_VALUES** (`fndprofileoptionvalues-3272.html`): PK APPLICATION_ID + PROFILE_OPTION_ID + LEVEL_NAME + LEVEL_VALUE + ENTERPRISE_ID; PROFILE_OPTION_VALUE. The LEVEL_NAME codes are not documented: V10_1 C3 prints them.
- **FND_TIMEZONES_B / _TL** (`fndtimezonesb-31971.html`, `fndtimezonestl-30951.html`): TIMEZONE_CODE, ENABLED_FLAG; the TL table has NAME.
- **FND_TIMEZONE** profile: "Default User Time Zone", set at Site level in Manage Administrator Profile Values (Oracle Customer Connect / HR regional-preferences docs).
- **PATCH_RUN / PATCH_ARTIFACT** (`patchrun-6525.html`, owner APM): base file vs patch file, chosen resolution. This is customization-merge patching, **not** the update level, so it is not used; V10_0 lists it as a candidate.
- **AD_PRODUCT_GROUPS:** no Oracle table page (the Applications Common table of contents has no `AD_` table). Source: fusionhcmknowledgebase.com (2022), `select RELEASE_NAME, LAST_UPDATE_DATE from AD_PRODUCT_GROUPS`. V10_2a decides.
- **Oracle Database 19c reference:**
  - PRODUCT_COMPONENT_VERSION has PRODUCT, VERSION, VERSION_FULL ("displayed only for the database component") and STATUS, and is granted to PUBLIC.
  - NLS_DATABASE_PARAMETERS has PARAMETER and VALUE.
  - DBMS_UTILITY.PORT_STRING "returns a string that identifies the operating system" (pragma WNDS / RNDS, so it can be called from SQL).
  - V$VERSION and DBMS_UTILITY are granted to PUBLIC by default (seanstuber.com, 2021).

## Checks (RUN_LOG C78–C86)

| Check | What holds |
|---|---|
| C78 | V10_0 ord 0 reads `V10_0 v1.0 (Section 10 block v1.0) / 14 objects / 56 columns needed`. Ord 1–14 say ALL OK; rows 1 / 2 / 9 may say NOT VISIBLE (read tests decide). |
| C79 | The read tests V10_2a–f give one verdict per source (readable / error). An error changes the F query (v1.1) and is not a failure of the pod. |
| C80 | V10_1 A2 verdict OK: ESS times follow the database clock, which is UTC. Otherwise the hour label changes. |
| C81 | F10.2 rows 11 / 12 = V10_1 A1 (same block, same run). A4 says whether the EBS rule would pick other hours. |
| C82 | V10_1 B0 rows = codes, and B1 shows INSTALLED_FLAG B / I in use (the EBS codes). |
| C83 | V10_1 C2 shows exactly one FND_TIMEZONE site value, and C3 shows SITE is the stored LEVEL_NAME. |
| C84 | V10_1 D1 counted = never published and not destroyed: 4 / 36 as R017, unless sandboxes changed since 2026-10-05. |
| C85 | AD_PRODUCT_GROUPS.LAST_UPDATE_DATE (V10_2a) is plausible as the last quarterly update. If it is not, F10.1 row 9 becomes a fixed text. |
| C86 | F10.3 row 4 history start = the F8.2c ESS history start = 2026-09-21 (same pod). |

## Expected values on this pod (not targets)

| Output | Expected |
|---|---|
| F10.3 row 3 | "4 not yet published (36 published)" (R017, 2026-10-05) |
| F10.3 row 4 | from 2026-09-21; requests and runs above R035's 29,661 / 29,473 (ESS grows every day) |
| F10.2 rows 11 / 12 | ESS history 2026-09-21 to the run day; hours and counts from V10_1 A3 |
| F10.2 row 8 | AL32UTF8, if V10_2b is readable |
| Everything else | first measured by R039 onwards |

## Captions for the report (Fusion wording of EBS Appendix A, row 10)

- **Scheduled-process load** (10.2, last two rows) counts scheduled-process (ESS) runs by hour of day, in UTC, over the last 90 days of request history on this pod, not the discovery window.
  - Fusion keeps ESS history only for a short time (from 2026-09-21 on this pod), so the rows state the span they cover and a per-day figure.
  - Requests that never started (schedule parents) are not counted.
- **Oracle-managed (SaaS)** marks a row about a tier Oracle runs and customers cannot see: database size, RAC, Data Guard, backups, operating systems and patching. The report user cannot read the database catalog views EBS uses (V10_2f).
- **10.3** is not in the EBS report. It lists what the target pod must match or finish before a Fusion → Fusion migration: the languages, the default time zone, unpublished sandboxes, and how much scheduled-process history exists.
- **Release parity:** Oracle requires the source and target pods to be on the same release and patch level for Configuration Set Migration and setup data export / import. Compare 10.1 row 1 on both pods.

## Known limits

- **The release row depends on an undocumented object** (AD_PRODUCT_GROUPS). If V10_2a fails, row 1 points to About This Application, a manual step.
- **No patch history** is readable in SaaS. Row 9 is at best a proxy (C85).
- **ESS history is short:** 15–16 days on this pod. Run the discovery soon after a refresh, or on production, to see more.
- **No SQL source for the environment type** (production / test) or the next scheduled update.
