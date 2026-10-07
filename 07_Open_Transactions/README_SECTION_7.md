# Section 7: Open transactions snapshot (built 2026-10-05; v1.3 = 10 rows; checks R023-R030 all pass; F7.1 not yet run)

This is the Fusion version of the EBS report's Section 7.1. The section has two parts:
- An 8-row summary table.
- A by-business-unit workbook (WB8).

Both are ported from the EBS agent's `ebs_discover_open_transactions`, the final logic, which matches the 30-Sep-2026 report. The June draft `02_SQL_Existing/07_Open_Transactions/16_S7.1_Open_Transactions.sql` was a starting point only; the changes from it are listed below.

## Deliverables

| Report item | File | Window | Status |
|---|---|---|---|
| **7.1** Open transactions summary (10 rows: Open Item / Count / Value) | `F7.1_Open_Transactions.sql` **v1.3** | **None.** Snapshot of the run day; dates are ignored. | Not run. Expected values: C52 below |
| **WB8** `Fusion_Discovery_7_1_Open_Transactions_By_BU.xlsx` (Business Unit × 10 classes, zeros included) | `F7.1_WB_Open_Transactions_By_BU.sql` **v1.3** | None | Not run (3 BUs = 30 rows) |
| Column check | `../00_Verify_First/V7_0_Columns_Check_Section_7.sql` **v1.3** (18 objects / 88 columns) | none | ✅ R023 (v1.0), R025 (v1.2) and R029 all ALL OK. R029 cannot show its own version: V7_0 never prints its need list. The 3 columns v1.3 added are proven by R030, which reads them. |
| Status codes + sanity | `../00_Verify_First/V7_1_Code_Values_Section_7.sql` **v1.3** | none | ✅ R030 (v1.3): row 1 = **4**, no consigned stock. R024 (v1.0) and R026 (v1.2) each found a row 1 defect, both fixed. |

**Run order:** V7_0 v1.3 and V7_1 v1.3 are done (R029 / R030). **Next: F7.1 v1.3 → F7.1_WB v1.3**, with blank parameters, to compare with the expected values below. Use the same ledger / BU for F7.1 and the workbook. Blank ledger / BU = the whole pod (3 BUs, one primary ledger 300000004500337).

The open-item block is **byte-identical** in F7.1 and the workbook. For the same parameters, each class summed over the workbook's BU rows must equal that F7.1 row, for both Count and Value. If a class rule ever changes, change both files.

## The 10 classes

| # | Open item | Fusion source and rule | BU column | Value |
|---|---|---|---|---|
| 1 | Open requisitions | Approved requisitions (`DOCUMENT_STATUS = 'APPROVED'`) with at least one **approved line** (`LINE_STATUS = 'APPROVED'`) that is **on no order**: no PO (`PO_HEADER_ID`) and no transfer order (`TO_HEADER_ID`); Oracle indexes the pair as `NVL(TO_HEADER_ID, PO_HEADER_ID)`. v1.1 after R024; transfer orders v1.3 after R026. | REQ_BU_ID | — |
| 2 | Open purchase orders | STANDARD POs, not cancelled, approved (`APPROVED_FLAG = 'Y'`), DOCUMENT_STATUS not CLOSED / FINALLY CLOSED / CANCELED | procurement BU, else requisitioning BU, else bill-to BU (the first one in scope) | — |
| 3 | Open PO receipts | PO schedules with quantity received > quantity billed, not cancelled, SCHEDULE_STATUS not CLOSED / FINALLY CLOSED / CANCELED. Counted per schedule. | the PO's BU (as row 2) | — |
| 4 | Open Payables invoices | Not cancelled, PAYMENT_STATUS_FLAG N or P, every invoice type | ORG_ID | invoice amount − amount paid |
| 5 | Open prepayments | PREPAYMENT invoices, not cancelled, never applied to an invoice (no distribution points back through PREPAY_DISTRIBUTION_ID) | ORG_ID | — |
| 6 | Open sales orders | One per order (revisions collapsed, the F4.2 rule). OPEN_FLAG Y and CANCELED_FLAG not Y on that version. | ORG_ID | — |
| 7 | Open Receivables invoices | Payment schedules STATUS OP, CLASS INV, one row per transaction | transaction ORG_ID | amount due remaining |
| 8 | Open or unapplied receipts | Payment schedules STATUS OP, CLASS PMT, receipt not reversed, one row per receipt | receipt ORG_ID | size of each receipt's open amount |
| 9 | On-hand inventory (item-org) | INV_ONHAND_QUANTITIES_DETAIL: one row per (inventory org, item) whose stock layers net to more than zero in the primary unit. Consigned stock counts, as in EBS; negative pairs don't (a clean-up item; 0 on this pod). Added v1.2, as EBS v3 class 9. | the inventory org's BU | — |
| 10 | Open work orders | WIE_WORK_ORDERS_B whose status rolls up to system status **Released** or **On Hold** (WIE_WO_STATUSES_B.WO_SYSTEM_STATUS_CODE). Unreleased and Completed are not counted, as in EBS. Every work order type counts, maintenance included. Added v1.2, as EBS v3 class 10. | the inventory org's BU | — |

