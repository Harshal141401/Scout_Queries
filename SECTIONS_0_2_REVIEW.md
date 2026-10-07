# Sections 0, 1 and 2: Fusion query review and Phase 2 rebuild

**Baseline report:** `EBS_Discovery_Report_30_September_26.pdf`, the latest run (September 30, 2026).

Sections 0–2 are unchanged from the Sep 15 run:

| Section | Figures |
|---|---|
| Executive summary | 37 users who transacted · 1 ledger · 6 legal entities · 4 operating units · 16 active modules |
| 1.1 | 16 modules, all Active |
| 1.2 | none dormant |
| 2.1 | Primary: 6 LEs / 4 OUs / 38 inventory orgs; Secondary: 6 / NA / NA; calendar type "Calendar month (12)" |
| 2.2 | 5 segments: 24 / 100 / 526 / 161 / 33 values; 844 enabled values in the workbook |

**Every pod run and validation is recorded in `../06_Run_Results/RUN_LOG.md`**: run index, outputs word for word, query versions, and the reconciliation board. Check it before comparing two numbers.

**Status:** built and statically checked. **First pod run, 2026-09-30 (R001, shared block v1):** `F0_Executive_Summary.sql` ran with no error and returned:

| Card | Value |
|---|---|
| Users who transacted | 37 |
| Ledgers | 1 |
| Legal Entities | 1 |
| Business Units | 3 |
| Active Modules | 12 |

- **What the run proves:** every table and column in the shared scope and activity block exists and is readable on that pod. That includes the two `FA_TRANSACTION_HEADERS` columns the docs could not confirm, `EGP_STRUCTURES_B.PK2_VALUE`, `CST_COST_DISTRIBUTIONS`, `FLA_LEASES_ALL` and `FUN_TRX_HEADERS`.
- **What it does not prove:** that the numbers are right. Run `00_Verify_First/V0_3_Explain_Executive_Summary.sql` with the **same parameters** to list the exact ledger, legal entity, BUs, modules and users behind each card, and check them against the Fusion UI.
- The parameters used for this run (ledger, dates) were not recorded; V0_3 block A prints them.
- The other files have not been run yet.
- Static checks: parentheses and quotes balanced, no `DISTINCT`, no `;`, no bare reserved-word aliases, CASE/END balanced, UNION column counts match.
- Numbers only count once V0_1 and V0_2 come back clean and the reconciliations at the bottom of this document hold.

---

## 1. Are the existing Fusion queries correct? Verdict per report item

| Report item | Existing Fusion query (`02_SQL_Existing/`) | Verdict | Why |
|---|---|---|---|
| Exec: Users who transacted | `01_Exec_Executive_Summary.sql` "Active Users" | **Wrong metric** | Counts every active `PER_USERS` row. The report counts people who created transactions in the period, de-duplicated across modules. These are different numbers. |
| Exec: Ledgers | same, "Ledgers" | **Wrong scope** | `COUNT(*) FROM gl_ledgers` counts ledger **sets** too (`OBJECT_TYPE_CODE` 'S') and ignores the ledger parameter. The dev pod gave 108; the report shows 1. |
| Exec: Legal Entities | — | **Missing** | The existing query has no legal-entity card. |
| Exec: Operating Units | same, "Operating Units" | **Wrong scope** | Counts every BU on the pod (156 on the dev pod), with no ledger scope and no status filter. |
| Exec: Active Modules | — | **Missing** | Replaced by "BPM workflows", an unfiltered ESS count (171,044) and a **hard-coded Integrations = 97**. None of these is in the report. |
| 1.1 Active modules | `02_S1.1_Active_Module_Inventory.sql` | **Partly wrong** | See the breakdown below this table. |
| 1.2 No activity | `03_S1.2_Dormant_Modules.sql` | **Different definition** | "No activity in 12 months" across 9 modules. The report uses "no activity in the discovery period" across the same 16 as 1.1. |
| 2.1 Ledger / LE / OU map | `04_S2.1_Ledger_Entities.sql` | **Wrong shape and a join risk** | See the breakdown below this table. |
| 2.1 workbook | — | **Missing** | No query existed. |
| 2.2 COA structure | `05_S2.2_Chart_of_Accounts.sql` | **Partly right** | The enabled-value count is the right idea. Problems:<br>• no Segment column (SEGMENT1…)<br>• no **Qualifier**<br>• per ledger, not per chart<br>• mandatory bind<br>• the local copy uses the reserved word `Values` as an alias<br>• counts through `FND_FLEX_VALUES_VL`, whose Fusion definition could not be confirmed |
| 2.2 workbook (values, CVR, BSV → LE) | — | **Missing** | No query existed. |

