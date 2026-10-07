# Section 9: Security & segregation of duties

**Status (2026-10-06):** checks done: V9_1 v1.0 ran as **R037**, v1.1 as **R038**. R038 found one Oracle application identity held by two accounts that can both sign in, which F9.1 v1.0 counted twice. **F9.1 v1.1** counts login names instead (Section 9 block v1.1). Not run yet; expected Users **114**, Roles **511**.

This is the Fusion version of the EBS report's Section 9:
- **9.1 Security footprint:** two numbers, Users and Roles. EBS shows Users and Responsibilities.

Ported from the EBS agent's `ebs_discover_security` (tools.py 5790), the final logic. The EBS reviewer's instruction (2026-09-10) was: "Security footprint → keep it simple. Just have number of users and responsibilities." The agent dropped its total / custom / assignments / workflow-roles / ledger-access tiles to match.

## Files

| Report item | File | Version | Status |
|---|---|---|---|
| **9.1** Security footprint (Metric · Value, 2 rows) | `F9.1_Security_Footprint.sql` | 1.1 | Not run (v1.0 was never run) |
| Code values (pre-flight) | `../00_Verify_First/V9_1_Code_Values_Section_9.sql` | 1.2 | v1.0 ran (R037), v1.1 ran (R038). v1.2 only carries block v1.1; optional (R038 fixes its values: A0 290 / 115 / 251 / 114, A5 OK). |
| Column check | none | — | Not needed. Every column F9.1 and V9_1 read was printed on the pod: PER_USERS by R006 (V3_1) and R016 (V5_0), PER_ROLES_DN by R016. `colrefs.py` lists 10 PER_USERS and 8 PER_ROLES_DN columns, all in those lists. |

