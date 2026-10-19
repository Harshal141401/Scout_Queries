-- ============================================================================
--  V7_2  OPEN AMOUNTS CHECK - the values F7.1 v1.4 adds to rows 1, 2, 3, 5, 6
--  Version   : 1.1 (2026-10-12)        Run log: 06_Run_Results/RUN_LOG.md
--              v1.1 adds D2 (is row 3 inside row 2?) and F5 (how much of row 6
--              comes from orders never submitted). v1.0 ran as R043: every
--              block OK ties, counts = R041. No new columns (V7_0 v1.4 covers
--              v1.1); the open-item block is unchanged.
--  For: F7.1 v1.4 and F7.1_WB v1.4 (open-item block v1.4, byte-identical here)
--  Why: after R041 Satyajit (through the user) asked for "the total amount for
--  the fields which are unpaid" on every row, not only Payables, Receivables
--  and receipts. Each new value is the part NOT YET SETTLED by the next
--  document, so an amount already on an invoice is left to the Payables /
--  Receivables rows. Two overlaps are by design: row 3 lies inside row 2, and
--  an unpaid prepayment is in rows 4 and 5 (as its count is).
--    1 requisitions    open lines (approved, on no order): AMOUNT for an
--                      amount-based line, else quantity left x unit price
--    2 purchase orders schedules not closed or cancelled: ordered - billed -
--                      cancelled (MATCHING_BASIS AMOUNT: amounts; QUANTITY:
--                      quantities x PRICE_OVERRIDE); never below 0
--    3 PO receipts     received - billed, x PRICE_OVERRIDE (a part of row 2)
--    5 prepayments     the prepayment amount (never applied)
--    6 sales orders    EXTENDED_AMOUNT of the open, not cancelled fulfillment
--                      lines not yet sent to billing (INVOICE_INTERFACED_FLAG)
--  Each value is in the document's own currency (as rows 4, 7, 8).
--  RUN AFTER V7_0 v1.4 (it proves the new columns and DOO_FULFILL_LINES_ALL).
--  Binds: the standard five; use the SAME ledger / BU as F7.1.
--
--  BLOCKS
--    A  the ten F7.1 v1.4 rows as printed (Count / Value)
--    B  row 1: open requisition lines by basis and currency - AMOUNT filled,
--       no price, AMOUNT differing from quantity x price, part-cancelled
--    C  row 2: open POs and their schedules by counted Y/N x schedule type x
--       basis x status -
--       ordered, billed, not yet invoiced, billed above order, no price; the
--       June-draft "total ordered" for comparison; currency
--    D  row 3: schedules received not yet invoiced by basis, no price;
--       D2 (v1.1): is row 3 inside row 2? Every such schedule must sit on an
--       open PO of row 2 and not be received above its order (received <=
--       quantity - cancelled); verdict "OK inside row 2"
--    E  row 5: prepayments never applied; PREPAY_AMOUNT_REMAINING alongside
--    F  row 6: open orders with / without fulfillment lines; lines by
--       CATEGORY_CODE (returns?) x OPEN_FLAG x CANCELED_FLAG x
--       INVOICE_INTERFACED_FLAG with counted Y/N;
--       the version's submitted flag; currency; the whole-order value for
--       comparison; F5 (v1.1): the value split by the version's
--       SUBMITTED_FLAG (N = a draft never submitted, counted as EBS counts
--       entered orders)
--    Every block opens with a TIE verdict: the detail must equal what the
--    F7.1 row prints ("OK ties").
--
--  OUTPUT  ord | section | item | value_text   (one grid, paste it back whole)
--  Pure SELECT. Nothing is written.
-- ============================================================================
WITH
-- ---- PARAMS / WINDOW / SCOPE: copied unchanged from F1 (shared block v3.3).
params AS (
    SELECT :p_ledger_id     AS p_ledger_id,
           :p_bu_id         AS p_bu_id,
           :p_custom_prefix AS p_custom_prefix,
           :p_from_date     AS p_from_date,
           :p_to_date       AS p_to_date
    FROM   dual
),
-- ---- WINDOW: identical in F0 and F1 -------------------------------------
win AS (
    SELECT NVL(TO_DATE(p.p_from_date, 'YYYY-MM-DD'),     DATE '0001-01-01') AS start_date,
           NVL(TO_DATE(p.p_to_date,   'YYYY-MM-DD') + 1, DATE '9999-12-31') AS end_date_excl
    FROM   params p
),
-- ---- SCOPE BLOCK: identical in F0 and F1 --------------------------------
led_scope AS (
    SELECT gl.ledger_id
    FROM   gl_ledgers gl
    CROSS  JOIN params p
    WHERE  gl.object_type_code = 'L'
    AND    NVL(gl.complete_flag, 'Y') = 'Y'
    AND    (p.p_ledger_id IS NULL OR gl.ledger_id = TO_NUMBER(p.p_ledger_id))
    -- v3.3: a BU narrows the ledgers to its primary ledger
    AND    (p.p_bu_id IS NULL
            OR EXISTS ( SELECT 1
                        FROM   fun_all_business_units_v bx
                        WHERE  bx.bu_id = TO_NUMBER(p.p_bu_id)
                        AND    TRIM(bx.primary_ledger_id) = TO_CHAR(gl.ledger_id) ))
),
-- FUN_ALL_BUSINESS_UNITS_V.PRIMARY_LEDGER_ID is ORG_INFORMATION3 (a string),
-- so it is compared as a string. A BU whose classification STATUS is
-- inactive ('I' / 'INACTIVE') is excluded - the Fusion counterpart of the EBS
-- W3-Houston "disabled OU" rule. The view itself already drops BUs whose
-- effective dates have ended. V0_2 block A prints the STATUS values present.
bu_scope AS (
    SELECT bu.bu_id
    FROM   fun_all_business_units_v bu
    CROSS  JOIN params p
    WHERE  bu.primary_ledger_id IS NOT NULL
    AND    NVL(UPPER(bu.status), 'A') NOT IN ('I', 'INACTIVE')
    AND    (p.p_ledger_id IS NULL OR bu.primary_ledger_id = TRIM(p.p_ledger_id))
    AND    (p.p_bu_id     IS NULL OR bu.bu_id = TO_NUMBER(p.p_bu_id))
    GROUP  BY bu.bu_id
),
inv_org_scope AS (
    SELECT iod.organization_id
    FROM   inv_organization_definitions_v iod
    CROSS  JOIN params p
    WHERE  (p.p_ledger_id IS NULL OR iod.set_of_books_id = TO_NUMBER(p.p_ledger_id))
    -- v3.3: a BU narrows the inventory orgs to its own (the org's business unit)
    AND    (p.p_bu_id IS NULL OR iod.business_unit_id = TO_NUMBER(p.p_bu_id))
    GROUP  BY iod.organization_id
),
fa_book_scope AS (
    SELECT fbc.book_type_code
    FROM   fa_book_controls fbc
    CROSS  JOIN params p
    WHERE  (p.p_ledger_id IS NULL OR fbc.set_of_books_id = TO_NUMBER(p.p_ledger_id))
    -- v3.3: a BU narrows the asset books to its primary ledger's
    AND    (p.p_bu_id IS NULL
            OR EXISTS ( SELECT 1
                        FROM   fun_all_business_units_v bx
                        WHERE  bx.bu_id = TO_NUMBER(p.p_bu_id)
                        AND    TRIM(bx.primary_ledger_id) = TO_CHAR(fbc.set_of_books_id) ))
    GROUP  BY fbc.book_type_code
),
-- ==== OPEN-ITEM BLOCK v1.4: byte-identical in F7.1, F7.1_WB and V7_2 =======
-- One row per (in-scope BU, class). Scope is applied INSIDE each class, by the
-- document's own BU column, so nothing outside scope can reach a total. If a
-- class rule changes, change ALL THREE files. Check: each F7.1 Count and Value
-- = that class summed down the F7.1_WB rows (all 10 must tie).
-- v1.4 (2026-10-12, user / Satyajit): a Value on rows 1, 2, 3, 5 and 6 too -
-- the amount NOT YET SETTLED by the next document, so an amount already on
-- an invoice is left to the Payables (4) or Receivables (7) row: requisition
-- lines not yet on an order; PO amount not yet invoiced; received not yet
-- invoiced (inside row 2); prepayments not yet applied (an unpaid one is in
-- row 4 too, as its count is); order lines not yet sent to billing. Values
-- are in each document's own currency, as rows 4, 7 and 8. Counts unchanged.
--
-- PO header -> ONE in-scope BU: procurement, else requisitioning, else bill-to.
po_bu AS (
    SELECT ph.po_header_id,
           COALESCE(b1.bu_id, b2.bu_id, b3.bu_id) AS bu_id
    FROM        po_headers_all ph
    LEFT JOIN   bu_scope       b1 ON b1.bu_id = ph.prc_bu_id
    LEFT JOIN   bu_scope       b2 ON b2.bu_id = ph.req_bu_id
    LEFT JOIN   bu_scope       b3 ON b3.bu_id = ph.billto_bu_id
    WHERE       COALESCE(b1.bu_id, b2.bu_id, b3.bu_id) IS NOT NULL
),
-- Sales orders: one row per order, revisions collapsed (the F4.2 rule).
so_hdr AS (
    SELECT dh.order_number,
           dh.source_order_system,
           MAX(dh.org_id) KEEP (DENSE_RANK FIRST ORDER BY
               CASE WHEN dh.submitted_flag = 'Y' THEN 0 ELSE 1 END, dh.header_id DESC)
                                                                    AS org_id,
           MAX(dh.open_flag) KEEP (DENSE_RANK FIRST ORDER BY
               CASE WHEN dh.submitted_flag = 'Y' THEN 0 ELSE 1 END, dh.header_id DESC)
                                                                    AS open_flag,
           MAX(dh.canceled_flag) KEEP (DENSE_RANK FIRST ORDER BY
               CASE WHEN dh.submitted_flag = 'Y' THEN 0 ELSE 1 END, dh.header_id DESC)
                                                                    AS canceled_flag,
           MAX(dh.header_id) KEEP (DENSE_RANK FIRST ORDER BY
               CASE WHEN dh.submitted_flag = 'Y' THEN 0 ELSE 1 END, dh.header_id DESC)
                                                                    AS header_id
    FROM   doo_headers_all dh
    GROUP  BY dh.order_number, dh.source_order_system
),
-- v1.4 values. Requisition lines still open (the row 1 line rule): approved,
-- not cancelled, on no PO and no transfer order. Amount: an amount-based
-- (services) line is its AMOUNT; a quantity line is quantity left x unit price.
-- The CURRENCY_ columns hold the foreign-currency figures when the line is not
-- in the ledger currency (doc 25D), so they are preferred: the line's own
-- currency, as the other rows.
req_open_line AS (
    SELECT rl.requisition_header_id,
           COUNT(*)                                                         AS n_lines,
           SUM(CASE WHEN UPPER(NVL(rl.matching_basis, 'QUANTITY')) = 'AMOUNT'
                    THEN NVL(rl.currency_amount, NVL(rl.amount, 0))
                    ELSE (NVL(rl.quantity, 0) - NVL(rl.quantity_cancelled, 0))
                         * NVL(rl.currency_unit_price, NVL(rl.unit_price, 0))
               END)                                                         AS open_amt
    FROM   por_requisition_lines_all rl
    WHERE  NVL(rl.cancel_flag, 'N') = 'N'
    AND    rl.line_status = 'APPROVED'
    AND    NVL(rl.to_header_id, rl.po_header_id) IS NULL
    GROUP  BY rl.requisition_header_id
),
-- PO amount not yet invoiced, per PO, over its schedules that are not closed or
-- cancelled. MATCHING_BASIS says how a schedule is invoiced (doc 25C): AMOUNT
-- (services: AMOUNT - AMOUNT_BILLED - AMOUNT_CANCELLED) or QUANTITY
-- (quantity left to invoice x PRICE_OVERRIDE). A schedule billed above its
-- order counts 0, never negative.
po_open_amt AS (
    SELECT pll.po_header_id,
           SUM(GREATEST(CASE WHEN UPPER(NVL(pll.matching_basis, 'QUANTITY')) = 'AMOUNT'
                             THEN NVL(pll.amount, 0) - NVL(pll.amount_billed, 0)
                                  - NVL(pll.amount_cancelled, 0)
                             ELSE (NVL(pll.quantity, 0) - NVL(pll.quantity_billed, 0)
                                   - NVL(pll.quantity_cancelled, 0))
                                  * NVL(pll.price_override, 0)
                        END, 0))                                            AS open_amt
    FROM   po_line_locations_all pll
    WHERE  NVL(pll.cancel_flag, 'N') = 'N'
    AND    REPLACE(UPPER(NVL(pll.schedule_status, 'OPEN')), '_', ' ')
               NOT IN ('CLOSED', 'FINALLY CLOSED', 'CANCELED', 'CANCELLED')
    GROUP  BY pll.po_header_id
),
-- Sales-order amount not yet invoiced, per order version: fulfillment lines
-- that are open (OPEN_FLAG = not closed or cancelled), not cancelled, and not
-- yet sent to billing (INVOICE_INTERFACED_FLAG; once sent, the amount belongs
-- to Receivables). EXTENDED_AMOUNT = "monetary amount for the fulfill line
-- quantity" (doc 25C), in the order's currency.
so_open_amt AS (
    SELECT fl.header_id,
           SUM(NVL(fl.extended_amount, 0))                                  AS open_amt
    FROM   doo_fulfill_lines_all fl
    WHERE  NVL(fl.open_flag, 'N') = 'Y'
    AND    NVL(fl.canceled_flag, 'N') <> 'Y'
    AND    NVL(fl.invoice_interfaced_flag, 'N') <> 'Y'
    GROUP  BY fl.header_id
),
-- Receivables invoices: schedules are per installment -> one row per transaction.
ar_open_trx AS (
    SELECT ct.org_id                            AS bu_id,
           ps.customer_trx_id,
           SUM(NVL(ps.amount_due_remaining, 0)) AS amt_remaining
    FROM   ar_payment_schedules_all ps
    JOIN   ra_customer_trx_all      ct ON ct.customer_trx_id = ps.customer_trx_id
    JOIN   bu_scope                 b  ON b.bu_id = ct.org_id
    WHERE  ps.status = 'OP'
    AND    ps.class  = 'INV'
    GROUP  BY ct.org_id, ps.customer_trx_id
),
-- Receipts: one row per receipt; the size of its open amount (ABS per receipt).
rcpt_open AS (
    SELECT cr.org_id                                 AS bu_id,
           ps.cash_receipt_id,
           ABS(SUM(NVL(ps.amount_due_remaining, 0))) AS open_amt
    FROM   ar_payment_schedules_all ps
    JOIN   ar_cash_receipts_all     cr ON cr.cash_receipt_id = ps.cash_receipt_id
    JOIN   bu_scope                 b  ON b.bu_id = cr.org_id
    WHERE  ps.class  = 'PMT'
    AND    ps.status = 'OP'
    AND    cr.reversal_date IS NULL
    AND    NVL(cr.status, 'X') <> 'REV'
    GROUP  BY cr.org_id, ps.cash_receipt_id
),
-- Inventory org -> ONE in-scope BU, its business unit. Rows 9 and 10 only:
-- on-hand and work-order rows carry an inventory org, never a BU. Built on
-- bu_scope (as EBS v3 builds inv_org_ou on ou), so a bound ledger or BU
-- limits the orgs as well. V7_1 K checks that no org maps to two BUs.
inv_org_bu AS (
    SELECT iod.organization_id       AS inv_org_id,
           MAX(iod.business_unit_id) AS bu_id
    FROM   inv_organization_definitions_v iod
    JOIN   bu_scope                       b ON b.bu_id = iod.business_unit_id
    GROUP  BY iod.organization_id
),
-- On-hand: one row per (inventory org, item) that holds stock. Rows of the
-- on-hand table are stock LAYERS (subinventory, locator, lot, receipt), so
-- they are summed first, in the primary unit, and kept when the net is > 0.
onhand_pairs AS (
    SELECT io.bu_id,
           oh.organization_id,
           oh.inventory_item_id
    FROM   inv_onhand_quantities_detail oh
    JOIN   inv_org_bu                   io ON io.inv_org_id = oh.organization_id
    GROUP  BY io.bu_id, oh.organization_id, oh.inventory_item_id
    HAVING SUM(NVL(oh.primary_transaction_quantity, 0)) > 0
),
-- Work order statuses, one row per status id (the table carries seed-set
-- keys, so it is grouped before the join to keep work orders 1:1).
wo_status AS (
    SELECT st.wo_status_id,
           MAX(st.wo_system_status_code) AS system_status
    FROM   wie_wo_statuses_b st
    GROUP  BY st.wo_status_id
),
open_items AS (
    -- 1 open requisitions: approved, >= 1 approved line not yet on an order.
    --   A line is placed on a PO (PO_HEADER_ID) or on a transfer order
    --   (TO_HEADER_ID), tested on every line (R030: 3 transfer-order lines sit
    --   on requisitions not flagged as transfers); Oracle indexes the
    --   pair as NVL(TO_HEADER_ID, PO_HEADER_ID) (POR_REQUISITION_LINES_N33,
    --   doc 25D). LINE_LOCATION_ID is never filled here and cancellation is
    --   LINE_STATUS (CANCEL_FLAG stays empty) - measured in R024 / R026.
    --   v1.4: the line rule moved to req_open_line (one row per requisition),
    --   so the JOIN counts exactly what the EXISTS counted; Value = its lines.
    SELECT rh.req_bu_id AS bu_id, 1 AS seq, COUNT(*) AS cnt, NVL(SUM(ro.open_amt), 0) AS amt
    FROM   por_requisition_headers_all rh
    JOIN   bu_scope                    b  ON b.bu_id = rh.req_bu_id
    JOIN   req_open_line               ro ON ro.requisition_header_id = rh.requisition_header_id
    WHERE  rh.document_status = 'APPROVED'
    GROUP  BY rh.req_bu_id
    UNION ALL
    -- 2 open purchase orders: STANDARD, approved, not closed or cancelled
    --   Value: amount not yet invoiced (po_open_amt, one row per PO)
    SELECT pb.bu_id, 2, COUNT(*), NVL(SUM(pa.open_amt), 0)
    FROM        po_headers_all ph
    JOIN        po_bu          pb ON pb.po_header_id = ph.po_header_id
    LEFT JOIN   po_open_amt    pa ON pa.po_header_id = ph.po_header_id
    WHERE  ph.type_lookup_code = 'STANDARD'
    AND    NVL(ph.cancel_flag, 'N') = 'N'
    AND    ph.approved_flag = 'Y'
    AND    REPLACE(UPPER(NVL(ph.document_status, 'OPEN')), '_', ' ')
               NOT IN ('CLOSED', 'FINALLY CLOSED', 'CANCELED', 'CANCELLED')
    GROUP  BY pb.bu_id
    UNION ALL
    -- 3 open PO receipts: schedules received but not yet invoiced
    --   Value: received quantity not yet invoiced x the schedule price
    SELECT pb.bu_id, 3, COUNT(*),
           NVL(SUM((NVL(pll.quantity_received, 0) - NVL(pll.quantity_billed, 0))
                   * NVL(pll.price_override, 0)), 0)
    FROM   po_line_locations_all pll
    JOIN   po_bu                 pb ON pb.po_header_id = pll.po_header_id
    WHERE  NVL(pll.quantity_received, 0) > NVL(pll.quantity_billed, 0)
    AND    NVL(pll.cancel_flag, 'N') = 'N'
    AND    REPLACE(UPPER(NVL(pll.schedule_status, 'OPEN')), '_', ' ')
               NOT IN ('CLOSED', 'FINALLY CLOSED', 'CANCELED', 'CANCELLED')
    GROUP  BY pb.bu_id
    UNION ALL
    -- 4 open Payables invoices (value)
    SELECT ai.org_id, 4, COUNT(*),
           NVL(SUM(ai.invoice_amount - NVL(ai.amount_paid, 0)), 0)
    FROM   ap_invoices_all ai
    JOIN   bu_scope        b ON b.bu_id = ai.org_id
    WHERE  ai.cancelled_date IS NULL
    AND    NVL(ai.payment_status_flag, 'N') IN ('N', 'P')
    GROUP  BY ai.org_id
    UNION ALL
    -- 5 open prepayments: never applied to an invoice
    --   Value: the prepayment amount (none of it applied yet)
    SELECT ai.org_id, 5, COUNT(*), NVL(SUM(ai.invoice_amount), 0)
    FROM   ap_invoices_all ai
    JOIN   bu_scope        b ON b.bu_id = ai.org_id
    WHERE  ai.cancelled_date IS NULL
    AND    ai.invoice_type_lookup_code = 'PREPAYMENT'
    AND    NOT EXISTS ( SELECT 1
                        FROM   ap_invoice_distributions_all pd
                        JOIN   ap_invoice_distributions_all cd
                               ON cd.prepay_distribution_id = pd.invoice_distribution_id
                        WHERE  pd.invoice_id = ai.invoice_id )
    GROUP  BY ai.org_id
    UNION ALL
    -- 6 open sales orders: one per order
    --   Value: open lines not yet sent to billing (so_open_amt, one row per
    --   order version; the version is the one so_hdr picks)
    SELECT so.org_id, 6, COUNT(*), NVL(SUM(sa.open_amt), 0)
    FROM        so_hdr      so
    JOIN        bu_scope    b  ON b.bu_id = so.org_id
    LEFT JOIN   so_open_amt sa ON sa.header_id = so.header_id
    WHERE  NVL(so.open_flag, 'N') = 'Y'
    AND    NVL(so.canceled_flag, 'N') = 'N'
    GROUP  BY so.org_id
    UNION ALL
    -- 7 open Receivables invoices (value)
    SELECT t.bu_id, 7, COUNT(*), NVL(SUM(t.amt_remaining), 0)
    FROM   ar_open_trx t
    GROUP  BY t.bu_id
    UNION ALL
    -- 8 open or unapplied receipts (value)
    SELECT r.bu_id, 8, COUNT(*), NVL(SUM(r.open_amt), 0)
    FROM   rcpt_open r
    GROUP  BY r.bu_id
    UNION ALL
    -- 9 on-hand inventory: (inventory org, item) pairs holding stock
    SELECT p.bu_id, 9, COUNT(*), CAST(NULL AS NUMBER)
    FROM   onhand_pairs p
    GROUP  BY p.bu_id
    UNION ALL
    -- 10 open work orders: system status Released or On Hold. A code stored
    --    with the ORA_ prefix or '_' for ' ' is treated the same.
    SELECT io.bu_id, 10, COUNT(*), CAST(NULL AS NUMBER)
    FROM   wie_work_orders_b wo
    JOIN   inv_org_bu        io ON io.inv_org_id   = wo.organization_id
    JOIN   wo_status         ws ON ws.wo_status_id = wo.work_order_status_id
    WHERE  REPLACE(REPLACE(UPPER(NVL(ws.system_status, 'X')), 'ORA_', ''), '_', ' ')
               IN ('RELEASED', 'ON HOLD')
    GROUP  BY io.bu_id
),
-- ==== END OF OPEN-ITEM BLOCK ===============================================
-- ==== V7_2 checks (not shared) ================================================
-- cls_v / class_tot_v: the ten rows exactly as F7.1 v1.4 prints them
cls_v AS (
    SELECT 1 AS seq, 'Open requisitions' AS open_item, 'Y' AS has_value FROM dual
    UNION ALL SELECT 2, 'Open purchase orders',       'Y' FROM dual
    UNION ALL SELECT 3, 'Open PO receipts',           'Y' FROM dual
    UNION ALL SELECT 4, 'Open Payables invoices',     'Y' FROM dual
    UNION ALL SELECT 5, 'Open prepayments',           'Y' FROM dual
    UNION ALL SELECT 6, 'Open sales orders',          'Y' FROM dual
    UNION ALL SELECT 7, 'Open Receivables invoices',  'Y' FROM dual
    UNION ALL SELECT 8, 'Open or unapplied receipts', 'Y' FROM dual
    UNION ALL SELECT 9, 'On-hand inventory (item-org)', 'N' FROM dual
    UNION ALL SELECT 10, 'Open work orders',          'N' FROM dual
),
class_tot_v AS (
    SELECT oi.seq, SUM(oi.cnt) AS cnt, SUM(oi.amt) AS amt
    FROM   open_items oi
    GROUP  BY oi.seq
),
a_rows AS (
    SELECT c.seq, c.open_item, c.has_value,
           NVL(t.cnt, 0)                                                    AS cnt,
           CASE WHEN c.has_value = 'Y' THEN NVL(t.amt, 0) END               AS amt
    FROM        cls_v       c
    LEFT JOIN   class_tot_v t ON t.seq = c.seq
),
-- ==== B row 1: the open requisition lines behind the value ======================
b_lines AS (
    SELECT UPPER(NVL(rl.matching_basis, 'QUANTITY'))                        AS basis,
           NVL(TO_CHAR(rl.currency_code), '(none)')                         AS currency,
           rl.amount                                                        AS amount,
           rl.quantity                                                      AS quantity,
           rl.quantity_cancelled                                            AS quantity_cancelled,
           rl.unit_price                                                    AS unit_price,
           rl.currency_unit_price                                           AS currency_unit_price,
           CASE WHEN UPPER(NVL(rl.matching_basis, 'QUANTITY')) = 'AMOUNT'
                THEN NVL(rl.currency_amount, NVL(rl.amount, 0))
                ELSE (NVL(rl.quantity, 0) - NVL(rl.quantity_cancelled, 0))
                     * NVL(rl.currency_unit_price, NVL(rl.unit_price, 0))
           END                                                              AS line_val
    FROM   por_requisition_lines_all   rl
    JOIN   por_requisition_headers_all rh ON rh.requisition_header_id = rl.requisition_header_id
    JOIN   bu_scope                    b  ON b.bu_id = rh.req_bu_id
    WHERE  rh.document_status = 'APPROVED'
    AND    NVL(rl.cancel_flag, 'N') = 'N'
    AND    rl.line_status = 'APPROVED'
    AND    NVL(rl.to_header_id, rl.po_header_id) IS NULL
),
b_tot AS (
    SELECT COUNT(*)                                                         AS n_lines,
           NVL(SUM(l.line_val), 0)                                          AS val
    FROM   b_lines l
),
b_grp AS (
    SELECT l.basis, l.currency,
           COUNT(*)                                                         AS n_lines,
           NVL(SUM(l.line_val), 0)                                          AS val,
           NVL(SUM(CASE WHEN l.amount IS NOT NULL THEN 1 ELSE 0 END), 0)    AS n_amount,
           NVL(SUM(CASE WHEN l.unit_price IS NULL AND l.currency_unit_price IS NULL
                        THEN 1 ELSE 0 END), 0)                              AS n_no_price,
           NVL(SUM(CASE WHEN l.basis <> 'AMOUNT' AND l.amount IS NOT NULL
                         AND ABS(l.amount - NVL(l.quantity, 0) * NVL(l.unit_price, 0)) > 0.01
                        THEN 1 ELSE 0 END), 0)                              AS n_amt_differs,
           NVL(SUM(CASE WHEN NVL(l.quantity_cancelled, 0) <> 0 THEN 1 ELSE 0 END), 0)
                                                                            AS n_part_cancel
    FROM   b_lines l
    GROUP  BY l.basis, l.currency
),
b_grp_rows AS (
    SELECT g.basis, g.currency, g.n_lines, g.val, g.n_amount, g.n_no_price,
           g.n_amt_differs, g.n_part_cancel,
           ROW_NUMBER() OVER (ORDER BY g.basis, g.currency)                 AS rn
    FROM   b_grp g
),
-- ==== C row 2: the schedules of the open POs ====================================
c_po AS (
    SELECT ph.po_header_id,
           NVL(TO_CHAR(ph.currency_code), '(none)')                         AS currency
    FROM   po_headers_all ph
    JOIN   po_bu          pb ON pb.po_header_id = ph.po_header_id
    WHERE  ph.type_lookup_code = 'STANDARD'
    AND    NVL(ph.cancel_flag, 'N') = 'N'
    AND    ph.approved_flag = 'Y'
    AND    REPLACE(UPPER(NVL(ph.document_status, 'OPEN')), '_', ' ')
               NOT IN ('CLOSED', 'FINALLY CLOSED', 'CANCELED', 'CANCELLED')
),
c_sched AS (
    SELECT p.currency,
           NVL(UPPER(TO_CHAR(pll.shipment_type)), '-')                      AS ship_type,
           UPPER(NVL(pll.matching_basis, 'QUANTITY'))                       AS basis,
           REPLACE(UPPER(NVL(pll.schedule_status, 'OPEN')), '_', ' ')       AS sched_status,
           CASE WHEN NVL(pll.cancel_flag, 'N') = 'N'
                 AND REPLACE(UPPER(NVL(pll.schedule_status, 'OPEN')), '_', ' ')
                     NOT IN ('CLOSED', 'FINALLY CLOSED', 'CANCELED', 'CANCELLED')
                THEN 'Y' ELSE 'N'
           END                                                              AS counted,
           CASE WHEN UPPER(NVL(pll.matching_basis, 'QUANTITY')) = 'AMOUNT'
                THEN NVL(pll.amount, 0)
                ELSE NVL(pll.quantity, 0) * NVL(pll.price_override, 0)
           END                                                              AS ordered_amt,
           CASE WHEN UPPER(NVL(pll.matching_basis, 'QUANTITY')) = 'AMOUNT'
                THEN NVL(pll.amount_billed, 0)
                ELSE NVL(pll.quantity_billed, 0) * NVL(pll.price_override, 0)
           END                                                              AS billed_amt,
           CASE WHEN UPPER(NVL(pll.matching_basis, 'QUANTITY')) = 'AMOUNT'
                THEN NVL(pll.amount, 0) - NVL(pll.amount_billed, 0)
                     - NVL(pll.amount_cancelled, 0)
                ELSE (NVL(pll.quantity, 0) - NVL(pll.quantity_billed, 0)
                      - NVL(pll.quantity_cancelled, 0))
                     * NVL(pll.price_override, 0)
           END                                                              AS remain_raw,
           CASE WHEN pll.price_override IS NULL THEN 1 ELSE 0 END           AS no_price
    FROM   po_line_locations_all pll
    JOIN   c_po                  p ON p.po_header_id = pll.po_header_id
),
c_po_cnt AS (
    SELECT COUNT(*)                                                         AS n_po
    FROM   c_po
),
c_tot AS (
    SELECT COUNT(*)                                                         AS n_sched,
           NVL(SUM(CASE WHEN s.counted = 'Y' THEN 1 ELSE 0 END), 0)         AS n_counted,
           NVL(SUM(s.ordered_amt), 0)                                       AS ordered_all,
           NVL(SUM(CASE WHEN s.counted = 'Y' THEN s.ordered_amt ELSE 0 END), 0)
                                                                            AS ordered_counted,
           NVL(SUM(CASE WHEN s.counted = 'Y' THEN s.billed_amt ELSE 0 END), 0)
                                                                            AS billed_counted,
           NVL(SUM(CASE WHEN s.counted = 'Y' THEN GREATEST(s.remain_raw, 0) ELSE 0 END), 0)
                                                                            AS open_amt
    FROM   c_sched s
),
c_grp AS (
    SELECT s.counted, s.ship_type, s.basis, s.sched_status,
           COUNT(*)                                                         AS n_sched,
           NVL(SUM(s.ordered_amt), 0)                                       AS ordered_amt,
           NVL(SUM(s.billed_amt), 0)                                        AS billed_amt,
           NVL(SUM(GREATEST(s.remain_raw, 0)), 0)                           AS open_amt,
           NVL(SUM(CASE WHEN s.remain_raw < 0 THEN 1 ELSE 0 END), 0)        AS n_negative,
           NVL(SUM(s.no_price), 0)                                          AS n_no_price
    FROM   c_sched s
    GROUP  BY s.counted, s.ship_type, s.basis, s.sched_status
),
c_grp_rows AS (
    SELECT g.counted, g.ship_type, g.basis, g.sched_status, g.n_sched, g.ordered_amt,
           g.billed_amt, g.open_amt, g.n_negative, g.n_no_price,
           ROW_NUMBER() OVER (ORDER BY g.counted DESC, g.ship_type, g.basis,
                                       g.sched_status)                      AS rn
    FROM   c_grp g
),
c_cur AS (
    SELECT s.currency,
           COUNT(*)                                                         AS n_sched,
           NVL(SUM(CASE WHEN s.counted = 'Y' THEN GREATEST(s.remain_raw, 0) ELSE 0 END), 0)
                                                                            AS open_amt
    FROM   c_sched s
    GROUP  BY s.currency
),
c_cur_rows AS (
    SELECT c.currency, c.n_sched, c.open_amt,
           ROW_NUMBER() OVER (ORDER BY c.open_amt DESC, c.currency)         AS rn
    FROM   c_cur c
),
-- ==== D row 3: the schedules received but not yet invoiced =======================
d_sched AS (
    SELECT UPPER(NVL(pll.matching_basis, 'QUANTITY'))                       AS basis,
           (NVL(pll.quantity_received, 0) - NVL(pll.quantity_billed, 0))
               * NVL(pll.price_override, 0)                                 AS val,
           CASE WHEN pll.price_override IS NULL THEN 1 ELSE 0 END           AS no_price,
           pll.po_header_id                                                 AS po_header_id,
           CASE WHEN NVL(pll.quantity_received, 0)
                     > NVL(pll.quantity, 0) - NVL(pll.quantity_cancelled, 0)
                THEN 1 ELSE 0
           END                                                              AS is_over,
           CASE WHEN NVL(pll.quantity_received, 0)
                     > NVL(pll.quantity, 0) - NVL(pll.quantity_cancelled, 0)
                THEN (NVL(pll.quantity_received, 0)
                      - (NVL(pll.quantity, 0) - NVL(pll.quantity_cancelled, 0)))
                     * NVL(pll.price_override, 0)
                ELSE 0
           END                                                              AS over_val
    FROM   po_line_locations_all pll
    JOIN   po_bu                 pb ON pb.po_header_id = pll.po_header_id
    WHERE  NVL(pll.quantity_received, 0) > NVL(pll.quantity_billed, 0)
    AND    NVL(pll.cancel_flag, 'N') = 'N'
    AND    REPLACE(UPPER(NVL(pll.schedule_status, 'OPEN')), '_', ' ')
               NOT IN ('CLOSED', 'FINALLY CLOSED', 'CANCELED', 'CANCELLED')
),
d_grp AS (
    SELECT d.basis,
           COUNT(*)                                                         AS n_sched,
           NVL(SUM(d.val), 0)                                               AS val,
           NVL(SUM(d.no_price), 0)                                          AS n_no_price
    FROM   d_sched d
    GROUP  BY d.basis
),
d_tot AS (
    SELECT COUNT(*)                                                         AS n_sched,
           NVL(SUM(d.val), 0)                                               AS val
    FROM   d_sched d
),
d_grp_rows AS (
    SELECT g.basis, g.n_sched, g.val, g.n_no_price,
           ROW_NUMBER() OVER (ORDER BY g.basis)                             AS rn
    FROM   d_grp g
),
-- D2 (v1.1): row 3 is a part of row 2 only if every row 3 schedule sits on an
-- open PO of row 2 (c_po; the schedule filters are the same) and was not
-- received above its order. Then received - billed <= quantity - billed -
-- cancelled, so its row 3 value <= its row 2 value. over_val bounds the
-- excess from above (exact unless the schedule is also billed above it).
d_in2 AS (
    SELECT NVL(SUM(CASE WHEN p.po_header_id IS NULL THEN 1 ELSE 0 END), 0)      AS n_outside,
           NVL(SUM(CASE WHEN p.po_header_id IS NULL THEN d.val ELSE 0 END), 0)  AS val_outside,
           NVL(SUM(d.is_over), 0)                                             AS n_over,
           NVL(SUM(d.over_val), 0)                                            AS over_val
    FROM        d_sched d
    LEFT JOIN   c_po    p ON p.po_header_id = d.po_header_id
),
-- ==== E row 5: prepayments never applied ==========================================
e_prepay AS (
    SELECT ai.invoice_id,
           ai.invoice_amount                                                AS invoice_amount
    FROM   ap_invoices_all ai
    JOIN   bu_scope        b ON b.bu_id = ai.org_id
    WHERE  ai.cancelled_date IS NULL
    AND    ai.invoice_type_lookup_code = 'PREPAYMENT'
    AND    NOT EXISTS ( SELECT 1
                        FROM   ap_invoice_distributions_all pd
                        JOIN   ap_invoice_distributions_all cd
                               ON cd.prepay_distribution_id = pd.invoice_distribution_id
                        WHERE  pd.invoice_id = ai.invoice_id )
),
e_tot AS (
    SELECT COUNT(*)                                                         AS n_prepay,
           NVL(SUM(e.invoice_amount), 0)                                    AS amt
    FROM   e_prepay e
),
e_rem AS (
    SELECT NVL(SUM(d.prepay_amount_remaining), 0)                           AS rem
    FROM   ap_invoice_distributions_all d
    JOIN   e_prepay                     e ON e.invoice_id = d.invoice_id
),
-- ==== F row 6: the fulfillment lines of the open sales orders =====================
f_ord AS (
    SELECT so.header_id
    FROM   so_hdr   so
    JOIN   bu_scope b ON b.bu_id = so.org_id
    WHERE  NVL(so.open_flag, 'N') = 'Y'
    AND    NVL(so.canceled_flag, 'N') = 'N'
),
f_hdr AS (
    SELECT dh.header_id,
           NVL(TO_CHAR(dh.transactional_currency_code), '(none)')           AS currency,
           NVL(UPPER(TO_CHAR(dh.submitted_flag)), '-')                      AS submitted
    FROM   doo_headers_all dh
    JOIN   f_ord           o ON o.header_id = dh.header_id
),
f_lines AS (
    SELECT fl.header_id,
           NVL(UPPER(TO_CHAR(fl.category_code)), '-')                       AS category,
           NVL(UPPER(TO_CHAR(fl.open_flag)), '-')                           AS open_flag,
           NVL(UPPER(TO_CHAR(fl.canceled_flag)), '-')                       AS canceled_flag,
           NVL(UPPER(TO_CHAR(fl.invoice_interfaced_flag)), '-')             AS interfaced,
           fl.extended_amount                                               AS extended_amount,
           CASE WHEN NVL(fl.open_flag, 'N') = 'Y'
                 AND NVL(fl.canceled_flag, 'N') <> 'Y'
                 AND NVL(fl.invoice_interfaced_flag, 'N') <> 'Y'
                THEN 'Y' ELSE 'N'
           END                                                              AS counted
    FROM   doo_fulfill_lines_all fl
    JOIN   f_ord                 o ON o.header_id = fl.header_id
),
f_flag AS (
    SELECT l.category, l.open_flag, l.canceled_flag, l.interfaced, l.counted,
           COUNT(*)                                                         AS n_lines,
           NVL(SUM(l.extended_amount), 0)                                   AS amt,
           NVL(SUM(CASE WHEN l.extended_amount IS NULL THEN 1 ELSE 0 END), 0) AS n_null_amt
    FROM   f_lines l
    GROUP  BY l.category, l.open_flag, l.canceled_flag, l.interfaced, l.counted
),
f_flag_rows AS (
    SELECT g.category, g.open_flag, g.canceled_flag, g.interfaced, g.counted, g.n_lines,
           g.amt, g.n_null_amt,
           ROW_NUMBER() OVER (ORDER BY g.counted DESC, g.category, g.open_flag DESC,
                                       g.canceled_flag, g.interfaced)       AS rn
    FROM   f_flag g
),
f_ord_lines AS (
    SELECT o.header_id,
           MAX(CASE WHEN l.header_id IS NOT NULL THEN 1 ELSE 0 END)         AS has_line,
           MAX(CASE WHEN l.counted = 'Y' THEN 1 ELSE 0 END)                 AS has_counted
    FROM        f_ord   o
    LEFT JOIN   f_lines l ON l.header_id = o.header_id
    GROUP  BY o.header_id
),
f_ord_sum AS (
    SELECT COUNT(*)                                                         AS n_orders,
           NVL(SUM(x.has_line), 0)                                          AS n_with_lines,
           NVL(SUM(x.has_counted), 0)                                       AS n_with_counted
    FROM   f_ord_lines x
),
f_sub AS (
    SELECT h.submitted, COUNT(*)                                            AS n
    FROM   f_hdr h
    GROUP  BY h.submitted
),
f_sub_rows AS (
    SELECT s.submitted, s.n, ROW_NUMBER() OVER (ORDER BY s.submitted DESC)  AS rn
    FROM   f_sub s
),
f_tot AS (
    SELECT NVL(SUM(CASE WHEN l.counted = 'Y' THEN l.extended_amount ELSE 0 END), 0)
                                                                            AS open_amt,
           NVL(SUM(CASE WHEN l.open_flag = 'Y' AND l.canceled_flag <> 'Y'
                        THEN l.extended_amount ELSE 0 END), 0)              AS open_incl_billing,
           NVL(SUM(CASE WHEN l.canceled_flag <> 'Y' THEN l.extended_amount ELSE 0 END), 0)
                                                                            AS all_not_cancelled
    FROM   f_lines l
),
f_cur AS (
    SELECT h.currency,
           COUNT(*)                                                         AS n_orders,
           NVL(SUM(v.open_amt), 0)                                          AS open_amt
    FROM        f_hdr       h
    LEFT JOIN   so_open_amt v ON v.header_id = h.header_id
    GROUP  BY h.currency
),
f_cur_rows AS (
    SELECT c.currency, c.n_orders, c.open_amt,
           ROW_NUMBER() OVER (ORDER BY c.open_amt DESC, c.currency)         AS rn
    FROM   f_cur c
),
-- F5 (v1.1): row 6 split by the SUBMITTED_FLAG of the order version it
-- counts. N = a draft never submitted: counted (EBS counts entered orders),
-- and its fulfillment lines can be open, so its lines reach the value too.
f_subl AS (
    SELECT h.submitted,
           COUNT(*)                                                         AS n_lines,
           NVL(SUM(CASE WHEN l.extended_amount IS NULL THEN 1 ELSE 0 END), 0) AS n_null_amt
    FROM   f_lines l
    JOIN   f_hdr   h ON h.header_id = l.header_id
    WHERE  l.counted = 'Y'
    GROUP  BY h.submitted
),
f_subv AS (
    SELECT h.submitted,
           COUNT(*)                                                         AS n_orders,
           NVL(SUM(CASE WHEN v.header_id IS NOT NULL THEN 1 ELSE 0 END), 0)  AS n_with_open,
           NVL(SUM(v.open_amt), 0)                                          AS open_amt
    FROM        f_hdr       h
    LEFT JOIN   so_open_amt v ON v.header_id = h.header_id
    GROUP  BY h.submitted
),
f_subv_rows AS (
    SELECT s.submitted, s.n_orders, s.n_with_open, s.open_amt,
           NVL(l.n_lines, 0)                                                AS n_lines,
           NVL(l.n_null_amt, 0)                                             AS n_null_amt,
           ROW_NUMBER() OVER (ORDER BY s.submitted DESC)                    AS rn
    FROM        f_subv s
    LEFT JOIN   f_subl l ON l.submitted = s.submitted
),
-- ==== value of each F7.1 row, for the tie verdicts ================================
t_val AS (
    SELECT NVL(MAX(CASE WHEN a.seq = 1 THEN a.amt END), 0)                  AS v1,
           NVL(MAX(CASE WHEN a.seq = 2 THEN a.amt END), 0)                  AS v2,
           NVL(MAX(CASE WHEN a.seq = 3 THEN a.amt END), 0)                  AS v3,
           NVL(MAX(CASE WHEN a.seq = 5 THEN a.amt END), 0)                  AS v5,
           NVL(MAX(CASE WHEN a.seq = 6 THEN a.amt END), 0)                  AS v6
    FROM   a_rows a
),
grid AS (
    -- A ---------------------------------------------------------------------------
    SELECT 100 + a.seq                                              AS ord,
           CAST('A F7.1 v1.4 rows' AS VARCHAR2(400))                AS section,
           CAST('A1 row ' || a.seq || ' ' || a.open_item || ': Count / Value'
                AS VARCHAR2(1000))                                  AS item,
           CAST(a.cnt || ' / '
                || CASE WHEN a.has_value = 'Y'
                        THEN TO_CHAR(a.amt, 'FM999,999,999,990.00')
                        ELSE '(count only)'
                   END
                AS VARCHAR2(4000))                                  AS value_text
    FROM   a_rows a
    UNION ALL
    SELECT 100, TO_CHAR('A F7.1 v1.4 rows'),
           TO_CHAR('A0 summary (V7_2 v1.1, open-item block v1.4). Counts and values must'
                   || ' equal F7.1 v1.4 run the same day. R043 (V7_2 v1.0, 2026-10-12): 4 /'
                   || ' 41,324.41; 864 / 40,605,056.30; 212 / 1,529,309.74; 628 / 22,349,328.67;'
                   || ' 0 / 0.00; 6973 / 229,302,762.82; 641 / 25,157,042.57; 10 / 33,636.61;'
                   || ' 4509; 133'),
           TO_CHAR('Values are new on rows 1, 2, 3, 5, 6; rows 4, 7, 8 as before; 9, 10 count'
                   || ' only')
    FROM   dual
    -- B ---------------------------------------------------------------------------
    UNION ALL
    SELECT 200, TO_CHAR('B row 1 requisition lines'),
           TO_CHAR('B0 open lines / their value / F7.1 row 1 value / verdict'),
           TO_CHAR(b.n_lines || ' / ' || TO_CHAR(b.val, 'FM999,999,999,990.00') || ' / '
                   || TO_CHAR(v.v1, 'FM999,999,999,990.00') || ' / '
                   || CASE WHEN ABS(b.val - v.v1) < 0.005 THEN 'OK ties'
                           ELSE 'CHECK: does not tie' END)
    FROM        b_tot b
    CROSS JOIN  t_val v
    UNION ALL
    SELECT 200 + g.rn, TO_CHAR('B row 1 requisition lines'),
           TO_CHAR('B1 basis=' || g.basis || ' currency=' || g.currency
                   || ': lines / value / AMOUNT filled / no price / AMOUNT differs from'
                   || ' qty x price / partly cancelled'),
           TO_CHAR(g.n_lines || ' / ' || TO_CHAR(g.val, 'FM999,999,999,990.00') || ' / '
                   || g.n_amount || ' / ' || g.n_no_price || ' / ' || g.n_amt_differs
                   || ' / ' || g.n_part_cancel)
    FROM   b_grp_rows g
    WHERE  g.rn <= 20
    -- C ---------------------------------------------------------------------------
    UNION ALL
    SELECT 300, TO_CHAR('C row 2 purchase orders'),
           TO_CHAR('C0 open POs / their schedules / schedules counted / value not yet'
                   || ' invoiced / F7.1 row 2 value / verdict'),
           TO_CHAR(p.n_po || ' / ' || c.n_sched || ' / ' || c.n_counted || ' / '
                   || TO_CHAR(c.open_amt, 'FM999,999,999,990.00') || ' / '
                   || TO_CHAR(v.v2, 'FM999,999,999,990.00') || ' / '
                   || CASE WHEN ABS(c.open_amt - v.v2) < 0.005 THEN 'OK ties'
                           ELSE 'CHECK: does not tie' END)
    FROM        c_tot    c
    CROSS JOIN  c_po_cnt p
    CROSS JOIN  t_val    v
    UNION ALL
    SELECT 301, TO_CHAR('C row 2 purchase orders'),
           TO_CHAR('C1 for comparison: total ordered on every schedule of the open POs'
                   || ' (the June draft rule) / ordered on counted schedules / billed on'
                   || ' counted schedules'),
           TO_CHAR(TO_CHAR(c.ordered_all, 'FM999,999,999,990.00') || ' / '
                   || TO_CHAR(c.ordered_counted, 'FM999,999,999,990.00') || ' / '
                   || TO_CHAR(c.billed_counted, 'FM999,999,999,990.00'))
    FROM   c_tot c
    UNION ALL
    SELECT 310 + g.rn, TO_CHAR('C row 2 purchase orders'),
           TO_CHAR('C2 counted=' || g.counted || ' type=' || g.ship_type || ' basis='
                   || g.basis || ' status='
                   || g.sched_status || ': schedules / ordered / billed / not yet invoiced'
                   || ' / billed above order / no price'),
           TO_CHAR(g.n_sched || ' / ' || TO_CHAR(g.ordered_amt, 'FM999,999,999,990.00')
                   || ' / ' || TO_CHAR(g.billed_amt, 'FM999,999,999,990.00') || ' / '
                   || TO_CHAR(g.open_amt, 'FM999,999,999,990.00') || ' / ' || g.n_negative
                   || ' / ' || g.n_no_price)
    FROM   c_grp_rows g
    WHERE  g.rn <= 25
    UNION ALL
    SELECT 340 + r.rn, TO_CHAR('C row 2 purchase orders'),
           TO_CHAR('C3 PO currency=' || r.currency || ': schedules / value not yet invoiced'),
           TO_CHAR(r.n_sched || ' / ' || TO_CHAR(r.open_amt, 'FM999,999,999,990.00'))
    FROM   c_cur_rows r
    WHERE  r.rn <= 10
    -- D ---------------------------------------------------------------------------
    UNION ALL
    SELECT 400, TO_CHAR('D row 3 PO receipts'),
           TO_CHAR('D0 schedules received not yet invoiced / their value / F7.1 row 3 value'
                   || ' / verdict'),
           TO_CHAR(d.n_sched || ' / ' || TO_CHAR(d.val, 'FM999,999,999,990.00') || ' / '
                   || TO_CHAR(v.v3, 'FM999,999,999,990.00') || ' / '
                   || CASE WHEN ABS(d.val - v.v3) < 0.005 THEN 'OK ties'
                           ELSE 'CHECK: does not tie' END)
    FROM        d_tot d
    CROSS JOIN  t_val v
    UNION ALL
    SELECT 400 + g.rn, TO_CHAR('D row 3 PO receipts'),
           TO_CHAR('D1 basis=' || g.basis || ': schedules / value / no price'),
           TO_CHAR(g.n_sched || ' / ' || TO_CHAR(g.val, 'FM999,999,999,990.00') || ' / '
                   || g.n_no_price)
    FROM   d_grp_rows g
    WHERE  g.rn <= 10
    UNION ALL
    SELECT 420, TO_CHAR('D row 3 PO receipts'),
           TO_CHAR('D2 is row 3 inside row 2? schedules on a PO row 2 does not count / their'
                   || ' value / schedules received above their order / value above the order'
                   || ' (at most) / verdict'),
           TO_CHAR(i.n_outside || ' / ' || TO_CHAR(i.val_outside, 'FM999,999,999,990.00')
                   || ' / ' || i.n_over || ' / '
                   || TO_CHAR(i.over_val, 'FM999,999,999,990.00') || ' / '
                   || CASE WHEN i.n_outside = 0 AND i.n_over = 0 THEN 'OK inside row 2'
                           ELSE 'CHECK: not wholly inside row 2' END)
    FROM   d_in2 i
    -- E ---------------------------------------------------------------------------
    UNION ALL
    SELECT 500, TO_CHAR('E row 5 prepayments'),
           TO_CHAR('E0 prepayments never applied / their amount / PREPAY_AMOUNT_REMAINING on'
                   || ' their distributions / F7.1 row 5 value / verdict'),
           TO_CHAR(e.n_prepay || ' / ' || TO_CHAR(e.amt, 'FM999,999,999,990.00') || ' / '
                   || TO_CHAR(r.rem, 'FM999,999,999,990.00') || ' / '
                   || TO_CHAR(v.v5, 'FM999,999,999,990.00') || ' / '
                   || CASE WHEN ABS(e.amt - v.v5) < 0.005 THEN 'OK ties'
                           ELSE 'CHECK: does not tie' END)
    FROM        e_tot e
    CROSS JOIN  e_rem r
    CROSS JOIN  t_val v
    -- F ---------------------------------------------------------------------------
    UNION ALL
    SELECT 600, TO_CHAR('F row 6 sales orders'),
           TO_CHAR('F0 open orders / with fulfillment lines / with a line counted / value'
                   || ' not yet sent to billing / F7.1 row 6 value / verdict'),
           TO_CHAR(s.n_orders || ' / ' || s.n_with_lines || ' / ' || s.n_with_counted
                   || ' / ' || TO_CHAR(t.open_amt, 'FM999,999,999,990.00') || ' / '
                   || TO_CHAR(v.v6, 'FM999,999,999,990.00') || ' / '
                   || CASE WHEN ABS(t.open_amt - v.v6) < 0.005 THEN 'OK ties'
                           ELSE 'CHECK: does not tie' END)
    FROM        f_ord_sum s
    CROSS JOIN  f_tot     t
    CROSS JOIN  t_val     v
    UNION ALL
    SELECT 601, TO_CHAR('F row 6 sales orders'),
           TO_CHAR('F1 for comparison: open lines including those already sent to billing'
                   || ' / every line not cancelled (the whole order value)'),
           TO_CHAR(TO_CHAR(t.open_incl_billing, 'FM999,999,999,990.00') || ' / '
                   || TO_CHAR(t.all_not_cancelled, 'FM999,999,999,990.00'))
    FROM   f_tot t
    UNION ALL
    SELECT 610 + g.rn, TO_CHAR('F row 6 sales orders'),
           TO_CHAR('F2 CATEGORY_CODE=' || g.category || ' OPEN_FLAG=' || g.open_flag
                   || ' CANCELED_FLAG=' || g.canceled_flag
                   || ' INVOICE_INTERFACED_FLAG=' || g.interfaced || ' counted=' || g.counted
                   || ': lines / amount / lines with no amount'),
           TO_CHAR(g.n_lines || ' / ' || TO_CHAR(g.amt, 'FM999,999,999,990.00') || ' / '
                   || g.n_null_amt)
    FROM   f_flag_rows g
    WHERE  g.rn <= 20
    UNION ALL
    SELECT 640 + r.rn, TO_CHAR('F row 6 sales orders'),
           TO_CHAR('F3 order version SUBMITTED_FLAG=' || r.submitted || ': open orders'
                   || ' (1,077 never submitted on 2026-10-05, R024)'),
           TO_CHAR(r.n || ' orders')
    FROM   f_sub_rows r
    WHERE  r.rn <= 5
    UNION ALL
    SELECT 650 + r.rn, TO_CHAR('F row 6 sales orders'),
           TO_CHAR('F4 order currency=' || r.currency || ': open orders / value'),
           TO_CHAR(r.n_orders || ' / ' || TO_CHAR(r.open_amt, 'FM999,999,999,990.00'))
    FROM   f_cur_rows r
    WHERE  r.rn <= 10
    UNION ALL
    SELECT 670 + r.rn, TO_CHAR('F row 6 sales orders'),
           TO_CHAR('F5 order version SUBMITTED_FLAG=' || r.submitted || ': open orders / with'
                   || ' an open line not yet billed / those lines / lines with no amount /'
                   || ' value'),
           TO_CHAR(r.n_orders || ' / ' || r.n_with_open || ' / ' || r.n_lines || ' / '
                   || r.n_null_amt || ' / ' || TO_CHAR(r.open_amt, 'FM999,999,999,990.00'))
    FROM   f_subv_rows r
    WHERE  r.rn <= 5
)
SELECT  g.ord         AS ord,
        g.section     AS section,
        g.item        AS item,
        g.value_text  AS value_text
FROM    grid g
ORDER BY g.ord