**1.1 Active modules: what is wrong in the existing query**
- It covers **10 of 16 modules**. Missing: Cost Management, Projects, BOM, Shipping, Expenses, Lease (Property Manager), Intercompany. It adds a Tax row the report doesn't have.
- The window is fixed at 1 Jul – 30 Sep 2025.
- Assets and Inventory show **Active from the stock of assets and items, not from transactions**, so they read Active even with zero activity.
- Purchasing is **pod-wide**, with no ledger scope.
- Assets users come from `FA_BOOKS.LAST_UPDATE_DATE`, not asset transactions.

**2.1 Ledger / LE / OU map: what is wrong in the existing query**
- It returns one row per BU, not per ledger.
- It has no ledger type, calendar, calendar type or accounting method.
- It joins through `XLE_LE_OU_LEDGER_V`. **On EBS that view is an LE × OU cross product** (the 234-row bug); V0_2 block C tests the Fusion behaviour.
- It requires the ledger bind.

**Conclusion:** none of the existing section 0–2 queries can be sent as the report's query. All seven report items above have been rebuilt below.

## 2. What was built (`02_SQL_Phase2/`)

| File | Report item | Replaces | Output |
|---|---|---|---|
| `00_Verify_First/V0_1_Verify_Objects_Columns_Sections_0_2.sql` | (run first) | — | 150 table.column checks (OK / MISSING), a column dump of the objects the docs could not confirm, and object visibility |
| `00_Verify_First/V0_2_Verify_Data_Rules_Sections_0_2.sql` | (run second) | — | 12 data-rule checks (blocks A–J), each with a verdict |
| `00_Verify_First/V0_3_Explain_Executive_Summary.sql` | explains F0 | — | Every ledger, legal entity, business unit (plus the BUs excluded as inactive), module and user behind the 5 cards, and totals that must equal F0. Shares F0's code block byte-for-byte. |
| `00_Executive_Summary/F0_Executive_Summary.sql` | Exec cards 1–5 | existing 01 | 5 rows, the **same metrics in the same order as the EBS report, in Fusion terms**: Users who transacted · Ledgers · Legal Entities · **Business Units** (the EBS "Operating Units" metric) · Active Modules |
| `01_Module_Footprint_and_Usage/F1_Active_Module_Inventory.sql` | 1.1 | existing 02 | **Active modules only**, the EBS agent's rule. Fields: Module · Status ('Active') · Users (period). **No module name or code is typed in the query** (decided 2026-09-30): each source table's owning application short name comes from `FND_TABLES.APPLICATION_SHORT_NAME`, and the application name from `FND_APPLICATION_VL`, matched on short name. Fusion `FND_TABLES` has no `APPLICATION_ID`: that gave ORA-00904 on the pod on 2026-10-01. **Run `00_Verify_First/V0_0_Registry_Columns_Check.sql` first**; both of its first two rows must say ALL OK. An unregistered table shows as "Not registered: TABLE". Row count = F0 Active Modules. The table → application mapping is printed by V0_3 block G. |
| `01_Module_Footprint_and_Usage/F1.2_Modules_No_Activity.sql` | 1.2 | existing 03 | The modules with no activity in the period. Fields: Module · Status ('Dormant', the EBS wording). F1 + F1.2 = the number of distinct owning applications of the 17 source tables (17 if all differ; V0_3 block G shows it). Zero rows means the report prints "No dormant modules detected". Same code block and module list as F1. |
| `02_Enterprise_Structures_and_COA/F2.1_Ledger_LE_BU_Map.sql` | 2.1 table | existing 04 | One row per ledger (primary, then its secondary/reporting ledgers), with the EBS columns. BUs and Inv Orgs read **NA** on non-primary ledgers. |
| `02_Enterprise_Structures_and_COA/F2.1_Org_Structure_Detail.sql` | 2.1 workbook (WB1) | new | Ledger → LE → BU → inventory org, plus BUs without orgs and LEs without BUs; BSVs and reporting currency beside their entity |
| `02_Enterprise_Structures_and_COA/F2.2_COA_Structure.sql` | 2.2 table | existing 05 | One row per chart × segment: Ledgers · COA · Segment · Name · Qualifier · Values · Size |
| `02_Enterprise_Structures_and_COA/F2.2_COA_Segment_Values_Detail.sql` | 2.2 workbook (WB2), values sheet | new | One row per enabled value, with value set, parent value, description, account type, allow posting / budgeting, summary flag and dates |
| `02_Enterprise_Structures_and_COA/F2.2_BSV_Legal_Entity_Detail.sql` | 2.2 workbook (WB2), BSV → LE sheet | new | Ledger × LE × balancing value |
| — | 2.2 workbook, **cross-validation rules sheet** | — | **Deferred on purpose.** Fusion CVRs are `FND_KF_CROSS_VAL_RULES` with XML condition/validation filters, not EBS include/exclude ranges. V0_1 block B dumps the table's real columns; the sheet gets written against that dump. |