**Run order:** ~~V9_1 v1.0 / v1.1~~ (R037 / R038) → **F9.1 v1.1**. There is no window; the parameters can be blank (they don't change the result).

**One population:** the "Section 9 block v1.1" is byte-identical in F9.1 v1.1 and V9_1 v1.2 (md5 of the block `1da03699…`; v1.0 was `b3dce45c…`). If a rule changes, change both.

## 9.1 EBS → Fusion mapping

| EBS row (30-Sep report, Vision) | Fusion row | Fusion rule |
|---|---|---|
| Users 3,156: FND_USER, start / end dates contain today (USER_NAME is unique in EBS, so this counts login names) | **Users** | **Login names** (PER_USERS.USERNAME, upper-cased) with at least one account that can sign in today: ACTIVE_FLAG not 'N' (Oracle: 'N' only when deleted from the identity store), SUSPENDED not 'Y' (a suspended account is "Inactive" in the Security Console), START_DATE / END_DATE contain today (blank = open). Login names with no person count (Oracle application identities, service and integration accounts), as EBS counts its seeded users. |
| Responsibilities 4,365: FND_RESPONSIBILITY, dates contain today | **Roles** | Fusion assigns roles, not responsibilities. Every PER_ROLES_DN role not flagged inactive (ACTIVE_FLAG not 'N'). PER_ROLES_DN has no start / end date. Oracle (ORA_) and client roles both count, as EBS counts seeded and custom responsibilities alike. |

**Not in 9.1, by design:**
- Custom roles are Section 5's measure; R019 counted 71.
- Role assignments, data access sets and segregation-of-duties analysis are left out. The EBS reviewer asked for two numbers.
- A blank Value means the table returned no rows to the report user, never 0.

## Decisions and checks

| Check | What V9_1 prints | Default | R037 / R038 result |
|---|---|---|---|
| C74 Suspended accounts | A1: accounts per ACTIVE_FLAG × SUSPENDED × date state × person, with "counted Y/N" | Suspended accounts are **not** counted. They cannot sign in, so they match an end-dated EBS user. If the user prefers EBS's literal rule (dates only), drop the SUSPENDED test. | **23 suspended** (18 people, 5 without a person): Users **115** without them, 138 with (on login names, v1.1: **114** / 137). Every account's dates are current, so EBS's dates-only rule would count all 290, including **152 deleted** accounts; it can't be used. Default kept, the user's call. |
| C75 Role types | B1: roles per ACTIVE_FLAG × job / abstract / duty / data / external flag × code class | **All** types count, as EBS counts every responsibility. If PER_ROLES_DN holds duty roles (the Fusion counterpart of an EBS menu, not of a responsibility), the user may prefer job + abstract + data roles only. | ✅ **Closed.** PER_ROLES_DN holds no duty or data roles: job 442, abstract 57, and 12 ORA_ roles with no type flag, all Oracle **discretionary** roles (`ORA_…_DISCRETIONARY`, R038 B3), which are assignable like job roles. Nothing to exclude. |
| C76 Grain | A0 / B0: rows against keys; A3 user names held by several accounts | One row per USER_ID / ROLE_ID is expected. A duplicate is counted once. | Roles ✅ 511 = 511 = 511; USER_ID ✅ 290 = 290. 37 user names are held by 76 accounts (R037). R038 A5: 34 are one account that can sign in plus deleted predecessors, 2 have none, and **1, the Oracle application identity `urn_opc_resource_fusion_iamoqy-dev1_knowledge-management_APPID`, is held by two accounts that can sign in**; v1.0 counted it twice. ✅ **Fixed in F9.1 v1.1**: Users counts login names (115 accounts → 114 login names). |
| C77 Oracle application identities | A4 (R038): every account that can sign in without a person, with SUSPENDED, creator and creation date | **Kept**, as EBS counts its seeded users (SYSADMIN, GUEST …) | 42 login names are Oracle application identities: no person, SUSPENDED blank (`FUSION_APPS_*_APPID` 24, `urn_opc_resource_fusion_*_APPID` 15, `FACP-…_scim_client_APPID` 2, `anonymous`), created by `anonymous` or another `_APPID`. Leaving them out gives **72** (57 people + 15 other accounts without a person). User's call. |

## Expected values on this pod (not targets)

| Output | Expected |
|---|---|
| F9.1 Roles | **511** (R037 / R038): 440 ORA_ + 22 _CUSTOM + 49 other; job 442 / abstract 57 / discretionary 12 |
| F9.1 Users | **114** (R038, F9.1 v1.1): 57 people + 57 login names without a person = 42 Oracle application identities + 5 Oracle operational accounts (`em_monitoring`, `FAAdmin`, `octo_monitor`, `rats_monitor`, `puds.pscr.anonymous.user`) + 10 accounts created on the pod by named users (service / integration accounts such as `Avalara.B2BService`, `SVC2`, and sign-ins without a person record). Not counted: 23 suspended, 152 deleted. |

## Caption for the report (Fusion wording of EBS Appendix A, row 9.1)

- **Users** is every Fusion user account that can sign in today: not deleted and not suspended. It includes Oracle's own application accounts and the client's integration accounts, which have no person (57 of 114 on this pod), as EBS counts its seeded users. Each login name counts once. It is not the number of people who transacted in the discovery window; that is the executive-summary card.
- **Roles** is every active role defined on the pod (PER_ROLES_DN), Oracle-delivered and client-defined. Fusion grants access through roles where EBS used responsibilities.
- Segregation-of-duties (SoD) conflict analysis is not performed by this read-only inventory. The footprint feeds a downstream role-design exercise.

## Changes from the June draft (`02_SQL_Existing/09_Security_and_Access/18_S9.1_Security_Footprint.sql`)

- **Rows:** Custom Roles and Data Access Sets were dropped; they are not in EBS 9.1, and custom roles are in Section 5. Responsibilities became Roles.
- **Users:** the draft counted ACTIVE_FLAG = 'Y' only. v1.0 also requires the account to be not suspended and date-effective, the EBS rule; v1.1 counts each login name once (R038).
- **Roles:** the draft counted every PER_ROLES_DN_VL row. v1.0 reads PER_ROLES_DN (proven on the pod) and leaves out inactive roles.
- **Statement rules:** no COUNT(DISTINCT), a source guard, and the shared block.