Values are in **entered currency**, as in EBS. Amounts in different currencies are added together; V7_1 D2 / F3 show the currency mix. A "—" Value means the row is count-only; it never means zero.

## What R025 / R026 found (V7_0 / V7_1 v1.2)

- **Row 1 counted transfer requisitions as open forever.** 1,632 of the 1,641 lines v1.2 counted belong to internal transfer requisitions. Those are filled by **transfer orders** (POR_REQUISITION_LINES_ALL.TO_HEADER_ID), never by a PO. Oracle indexes the order link as `NVL(TO_HEADER_ID, PO_HEADER_ID)`.
  - **v1.3:** a line is open only when it is on no order.
  - EBS has the same blind spot: an internal requisition filled from stock never gets a LINE_LOCATION_ID.
- **Row 9:** 4,509 item-org pairs hold stock (3,977 items in 8 of the 11 inventory orgs, 6,010 stock layers). No pair is negative or zero.
- **Row 10:** 132 work orders (Released 131 + On Hold 1). Also on the pod: Closed 2,025 · Canceled 191 · **Unreleased 12** (not counted, EBS's open decision). No Completed status and no maintenance work orders exist here.
- **Consigned stock:** Oracle's doc says a record is consigned only if OWNING_TYPE is populated, but it is populated on every row. V7_1 v1.3 I3 shows the stored OWNING_TYPE values and whether the owner is the org itself, so the caption can give a real consigned figure. **Answered by R030 (below): 0.**
- **Inventory orgs:** all 11 map to exactly one in-scope BU (0 orphans, 0 double-mapped).
- **AP cancellation** is reliable: D7 = 0 invoices look cancelled without a CANCELLED_DATE.

## What R030 found (V7_1 v1.3); R029 (V7_0) all OK

- **Row 1 = 4 requisitions** (was 1,012 under the v1.2 rule).
  - These 4 hold 6 approved lines on no order: 4 INVENTORY lines and 2 DROP SHIP lines. That is real demand still waiting for an order.
  - 1,635 lines sit on transfer orders.
  - Every line reconciles with R026: 5,558 on a PO · 1,635 on a transfer order · 6 on no order · 322 cancelled · 4 returned = 7,525.
- **The header's INTERNAL_TRANSFER_REQ_FLAG is not enough.** 3 lines on requisitions flagged N are on transfer orders. The v1.3 rule tests the order link on every line, so they are correctly not counted.
- **No consigned stock.**
  - OWNING_TYPE is **2** on all 6,010 on-hand rows, and each row's owner (OWNING_ENTITY_ID) is the org that holds it.
  - Row 9 needs no change: it counts consigned stock anyway, as EBS v3 does (physically on hand). The caption figure is 0.
  - The lookup name V7_1 tried (INV_OWNING_TYPES) returned no meaning, so the verdict rests on the owner id.
- **TO_HEADER_ID, LIFECYCLE_STATUS and OWNING_ENTITY_ID exist:** V7_1 v1.3 reads them without ORA-00904.
- **Every other block is identical to R026.**

## Rows 9 and 10 (added 2026-10-05, user request: "like the latest EBS update")

They mirror EBS v3 (`EBS to Fusion/Phase2/sql/8.1_Open_Transactions_Snapshot_v3.sql`, 2026-10-01). Vision measured 1,509 item-org pairs and 59 open work orders; those are not targets. Both rows are **count-only**: a value needs a cost source that this section has never measured.

- **Grain, on-hand:** item × inventory org, as EBS. On-hand rows are stock layers (subinventory, locator, lot, receipt), so they are summed first. Distinct items would not add up across BUs, so the workbook could not tie.
- **Business unit:** inventory rows carry an inventory org, not a BU. Each org takes its business unit from INV_ORGANIZATION_DEFINITIONS_V. Only orgs whose BU is in scope count, so a bound BU limits them too. EBS v3 does the same through the org's operating unit. V7_1 K checks that no org has no BU or two BUs.
- **Open work orders:**
  - EBS's open set is Released, On Hold, Pending Close, Failed Close and Pending Scheduling. The last three are EBS close and scheduling states with no Fusion system status, so Fusion's open set is **Released + On Hold**.
  - Fusion statuses are user-defined and roll up to a system status (lookup ORA_WIE_WO_SYSTEM_STATUS). The query tests the system status and never a status name; the June draft tested names, which depend on setup and language.
- **Decision carried over from EBS:** Unreleased work orders are not counted. V7_1 J0 prints how many there are, so the call can be made against a number.
- **Caption items V7_1 reports:**
  - net-negative on-hand pairs, which are not counted and are a cutover clean-up item
  - consigned pairs, which are counted (0 on this pod, R030)
  - stock in orgs outside the scope
  - work orders by type (maintenance vs production)
- **Not included yet** (EBS v3 has them as extra workbook sheets): a per-item on-hand list with quantity, unit and cost, and a per-work-order list with conversion columns. Fusion item cost needs its own cost-book sources checked first.

## Where Fusion differs from EBS (same metric, Fusion terms)

These were checked against Oracle's table docs and the pod's column lists:
- POR_REQUISITION_HEADERS_ALL 25C, POR_REQUISITION_LINES_ALL 25D, PO_LINE_LOCATIONS_ALL 25C.
- AP_INVOICE_DISTRIBUTIONS_ALL 25D, AR_PAYMENT_SCHEDULES_ALL 25D, AR_CASH_RECEIPTS_ALL 26A.
- R020 for PO_HEADERS_ALL and DOO_HEADERS_ALL.

The differences:
- **Requisitions:** the Fusion header has no AUTHORIZATION_STATUS and no ORG_ID. Approval is DOCUMENT_STATUS, and the BU is REQ_BU_ID. The header's PRC_BU_ID is only the BU of an emergency PO number.
- **Purchase orders:** the Fusion header has no CLOSED_CODE or AUTHORIZATION_STATUS. Approval is APPROVED_FLAG and closure is DOCUMENT_STATUS. Fusion has **no blanket releases** (EBS adds PO_RELEASES_ALL). An agreement raises standard POs, and those are counted.
- **PO schedules:** no CLOSED_CODE. Closure is SCHEDULE_STATUS ("applicable only to SPO"), and closed dates are kept in separate columns.
- **Status spelling:** a status stored with `_` instead of a space is treated the same. V7_1 lists every stored status with whether F7.1 counts it.
- **Sales orders:** Fusion keeps every revision as a header row (11,703 rows = 6,988 orders, R021), so orders are counted once.
- **Receipts:** the size is taken per receipt, then added. The EBS agent takes the size of each OU's total, which is the same unless receipts of opposite sign net off.

## What the checks found (R023 / R024) and what changed (v1.1)

- **Requisition lines never carry LINE_LOCATION_ID on this pod.** All 7,525 live lines of approved requisitions have it empty, including the 5,558 that are already on a PO. The PO link is PO_HEADER_ID, the column F4.1 uses. v1.0's rule would have counted almost every approved requisition as open. **v1.1:** "not yet on a PO" = PO_HEADER_ID empty.
- **Fusion records cancellation in status columns, not CANCEL_FLAG.**
  - 322 requisition lines with LINE_STATUS CANCELED have no CANCEL_FLAG.
  - All 260 cancelled STANDARD POs (DOCUMENT_STATUS CANCELED) have CANCEL_FLAG empty.
  - **v1.1:** a line counts only when LINE_STATUS = 'APPROVED', which also leaves out the 4 RETURNED lines, mirroring EBS, where a returned requisition is not APPROVED. Schedules also leave out CANCELED.
  - The same flaw was in **F4.1 (row 2) and F6.1 (chart 2)**, now fixed as F4.1 v1.3 and F6.1 v1.2 (C53).
- **Rows 2, 3, 6 and 8 already classified correctly:**
  - POs: OPEN / CLOSED FOR RECEIVING / CLOSED FOR INVOICING / ON HOLD counted; CLOSED / CANCELED / INCOMPLETE / REJECTED / PENDING APPROVAL not.
  - Schedules: CLOSED FOR RECEIVING and OPEN counted; CLOSED not.
  - Orders: CLOSED not counted.
  - Receipts: UNAPP, not reversed, counted.
- **Scope:** no document is lost to the BU scope (0 in every table). 3 BUs, all on one primary ledger.

**Expected F7.1 v1.3 values with blank parameters (C52; final after R030):**

| Row | Count | Value |
|---|---|---|
| Open requisitions | 4 (6 lines on no order) | — |
| Open purchase orders | 864 | — |
| Open PO receipts | 213 | — |
| Open Payables invoices | 628 | 22,349,328.67 (all USD) |
| Open prepayments | 0 (the pod has no prepayment invoices) | — |
| Open sales orders | 6,972 | — |
| Open Receivables invoices | 642 | 25,157,042.57 (incl. 5 EUR invoices, 12,427.75 EUR) |
| Open or unapplied receipts | 10 (5 have no open amount left) | 33,636.61 (R026 F4) |
| On-hand inventory (item-org) | 4,509 | — |
| Open work orders | 132 (+ 12 Unreleased not counted) | — |

**Things to state under the table (pod facts):**
- **Open sales orders are 99.8% of all orders** (6,972 of 6,988; only 16 ever closed). That includes 1,077 drafts or approval-pending orders that were never submitted, and 5,891 submitted orders this pod has never closed. Splitting the 5,891 into "lines still to ship" and "shipped and billed but never closed" needs fulfillment-line status. That is outside the EBS metric; it is offered as a follow-up check.
- **Receivables value** adds 5 EUR invoices to USD amounts (0.05% of the value), as entered.
- **Open or unapplied receipts:** 5 of the 10 have no amount left; they are counted because their schedule is still open, which is the EBS rule.

## Logic changes from the June draft (16_S7.1)

- **Rows:** 16 → the 8 EBS classes.
  - Dropped (not in the EBS report): invoices on hold, open credit memos, blanket releases, backorders, pending material transactions, on-hand, open WIP jobs, FA mass additions, unposted journals.
  - Added: **Open PO receipts**.
- **As-of date:** the fixed 05-May-2026 date is gone. This is a run-day snapshot.
- **AP:** the draft counted STANDARD / CREDIT / MIXED only. It now counts every type, as EBS does.
- **AR:** the draft's COMPLETE_FLAG and transaction-date filters are removed, as in EBS.
- **Receipts:**
  - Draft: application rows with STATUS UNAPP and DISPLAY = 'Y'.
  - Now: open receipt payment schedules. This also catches on-account and unidentified cash.
  - EBS learned that the application-row method can give a false zero.
- **Requisitions:**
  - Draft: PRC_BU_ID (the emergency-PO BU) and in-process statuses.
  - Now: REQ_BU_ID and approved requisitions only.
- **POs:** approval is now tested, and the made-up value (line amounts) is removed. The row is count-only, as in EBS.
- **Sales orders:** the draft counted every revision row and valued them at summed unit prices. It now counts one row per order, count only.
- **Scope:** a single mandatory `:p_ledger_id` → the shared optional block.
- **Output:** a formatted text value with a non-ASCII dash → numeric columns.

## Captions for the report (Fusion wording of the EBS Appendix A, 7.1)

- **Value:** "—" means the row is a count, not a balance; it never means zero. Money is shown only on Open Payables invoices, Open Receivables invoices and Open or unapplied receipts, in entered currency:
  - Payables: invoice amount − amount paid.
  - Receivables: amount due remaining.
  - Receipts: the size of each receipt's open amount.
- **Open purchase orders** are approved standard purchase orders that are not closed or cancelled. Purchase agreements are not purchase orders. Fusion has no blanket releases.
- **Open PO receipts** are PO schedules where the quantity received is more than the quantity billed.
- **No date window:** "open" is a snapshot.
- **Open Receivables invoices** count open INV payment schedules, one per transaction after collapsing installments.

## Checks to reconcile (RUN_LOG C48–C57)

| Check | What must hold |
|---|---|
| C48 | V7_0: every row ALL OK, type flags '-'. ✅ R023 |
| C49 | V7_1: A0 and D0 OK. In blocks B, C, E and F5, no closed or cancelled value is marked counted, and no open value is uncounted. R024: B / C / E / F5 OK; **A failed → fixed in v1.1** (confirm with V7_1 v1.1) |
| C50 | F7.1 = F7.1_WB summed per class (same parameters), Count and Value, all 10 rows |
| C51 | V7_1 G: documents whose BU has no primary ledger (dropped even with blank parameters). 0 expected; anything else is stated under the table. ✅ R024: 0 |
| C52 | F7.1 v1.3 with blank parameters = the expected values above |
| C53 | PO cancellation read from DOCUMENT_STATUS in F4.1 v1.3 / F6.1 v1.2 (CANCEL_FLAG is never set) |
| C54 | V7_0 v1.2 ALL OK on the new objects (INV_ONHAND_QUANTITIES_DETAIL, WIE_WO_STATUSES_B, WIE_WORK_ORDERS_B, FND_LOOKUP_VALUES) |
| C55 | F7.1 rows 9 / 10 (blank parameters) = V7_1 I0 / J0 = **4,509 / 132**; in block J every Released / On Hold system status is counted Y and every other status N; K2 = 0 / 0 / 0. ✅ checks R026 |
| C56 | F7.1 v1.3 row 1 = V7_1 v1.3 A2 summary (line open only when on no order: NVL(TO_HEADER_ID, PO_HEADER_ID) empty). ✅ checks R030: **4** |
| C57 | Consigned on-hand figure from V7_1 v1.3 I3 (OWNING_TYPE value + owner), never from OWNING_TYPE being set. ✅ CLOSED R030: **0** (OWNING_TYPE 2, owner = the org itself, all 6,010 rows) |

## Known limits (stated, not hidden)

- **Open Payables value** uses invoice amount − amount paid, as in the delivered EBS report. On EBS this was measured against AP's own payment schedules (AP_PAYMENT_SCHEDULES_ALL.AMOUNT_REMAINING): the difference was 0.1% on Vision. Header arithmetic does not net applied prepayments, discounts or withholding.
- **Services schedules:** a quantity test cannot see amount-based PO schedules. That is the EBS rule; V7_1 C9 counts how many it leaves out.
- **Open sales orders** include draft orders that were never submitted, as EBS includes entered (unbooked) orders. V7_1 E0 says how many there are.