**Parameters (every file, all optional):**
- `:p_ledger_id`, `:p_bu_id`, `:p_custom_prefix`: the EBS three, with OU → BU.
- `:p_from_date` and `:p_to_date` (`YYYY-MM-DD`): new. **No fixed dates anywhere.**
- Blank dates mean the last 90 days to today, the same default as the Scout agent.
- Blank ledger means the whole pod.

## 3. Fusion facts behind the rebuild (checked against Oracle's Tables and Views guides, 2026-09-30)

| Fact | Consequence |
|---|---|
| `FUN_ALL_BUSINESS_UNITS_V.PRIMARY_LEDGER_ID` and `LEGAL_ENTITY_ID` are `ORG_INFORMATION3/2` **strings**; the view is date-effective and has `STATUS`. | Compared as strings. Active BU = `STATUS 'A'`; V0_2 block A prints the real values. |
| `GL_LEDGER_LE_V` exists in Fusion: ledger × LE × registration location. | Legal Entities is counted from it, grouped. `XLE_LE_OU_LEDGER_V` is avoided. |
| `INV_ORGANIZATION_DEFINITIONS_V` returns only INV-classified orgs; `SET_OF_BOOKS_ID` is derived from the org's BU primary ledger. | Oracle's own org → ledger rule. V0_2 block D compares it with the draft's profit-centre rule. |
| `GL_LEDGERS.LEDGER_CATEGORY_CODE` = PRIMARY / SECONDARY / ALC; `OBJECT_TYPE_CODE` = ledger or ledger set. | Same meaning as EBS; the rule `OBJECT_TYPE_CODE = 'L'` carries over. |
| Every Fusion `CREATED_BY` is the **user name**, `VARCHAR2(64)`; `CREATION_DATE` is `TIMESTAMP`. | The users count works exactly as on EBS, including service accounts. |
| `DOO_HEADERS_ALL.ORG_ID` is `NUMBER(18)`, "the business unit". | The draft's "ORG_ID is VARCHAR2" note was wrong. |
| `PO_HEADERS_ALL` has `PRC_BU_ID`, `REQ_BU_ID` and `BILLTO_BU_ID`. | A PO is in scope if **any** of the three is a ledger BU; a procurement BU often has no ledger. |
| `CST_COST_DISTRIBUTIONS` carries `LEDGER_ID` and `GL_DATE`. | Cost Management is scoped by ledger. |
| **`EGP_STRUCTURES_B` has no `ORGANIZATION_ID`**; the org is `PK2_VALUE`. | The BOM row joins on `PK2_VALUE`. V0_2 block G proves this before the row can be trusted. |
| `EXM_EXPENSE_REPORTS`, `PJC_EXP_ITEMS_ALL`, `PJF_PROJECTS_ALL_B` and `FLA_LEASES_ALL` all have `ORG_ID` = BU. | Expenses, Projects and Lease Accounting are BU-scoped (EBS parity). |
| `FND_ID_FLEX_SEGMENTS_VL` is a compatibility view over `FND_KF_*` **structure instances**. `ID_FLEX_NUM` = `GL_LEDGERS.CHART_OF_ACCOUNTS_ID`; `SEGMENT_NAME` is the **code**, and the display name is `FORM_LEFT_PROMPT`. | Name = `COALESCE(FORM_LEFT_PROMPT, SEGMENT_NAME)`. |
| Values live in `FND_VS_VALUES_B`. Qualifiers are **`FLEX_VALUE_ATTRIBUTE1..20`**, and `FND_VS_KF_VALUE_ATTRS` says which code is in which column. | **The EBS `COMPILED_VALUE_ATTRIBUTES` token parsing must not be ported.** The values sheet unpivots the 20 columns instead. |
| `GL_LEDGER_LE_BSV_SPECIFIC_V` = ledger × LE × balancing value. | BSV → LE sheet and WB1 BSV column. |
| Doc pages **not retrievable**: `FA_TRANSACTION_HEADERS`, `XLA_AE_HEADERS`, `FND_SEGMENT_ATTRIBUTE_VALUES` columns, `FND_KF_CROSS_VAL_RULES` columns. | V0_1 checks or dumps all of them. Nothing depending on them is trusted until V0_1 is clean. |

## 4. Deliberate differences from the EBS queries

