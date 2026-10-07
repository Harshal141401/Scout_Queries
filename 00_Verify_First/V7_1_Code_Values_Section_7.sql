-- ============================================================================
--  V7_1  CODE VALUES + SANITY - the stored values Section 7 tests (run after V7_0)
--  Version   : 1.3 (2026-10-05)        Run log: 06_Run_Results/RUN_LOG.md
--  v1.3 (after R026): block A follows F7.1 v1.3 - a line on a transfer order
--       (TO_HEADER_ID) is no longer open demand; A2 shows LINE_STATUS x order
--       link (PO / transfer order / none) x transfer-requisition flag, A4 the
--       counted lines' LIFECYCLE_STATUS. Block I3 now prints the stored
--       OWNING_TYPE values and whether the owner is the org itself: v1.2's
--       "consigned = OWNING_TYPE set" was wrong - it is set on every row (R026).
--  v1.2 adds blocks I / J / K for F7.1 v1.2's new rows 9 (on-hand inventory,
--       item-org) and 10 (open work orders): on-hand pairs by net sign,
--       consigned stock and layers; every work-order system status with
--       "counted", the counted ones by type, the Unreleased count (EBS's open
--       decision); and the inventory-org -> BU map they are attributed by.
--  v1.1 (after R024): block A follows F7.1 v1.1's requisition rule (approved
--       line, PO_HEADER_ID empty) and shows every LINE_STATUS x PO link x
--       CANCEL_FLAG with "counted", plus the counted lines by internal-transfer
--       flag and destination type; block C's predicate also leaves out CANCELED
--       schedules; D6 / D7 test that AP cancellation is in CANCELLED_DATE (the
--       PO lesson: CANCEL_FLAG was never set); F4 adds the receipts' open value.
--  For: F7.1_Open_Transactions, F7.1_WB_Open_Transactions_By_BU
--  Binds: none. Pod-wide on purpose: it also shows what the BU scope drops.
--
--  WHY: "open" in F7.1 rests on status codes that Fusion spells its own way:
--  requisition / PO DOCUMENT_STATUS, schedule SCHEDULE_STATUS, AP
--  PAYMENT_STATUS_FLAG, DOO OPEN_FLAG / CANCELED_FLAG, AR STATUS / CLASS. A code
--  spelled differently silently moves documents in or out of "open". Each block
--  lists every stored value with its count AND whether F7.1 counts it (the same
--  predicate, copied). Read the "counted" column: a closed or cancelled value
--  marked counted Y, or an open value marked N, is a defect - send it back.
--
--  OUTPUT  ord | section | item | value_text   (one grid, paste it back whole)
--    A 100-139  requisitions: header DOCUMENT_STATUS (A0 verdict); A2 every
--               line of an approved requisition by LINE_STATUS x order link x
--               transfer-requisition flag, counted Y / N (110 = summary); A3
--               the counted lines by transfer flag and destination type; A4 by
--               LIFECYCLE_STATUS
--    B 200-219  STANDARD PO headers: DOCUMENT_STATUS x APPROVED_FLAG x CANCEL_FLAG
--    C 300-319  PO schedules received > billed: SCHEDULE_STATUS x CANCEL_FLAG;
--               C9 amount-based schedules the quantity test cannot see
--    D 400-425  AP: PAYMENT_STATUS_FLAG (D0 verdict); open invoices by
--               currency; prepayments (all / never applied / also unpaid);
--               D6 / D7 cancellation recorded in CANCELLED_DATE
--    E 500-515  sales orders, one per order: OPEN_FLAG x CANCELED_FLAG x
--               STATUS_CODE, and how many were never submitted (drafts)
--    F 600-639  AR payment schedules STATUS x CLASS; open-invoice grain and
--               currency; open receipts: sign of the open amount, receipt
--               STATUS and reversal
--    G 700-706  scope loss: documents whose BU has no primary ledger or is
--               inactive - dropped from F7.1 even with blank parameters
--    H 800-829  the BUs in scope with blank parameters (WB8 rows = BUs x 10)
--    I 900-916  on-hand (row 9): I0 expected F7.1 row 9; item-org pairs by net
--               sign; stock layers; pairs lost to scope; I3 OWNING_TYPE values
--               (lookup INV_OWNING_TYPES) x owner = the org itself or not
--    J 1000-1030 work orders (row 10): J0 expected F7.1 row 10 and the
--               Unreleased count; every system status (with its lookup
--               meaning) x status code, counted Y / N; counted by type;
--               status table grain
--    K 1101-1102 inventory org -> BU: orgs mapped, orgs with no / out-of-scope
--               / two BUs
--  Pure SELECT. Nothing is written.
-- ============================================================================
WITH
-- the shared block's bu_scope with blank parameters
bu_all AS (
    SELECT bu.bu_id,
           MAX(bu.bu_name)           AS bu_name,
           MAX(bu.primary_ledger_id) AS ledger_id
    FROM   fun_all_business_units_v bu
    WHERE  bu.primary_ledger_id IS NOT NULL
    AND    NVL(UPPER(bu.status), 'A') NOT IN ('I', 'INACTIVE')
    GROUP  BY bu.bu_id
),
-- ---- A requisitions -----------------------------------------------------------
req_status AS (
    SELECT NVL(TO_CHAR(rh.document_status), '(null)') AS val, COUNT(*) AS n
    FROM   por_requisition_headers_all rh
    GROUP  BY NVL(TO_CHAR(rh.document_status), '(null)')
),
req_status_rows AS (
    SELECT x.val, x.n, ROW_NUMBER() OVER (ORDER BY x.n DESC, x.val) AS rn
    FROM   req_status x
),
req_chk AS (
    SELECT NVL(SUM(CASE WHEN x.val = 'APPROVED' THEN x.n END), 0) AS n_approved,
           NVL(SUM(x.n), 0)                                       AS n_all
    FROM   req_status x
),
req_line_base AS (
    SELECT rh.requisition_header_id,
           NVL(TO_CHAR(rl.line_status), '(null)')                     AS line_status,
           CASE WHEN rl.po_header_id IS NOT NULL AND rl.to_header_id IS NOT NULL
                     THEN 'on a PO and a transfer order'
                WHEN rl.po_header_id IS NOT NULL THEN 'on a PO'
                WHEN rl.to_header_id IS NOT NULL THEN 'on a transfer order'
                ELSE 'on no order' END                                AS link_state,
           CASE WHEN rl.line_location_id IS NULL THEN 0 ELSE 1 END    AS loc_set,
           CASE WHEN NVL(rl.cancel_flag, 'N') = 'N'
                AND  rl.line_status = 'APPROVED'
                AND  NVL(rl.to_header_id, rl.po_header_id) IS NULL
                THEN 'Y' ELSE 'N' END                                 AS counted,
           NVL(TO_CHAR(rh.internal_transfer_req_flag), '(null)')     AS transfer_flag,
           NVL(TO_CHAR(rl.destination_type_code), '(null)')           AS dest_type,
           NVL(TO_CHAR(rl.lifecycle_status), '(null)')                AS lifecycle
    FROM   por_requisition_lines_all   rl
    JOIN   por_requisition_headers_all rh ON rh.requisition_header_id = rl.requisition_header_id
    WHERE  rh.document_status = 'APPROVED'
),
req_line_combo AS (
    SELECT b.line_status, b.link_state, b.transfer_flag, b.counted, COUNT(*) AS n
    FROM   req_line_base b
    GROUP  BY b.line_status, b.link_state, b.transfer_flag, b.counted
),
req_line_rows AS (
    SELECT x.line_status, x.link_state, x.transfer_flag, x.counted, x.n,
           ROW_NUMBER() OVER (ORDER BY x.n DESC, x.line_status, x.link_state,
                                       x.transfer_flag) AS rn
    FROM   req_line_combo x
),
req_counted_mix AS (
    SELECT b.transfer_flag, b.dest_type, COUNT(*) AS n
    FROM   req_line_base b
    WHERE  b.counted = 'Y'
    GROUP  BY b.transfer_flag, b.dest_type
),
req_counted_mix_rows AS (
    SELECT x.transfer_flag, x.dest_type, x.n,
           ROW_NUMBER() OVER (ORDER BY x.n DESC, x.transfer_flag, x.dest_type) AS rn
    FROM   req_counted_mix x
),
req_counted_life AS (
    SELECT b.lifecycle AS val, COUNT(*) AS n
    FROM   req_line_base b
    WHERE  b.counted = 'Y'
    GROUP  BY b.lifecycle
),
req_counted_life_rows AS (
    SELECT x.val, x.n, ROW_NUMBER() OVER (ORDER BY x.n DESC, x.val) AS rn
    FROM   req_counted_life x
),
req_open_hdr_list AS (
    SELECT b.requisition_header_id,
           MAX(CASE WHEN b.transfer_flag = 'Y' THEN 1 ELSE 0 END) AS is_transfer
    FROM   req_line_base b
    WHERE  b.counted = 'Y'
    GROUP  BY b.requisition_header_id
),
req_open_hdrs AS (
    SELECT COUNT(*) AS n_req, NVL(SUM(h.is_transfer), 0) AS n_req_transfer
    FROM   req_open_hdr_list h
),
req_line_chk AS (
    SELECT COUNT(*)                                                   AS n_lines,
           NVL(SUM(CASE WHEN b.counted = 'Y' THEN 1 ELSE 0 END), 0)   AS n_counted,
           NVL(SUM(CASE WHEN b.link_state LIKE '%transfer order%'
                        THEN 1 ELSE 0 END), 0)                        AS n_on_to,
           NVL(SUM(b.loc_set), 0)                                     AS n_loc_set
    FROM   req_line_base b
),
-- ---- B STANDARD PO headers (counted = the F7.1 class 2 predicate) -------------
po_hdr_base AS (
    SELECT NVL(TO_CHAR(ph.document_status), '(null)') AS doc_status,
           NVL(TO_CHAR(ph.approved_flag), '(null)')   AS appr,
           NVL(TO_CHAR(ph.cancel_flag), '(null)')     AS canc,
           CASE WHEN NVL(ph.cancel_flag, 'N') = 'N'
                AND  ph.approved_flag = 'Y'
                AND  REPLACE(UPPER(NVL(ph.document_status, 'OPEN')), '_', ' ')
                         NOT IN ('CLOSED', 'FINALLY CLOSED', 'CANCELED', 'CANCELLED')
                THEN 'Y' ELSE 'N' END                  AS counted
    FROM   po_headers_all ph
    WHERE  ph.type_lookup_code = 'STANDARD'
),
po_hdr_combo AS (
    SELECT p.doc_status, p.appr, p.canc, p.counted, COUNT(*) AS n
    FROM   po_hdr_base p
    GROUP  BY p.doc_status, p.appr, p.canc, p.counted
),
po_hdr_rows AS (
    SELECT x.doc_status, x.appr, x.canc, x.counted, x.n,
           ROW_NUMBER() OVER (ORDER BY x.n DESC, x.doc_status, x.appr, x.canc) AS rn
    FROM   po_hdr_combo x
),
po_hdr_chk AS (
    SELECT NVL(SUM(CASE WHEN x.counted = 'Y' THEN x.n END), 0) AS n_counted,
           NVL(SUM(x.n), 0)                                    AS n_all,
           COUNT(*)                                            AS n_combos
    FROM   po_hdr_combo x
),
-- ---- C PO schedules received > billed (counted = the F7.1 class 3 predicate) --
pll_base AS (
    SELECT NVL(TO_CHAR(pll.schedule_status), '(null)') AS sch_status,
           NVL(TO_CHAR(pll.cancel_flag), '(null)')     AS canc,
           CASE WHEN NVL(pll.cancel_flag, 'N') = 'N'
                AND  REPLACE(UPPER(NVL(pll.schedule_status, 'OPEN')), '_', ' ')
                         NOT IN ('CLOSED', 'FINALLY CLOSED', 'CANCELED', 'CANCELLED')
                THEN 'Y' ELSE 'N' END                   AS counted
    FROM   po_line_locations_all pll
    WHERE  NVL(pll.quantity_received, 0) > NVL(pll.quantity_billed, 0)
),
pll_combo AS (
    SELECT p.sch_status, p.canc, p.counted, COUNT(*) AS n
    FROM   pll_base p
    GROUP  BY p.sch_status, p.canc, p.counted
),
pll_rows AS (
    SELECT x.sch_status, x.canc, x.counted, x.n,
           ROW_NUMBER() OVER (ORDER BY x.n DESC, x.sch_status, x.canc) AS rn
    FROM   pll_combo x
),
pll_chk AS (
    SELECT NVL(SUM(CASE WHEN x.counted = 'Y' THEN x.n END), 0) AS n_counted,
           NVL(SUM(x.n), 0)                                    AS n_all
    FROM   pll_combo x
),
pll_amount AS (
    SELECT COUNT(*) AS n
    FROM   po_line_locations_all pll
    WHERE  NVL(pll.amount_received, 0) > NVL(pll.amount_billed, 0)
    AND    NOT ( NVL(pll.quantity_received, 0) > NVL(pll.quantity_billed, 0) )
    AND    NVL(pll.cancel_flag, 'N') = 'N'
),
-- ---- D Payables -----------------------------------------------------------------
ap_flag AS (
    SELECT NVL(TO_CHAR(ai.payment_status_flag), '(null)')          AS val,
           COUNT(*)                                                AS n,
           NVL(SUM(ai.invoice_amount - NVL(ai.amount_paid, 0)), 0) AS open_amt
    FROM   ap_invoices_all ai
    WHERE  ai.cancelled_date IS NULL
    GROUP  BY NVL(TO_CHAR(ai.payment_status_flag), '(null)')
),
ap_flag_rows AS (
    SELECT x.val, x.n, x.open_amt, ROW_NUMBER() OVER (ORDER BY x.n DESC, x.val) AS rn
    FROM   ap_flag x
),
ap_flag_chk AS (
    SELECT NVL(SUM(CASE WHEN x.val NOT IN ('N', 'P', 'Y') THEN x.n END), 0) AS n_other,
           NVL(SUM(CASE WHEN x.val IN ('N', 'P') THEN x.n END), 0)        AS n_open
    FROM   ap_flag x
),
ap_ccy AS (
    SELECT NVL(TO_CHAR(ai.invoice_currency_code), '(null)')        AS val,
           COUNT(*)                                                AS n,
           NVL(SUM(ai.invoice_amount - NVL(ai.amount_paid, 0)), 0) AS open_amt
    FROM   ap_invoices_all ai
    WHERE  ai.cancelled_date IS NULL
    AND    NVL(ai.payment_status_flag, 'N') IN ('N', 'P')
    GROUP  BY NVL(TO_CHAR(ai.invoice_currency_code), '(null)')
),
ap_ccy_rows AS (
    SELECT x.val, x.n, x.open_amt, ROW_NUMBER() OVER (ORDER BY x.n DESC, x.val) AS rn
    FROM   ap_ccy x
),
prepay_applied AS (
    SELECT pd.invoice_id
    FROM   ap_invoice_distributions_all pd
    JOIN   ap_invoice_distributions_all cd
           ON cd.prepay_distribution_id = pd.invoice_distribution_id
    GROUP  BY pd.invoice_id
),
prepay_base AS (
    SELECT ai.invoice_id,
           NVL(TO_CHAR(ai.payment_status_flag), 'N')             AS psf,
           CASE WHEN pa.invoice_id IS NULL THEN 'N' ELSE 'Y' END AS applied
    FROM        ap_invoices_all ai
    LEFT JOIN   prepay_applied  pa ON pa.invoice_id = ai.invoice_id
    WHERE       ai.cancelled_date IS NULL
    AND         ai.invoice_type_lookup_code = 'PREPAYMENT'
),
prepay_chk AS (
    SELECT COUNT(*)                                                       AS n_all,
           NVL(SUM(CASE WHEN p.applied = 'N' THEN 1 ELSE 0 END), 0)       AS n_open,
           NVL(SUM(CASE WHEN p.applied = 'N' AND p.psf IN ('N', 'P')
                        THEN 1 ELSE 0 END), 0)                            AS n_open_in_row4
    FROM   prepay_base p
),
ap_cancel_chk AS (
    SELECT NVL(SUM(CASE WHEN ai.cancelled_date IS NOT NULL THEN 1 ELSE 0 END), 0) AS n_cancelled,
           NVL(SUM(CASE WHEN ai.cancelled_date IS NULL
                         AND ( ai.cancelled_by IS NOT NULL
                               OR NVL(ai.cancelled_amount, 0) <> 0 )
                        THEN 1 ELSE 0 END), 0)                           AS n_mark_no_date
    FROM   ap_invoices_all ai
),
-- ---- E sales orders, one per order (counted = the F7.1 class 6 predicate) ------
so_rev AS (
    SELECT dh.order_number,
           dh.source_order_system,
           MAX(dh.open_flag) KEEP (DENSE_RANK FIRST ORDER BY
               CASE WHEN dh.submitted_flag = 'Y' THEN 0 ELSE 1 END, dh.header_id DESC)
                                                                    AS open_flag,
           MAX(dh.canceled_flag) KEEP (DENSE_RANK FIRST ORDER BY
               CASE WHEN dh.submitted_flag = 'Y' THEN 0 ELSE 1 END, dh.header_id DESC)
                                                                    AS canceled_flag,
           MAX(dh.status_code) KEEP (DENSE_RANK FIRST ORDER BY
               CASE WHEN dh.submitted_flag = 'Y' THEN 0 ELSE 1 END, dh.header_id DESC)
                                                                    AS status_code,
           MAX(CASE WHEN dh.submitted_flag = 'Y' THEN 1 ELSE 0 END)  AS ever_submitted
    FROM   doo_headers_all dh
    GROUP  BY dh.order_number, dh.source_order_system
),
so_base AS (
    SELECT NVL(TO_CHAR(s.open_flag), '(null)')     AS openf,
           NVL(TO_CHAR(s.canceled_flag), '(null)') AS cancf,
           NVL(TO_CHAR(s.status_code), '(null)')   AS st,
           CASE WHEN NVL(s.open_flag, 'N') = 'Y'
                AND  NVL(s.canceled_flag, 'N') = 'N'
                THEN 'Y' ELSE 'N' END               AS counted,
           s.ever_submitted
    FROM   so_rev s
),
so_combo AS (
    SELECT b.openf, b.cancf, b.st, b.counted, COUNT(*) AS n,
           NVL(SUM(CASE WHEN b.ever_submitted = 0 THEN 1 ELSE 0 END), 0) AS n_never_submitted
    FROM   so_base b
    GROUP  BY b.openf, b.cancf, b.st, b.counted
),
so_rows AS (
    SELECT x.openf, x.cancf, x.st, x.counted, x.n, x.n_never_submitted,
           ROW_NUMBER() OVER (ORDER BY x.n DESC, x.openf, x.cancf, x.st) AS rn
    FROM   so_combo x
),
so_chk AS (
    SELECT NVL(SUM(CASE WHEN x.counted = 'Y' THEN x.n END), 0)                 AS n_counted,
           NVL(SUM(CASE WHEN x.counted = 'Y' THEN x.n_never_submitted END), 0) AS n_counted_draft,
           NVL(SUM(x.n), 0)                                                    AS n_all
    FROM   so_combo x
),
-- ---- F Receivables ----------------------------------------------------------------
ps_combo AS (
    SELECT NVL(TO_CHAR(ps.status), '(null)') AS st,
           NVL(TO_CHAR(ps.class), '(null)')  AS cl,
           COUNT(*)                          AS n
    FROM   ar_payment_schedules_all ps
    GROUP  BY NVL(TO_CHAR(ps.status), '(null)'), NVL(TO_CHAR(ps.class), '(null)')
),
ps_rows AS (
    SELECT x.st, x.cl, x.n, ROW_NUMBER() OVER (ORDER BY x.n DESC, x.st, x.cl) AS rn
    FROM   ps_combo x
),
ar_inv_open AS (
    SELECT ps.customer_trx_id,
           MAX(NVL(TO_CHAR(ps.invoice_currency_code), '(null)')) AS ccy,
           SUM(NVL(ps.amount_due_remaining, 0))                  AS amt,
           COUNT(*)                                              AS n_sched
    FROM   ar_payment_schedules_all ps
    WHERE  ps.status = 'OP'
    AND    ps.class  = 'INV'
    GROUP  BY ps.customer_trx_id
),
ar_grain AS (
    SELECT NVL(SUM(a.n_sched), 0) AS n_rows, COUNT(*) AS n_trx
    FROM   ar_inv_open a
),
ar_ccy AS (
    SELECT a.ccy AS val, COUNT(*) AS n, NVL(SUM(a.amt), 0) AS open_amt
    FROM   ar_inv_open a
    GROUP  BY a.ccy
),
ar_ccy_rows AS (
    SELECT x.val, x.n, x.open_amt, ROW_NUMBER() OVER (ORDER BY x.n DESC, x.val) AS rn
    FROM   ar_ccy x
),
pmt_open AS (
    SELECT ps.cash_receipt_id, SUM(NVL(ps.amount_due_remaining, 0)) AS amt
    FROM   ar_payment_schedules_all ps
    WHERE  ps.class  = 'PMT'
    AND    ps.status = 'OP'
    GROUP  BY ps.cash_receipt_id
),
pmt_sign AS (
    SELECT COUNT(*)                                           AS n_all,
           NVL(SUM(CASE WHEN p.amt < 0 THEN 1 ELSE 0 END), 0) AS n_neg,
           NVL(SUM(CASE WHEN p.amt > 0 THEN 1 ELSE 0 END), 0) AS n_pos,
           NVL(SUM(CASE WHEN p.amt = 0 THEN 1 ELSE 0 END), 0) AS n_zero,
           NVL(SUM(ABS(p.amt)), 0)                            AS open_abs
    FROM   pmt_open p
),
rcpt_base AS (
    SELECT NVL(TO_CHAR(cr.status), '(null)')                      AS st,
           CASE WHEN cr.reversal_date IS NULL THEN 'not reversed'
                ELSE 'REVERSAL_DATE set' END                      AS rev,
           CASE WHEN cr.reversal_date IS NULL
                AND  NVL(cr.status, 'X') <> 'REV'
                THEN 'Y' ELSE 'N' END                             AS counted
    FROM   pmt_open             p
    JOIN   ar_cash_receipts_all cr ON cr.cash_receipt_id = p.cash_receipt_id
),
rcpt_combo AS (
    SELECT b.st, b.rev, b.counted, COUNT(*) AS n
    FROM   rcpt_base b
    GROUP  BY b.st, b.rev, b.counted
),
rcpt_rows AS (
    SELECT x.st, x.rev, x.counted, x.n,
           ROW_NUMBER() OVER (ORDER BY x.n DESC, x.st, x.rev) AS rn
    FROM   rcpt_combo x
),
-- ---- G scope loss with blank parameters ----------------------------------------
g_req AS (
    SELECT COUNT(*)                                                   AS n_all,
           NVL(SUM(CASE WHEN b.bu_id IS NULL THEN 1 ELSE 0 END), 0)   AS n_out
    FROM        por_requisition_headers_all rh
    LEFT JOIN   bu_all                      b ON b.bu_id = rh.req_bu_id
),
g_po AS (
    SELECT COUNT(*)                                                   AS n_all,
           NVL(SUM(CASE WHEN b1.bu_id IS NULL AND b2.bu_id IS NULL
                         AND b3.bu_id IS NULL THEN 1 ELSE 0 END), 0)  AS n_out
    FROM        po_headers_all ph
    LEFT JOIN   bu_all         b1 ON b1.bu_id = ph.prc_bu_id
    LEFT JOIN   bu_all         b2 ON b2.bu_id = ph.req_bu_id
    LEFT JOIN   bu_all         b3 ON b3.bu_id = ph.billto_bu_id
),
g_ap AS (
    SELECT COUNT(*)                                                   AS n_all,
           NVL(SUM(CASE WHEN b.bu_id IS NULL THEN 1 ELSE 0 END), 0)   AS n_out
    FROM        ap_invoices_all ai
    LEFT JOIN   bu_all          b ON b.bu_id = ai.org_id
),
g_so AS (
    SELECT COUNT(*)                                                   AS n_all,
           NVL(SUM(CASE WHEN b.bu_id IS NULL THEN 1 ELSE 0 END), 0)   AS n_out
    FROM        doo_headers_all dh
    LEFT JOIN   bu_all          b ON b.bu_id = dh.org_id
),
g_ar AS (
    SELECT COUNT(*)                                                   AS n_all,
           NVL(SUM(CASE WHEN b.bu_id IS NULL THEN 1 ELSE 0 END), 0)   AS n_out
    FROM        ra_customer_trx_all ct
    LEFT JOIN   bu_all              b ON b.bu_id = ct.org_id
),
g_rc AS (
    SELECT COUNT(*)                                                   AS n_all,
           NVL(SUM(CASE WHEN b.bu_id IS NULL THEN 1 ELSE 0 END), 0)   AS n_out
    FROM        ar_cash_receipts_all cr
    LEFT JOIN   bu_all               b ON b.bu_id = cr.org_id
),
-- ---- H business units -------------------------------------------------------------
bu_rows AS (
    SELECT a.bu_id, a.bu_name, a.ledger_id,
           ROW_NUMBER() OVER (ORDER BY a.bu_name, a.bu_id) AS rn
    FROM   bu_all a
),
bu_cnt AS (
    SELECT COUNT(*) AS n FROM bu_all
),
bu_view_cnt AS (
    SELECT COUNT(*) AS n_view
    FROM  ( SELECT bu.bu_id FROM fun_all_business_units_v bu GROUP BY bu.bu_id )
),
-- ---- K inventory org -> BU (rows 9-10), blank parameters ------------------------
io_map AS (
    SELECT iod.organization_id,
           MAX(iod.business_unit_id) AS bu_id,
           MIN(iod.business_unit_id) AS bu_id_min
    FROM   inv_organization_definitions_v iod
    GROUP  BY iod.organization_id
),
io_chk AS (
    SELECT COUNT(*)                                                         AS n_orgs,
           NVL(SUM(CASE WHEN m.bu_id IS NULL THEN 1 ELSE 0 END), 0)         AS n_no_bu,
           NVL(SUM(CASE WHEN m.bu_id IS NOT NULL AND b.bu_id IS NULL
                        THEN 1 ELSE 0 END), 0)                              AS n_bu_out,
           NVL(SUM(CASE WHEN m.bu_id <> m.bu_id_min THEN 1 ELSE 0 END), 0)  AS n_two_bu
    FROM        io_map m
    LEFT JOIN   bu_all b ON b.bu_id = m.bu_id
),
-- ---- I on-hand inventory (row 9) ---------------------------------------------------
oh_pairs AS (
    SELECT oh.organization_id,
           oh.inventory_item_id,
           SUM(NVL(oh.primary_transaction_quantity, 0))                AS net_qty,
           COUNT(*)                                                    AS n_layers
    FROM   inv_onhand_quantities_detail oh
    GROUP  BY oh.organization_id, oh.inventory_item_id
),
oh_scoped AS (
    SELECT p.organization_id, p.inventory_item_id, p.net_qty, p.n_layers,
           CASE WHEN b.bu_id IS NULL THEN 0 ELSE 1 END AS in_scope
    FROM        oh_pairs p
    LEFT JOIN   io_map   m ON m.organization_id = p.organization_id
    LEFT JOIN   bu_all   b ON b.bu_id = m.bu_id
),
oh_chk AS (
    SELECT COUNT(*)                                                                  AS n_pairs,
           NVL(SUM(CASE WHEN o.net_qty > 0 THEN 1 ELSE 0 END), 0)                    AS n_pos,
           NVL(SUM(CASE WHEN o.net_qty < 0 THEN 1 ELSE 0 END), 0)                    AS n_neg,
           NVL(SUM(CASE WHEN o.net_qty = 0 THEN 1 ELSE 0 END), 0)                    AS n_zero,
           NVL(SUM(o.n_layers), 0)                                                   AS n_layers,
           NVL(SUM(CASE WHEN o.net_qty > 0 AND o.in_scope = 1 THEN 1 ELSE 0 END), 0) AS n_counted,
           NVL(SUM(CASE WHEN o.net_qty > 0 AND o.in_scope = 0 THEN 1 ELSE 0 END), 0) AS n_pos_out
    FROM   oh_scoped o
),
oh_items AS (
    SELECT COUNT(*) AS n_items
    FROM  ( SELECT o.inventory_item_id
            FROM   oh_scoped o
            WHERE  o.net_qty > 0 AND o.in_scope = 1
            GROUP  BY o.inventory_item_id )
),
oh_orgs AS (
    SELECT COUNT(*) AS n_orgs
    FROM  ( SELECT o.organization_id
            FROM   oh_scoped o
            WHERE  o.net_qty > 0 AND o.in_scope = 1
            GROUP  BY o.organization_id )
),
-- I3 who owns the stock: OWNING_TYPE is set on every row (R026), so its VALUE
-- and the owner id decide what is consigned, not its presence
oh_owning_base AS (
    SELECT NVL(TO_CHAR(oh.owning_type), '(null)')                       AS val,
           CASE WHEN oh.owning_entity_id IS NULL THEN 'no owner id'
                WHEN oh.owning_entity_id = oh.organization_id
                     THEN 'owner = the org itself'
                ELSE 'owner = another party' END                        AS owner_state
    FROM   inv_onhand_quantities_detail oh
),
oh_owning AS (
    SELECT b.val, b.owner_state, COUNT(*) AS n_rows
    FROM   oh_owning_base b
    GROUP  BY b.val, b.owner_state
),
oh_owning_names AS (
    SELECT lv.lookup_code,
           TO_CHAR(MAX(lv.meaning) KEEP (DENSE_RANK FIRST ORDER BY
               CASE WHEN lv.language = USERENV('LANG') THEN 0 ELSE 1 END)) AS meaning
    FROM   fnd_lookup_values lv
    WHERE  lv.lookup_type = 'INV_OWNING_TYPES'
    AND    lv.language IN (USERENV('LANG'), 'US')
    GROUP  BY lv.lookup_code
),
oh_owning_rows AS (
    SELECT x.val, x.owner_state, x.n_rows, NVL(nm.meaning, '-') AS meaning,
           ROW_NUMBER() OVER (ORDER BY x.n_rows DESC, x.val, x.owner_state) AS rn
    FROM        oh_owning       x
    LEFT JOIN   oh_owning_names nm ON nm.lookup_code = x.val
),
-- ---- J work orders (row 10; counted = the F7.1 class 10 predicate) ---------------
wo_sys_names AS (
    SELECT lv.lookup_code,
           TO_CHAR(MAX(lv.meaning) KEEP (DENSE_RANK FIRST ORDER BY
               CASE WHEN lv.language = USERENV('LANG') THEN 0 ELSE 1 END)) AS meaning
    FROM   fnd_lookup_values lv
    WHERE  lv.lookup_type = 'ORA_WIE_WO_SYSTEM_STATUS'
    AND    lv.language IN (USERENV('LANG'), 'US')
    GROUP  BY lv.lookup_code
),
wo_st AS (
    SELECT st.wo_status_id,
           MAX(st.wo_status_code)        AS status_code,
           MAX(st.wo_system_status_code) AS system_status
    FROM   wie_wo_statuses_b st
    GROUP  BY st.wo_status_id
),
wo_st_grain AS (
    SELECT COUNT(*) AS n_rows FROM wie_wo_statuses_b st
),
wo_st_keys AS (
    SELECT COUNT(*) AS n_keys FROM wo_st
),
wo_base AS (
    SELECT NVL(TO_CHAR(s.system_status), '(no status row)')           AS sys_status,
           NVL(TO_CHAR(s.status_code), '(no status row)')             AS status_code,
           CASE WHEN REPLACE(REPLACE(UPPER(NVL(s.system_status, 'X')), 'ORA_', ''), '_', ' ')
                         IN ('RELEASED', 'ON HOLD')
                THEN 'Y' ELSE 'N' END                                  AS counted,
           CASE WHEN REPLACE(REPLACE(UPPER(NVL(s.system_status, 'X')), 'ORA_', ''), '_', ' ')
                         = 'UNRELEASED'
                THEN 1 ELSE 0 END                                      AS unreleased,
           NVL(TO_CHAR(wo.work_order_type), '(null)')                  AS wo_type,
           NVL(TO_CHAR(wo.work_order_sub_type), '(null)')              AS wo_sub_type,
           CASE WHEN b.bu_id IS NULL THEN 0 ELSE 1 END                 AS in_scope
    FROM        wie_work_orders_b wo
    LEFT JOIN   wo_st             s ON s.wo_status_id    = wo.work_order_status_id
    LEFT JOIN   io_map            m ON m.organization_id = wo.organization_id
    LEFT JOIN   bu_all            b ON b.bu_id           = m.bu_id
),
wo_combo AS (
    SELECT b.sys_status, b.status_code, b.counted, COUNT(*) AS n
    FROM   wo_base b
    GROUP  BY b.sys_status, b.status_code, b.counted
),
wo_rows AS (
    SELECT x.sys_status, x.status_code, x.counted, x.n,
           NVL(nm.meaning, '-')                                               AS meaning,
           ROW_NUMBER() OVER (ORDER BY x.n DESC, x.sys_status, x.status_code) AS rn
    FROM        wo_combo     x
    LEFT JOIN   wo_sys_names nm ON nm.lookup_code = x.sys_status
),
wo_kind AS (
    SELECT b.wo_type, b.wo_sub_type, COUNT(*) AS n
    FROM   wo_base b
    WHERE  b.counted = 'Y'
    GROUP  BY b.wo_type, b.wo_sub_type
),
wo_kind_rows AS (
    SELECT x.wo_type, x.wo_sub_type, x.n,
           ROW_NUMBER() OVER (ORDER BY x.n DESC, x.wo_type, x.wo_sub_type) AS rn
    FROM   wo_kind x
),
wo_chk AS (
    SELECT COUNT(*)                                                                    AS n_all,
           NVL(SUM(CASE WHEN b.counted = 'Y' AND b.in_scope = 1 THEN 1 ELSE 0 END), 0) AS n_counted,
           NVL(SUM(CASE WHEN b.counted = 'Y' AND b.in_scope = 0 THEN 1 ELSE 0 END), 0) AS n_counted_out,
           NVL(SUM(b.unreleased), 0)                                                   AS n_unreleased
    FROM   wo_base b
),
grid AS (
    -- A ------------------------------------------------------------------------
    SELECT 100                                                      AS ord,
           CAST('A requisitions' AS VARCHAR2(400))                  AS section,
           CAST('A0 verdict' AS VARCHAR2(400))                      AS item,
           CAST(CASE WHEN rc.n_approved > 0
                     THEN 'OK: ' || rc.n_approved || ' of ' || rc.n_all
                          || ' requisitions have DOCUMENT_STATUS = APPROVED'
                     ELSE '*** no DOCUMENT_STATUS = APPROVED: F7.1 row 1 would read 0'
                          || ' - send this back ***'
                END AS VARCHAR2(4000))                              AS value_text
    FROM   req_chk rc
    UNION ALL
    SELECT 100 + r.rn, TO_CHAR('A requisitions'), TO_CHAR('A1 DOCUMENT_STATUS=' || r.val),
           TO_CHAR(r.n || ' requisitions')
    FROM   req_status_rows r
    WHERE  r.rn <= 9
    UNION ALL
    SELECT 110, TO_CHAR('A requisitions'), TO_CHAR('A2 summary (F7.1 v1.3 row 1, pod-wide)'),
           TO_CHAR(ro.n_req || ' approved requisitions counted open (' || ro.n_req_transfer
                   || ' of them internal transfer requisitions): ' || rk.n_counted || ' of '
                   || rk.n_lines || ' lines are approved and on no order; ' || rk.n_on_to
                   || ' lines are on a transfer order; LINE_LOCATION_ID filled on '
                   || rk.n_loc_set || ' lines')
    FROM   req_open_hdrs ro CROSS JOIN req_line_chk rk
    UNION ALL
    SELECT 110 + l.rn, TO_CHAR('A requisitions'),
           TO_CHAR('A2 LINE_STATUS=' || l.line_status || ' / ' || l.link_state
                   || ' / transfer req=' || l.transfer_flag),
           TO_CHAR(l.n || ' lines on approved requisitions | counted ' || l.counted)
    FROM   req_line_rows l
    WHERE  l.rn <= 14
    UNION ALL
    SELECT 130 + m.rn, TO_CHAR('A requisitions'),
           TO_CHAR('A3 counted lines: INTERNAL_TRANSFER_REQ_FLAG=' || m.transfer_flag
                   || ' DESTINATION_TYPE_CODE=' || m.dest_type),
           TO_CHAR(m.n || ' lines')
    FROM   req_counted_mix_rows m
    WHERE  m.rn <= 4
    UNION ALL
    SELECT 134 + v.rn, TO_CHAR('A requisitions'),
           TO_CHAR('A4 counted lines: LIFECYCLE_STATUS=' || v.val),
           TO_CHAR(v.n || ' lines')
    FROM   req_counted_life_rows v
    WHERE  v.rn <= 5
    -- B ------------------------------------------------------------------------
    UNION ALL
    SELECT 200, TO_CHAR('B STANDARD PO headers'), TO_CHAR('B0 summary'),
           TO_CHAR('F7.1 counts ' || pc.n_counted || ' of ' || pc.n_all
                   || ' STANDARD POs as open (' || pc.n_combos || ' combinations below)')
    FROM   po_hdr_chk pc
    UNION ALL
    SELECT 200 + p.rn, TO_CHAR('B STANDARD PO headers'),
           TO_CHAR('B DOCUMENT_STATUS=' || p.doc_status || ' APPROVED_FLAG=' || p.appr
                   || ' CANCEL_FLAG=' || p.canc),
           TO_CHAR(p.n || ' POs | counted ' || p.counted)
    FROM   po_hdr_rows p
    WHERE  p.rn <= 19
    -- C ------------------------------------------------------------------------
    UNION ALL
    SELECT 300, TO_CHAR('C PO schedules received > billed'), TO_CHAR('C0 summary'),
           TO_CHAR('F7.1 counts ' || lc.n_counted || ' of ' || lc.n_all
                   || ' schedules received but not fully invoiced')
    FROM   pll_chk lc
    UNION ALL
    SELECT 300 + l.rn, TO_CHAR('C PO schedules received > billed'),
           TO_CHAR('C SCHEDULE_STATUS=' || l.sch_status || ' CANCEL_FLAG=' || l.canc),
           TO_CHAR(l.n || ' schedules | counted ' || l.counted)
    FROM   pll_rows l
    WHERE  l.rn <= 15
    UNION ALL
    SELECT 319, TO_CHAR('C PO schedules received > billed'),
           TO_CHAR('C9 amount received > billed, not counted by the quantity test'),
           TO_CHAR(pa.n || ' schedules (EBS rule leaves these out too)')
    FROM   pll_amount pa
    -- D ------------------------------------------------------------------------
    UNION ALL
    SELECT 400, TO_CHAR('D Payables'), TO_CHAR('D0 verdict'),
           TO_CHAR(CASE WHEN fc.n_other = 0
                        THEN 'OK: every PAYMENT_STATUS_FLAG is N / P / Y; ' || fc.n_open
                             || ' invoices are N or P (F7.1 row 4, pod-wide)'
                        ELSE 'CHECK: ' || fc.n_other || ' invoices have a flag outside'
                             || ' N / P / Y (empty counts as N in F7.1) - send this back'
                   END)
    FROM   ap_flag_chk fc
    UNION ALL
    SELECT 400 + f.rn, TO_CHAR('D Payables'), TO_CHAR('D1 PAYMENT_STATUS_FLAG=' || f.val),
           TO_CHAR(f.n || ' invoices | amount less paid ' || ROUND(f.open_amt, 2))
    FROM   ap_flag_rows f
    WHERE  f.rn <= 9
    UNION ALL
    SELECT 410 + c.rn, TO_CHAR('D Payables'), TO_CHAR('D2 open invoices, currency ' || c.val),
           TO_CHAR(c.n || ' invoices | open amount ' || ROUND(c.open_amt, 2))
    FROM   ap_ccy_rows c
    WHERE  c.rn <= 9
    UNION ALL
    SELECT 421, TO_CHAR('D Payables'), TO_CHAR('D3 prepayments, not cancelled'),
           TO_CHAR(pp.n_all || ' prepayments')
    FROM   prepay_chk pp
    UNION ALL
    SELECT 422, TO_CHAR('D Payables'), TO_CHAR('D4 never applied (F7.1 row 5, pod-wide)'),
           TO_CHAR(pp.n_open || ' prepayments')
    FROM   prepay_chk pp
    UNION ALL
    SELECT 423, TO_CHAR('D Payables'), TO_CHAR('D5 of D4, also unpaid or partly paid (so also in row 4)'),
           TO_CHAR(pp.n_open_in_row4 || ' prepayments')
    FROM   prepay_chk pp
    UNION ALL
    SELECT 424, TO_CHAR('D Payables'), TO_CHAR('D6 invoices cancelled (CANCELLED_DATE set)'),
           TO_CHAR(ac.n_cancelled || ' invoices')
    FROM   ap_cancel_chk ac
    UNION ALL
    SELECT 425, TO_CHAR('D Payables'),
           TO_CHAR('D7 CANCELLED_BY / CANCELLED_AMOUNT set but CANCELLED_DATE empty'),
           TO_CHAR(CASE WHEN ac.n_mark_no_date = 0
                        THEN 'OK: 0 - cancellation is recorded in CANCELLED_DATE'
                        ELSE '*** ' || ac.n_mark_no_date || ' invoices look cancelled without'
                             || ' CANCELLED_DATE: F7.1 row 4 would count them - send this back ***'
                   END)
    FROM   ap_cancel_chk ac
    -- E ------------------------------------------------------------------------
    UNION ALL
    SELECT 500, TO_CHAR('E sales orders (one per order)'), TO_CHAR('E0 summary'),
           TO_CHAR('F7.1 counts ' || sc.n_counted || ' of ' || sc.n_all
                   || ' orders as open; ' || sc.n_counted_draft
                   || ' of them were never submitted (drafts)')
    FROM   so_chk sc
    UNION ALL
    SELECT 500 + s.rn, TO_CHAR('E sales orders (one per order)'),
           TO_CHAR('E OPEN_FLAG=' || s.openf || ' CANCELED_FLAG=' || s.cancf
                   || ' STATUS_CODE=' || s.st),
           TO_CHAR(s.n || ' orders | counted ' || s.counted || ' | never submitted '
                   || s.n_never_submitted)
    FROM   so_rows s
    WHERE  s.rn <= 15
    -- F ------------------------------------------------------------------------
    UNION ALL
    SELECT 600 + p.rn, TO_CHAR('F Receivables'), TO_CHAR('F1 STATUS=' || p.st || ' CLASS=' || p.cl),
           TO_CHAR(p.n || ' payment schedule rows')
    FROM   ps_rows p
    WHERE  p.rn <= 12
    UNION ALL
    SELECT 620, TO_CHAR('F Receivables'), TO_CHAR('F2 open INV: schedule rows / transactions'),
           TO_CHAR(g.n_rows || ' / ' || g.n_trx)
    FROM   ar_grain g
    UNION ALL
    SELECT 620 + c.rn, TO_CHAR('F Receivables'), TO_CHAR('F3 open INV, currency ' || c.val),
           TO_CHAR(c.n || ' transactions | open amount ' || ROUND(c.open_amt, 2))
    FROM   ar_ccy_rows c
    WHERE  c.rn <= 9
    UNION ALL
    SELECT 630, TO_CHAR('F Receivables'),
           TO_CHAR('F4 open PMT receipts: negative / positive / zero / all | open value'),
           TO_CHAR(ps.n_neg || ' / ' || ps.n_pos || ' / ' || ps.n_zero || ' / ' || ps.n_all
                   || ' | ' || ROUND(ps.open_abs, 2))
    FROM   pmt_sign ps
    UNION ALL
    SELECT 630 + r.rn, TO_CHAR('F Receivables'),
           TO_CHAR('F5 open receipt STATUS=' || r.st || ', ' || r.rev),
           TO_CHAR(r.n || ' receipts | counted ' || r.counted)
    FROM   rcpt_rows r
    WHERE  r.rn <= 9
    -- G ------------------------------------------------------------------------
    UNION ALL
    SELECT 701, TO_CHAR('G scope loss (blank parameters)'),
           TO_CHAR('G1 requisitions: REQ_BU_ID outside / all'),
           TO_CHAR(x.n_out || ' / ' || x.n_all)
    FROM   g_req x
    UNION ALL
    SELECT 702, TO_CHAR('G scope loss (blank parameters)'),
           TO_CHAR('G2 PO headers: no BU of the three in scope / all'),
           TO_CHAR(x.n_out || ' / ' || x.n_all)
    FROM   g_po x
    UNION ALL
    SELECT 703, TO_CHAR('G scope loss (blank parameters)'),
           TO_CHAR('G3 AP invoices: ORG_ID outside / all'),
           TO_CHAR(x.n_out || ' / ' || x.n_all)
    FROM   g_ap x
    UNION ALL
    SELECT 704, TO_CHAR('G scope loss (blank parameters)'),
           TO_CHAR('G4 DOO header rows: ORG_ID outside / all'),
           TO_CHAR(x.n_out || ' / ' || x.n_all)
    FROM   g_so x
    UNION ALL
    SELECT 705, TO_CHAR('G scope loss (blank parameters)'),
           TO_CHAR('G5 AR transactions: ORG_ID outside / all'),
           TO_CHAR(x.n_out || ' / ' || x.n_all)
    FROM   g_ar x
    UNION ALL
    SELECT 706, TO_CHAR('G scope loss (blank parameters)'),
           TO_CHAR('G6 AR receipts: ORG_ID outside / all'),
           TO_CHAR(x.n_out || ' / ' || x.n_all)
    FROM   g_rc x
    -- H ------------------------------------------------------------------------
    UNION ALL
    SELECT 800, TO_CHAR('H business units'),
           TO_CHAR('H0 BUs in scope with blank parameters / BUs in the view'),
           TO_CHAR(bc.n || ' / ' || bv.n_view || ' (WB8 rows with blank parameters = '
                   || (bc.n * 10) || ')')
    FROM   bu_cnt bc CROSS JOIN bu_view_cnt bv
    UNION ALL
    SELECT 800 + b.rn, TO_CHAR('H business units'), TO_CHAR('H BU ' || b.bu_name),
           TO_CHAR('BU_ID ' || b.bu_id || ' | primary ledger ' || b.ledger_id)
    FROM   bu_rows b
    WHERE  b.rn <= 29
    -- I ------------------------------------------------------------------------
    UNION ALL
    SELECT 900, TO_CHAR('I on-hand inventory (row 9)'),
           TO_CHAR('I0 summary (F7.1 row 9, blank parameters)'),
           TO_CHAR(oc.n_counted || ' item-org pairs hold stock (' || oi.n_items
                   || ' items in ' || og.n_orgs || ' inventory orgs)')
    FROM   oh_chk oc CROSS JOIN oh_items oi CROSS JOIN oh_orgs og
    UNION ALL
    SELECT 901, TO_CHAR('I on-hand inventory (row 9)'),
           TO_CHAR('I1 item-org pairs: net > 0 / net < 0 (not counted) / net = 0 / all'),
           TO_CHAR(oc.n_pos || ' / ' || oc.n_neg || ' / ' || oc.n_zero || ' / ' || oc.n_pairs)
    FROM   oh_chk oc
    UNION ALL
    SELECT 902, TO_CHAR('I on-hand inventory (row 9)'),
           TO_CHAR('I2 on-hand rows (stock layers) behind the pairs'),
           TO_CHAR(oc.n_layers || ' rows')
    FROM   oh_chk oc
    UNION ALL
    SELECT 904, TO_CHAR('I on-hand inventory (row 9)'),
           TO_CHAR('I4 pairs with stock in an org with no in-scope BU (dropped)'),
           TO_CHAR(oc.n_pos_out || ' pairs')
    FROM   oh_chk oc
    UNION ALL
    SELECT 910 + w.rn, TO_CHAR('I on-hand inventory (row 9)'),
           TO_CHAR('I3 OWNING_TYPE=' || w.val || ' (' || w.meaning || '), ' || w.owner_state),
           TO_CHAR(w.n_rows || ' on-hand rows')
    FROM   oh_owning_rows w
    WHERE  w.rn <= 6
    -- J ------------------------------------------------------------------------
    UNION ALL
    SELECT 1000, TO_CHAR('J work orders (row 10)'),
           TO_CHAR('J0 summary (F7.1 row 10, blank parameters)'),
           TO_CHAR(wc.n_counted || ' of ' || wc.n_all || ' work orders are Released or On Hold;'
                   || ' Unreleased, not counted (EBS open decision): ' || wc.n_unreleased
                   || '; counted but in an org outside scope: ' || wc.n_counted_out)
    FROM   wo_chk wc
    UNION ALL
    SELECT 1000 + r.rn, TO_CHAR('J work orders (row 10)'),
           TO_CHAR('J WO_SYSTEM_STATUS_CODE=' || r.sys_status || ' (' || r.meaning
                   || ') WO_STATUS_CODE=' || r.status_code),
           TO_CHAR(r.n || ' work orders | counted ' || r.counted)
    FROM   wo_rows r
    WHERE  r.rn <= 15
    UNION ALL
    SELECT 1020 + k.rn, TO_CHAR('J work orders (row 10)'),
           TO_CHAR('J counted by WORK_ORDER_TYPE=' || k.wo_type
                   || ' WORK_ORDER_SUB_TYPE=' || k.wo_sub_type),
           TO_CHAR(k.n || ' work orders')
    FROM   wo_kind_rows k
    WHERE  k.rn <= 9
    UNION ALL
    SELECT 1030, TO_CHAR('J work orders (row 10)'),
           TO_CHAR('J9 status table: rows / WO_STATUS_ID keys'),
           TO_CHAR(sg.n_rows || ' / ' || sk.n_keys)
    FROM   wo_st_grain sg CROSS JOIN wo_st_keys sk
    -- K ------------------------------------------------------------------------
    UNION ALL
    SELECT 1101, TO_CHAR('K inventory org -> BU (rows 9-10)'),
           TO_CHAR('K1 inventory orgs in the view / with a BU in scope (blank parameters)'),
           TO_CHAR(ic.n_orgs || ' / ' || (ic.n_orgs - ic.n_no_bu - ic.n_bu_out))
    FROM   io_chk ic
    UNION ALL
    SELECT 1102, TO_CHAR('K inventory org -> BU (rows 9-10)'),
           TO_CHAR('K2 orgs with no BU / BU outside scope / two BUs (all should be 0)'),
           TO_CHAR(ic.n_no_bu || ' / ' || ic.n_bu_out || ' / ' || ic.n_two_bu)
    FROM   io_chk ic
)
SELECT  g.ord         AS ord,
        g.section     AS section,
        g.item        AS item,
        g.value_text  AS value_text
FROM    grid g
ORDER BY g.ord
