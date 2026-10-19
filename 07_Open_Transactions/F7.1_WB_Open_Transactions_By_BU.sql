-- ============================================================================
--  F7.1_WB  Workbook WB8: open transactions by business unit (section 7.1)
--  File      : Fusion_Discovery_7_1_Open_Transactions_By_BU.xlsx
--  Version   : 1.4 (2026-10-12). Not yet run on a pod. Same open-item block
--              v1.4 as F7.1 v1.4: a Value on rows 1, 2, 3, 5 and 6 as well (the
--              amount not yet settled; see F7.1). Counts unchanged.
--              v1.3 (2026-10-05). Same open-item block as F7.1 v1.3: row 1 also leaves out requisition lines already on a
--              transfer order (R026).
--              v1.2: rows 9 (on-hand inventory) and 10 (open work orders)
--              added, as in EBS v3, so each BU now has 10 rows.
--              v1.1: rows 1 and 3 changed after V7_1 (R024) - see F7.1.
--              Log every run in 06_Run_Results/RUN_LOG.md.
--  Source    : Oracle Fusion Cloud (BIP data model, data source ApplicationDB_FSCM)
--  Mirrors   : EBS agent open_by_ou (EBS_Discovery_7_1_Open_Transactions_By_OU.xlsx,
--              "OU x class, including zeros"; 32 rows on Vision = 4 OUs x 8)
--  Window    : NONE (snapshot of the run day). Dates accepted and ignored.
--  Scope     : the shared block's bu_scope; blank ledger / BU = every BU that has
--              a primary ledger and is not inactive. One row per in-scope BU x 10
--              classes, ZEROS INCLUDED (a BU with nothing open still shows 10 rows).
--              Rows 9-10 are attributed through the inventory org's BU.
--
--  OUTPUT  Business Unit | BU Id | Open Transaction | Count | Value
--    Value on rows 1-8 (v1.4), entered currency, as F7.1; rows 9-10 count only.
--
--  RECONCILIATION: the OPEN-ITEM BLOCK below is byte-identical to F7.1, so for
--  the same parameters each class summed over the BU rows = that F7.1 row
--  (Count and Value). All 10 must tie. Class rules and BU rules: see F7.1.
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
bu_names AS (
    SELECT b.bu_id, MAX(bu.bu_name) AS bu_name
    FROM   bu_scope                 b
    JOIN   fun_all_business_units_v bu ON bu.bu_id = b.bu_id
    GROUP  BY b.bu_id
),
cls AS (
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
)
-- open_items holds one row per (bu_id, seq), so this LEFT JOIN cannot fan out.
SELECT
    n.bu_name                                                 AS "Business Unit",
    n.bu_id                                                   AS "BU Id",
    c.open_item                                               AS "Open Transaction",
    NVL(oi.cnt, 0)                                            AS "Count",
    CASE WHEN c.has_value = 'Y' THEN NVL(oi.amt, 0) END       AS "Value"
FROM        bu_names   n
CROSS JOIN  cls        c
LEFT JOIN   open_items oi ON oi.bu_id = n.bu_id
                         AND oi.seq   = c.seq
ORDER BY    n.bu_name, n.bu_id, c.seq