- **Fusion terminology throughout** (decided 2026-09-30): the metrics are the EBS ones, but every label uses the Fusion term. The EBS "Operating Units" card is **"Business Units"** and counts active BUs whose primary ledger is in scope.
- **Business Group is dropped** from the 2.1 workbook. It is an HCM concept, and Fusion has one Enterprise per pod.
- **No EBS parent ranges** (PARENT_LOW / HIGH) in the values sheet. Fusion hierarchies are account trees, which are a later item (plan M5).
- **Module names come from the Fusion application registry, never typed** (decided 2026-09-30). The EBS agent types its 16 names in `module_scope.py`; the Fusion queries read them from `FND_TABLES` → `FND_APPLICATION_VL`, so the names are exactly what Fusion calls the owning application. Consequence: tables owned by different applications become separate modules (for example requisitions may sit under Self Service Procurement, separately from Purchasing), so the module count comes from the pod, not from a list of 16. The original note follows: Each maps 1:1 to the EBS row in the same position: Order Management → Order Management (DOO), Fixed Assets → Assets, Project Accounting → Project Costing, WIP → Manufacturing, BOM → Item Structures, Internet Expenses → Expenses, Property Manager → Lease Accounting.
- **Inventory is Active from material transactions, not from items on hand.** This follows the Scout agent's corrected rule (agent README, 2026-09-12). The EBS SQL pack still used items.
- **Unchanged from EBS:** Assets users use `LAST_UPDATED_BY`, and Intercompany is pod-wide with Users '-'. The Appendix A wording carries over as-is.

## 5. Run order for the consultant

1. `00_find_ledger_id.sql` (in `02_SQL_Existing/00_Executive_Summary/`) to pick the primary `LEDGER_ID`.
2. **V0_1.** Every row must read OK. Send the whole grid back, including block B.
3. **V0_2**, with `:p_ledger_id` bound. Send the grid back.
4. Only if 2 and 3 are clean: F0, F1, F2.1, F2.1 detail, F2.2, F2.2 values, F2.2 BSV. Bind `:p_ledger_id` and leave the dates blank, or set a period.

**Reconciliations that must hold.** If one fails, the query is wrong, not the pod.

| Check | Must equal |
|---|---|
| F0 "Active Modules" | the row count of F1 (same params, same day); F1 + F1.2 = distinct owning applications of the 17 source tables |
| F0 "Business Units" | F2.1 Business Units on the primary ledger row |
| F0 "Legal Entities" | F2.1 Legal Entities on the primary row, and the second number in V0_2 J |
| F0 "Ledgers" | 1 when a ledger is bound |
| Distinct Inventory Org in F2.1 detail | F2.1 Inv Orgs, and the first number in V0_2 D |
| Distinct Business Unit with BU Active = Y in F2.1 detail | F2.1 Business Units |
| Rows per segment in F2.2 values | F2.2 "Values" for that segment |

**UI cross-checks (recommended):**
- Manage Ledgers
- Manage Legal Entities
- Manage Business Units (and each BU's primary ledger)
- Manage Inventory Organizations
- Manage Chart of Accounts Structure Instances
- Manage Chart of Accounts Value Sets (value counts)

## 6. Still open

1. ~~Nothing has been run.~~ **Runs so far (see `06_Run_Results/RUN_LOG.md`):** R001 F0 (v1) 37/1/1/3/12 · R002 F1/F1.2 ORA-00904 (v2, fixed) · R003 V0_0 ALL OK · R004 F1 (v3.1) 13 active modules. **Open:** re-run F0 on v3.1 (card 5 must be 13), then F1.2, V0_3, V0_1/V0_2, F2.x.
1a. **⚠ C10, Active modules disputed (2026-10-01).** F1 shows 13 Active (R004); the functional consultant says 6 modules are live (R005). F1's rule (one row by anyone in 90 days) is a data test, not a live-module test. Run `00_Verify_First/V1_1_Module_Activity_Evidence.sql` (same params as F1) and `V1_2_Find_Offering_Enablement_Objects.sql`, and get the consultant's 6 names. **Do not report 1.1 or F0 card 5 until this closes.**
2. **Cross-validation rules sheet:** waiting for the V0_1 block B dump of `FND_KF_CROSS_VAL_RULES`.
3. **Value-attribute codes:** Account Type, Allow Posting and Allow Budgeting are matched by pattern until V0_2 block F prints the real codes.
4. **BU "active" rule:** a BU counts unless `STATUS` is 'I' / 'INACTIVE', which works for either coding. V0_2 block A shows the real values.
5. **BOM `PK2_VALUE`:** if V0_2 block G says it is not the organization, F1 row 12 must change.
6. ~~Module names~~ **decided 2026-09-30:** Fusion product names and Fusion terms everywhere (BU, not OU), with the same metrics as EBS.
