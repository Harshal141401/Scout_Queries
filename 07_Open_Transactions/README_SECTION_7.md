# Section 7: Open transactions snapshot (built 2026-10-05; v1.4 = 10 rows, a Value on 8 of them; checks R023-R030 all pass; F7.1 v1.3 ran 2026-10-12 as R041; V7_0 v1.4 / V7_2 ran as R042 / R043, all OK; F7.1 v1.4 not run)

> **R041 (2026-10-12, v1.3):** 4 · 864 · 212 · 628 / 22,349,328.67 · 0 · 6,973 · 641 / 25,157,042.57 · 10 / 33,636.61 · 4,509 · 133. Six rows equal the expected values. Rows 3, 6, 7 and 10 differ by a net one document, 7 days after the baseline. **The seven blank values are by design**: EBS publishes money only on open AP invoices, open AR invoices and open or unapplied receipts (agent `OPEN_TXN_METRICS`, EBS v3 `has_value`, EBS report Appendix A). The EBS report prints "—" there. One option for the user: the EBS v3 SQL values those three rows in ledger currency; the agent and the report use entered currency, as F7.1 does.

> **v1.4 (2026-10-12, after R041):** Satyajit asked for the total unpaid amount on the rows that were count-only. F7.1 and the workbook now print a Value on rows 1, 2, 3, 5 and 6 as well: the amount **not yet settled by the next document** (see [The values (v1.4)](#the-values-v14-2026-10-12)). The counts do not change. Rows 9 and 10 stay count-only. Run order: **V7_0 v1.4 → V7_2 v1.0 → F7.1 v1.4 → F7.1_WB v1.4**, on the same day and with the same ledger / BU.

> **R042 / R043 / R044 (2026-10-12):** V7_0 v1.4 19 / 19 ALL OK. V7_2: all five ties OK, counts = R041, and the rules hold (C89, C90 closed, no v1.5). **F7.1 v1.4 will print:** 4 / 41,324.41 · 864 / 40,605,056.30 · 212 / 1,529,309.74 · 628 / 22,349,328.67 · 0 / 0 · 6,973 / 229,302,762.82 · 641 / 25,157,042.57 · 10 / 33,636.61 · 4,509 · 133. R044 was the GitHub folder's stale v1.3 copy of F7.1 (counts equal, values on 4 / 7 / 8 only), so **F7.1 v1.4 still has to run**, then the workbook and V7_2 v1.1 (C91).

This is the Fusion version of the EBS report's Section 7.1. The section has two parts:
- A 10-row summary table.
- A by-business-unit workbook (WB8).

Both are ported from the EBS agent's `ebs_discover_open_transactions`, the final logic, which matches the 30-Sep-2026 report. The June draft `02_SQL_Existing/07_Open_Transactions/16_S7.1_Open_Transactions.sql` was a starting point only; the changes from it are listed below. v1.4 goes beyond EBS on one point, at Satyajit's request: a Value on rows 1, 2, 3, 5 and 6 (EBS shows money on rows 4, 7 and 8 only).

## Deliverables

| Report item | File | Window | Status |
|---|---|---|---|
| **7.1** Open transactions summary (10 rows: Open Item / Count / Value) | `F7.1_Open_Transactions.sql` **v1.4** | **None.** Snapshot of the run day; dates are ignored. | v1.3 ran as R041 and R044 (R044 = the GitHub folder's stale copy). **v1.4 not run**; it will print R043 block A |
| **WB8** `Fusion_Discovery_7_1_Open_Transactions_By_BU.xlsx` (Business Unit × 10 classes, zeros included) | `F7.1_WB_Open_Transactions_By_BU.sql` **v1.4** | None | Not run (3 BUs = 30 rows) |
| Column check | `../00_Verify_First/V7_0_Columns_Check_Section_7.sql` **v1.4** (19 objects / 112 columns) | none | ✅ **R042 (v1.4): 19 / 19 ALL OK**, incl. DOO_FULFILL_LINES_ALL; it also covers V7_2 v1.1 (identical need list). Earlier: R023 (v1.0), R025 (v1.2) and R029 all ALL OK. |
| Status codes + sanity | `../00_Verify_First/V7_1_Code_Values_Section_7.sql` **v1.3** | none | ✅ R030 (v1.3): row 1 = **4**, no consigned stock. **No re-run for v1.4**: the counts do not change. R024 (v1.0) and R026 (v1.2) each found a row 1 defect, both fixed. |
| Count defence (new) | `../00_Verify_First/V7_3_Open_Transactions_Reconciliation_Section_7.sql` v1.0 | none | Not run. Every document of each row's table with one reason (counted, or the first F7.1 test it fails), by status, with the latest three document numbers per group. Rows k001 must equal the F7.1 run. |
| Open sales orders (new) | `../00_Verify_First/V7_4_Open_Sales_Orders_Check_Section_7.sql` v1.0 | none | Not run. Row 6 only, order by order: row 1 = F7.1 row 6; row 2 = submitted only (the consultant rule, as F4.2 v1.3); by status, line state, BU, year, returns, source system. |
| Value check (new) | `../00_Verify_First/V7_2_Open_Amounts_Check_Section_7.sql` **v1.1** | none | ✅ **R043 (v1.0):** all five ties OK; C89 / C90 closed. **v1.1 not run:** adds D2 (is row 3 inside row 2?) and F5 (the share of row 6 from orders never submitted), C91 |

**Run order (v1.4):** ~~V7_0 v1.4~~ (R042) → ~~V7_2 v1.0~~ (R043) → **F7.1 v1.4 → F7.1_WB v1.4 → V7_2 v1.1**, all on the same day and with the same ledger / BU. Blank ledger / BU = the whole pod (3 BUs, one primary ledger 300000004500337). No dates. V7_1 v1.3 (R030) needs no re-run. Copy F7.1 from this folder (or the refreshed GitHub-folder copy); its header must read `Version : 1.4`.

The open-item block (v1.4) is **byte-identical** in F7.1, the workbook and V7_2. For the same parameters, each class summed over the workbook's BU rows must equal that F7.1 row, for both Count and Value. If a class rule ever changes, change all three files.

## The 10 classes

| # | Open item | Fusion source and rule | BU column | Value |
|---|---|---|---|---|
| 1 | Open requisitions | Approved requisitions (`DOCUMENT_STATUS = 'APPROVED'`) with at least one **approved line** (`LINE_STATUS = 'APPROVED'`) that is **on no order**: no PO (`PO_HEADER_ID`) and no transfer order (`TO_HEADER_ID`); Oracle indexes the pair as `NVL(TO_HEADER_ID, PO_HEADER_ID)`. v1.1 after R024; transfer orders v1.3 after R026. | REQ_BU_ID | v1.4: those open lines |
| 2 | Open purchase orders | STANDARD POs, not cancelled, approved (`APPROVED_FLAG = 'Y'`), DOCUMENT_STATUS not CLOSED / FINALLY CLOSED / CANCELED | procurement BU, else requisitioning BU, else bill-to BU (the first one in scope) | v1.4: amount not yet invoiced |
| 3 | Open PO receipts | PO schedules with quantity received > quantity billed, not cancelled, SCHEDULE_STATUS not CLOSED / FINALLY CLOSED / CANCELED. Counted per schedule. | the PO's BU (as row 2) | v1.4: received, not yet invoiced |
| 4 | Open Payables invoices | Not cancelled, PAYMENT_STATUS_FLAG N or P, every invoice type | ORG_ID | invoice amount − amount paid |
| 5 | Open prepayments | PREPAYMENT invoices, not cancelled, never applied to an invoice (no distribution points back through PREPAY_DISTRIBUTION_ID) | ORG_ID | v1.4: prepayment amount |
| 6 | Open sales orders | One per order (revisions collapsed, the F4.2 rule). OPEN_FLAG Y and CANCELED_FLAG not Y on that version. | ORG_ID | v1.4: open lines not yet sent to billing |
| 7 | Open Receivables invoices | Payment schedules STATUS OP, CLASS INV, one row per transaction | transaction ORG_ID | amount due remaining |
| 8 | Open or unapplied receipts | Payment schedules STATUS OP, CLASS PMT, receipt not reversed, one row per receipt | receipt ORG_ID | size of each receipt's open amount |
| 9 | On-hand inventory (item-org) | INV_ONHAND_QUANTITIES_DETAIL: one row per (inventory org, item) whose stock layers net to more than zero in the primary unit. Consigned stock counts, as in EBS; negative pairs don't (a clean-up item; 0 on this pod). Added v1.2, as EBS v3 class 9. | the inventory org's BU | — |
| 10 | Open work orders | WIE_WORK_ORDERS_B whose status rolls up to system status **Released** or **On Hold** (WIE_WO_STATUSES_B.WO_SYSTEM_STATUS_CODE). Unreleased and Completed are not counted, as in EBS. Every work order type counts, maintenance included. Added v1.2, as EBS v3 class 10. | the inventory org's BU | — |

Values are in **entered currency** (each document's own), as in EBS. Amounts in different currencies are added together; V7_1 D2 / F3 and V7_2 B1 / C3 / F4 show the currency mix. Since v1.4 only rows 9 and 10 print "—": count-only, never zero.

## The values (v1.4, 2026-10-12)

**Why:** after R041 the user passed on Satyajit's request: the tables behind sales orders, POs and the other rows hold amounts, so show the total amount still unpaid on every row, not only on Payables, Receivables and receipts.

**Rule:** each value is the amount **not yet settled by the next document** in the flow. Once the next document exists, the amount belongs to the next row. A PO amount that has been invoiced is in row 4 (while unpaid), not row 2. An order line sent to billing is in row 7, not row 6. So the same money does not appear before and after its invoice.

| # | Open item | Value (v1.4) | Fusion columns |
|---|---|---|---|
| 1 | Open requisitions | The open lines (the ones that make the requisition open). Amount-based (services) line: its amount. Quantity line: (quantity − quantity cancelled) × unit price. | POR_REQUISITION_LINES_ALL: MATCHING_BASIS, CURRENCY_AMOUNT / AMOUNT, QUANTITY, QUANTITY_CANCELLED, CURRENCY_UNIT_PRICE / UNIT_PRICE. The CURRENCY_ columns hold the line's own currency when it is not the ledger currency (doc 25D), so they are preferred. |
| 2 | Open purchase orders | Amount not yet invoiced, over the PO's schedules that are not closed or cancelled. Quantity basis: (quantity − billed − cancelled) × price. Amount basis: amount − billed − cancelled. A schedule billed above its order counts 0, never negative. | PO_LINE_LOCATIONS_ALL: MATCHING_BASIS, QUANTITY, QUANTITY_BILLED, QUANTITY_CANCELLED, PRICE_OVERRIDE, AMOUNT, AMOUNT_BILLED, AMOUNT_CANCELLED, SCHEDULE_STATUS |
| 3 | Open PO receipts | Received, not yet invoiced: (quantity received − quantity billed) × price. **It is the received part of row 2.** | PO_LINE_LOCATIONS_ALL: QUANTITY_RECEIVED, QUANTITY_BILLED, PRICE_OVERRIDE |
| 4 | Open Payables invoices | Unchanged: invoice amount − amount paid | AP_INVOICES_ALL |
| 5 | Open prepayments | The prepayment amount (never applied, so all of it is still to recover). An unpaid prepayment is also in row 4, as its count already is. V7_2 E prints PREPAY_AMOUNT_REMAINING beside it. The pod has no prepayments (R024). | AP_INVOICES_ALL.INVOICE_AMOUNT |
| 6 | Open sales orders | Order lines not yet sent to billing: EXTENDED_AMOUNT of the fulfillment lines that are open, not cancelled and not invoice-interfaced, on the order version row 6 counts | DOO_FULFILL_LINES_ALL: HEADER_ID, OPEN_FLAG, CANCELED_FLAG, INVOICE_INTERFACED_FLAG, EXTENDED_AMOUNT ("monetary amount for the fulfill line quantity", doc 25C) |
| 7 | Open Receivables invoices | Unchanged: amount due remaining | AR_PAYMENT_SCHEDULES_ALL |
| 8 | Open or unapplied receipts | Unchanged: the size of each receipt's open amount | AR_PAYMENT_SCHEDULES_ALL |
| 9, 10 | On-hand, work orders | Still count-only. Stock and work orders are not unpaid documents; a value would need item costs, which this section has never measured. | — |

**Never add up the Value column:**
- Rows 2 and 3 overlap: row 3 is the received part of row 2.
- An unpaid prepayment is in rows 4 and 5.
- The amounts mix currencies, as rows 4, 7 and 8 always did.

**What V7_2 had to show before the values are published (C87-C90; all met in R042 / R043, below):**
- Every block's first line says **OK ties**: the F7.1 value adds up from its documents. The ties follow from using the same rule at another grain, so they prove that no join counts a document twice. They do not prove the rule right; the splits are for that.
- Row 2 (C2): how much of the open amount sits on CLOSED FOR INVOICING schedules, and on schedule types other than STANDARD; schedules billed above their order; schedules with no price.
- Row 6 (F0, F2): open orders with no fulfillment line (value 0); RETURN lines (if they carry positive amounts, they add to the value instead of reducing it, and v1.5 must net them); lines with no amount.
- Row 1 (B1): lines with no price (value 0); lines whose AMOUNT differs from quantity × price.
- Block A: the counts equal R041 (v1.3, the same day), unless documents changed during the day.

## What R042 / R043 found (V7_0 v1.4, V7_2 v1.0; 2026-10-12)

- **V7_0 v1.4: 19 / 19 ALL OK** (C87). DOO_FULFILL_LINES_ALL is visible with all 6 needed columns.
- **V7_2: all five ties OK, and the counts equal R041** (C88). F7.1 v1.3, run 2.5 minutes later from the GitHub folder (R044), gave the same counts, so the v1.4 rewrite changes no count.
- **Requisitions (row 1):** 6 open lines, all quantity-based, USD and priced: **41,324.41**.
- **Purchase orders (row 2), C89 closed:**
  - **40,605,056.30** not yet invoiced on 1,359 open schedules of the 864 POs.
  - Every schedule on the pod is type STANDARD and quantity-based (no services schedules, no other types).
  - Open = ordered − billed exactly (45,233,301.78 − 4,628,245.48): no cancelled quantities, nothing billed above its order on a counted schedule.
  - CLOSED FOR INVOICING (37 schedules) adds **0.00**: fully billed. CLOSED FOR RECEIVING (195) holds 522,546.42, received and waiting for invoices. ON HOLD (7) 9,007.56. OPEN (1,120) 40,073,502.32.
  - EUR 52,113.32 (0.13%). The June draft's "everything ordered" would have given 57,228,282.61.
- **PO receipts (row 3):** 212 schedules, **1,529,309.74**, all quantity-based and priced. That row 3 lies inside row 2 is still an assumption → V7_2 v1.1 D2.
- **Prepayments (row 5):** none.
- **Sales orders (row 6), C90 closed:**
  - **229,302,762.82** on 3,212 open lines of 1,594 orders: 3,181 order lines (229,341,480.04) and **31 return lines (−38,717.22)**. Returns are stored negative, so the value is already net of open returns.
  - 73 open orders have no fulfillment line (value 0); 23 open order lines have no amount yet (count as 0).
  - 3 open lines already sent to billing are left out (116.32 and −6,804.00; their amount is in Receivables).
  - The whole value of the open orders (every line not cancelled) is 527,711,048.88; 304,459,037.07 of it is lines already billed and closed.
  - EUR 24,757.20 (0.01%).
  - **Drafts:** the counted version was never submitted for 1,077 orders, and at least 1,004 of them have fulfillment lines (6,900 orders have lines; 5,896 are submitted). Their open lines are inside the 229.3 M. How much → V7_2 v1.1 F5 (C91).

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
- **POs:** approval is now tested, and the made-up value (line amounts) is removed. v1.0-v1.3 were count-only, as in EBS. v1.4 adds a value again, but it is the amount not yet invoiced on open schedules, not the draft's total of line amounts.
- **Sales orders:** the draft counted every revision row and valued them at summed unit prices. It now counts one row per order. v1.4 values it at its open lines not yet sent to billing.
- **Scope:** a single mandatory `:p_ledger_id` → the shared optional block.
- **Output:** a formatted text value with a non-ASCII dash → numeric columns.

## Captions for the report (Fusion wording of the EBS Appendix A, 7.1)

- **Value (v1.4):** the amount still open on each row, in each document's own currency. For requisitions, orders and receipts it is the part not yet passed to the next document:
  - Open requisitions: the open lines (quantity left × price, or the line amount for services).
  - Open purchase orders: the amount not yet invoiced.
  - Open PO receipts: the received amount not yet invoiced (part of the open purchase order amount).
  - Open Payables invoices: invoice amount − amount paid.
  - Open prepayments: the prepayment amount, none of it applied yet.
  - Open sales orders: the open order lines not yet sent to billing.
  - Open Receivables invoices: amount due remaining.
  - Open or unapplied receipts: the size of each receipt's open amount.
  - "—" on on-hand inventory and open work orders: a count, not a balance; it never means zero.
  - Amounts in different currencies are added together. Do not total the column.
- **Open purchase orders** are approved standard purchase orders that are not closed or cancelled. Purchase agreements are not purchase orders. Fusion has no blanket releases.
- **Open PO receipts** are PO schedules where the quantity received is more than the quantity billed.
- **No date window:** "open" is a snapshot.
- **Open Receivables invoices** count open INV payment schedules, one per transaction after collapsing installments.
- **Open sales orders (value):** the open order lines not yet sent to billing, net of open return lines; 73 open orders have no lines yet and 23 lines have no price yet (both count as 0). Draft orders never submitted are counted, as EBS counts entered orders; V7_2 v1.1 F5 gives their share of the value.
- **Open purchase orders (value):** on this pod every schedule is quantity-based; schedules closed for invoicing are fully billed and add nothing.

## Checks to reconcile (RUN_LOG C48–C57)

| Check | What must hold |
|---|---|
| C48 | V7_0: every row ALL OK, type flags '-'. ✅ R023 |
| C49 | V7_1: A0 and D0 OK. In blocks B, C, E and F5, no closed or cancelled value is marked counted, and no open value is uncounted. R024: B / C / E / F5 OK; **A failed → fixed in v1.1** (confirm with V7_1 v1.1) |
| C50 | F7.1 = F7.1_WB summed per class (same parameters), Count and Value, all 10 rows (Value on rows 1-8 from v1.4) |
| C51 | V7_1 G: documents whose BU has no primary ledger (dropped even with blank parameters). 0 expected; anything else is stated under the table. ✅ R024: 0 |
| C52 | F7.1 v1.3 with blank parameters = the expected values above |
| C53 | PO cancellation read from DOCUMENT_STATUS in F4.1 v1.3 / F6.1 v1.2 (CANCEL_FLAG is never set) |
| C54 | V7_0 v1.2 ALL OK on the new objects (INV_ONHAND_QUANTITIES_DETAIL, WIE_WO_STATUSES_B, WIE_WORK_ORDERS_B, FND_LOOKUP_VALUES) |
| C55 | F7.1 rows 9 / 10 (blank parameters) = V7_1 I0 / J0 = **4,509 / 132**; in block J every Released / On Hold system status is counted Y and every other status N; K2 = 0 / 0 / 0. ✅ checks R026 |
| C56 | F7.1 v1.3 row 1 = V7_1 v1.3 A2 summary (line open only when on no order: NVL(TO_HEADER_ID, PO_HEADER_ID) empty). ✅ checks R030: **4** |
| C57 | Consigned on-hand figure from V7_1 v1.3 I3 (OWNING_TYPE value + owner), never from OWNING_TYPE being set. ✅ CLOSED R030: **0** (OWNING_TYPE 2, owner = the org itself, all 6,010 rows) |
| C87 | V7_0 v1.4: ord 0 reads `V7_0 v1.4 (open-item block v1.4)` and 19 objects / 112 columns needed; every row ALL OK, type flags '-', DOO_FULFILL_LINES_ALL included. ✅ CLOSED R042 |
| C88 | V7_2: B0 / C0 / D0 / E0 / F0 all **OK ties**; block A counts = R041 (v1.3, same day) unless documents changed; then F7.1 v1.4 = V7_2 block A. ✅ ties and counts R043; F7.1 v1.4 run pending (R044 ran the v1.3 copy) |
| C89 | Row 2 value (V7_2 C2): the open amount on CLOSED FOR INVOICING schedules and on schedule types other than STANDARD is stated, or taken out in v1.5. ✅ CLOSED R043: 0.00 and none; no v1.5 |
| C90 | Row 6 value (V7_2 F0 / F2): open orders with no fulfillment line, and the sign of RETURN line amounts. Positive return amounts → v1.5 nets them. ✅ CLOSED R043: returns negative (netted); 73 orders without lines; no v1.5 |
| C91 | V7_2 v1.1: D2 says **OK inside row 2**, else the row 3 caption changes; F5 states the share of row 6 from orders never submitted |

## Known limits (stated, not hidden)

- **Values (v1.4) mix currencies**, as rows 4, 7 and 8 always did. Each is the document's own (entered) currency.
- **Values are line amounts as stored** (PO schedule quantity × price, the order line's EXTENDED_AMOUNT); the query adds no tax or charges.
- **Row 3 value**, like its count, cannot see amount-based (services) schedules. On this pod there are none (R043: every schedule is quantity-based).

- **Open Payables value** uses invoice amount − amount paid, as in the delivered EBS report. On EBS this was measured against AP's own payment schedules (AP_PAYMENT_SCHEDULES_ALL.AMOUNT_REMAINING): the difference was 0.1% on Vision. Header arithmetic does not net applied prepayments, discounts or withholding.
- **Services schedules:** a quantity test cannot see amount-based PO schedules. That is the EBS rule; V7_1 C9 counts how many it leaves out.
- **Open sales orders** include draft orders that were never submitted, as EBS includes entered (unbooked) orders. V7_1 E0 says how many there are.
