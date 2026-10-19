-- ============================================================================
--  V7_3  OPEN TRANSACTIONS RECONCILIATION - what is inside each F7.1 count
--  Version   : 1.0 (2026-10-13). Not yet run on a pod.
--              Run log: 06_Run_Results/RUN_LOG.md
--  For: F7.1_Open_Transactions v1.4 (open-item block v1.4). Run AFTER V7_0,
--  with the SAME ledger / BU as the F7.1 run being defended. F7.1 is a
--  run-day snapshot: the dates are accepted and ignored, here too.
--
--  WHY  To defend each F7.1 count document by document, the way V4_3 / V4_4
--  do for Section 4. Every document of each row's base table gets ONE reason:
--  'counted', or the first F7.1 test it fails (BU not in scope, cancelled,
--  closed, not approved, paid, applied, reversed ...). The tests are F7.1's
--  own predicates, copied; the "counted" rows must equal the F7.1 run.
--  V7_1 lists every stored code value and V7_2 checks the Values; this query
--  answers "which documents are these, and why are the others not in?".
--
--  OUTPUT  ord | block | item | value | note
--    Block k = F7.1 row k (1-10):
--      k001      the F7.1 row - MUST EQUAL the F7.1 run
--      k002-k005 alternative counts a reader may ask about (drafts, closed,
--                paid, reversed, Unreleased ...)
--      k101+     one row per reason x status combination, counted first;
--                note = the latest three document numbers to open in Fusion
--    1 requisitions   header DOCUMENT_STATUS x transfer flag (note: open lines)
--    2 POs            TYPE x DOCUMENT_STATUS x APPROVED_FLAG
--    3 PO receipts    schedules: SCHEDULE_STATUS x MATCHING_BASIS x
--                     SHIPMENT_TYPE (note: PO numbers)
--    4 AP invoices    type x PAYMENT_STATUS_FLAG
--    5 prepayments    PAYMENT_STATUS_FLAG
--    6 sales orders   one per order: submitted x STATUS_CODE (6002 = drafts,
--                     which F4.2 v1.3 no longer counts)
--    7 AR invoices    payment-schedule class x COMPLETE_FLAG
--    8 receipts       receipt STATUS
--    9 on-hand        (org, item) pairs per organization (note: org/item)
--    10 work orders   system status
--  Columns: every tested column is proved (V7_0 v1.4, R042). The document
--  numbers in "note" are not yet proved: POR_REQUISITION_HEADERS_ALL
--  .REQUISITION_NUMBER, PO_HEADERS_ALL.SEGMENT1, AP_INVOICES_ALL.INVOICE_NUM,
--  RA_CUSTOMER_TRX_ALL.TRX_NUMBER, AR_CASH_RECEIPTS_ALL.RECEIPT_NUMBER,
--  INV_ORGANIZATION_DEFINITIONS_V.ORGANIZATION_CODE, EGP_SYSTEM_ITEMS_B
--  .ITEM_NUMBER, WIE_WORK_ORDERS_B.WORK_ORDER_NUMBER. An ORA-00904 naming
--  one of them: report it.
--  Pure SELECT, one statement, every aggregate in its own CTE, no DISTINCT.
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
-- ---- F7.1 helpers, copied unchanged from the open-item block v1.4 --------
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
-- Work order statuses, one row per status id (the table carries seed-set
-- keys, so it is grouped before the join to keep work orders 1:1).
wo_status AS (
    SELECT st.wo_status_id,
           MAX(st.wo_system_status_code) AS system_status
    FROM   wie_wo_statuses_b st
    GROUP  BY st.wo_status_id
),
-- organization codes, one row per org (examples only)
org_codes AS (
    SELECT iod.organization_id, MAX(iod.organization_code) AS organization_code
    FROM   inv_organization_definitions_v iod
    GROUP  BY iod.organization_id
),
-- ---- row 1: open requisitions ----------------------------------------------
-- open lines per requisition: the F7.1 row 1 line rule (approved, not
-- cancelled, on no PO and no transfer order)
r1_line AS (
    SELECT rl.requisition_header_id, COUNT(*) AS n_lines
    FROM   por_requisition_lines_all rl
    WHERE  NVL(rl.cancel_flag, 'N') = 'N'
    AND    rl.line_status = 'APPROVED'
    AND    NVL(rl.to_header_id, rl.po_header_id) IS NULL
    GROUP  BY rl.requisition_header_id
),
r1_tag AS (
    SELECT rh.requisition_header_id                                   AS id,
           TO_CHAR(rh.requisition_number)                             AS doc_num,
           NVL(TO_CHAR(rh.document_status), '(null)')                 AS d1,
           NVL(TO_CHAR(rh.internal_transfer_req_flag), '(null)')      AS d2,
           '-'                                                        AS d3,
           NVL(ol.n_lines, 0)                                         AS extra,
           CASE WHEN b.bu_id IS NULL                            THEN 'BU not in scope'
                WHEN NVL(rh.document_status, '~') <> 'APPROVED' THEN 'header not APPROVED'
                WHEN ol.requisition_header_id IS NULL
                THEN 'no open line (every line on an order, cancelled or not approved)'
                ELSE 'counted'
           END                                                        AS reason
    FROM        por_requisition_headers_all rh
    LEFT JOIN   bu_scope b  ON b.bu_id = rh.req_bu_id
    LEFT JOIN   r1_line  ol ON ol.requisition_header_id = rh.requisition_header_id
),
r1_grp AS (
    SELECT reason, d1, d2, d3, COUNT(*) AS n, SUM(extra) AS extra
    FROM   r1_tag
    GROUP  BY reason, d1, d2, d3
),
r1_ex AS (
    SELECT reason, d1, d2, d3,
           LISTAGG(doc_num, ', ') WITHIN GROUP (ORDER BY id DESC, doc_num DESC) AS examples
    FROM  ( SELECT t.reason, t.d1, t.d2, t.d3, t.doc_num, t.id,
                   ROW_NUMBER() OVER (PARTITION BY t.reason, t.d1, t.d2, t.d3
                                      ORDER BY t.id DESC, t.doc_num DESC) AS rn
            FROM   r1_tag t )
    WHERE  rn <= 3
    GROUP  BY reason, d1, d2, d3
),
r1_det AS (
    SELECT g.reason, g.d1, g.d2, g.d3, g.n, g.extra, e.examples,
           ROW_NUMBER() OVER (ORDER BY CASE WHEN g.reason = 'counted' THEN 0 ELSE 1 END,
                                       g.reason, g.n DESC, g.d1, g.d2, g.d3) AS rn
    FROM        r1_grp g
    LEFT JOIN   r1_ex  e ON  e.reason = g.reason AND e.d1 = g.d1
                          AND e.d2     = g.d2     AND e.d3 = g.d3
),
r1_head AS (
    SELECT
           NVL(SUM(CASE WHEN reason = 'counted' THEN n END), 0) AS h1,
           NVL(SUM(CASE WHEN reason = 'counted' THEN extra END), 0) AS h2,
           NVL(SUM(CASE WHEN reason = 'counted' AND d2 = 'Y' THEN n END), 0) AS h3,
           NVL(SUM(CASE WHEN reason LIKE 'no open line%' THEN n END), 0) AS h4
    FROM   r1_grp
),
-- ---- row 2: open purchase orders -------------------------------------------
r2_tag AS (
    SELECT ph.po_header_id                                            AS id,
           TO_CHAR(ph.segment1)                                       AS doc_num,
           NVL(TO_CHAR(ph.type_lookup_code), '(null)')                AS d1,
           NVL(TO_CHAR(ph.document_status), '(null)')                 AS d2,
           NVL(TO_CHAR(ph.approved_flag), '(null)')                   AS d3,
           0                                                          AS extra,
           CASE WHEN pb.po_header_id IS NULL                          THEN 'BU not in scope'
                WHEN NVL(ph.type_lookup_code, '~') <> 'STANDARD'      THEN 'not a STANDARD PO (an agreement)'
                WHEN NVL(ph.cancel_flag, 'N') <> 'N'
                  OR REPLACE(UPPER(NVL(ph.document_status, 'OPEN')), '_', ' ')
                     IN ('CANCELED', 'CANCELLED')                     THEN 'cancelled'
                WHEN REPLACE(UPPER(NVL(ph.document_status, 'OPEN')), '_', ' ')
                     IN ('CLOSED', 'FINALLY CLOSED')                  THEN 'closed'
                WHEN NVL(ph.approved_flag, 'N') <> 'Y'                THEN 'not approved'
                ELSE 'counted'
           END                                                        AS reason
    FROM        po_headers_all ph
    LEFT JOIN   po_bu          pb ON pb.po_header_id = ph.po_header_id
),
r2_grp AS (
    SELECT reason, d1, d2, d3, COUNT(*) AS n, SUM(extra) AS extra
    FROM   r2_tag
    GROUP  BY reason, d1, d2, d3
),
r2_ex AS (
    SELECT reason, d1, d2, d3,
           LISTAGG(doc_num, ', ') WITHIN GROUP (ORDER BY id DESC, doc_num DESC) AS examples
    FROM  ( SELECT t.reason, t.d1, t.d2, t.d3, t.doc_num, t.id,
                   ROW_NUMBER() OVER (PARTITION BY t.reason, t.d1, t.d2, t.d3
                                      ORDER BY t.id DESC, t.doc_num DESC) AS rn
            FROM   r2_tag t )
    WHERE  rn <= 3
    GROUP  BY reason, d1, d2, d3
),
r2_det AS (
    SELECT g.reason, g.d1, g.d2, g.d3, g.n, g.extra, e.examples,
           ROW_NUMBER() OVER (ORDER BY CASE WHEN g.reason = 'counted' THEN 0 ELSE 1 END,
                                       g.reason, g.n DESC, g.d1, g.d2, g.d3) AS rn
    FROM        r2_grp g
    LEFT JOIN   r2_ex  e ON  e.reason = g.reason AND e.d1 = g.d1
                          AND e.d2     = g.d2     AND e.d3 = g.d3
),
r2_head AS (
    SELECT
           NVL(SUM(CASE WHEN reason = 'counted' THEN n END), 0) AS h1,
           NVL(SUM(CASE WHEN reason = 'closed' THEN n END), 0) AS h2,
           NVL(SUM(CASE WHEN reason = 'not approved' THEN n END), 0) AS h3,
           NVL(SUM(CASE WHEN reason LIKE 'not a STANDARD%' THEN n END), 0) AS h4
    FROM   r2_grp
),
-- ---- row 3: open PO receipts (schedules) -----------------------------------
r3_tag AS (
    SELECT pll.po_header_id                                           AS id,
           TO_CHAR(ph.segment1)                                       AS doc_num,
           NVL(TO_CHAR(pll.schedule_status), '(null)')                AS d1,
           NVL(TO_CHAR(pll.matching_basis), '(null)')                 AS d2,
           NVL(TO_CHAR(pll.shipment_type), '(null)')                  AS d3,
           0                                                          AS extra,
           CASE WHEN pb.po_header_id IS NULL                          THEN 'BU not in scope'
                WHEN NVL(pll.cancel_flag, 'N') <> 'N'
                  OR REPLACE(UPPER(NVL(pll.schedule_status, 'OPEN')), '_', ' ')
                     IN ('CANCELED', 'CANCELLED')                     THEN 'cancelled'
                WHEN REPLACE(UPPER(NVL(pll.schedule_status, 'OPEN')), '_', ' ')
                     IN ('CLOSED', 'FINALLY CLOSED')                  THEN 'closed'
                WHEN NVL(pll.quantity_received, 0) <= NVL(pll.quantity_billed, 0)
                 AND NVL(pll.quantity_received, 0) = 0                THEN 'nothing received'
                WHEN NVL(pll.quantity_received, 0) <= NVL(pll.quantity_billed, 0)
                                                                      THEN 'received and fully invoiced'
                ELSE 'counted'
           END                                                        AS reason
    FROM        po_line_locations_all pll
    LEFT JOIN   po_bu                 pb ON pb.po_header_id = pll.po_header_id
    LEFT JOIN   po_headers_all        ph ON ph.po_header_id = pll.po_header_id
),
r3_grp AS (
    SELECT reason, d1, d2, d3, COUNT(*) AS n, SUM(extra) AS extra
    FROM   r3_tag
    GROUP  BY reason, d1, d2, d3
),
r3_ex AS (
    SELECT reason, d1, d2, d3,
           LISTAGG(doc_num, ', ') WITHIN GROUP (ORDER BY id DESC, doc_num DESC) AS examples
    FROM  ( SELECT t.reason, t.d1, t.d2, t.d3, t.doc_num, t.id,
                   ROW_NUMBER() OVER (PARTITION BY t.reason, t.d1, t.d2, t.d3
                                      ORDER BY t.id DESC, t.doc_num DESC) AS rn
            FROM   r3_tag t )
    WHERE  rn <= 3
    GROUP  BY reason, d1, d2, d3
),
r3_det AS (
    SELECT g.reason, g.d1, g.d2, g.d3, g.n, g.extra, e.examples,
           ROW_NUMBER() OVER (ORDER BY CASE WHEN g.reason = 'counted' THEN 0 ELSE 1 END,
                                       g.reason, g.n DESC, g.d1, g.d2, g.d3) AS rn
    FROM        r3_grp g
    LEFT JOIN   r3_ex  e ON  e.reason = g.reason AND e.d1 = g.d1
                          AND e.d2     = g.d2     AND e.d3 = g.d3
),
r3_head AS (
    SELECT
           NVL(SUM(CASE WHEN reason = 'counted' THEN n END), 0) AS h1,
           NVL(SUM(CASE WHEN reason = 'received and fully invoiced' THEN n END), 0) AS h2,
           NVL(SUM(CASE WHEN reason = 'nothing received' THEN n END), 0) AS h3,
           NVL(SUM(CASE WHEN reason IN ('cancelled', 'closed') THEN n END), 0) AS h4
    FROM   r3_grp
),
-- ---- row 4: open Payables invoices -----------------------------------------
r4_tag AS (
    SELECT ai.invoice_id                                              AS id,
           TO_CHAR(ai.invoice_num)                                    AS doc_num,
           NVL(TO_CHAR(ai.invoice_type_lookup_code), '(no type)')     AS d1,
           NVL(TO_CHAR(ai.payment_status_flag), '(null)')             AS d2,
           '-'                                                        AS d3,
           0                                                          AS extra,
           CASE WHEN b.bu_id IS NULL                                  THEN 'BU not in scope'
                WHEN ai.cancelled_date IS NOT NULL                    THEN 'cancelled'
                WHEN NVL(ai.payment_status_flag, 'N') NOT IN ('N', 'P') THEN 'fully paid'
                ELSE 'counted'
           END                                                        AS reason
    FROM        ap_invoices_all ai
    LEFT JOIN   bu_scope        b ON b.bu_id = ai.org_id
),
r4_grp AS (
    SELECT reason, d1, d2, d3, COUNT(*) AS n, SUM(extra) AS extra
    FROM   r4_tag
    GROUP  BY reason, d1, d2, d3
),
r4_ex AS (
    SELECT reason, d1, d2, d3,
           LISTAGG(doc_num, ', ') WITHIN GROUP (ORDER BY id DESC, doc_num DESC) AS examples
    FROM  ( SELECT t.reason, t.d1, t.d2, t.d3, t.doc_num, t.id,
                   ROW_NUMBER() OVER (PARTITION BY t.reason, t.d1, t.d2, t.d3
                                      ORDER BY t.id DESC, t.doc_num DESC) AS rn
            FROM   r4_tag t )
    WHERE  rn <= 3
    GROUP  BY reason, d1, d2, d3
),
r4_det AS (
    SELECT g.reason, g.d1, g.d2, g.d3, g.n, g.extra, e.examples,
           ROW_NUMBER() OVER (ORDER BY CASE WHEN g.reason = 'counted' THEN 0 ELSE 1 END,
                                       g.reason, g.n DESC, g.d1, g.d2, g.d3) AS rn
    FROM        r4_grp g
    LEFT JOIN   r4_ex  e ON  e.reason = g.reason AND e.d1 = g.d1
                          AND e.d2     = g.d2     AND e.d3 = g.d3
),
r4_head AS (
    SELECT
           NVL(SUM(CASE WHEN reason = 'counted' THEN n END), 0) AS h1,
           NVL(SUM(CASE WHEN reason = 'counted' AND d2 = 'N' THEN n END), 0) AS h2,
           NVL(SUM(CASE WHEN reason = 'counted' AND d2 = 'P' THEN n END), 0) AS h3,
           NVL(SUM(CASE WHEN reason = 'counted' AND d1 = 'PREPAYMENT' THEN n END), 0) AS h4,
           NVL(SUM(CASE WHEN reason = 'fully paid' THEN n END), 0) AS h5
    FROM   r4_grp
),
-- ---- row 5: open prepayments -----------------------------------------------
-- prepayments applied at least once (the F7.1 row 5 NOT EXISTS, as a list)
r5_applied AS (
    SELECT pd.invoice_id
    FROM   ap_invoice_distributions_all pd
    JOIN   ap_invoice_distributions_all cd
           ON cd.prepay_distribution_id = pd.invoice_distribution_id
    GROUP  BY pd.invoice_id
),
r5_tag AS (
    SELECT ai.invoice_id                                              AS id,
           TO_CHAR(ai.invoice_num)                                    AS doc_num,
           NVL(TO_CHAR(ai.payment_status_flag), '(null)')             AS d1,
           '-'                                                        AS d2,
           '-'                                                        AS d3,
           0                                                          AS extra,
           CASE WHEN b.bu_id IS NULL                                  THEN 'BU not in scope'
                WHEN ai.cancelled_date IS NOT NULL                    THEN 'cancelled'
                WHEN ap.invoice_id IS NOT NULL                        THEN 'applied to an invoice'
                ELSE 'counted'
           END                                                        AS reason
    FROM        ap_invoices_all ai
    LEFT JOIN   bu_scope        b  ON b.bu_id = ai.org_id
    LEFT JOIN   r5_applied      ap ON ap.invoice_id = ai.invoice_id
    WHERE       ai.invoice_type_lookup_code = 'PREPAYMENT'
),
r5_grp AS (
    SELECT reason, d1, d2, d3, COUNT(*) AS n, SUM(extra) AS extra
    FROM   r5_tag
    GROUP  BY reason, d1, d2, d3
),
r5_ex AS (
    SELECT reason, d1, d2, d3,
           LISTAGG(doc_num, ', ') WITHIN GROUP (ORDER BY id DESC, doc_num DESC) AS examples
    FROM  ( SELECT t.reason, t.d1, t.d2, t.d3, t.doc_num, t.id,
                   ROW_NUMBER() OVER (PARTITION BY t.reason, t.d1, t.d2, t.d3
                                      ORDER BY t.id DESC, t.doc_num DESC) AS rn
            FROM   r5_tag t )
    WHERE  rn <= 3
    GROUP  BY reason, d1, d2, d3
),
r5_det AS (
    SELECT g.reason, g.d1, g.d2, g.d3, g.n, g.extra, e.examples,
           ROW_NUMBER() OVER (ORDER BY CASE WHEN g.reason = 'counted' THEN 0 ELSE 1 END,
                                       g.reason, g.n DESC, g.d1, g.d2, g.d3) AS rn
    FROM        r5_grp g
    LEFT JOIN   r5_ex  e ON  e.reason = g.reason AND e.d1 = g.d1
                          AND e.d2     = g.d2     AND e.d3 = g.d3
),
r5_head AS (
    SELECT
           NVL(SUM(CASE WHEN reason = 'counted' THEN n END), 0) AS h1,
           NVL(SUM(CASE WHEN reason = 'counted' AND d1 IN ('N', 'P') THEN n END), 0) AS h2,
           NVL(SUM(CASE WHEN reason = 'applied to an invoice' THEN n END), 0) AS h3
    FROM   r5_grp
),
-- ---- row 6: open sales orders ----------------------------------------------
-- one row per order, the F7.1 version (submitted first, then the latest
-- header row), plus its STATUS_CODE and whether ANY version was submitted
r6_ord AS (
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
                                                                    AS header_id,
           MAX(dh.status_code) KEEP (DENSE_RANK FIRST ORDER BY
               CASE WHEN dh.submitted_flag = 'Y' THEN 0 ELSE 1 END, dh.header_id DESC)
                                                                    AS status_code,
           MAX(CASE WHEN dh.submitted_flag = 'Y' THEN 1 ELSE 0 END)  AS ever_submitted
    FROM   doo_headers_all dh
    GROUP  BY dh.order_number, dh.source_order_system
),
r6_tag AS (
    SELECT o.header_id                                                AS id,
           TO_CHAR(o.order_number)                                    AS doc_num,
           CASE WHEN o.ever_submitted = 1 THEN 'Y' ELSE 'N' END       AS d1,
           NVL(TO_CHAR(o.status_code), '(null)')                      AS d2,
           '-'                                                        AS d3,
           0                                                          AS extra,
           CASE WHEN b.bu_id IS NULL                                  THEN 'BU not in scope'
                WHEN NVL(o.canceled_flag, 'N') <> 'N'                 THEN 'cancelled'
                WHEN NVL(o.open_flag, 'N') <> 'Y'                     THEN 'closed (OPEN_FLAG not Y)'
                ELSE 'counted'
           END                                                        AS reason
    FROM        r6_ord   o
    LEFT JOIN   bu_scope b ON b.bu_id = o.org_id
),
r6_grp AS (
    SELECT reason, d1, d2, d3, COUNT(*) AS n, SUM(extra) AS extra
    FROM   r6_tag
    GROUP  BY reason, d1, d2, d3
),
r6_ex AS (
    SELECT reason, d1, d2, d3,
           LISTAGG(doc_num, ', ') WITHIN GROUP (ORDER BY id DESC, doc_num DESC) AS examples
    FROM  ( SELECT t.reason, t.d1, t.d2, t.d3, t.doc_num, t.id,
                   ROW_NUMBER() OVER (PARTITION BY t.reason, t.d1, t.d2, t.d3
                                      ORDER BY t.id DESC, t.doc_num DESC) AS rn
            FROM   r6_tag t )
    WHERE  rn <= 3
    GROUP  BY reason, d1, d2, d3
),
r6_det AS (
    SELECT g.reason, g.d1, g.d2, g.d3, g.n, g.extra, e.examples,
           ROW_NUMBER() OVER (ORDER BY CASE WHEN g.reason = 'counted' THEN 0 ELSE 1 END,
                                       g.reason, g.n DESC, g.d1, g.d2, g.d3) AS rn
    FROM        r6_grp g
    LEFT JOIN   r6_ex  e ON  e.reason = g.reason AND e.d1 = g.d1
                          AND e.d2     = g.d2     AND e.d3 = g.d3
),
r6_head AS (
    SELECT
           NVL(SUM(CASE WHEN reason = 'counted' THEN n END), 0) AS h1,
           NVL(SUM(CASE WHEN reason = 'counted' AND d1 = 'N' THEN n END), 0) AS h2,
           NVL(SUM(CASE WHEN reason = 'counted' AND d1 = 'Y' THEN n END), 0) AS h3,
           NVL(SUM(CASE WHEN reason IN ('cancelled', 'closed (OPEN_FLAG not Y)') THEN n END), 0) AS h4
    FROM   r6_grp
),
-- ---- row 7: open Receivables invoices --------------------------------------
-- per transaction: has it an open INV schedule (the F7.1 row 7 test)?
r7_ps AS (
    SELECT ps.customer_trx_id,
           MAX(CASE WHEN ps.class = 'INV' AND ps.status = 'OP' THEN 1 ELSE 0 END) AS open_inv,
           MAX(CASE WHEN ps.class = 'INV' THEN 1 ELSE 0 END)                      AS any_inv,
           MAX(ps.class)                                                          AS ps_class
    FROM   ar_payment_schedules_all ps
    WHERE  ps.customer_trx_id IS NOT NULL
    GROUP  BY ps.customer_trx_id
),
r7_tag AS (
    SELECT ct.customer_trx_id                                         AS id,
           TO_CHAR(ct.trx_number)                                     AS doc_num,
           NVL(TO_CHAR(s.ps_class), '(no schedule)')                  AS d1,
           NVL(TO_CHAR(ct.complete_flag), '(null)')                   AS d2,
           '-'                                                        AS d3,
           0                                                          AS extra,
           CASE WHEN b.bu_id IS NULL                       THEN 'BU not in scope'
                WHEN s.customer_trx_id IS NULL             THEN 'no payment schedule (incomplete)'
                WHEN s.any_inv = 0                         THEN 'not an invoice (schedule class not INV)'
                WHEN s.open_inv = 0                        THEN 'closed (nothing left to collect)'
                ELSE 'counted'
           END                                                        AS reason
    FROM        ra_customer_trx_all ct
    LEFT JOIN   bu_scope            b ON b.bu_id = ct.org_id
    LEFT JOIN   r7_ps               s ON s.customer_trx_id = ct.customer_trx_id
),
r7_grp AS (
    SELECT reason, d1, d2, d3, COUNT(*) AS n, SUM(extra) AS extra
    FROM   r7_tag
    GROUP  BY reason, d1, d2, d3
),
r7_ex AS (
    SELECT reason, d1, d2, d3,
           LISTAGG(doc_num, ', ') WITHIN GROUP (ORDER BY id DESC, doc_num DESC) AS examples
    FROM  ( SELECT t.reason, t.d1, t.d2, t.d3, t.doc_num, t.id,
                   ROW_NUMBER() OVER (PARTITION BY t.reason, t.d1, t.d2, t.d3
                                      ORDER BY t.id DESC, t.doc_num DESC) AS rn
            FROM   r7_tag t )
    WHERE  rn <= 3
    GROUP  BY reason, d1, d2, d3
),
r7_det AS (
    SELECT g.reason, g.d1, g.d2, g.d3, g.n, g.extra, e.examples,
           ROW_NUMBER() OVER (ORDER BY CASE WHEN g.reason = 'counted' THEN 0 ELSE 1 END,
                                       g.reason, g.n DESC, g.d1, g.d2, g.d3) AS rn
    FROM        r7_grp g
    LEFT JOIN   r7_ex  e ON  e.reason = g.reason AND e.d1 = g.d1
                          AND e.d2     = g.d2     AND e.d3 = g.d3
),
r7_head AS (
    SELECT
           NVL(SUM(CASE WHEN reason = 'counted' THEN n END), 0) AS h1,
           NVL(SUM(CASE WHEN reason = 'closed (nothing left to collect)' THEN n END), 0) AS h2,
           NVL(SUM(CASE WHEN reason = 'no payment schedule (incomplete)' THEN n END), 0) AS h3,
           NVL(SUM(CASE WHEN reason LIKE 'not an invoice%' THEN n END), 0) AS h4
    FROM   r7_grp
),
-- ---- row 8: open or unapplied receipts -------------------------------------
-- per receipt: has it an open PMT schedule (the F7.1 row 8 test)?
r8_ps AS (
    SELECT ps.cash_receipt_id,
           MAX(CASE WHEN ps.class = 'PMT' AND ps.status = 'OP' THEN 1 ELSE 0 END) AS open_pmt
    FROM   ar_payment_schedules_all ps
    WHERE  ps.cash_receipt_id IS NOT NULL
    GROUP  BY ps.cash_receipt_id
),
r8_tag AS (
    SELECT cr.cash_receipt_id                                         AS id,
           TO_CHAR(cr.receipt_number)                                 AS doc_num,
           NVL(TO_CHAR(cr.status), '(null)')                          AS d1,
           '-'                                                        AS d2,
           '-'                                                        AS d3,
           0                                                          AS extra,
           CASE WHEN b.bu_id IS NULL                                  THEN 'BU not in scope'
                WHEN cr.reversal_date IS NOT NULL
                  OR NVL(cr.status, 'X') = 'REV'                      THEN 'reversed'
                WHEN s.cash_receipt_id IS NULL                        THEN 'no payment schedule'
                WHEN s.open_pmt = 0                                   THEN 'fully applied (schedule closed)'
                ELSE 'counted'
           END                                                        AS reason
    FROM        ar_cash_receipts_all cr
    LEFT JOIN   bu_scope             b ON b.bu_id = cr.org_id
    LEFT JOIN   r8_ps                s ON s.cash_receipt_id = cr.cash_receipt_id
),
r8_grp AS (
    SELECT reason, d1, d2, d3, COUNT(*) AS n, SUM(extra) AS extra
    FROM   r8_tag
    GROUP  BY reason, d1, d2, d3
),
r8_ex AS (
    SELECT reason, d1, d2, d3,
           LISTAGG(doc_num, ', ') WITHIN GROUP (ORDER BY id DESC, doc_num DESC) AS examples
    FROM  ( SELECT t.reason, t.d1, t.d2, t.d3, t.doc_num, t.id,
                   ROW_NUMBER() OVER (PARTITION BY t.reason, t.d1, t.d2, t.d3
                                      ORDER BY t.id DESC, t.doc_num DESC) AS rn
            FROM   r8_tag t )
    WHERE  rn <= 3
    GROUP  BY reason, d1, d2, d3
),
r8_det AS (
    SELECT g.reason, g.d1, g.d2, g.d3, g.n, g.extra, e.examples,
           ROW_NUMBER() OVER (ORDER BY CASE WHEN g.reason = 'counted' THEN 0 ELSE 1 END,
                                       g.reason, g.n DESC, g.d1, g.d2, g.d3) AS rn
    FROM        r8_grp g
    LEFT JOIN   r8_ex  e ON  e.reason = g.reason AND e.d1 = g.d1
                          AND e.d2     = g.d2     AND e.d3 = g.d3
),
r8_head AS (
    SELECT
           NVL(SUM(CASE WHEN reason = 'counted' THEN n END), 0) AS h1,
           NVL(SUM(CASE WHEN reason = 'fully applied (schedule closed)' THEN n END), 0) AS h2,
           NVL(SUM(CASE WHEN reason = 'reversed' THEN n END), 0) AS h3
    FROM   r8_grp
),
-- ---- row 9: on-hand inventory (item-org pairs) -----------------------------
-- every (inventory org, item) pair in the on-hand table, layers netted
r9_pair AS (
    SELECT oh.organization_id,
           oh.inventory_item_id,
           SUM(NVL(oh.primary_transaction_quantity, 0)) AS net_qty
    FROM   inv_onhand_quantities_detail oh
    GROUP  BY oh.organization_id, oh.inventory_item_id
),
r9_item AS (
    SELECT si.inventory_item_id, si.organization_id, MAX(si.item_number) AS item_number
    FROM   egp_system_items_b si
    GROUP  BY si.inventory_item_id, si.organization_id
),
r9_tag AS (
    SELECT p.inventory_item_id                                        AS id,
           TO_CHAR(NVL(oc.organization_code, TO_CHAR(p.organization_id)) || '/'
                   || NVL(TO_CHAR(it.item_number), TO_CHAR(p.inventory_item_id))) AS doc_num,
           TO_CHAR(NVL(oc.organization_code, TO_CHAR(p.organization_id))) AS d1,
           '-'                                                        AS d2,
           '-'                                                        AS d3,
           0                                                          AS extra,
           CASE WHEN io.inv_org_id IS NULL      THEN 'organization not mapped to a BU in scope'
                WHEN p.net_qty = 0              THEN 'net quantity zero'
                WHEN p.net_qty < 0              THEN 'net quantity negative'
                ELSE 'counted'
           END                                                        AS reason
    FROM        r9_pair    p
    LEFT JOIN   inv_org_bu io ON io.inv_org_id      = p.organization_id
    LEFT JOIN   org_codes  oc ON oc.organization_id = p.organization_id
    LEFT JOIN   r9_item    it ON it.inventory_item_id = p.inventory_item_id
                             AND it.organization_id   = p.organization_id
),
r9_grp AS (
    SELECT reason, d1, d2, d3, COUNT(*) AS n, SUM(extra) AS extra
    FROM   r9_tag
    GROUP  BY reason, d1, d2, d3
),
r9_ex AS (
    SELECT reason, d1, d2, d3,
           LISTAGG(doc_num, ', ') WITHIN GROUP (ORDER BY id DESC, doc_num DESC) AS examples
    FROM  ( SELECT t.reason, t.d1, t.d2, t.d3, t.doc_num, t.id,
                   ROW_NUMBER() OVER (PARTITION BY t.reason, t.d1, t.d2, t.d3
                                      ORDER BY t.id DESC, t.doc_num DESC) AS rn
            FROM   r9_tag t )
    WHERE  rn <= 3
    GROUP  BY reason, d1, d2, d3
),
r9_det AS (
    SELECT g.reason, g.d1, g.d2, g.d3, g.n, g.extra, e.examples,
           ROW_NUMBER() OVER (ORDER BY CASE WHEN g.reason = 'counted' THEN 0 ELSE 1 END,
                                       g.reason, g.n DESC, g.d1, g.d2, g.d3) AS rn
    FROM        r9_grp g
    LEFT JOIN   r9_ex  e ON  e.reason = g.reason AND e.d1 = g.d1
                          AND e.d2     = g.d2     AND e.d3 = g.d3
),
r9_head AS (
    SELECT
           NVL(SUM(CASE WHEN reason = 'counted' THEN n END), 0) AS h1,
           NVL(SUM(CASE WHEN reason = 'net quantity zero' THEN n END), 0) AS h2,
           NVL(SUM(CASE WHEN reason = 'net quantity negative' THEN n END), 0) AS h3
    FROM   r9_grp
),
-- ---- row 10: open work orders ----------------------------------------------
r10_tag AS (
    SELECT 0                                                          AS id,
           TO_CHAR(wo.work_order_number)                              AS doc_num,
           NVL(TO_CHAR(ws.system_status), '(no status row)')          AS d1,
           '-'                                                        AS d2,
           '-'                                                        AS d3,
           0                                                          AS extra,
           CASE WHEN io.inv_org_id IS NULL      THEN 'organization not mapped to a BU in scope'
                WHEN ws.wo_status_id IS NULL    THEN 'no status row'
                WHEN REPLACE(REPLACE(UPPER(NVL(ws.system_status, 'X')), 'ORA_', ''), '_', ' ')
                     IN ('RELEASED', 'ON HOLD') THEN 'counted'
                ELSE 'status not Released / On Hold'
           END                                                        AS reason
    FROM        wie_work_orders_b wo
    LEFT JOIN   inv_org_bu        io ON io.inv_org_id   = wo.organization_id
    LEFT JOIN   wo_status         ws ON ws.wo_status_id = wo.work_order_status_id
),
r10_grp AS (
    SELECT reason, d1, d2, d3, COUNT(*) AS n, SUM(extra) AS extra
    FROM   r10_tag
    GROUP  BY reason, d1, d2, d3
),
r10_ex AS (
    SELECT reason, d1, d2, d3,
           LISTAGG(doc_num, ', ') WITHIN GROUP (ORDER BY id DESC, doc_num DESC) AS examples
    FROM  ( SELECT t.reason, t.d1, t.d2, t.d3, t.doc_num, t.id,
                   ROW_NUMBER() OVER (PARTITION BY t.reason, t.d1, t.d2, t.d3
                                      ORDER BY t.id DESC, t.doc_num DESC) AS rn
            FROM   r10_tag t )
    WHERE  rn <= 3
    GROUP  BY reason, d1, d2, d3
),
r10_det AS (
    SELECT g.reason, g.d1, g.d2, g.d3, g.n, g.extra, e.examples,
           ROW_NUMBER() OVER (ORDER BY CASE WHEN g.reason = 'counted' THEN 0 ELSE 1 END,
                                       g.reason, g.n DESC, g.d1, g.d2, g.d3) AS rn
    FROM        r10_grp g
    LEFT JOIN   r10_ex  e ON  e.reason = g.reason AND e.d1 = g.d1
                          AND e.d2     = g.d2     AND e.d3 = g.d3
),
r10_head AS (
    SELECT
           NVL(SUM(CASE WHEN reason = 'counted' THEN n END), 0) AS h1,
           NVL(SUM(CASE WHEN reason = 'counted' AND REPLACE(REPLACE(UPPER(d1), 'ORA_', ''), '_', ' ') = 'RELEASED' THEN n END), 0) AS h2,
           NVL(SUM(CASE WHEN reason = 'counted' AND REPLACE(REPLACE(UPPER(d1), 'ORA_', ''), '_', ' ') = 'ON HOLD' THEN n END), 0) AS h3,
           NVL(SUM(CASE WHEN reason <> 'counted' AND REPLACE(REPLACE(UPPER(d1), 'ORA_', ''), '_', ' ') = 'UNRELEASED' THEN n END), 0) AS h4
    FROM   r10_grp
),
grid AS (
    SELECT 1001 AS ord, CAST('01 REQUISITIONS' AS VARCHAR2(20)) AS block,
           CAST('F7.1 row 1 Open requisitions - must equal the F7.1 run' AS VARCHAR2(400)) AS item,
           h.h1 AS value, CAST(NULL AS VARCHAR2(4000)) AS note
    FROM   r1_head h
    UNION ALL
    SELECT 1002, '01 REQUISITIONS', 'open requisition lines behind them', h.h2, NULL
    FROM   r1_head h
    UNION ALL
    SELECT 1003, '01 REQUISITIONS', 'of them internal transfer requisitions (flag Y)', h.h3, NULL
    FROM   r1_head h
    UNION ALL
    SELECT 1004, '01 REQUISITIONS', 'approved, but every line already on an order or closed (left out)', h.h4, NULL
    FROM   r1_head h
    UNION ALL
    SELECT 1100 + d.rn, '01 REQUISITIONS',
           TO_CHAR(d.reason || ' | ' || 'DOCUMENT_STATUS ' || d.d1 || ' | transfer requisition ' || d.d2),
           d.n, TO_CHAR('open lines: ' || TO_CHAR(d.extra) || ' | latest: ' || d.examples)
    FROM   r1_det d
    UNION ALL
    SELECT 2001, '02 PURCHASE ORDERS', 'F7.1 row 2 Open purchase orders - must equal the F7.1 run', h.h1, NULL
    FROM   r2_head h
    UNION ALL
    SELECT 2002, '02 PURCHASE ORDERS', 'STANDARD POs closed (left out)', h.h2, NULL
    FROM   r2_head h
    UNION ALL
    SELECT 2003, '02 PURCHASE ORDERS', 'STANDARD POs not approved (left out)', h.h3, NULL
    FROM   r2_head h
    UNION ALL
    SELECT 2004, '02 PURCHASE ORDERS', 'agreements and other types (left out)', h.h4, NULL
    FROM   r2_head h
    UNION ALL
    SELECT 2100 + d.rn, '02 PURCHASE ORDERS',
           TO_CHAR(d.reason || ' | ' || d.d1 || ' | DOCUMENT_STATUS ' || d.d2 || ' | APPROVED_FLAG ' || d.d3),
           d.n, TO_CHAR('latest: ' || d.examples)
    FROM   r2_det d
    UNION ALL
    SELECT 3001, '03 PO RECEIPTS', 'F7.1 row 3 Open PO receipts (schedules) - must equal the F7.1 run', h.h1, NULL
    FROM   r3_head h
    UNION ALL
    SELECT 3002, '03 PO RECEIPTS', 'schedules received and fully invoiced (left out)', h.h2, NULL
    FROM   r3_head h
    UNION ALL
    SELECT 3003, '03 PO RECEIPTS', 'schedules with nothing received (left out)', h.h3, NULL
    FROM   r3_head h
    UNION ALL
    SELECT 3004, '03 PO RECEIPTS', 'schedules cancelled or closed (left out)', h.h4, NULL
    FROM   r3_head h
    UNION ALL
    SELECT 3100 + d.rn, '03 PO RECEIPTS',
           TO_CHAR(d.reason || ' | ' || 'SCHEDULE_STATUS ' || d.d1 || ' | MATCHING_BASIS ' || d.d2 || ' | SHIPMENT_TYPE ' || d.d3),
           d.n, TO_CHAR('latest POs: ' || d.examples)
    FROM   r3_det d
    UNION ALL
    SELECT 4001, '04 AP INVOICES', 'F7.1 row 4 Open Payables invoices - must equal the F7.1 run', h.h1, NULL
    FROM   r4_head h
    UNION ALL
    SELECT 4002, '04 AP INVOICES', 'of them unpaid (PAYMENT_STATUS_FLAG N)', h.h2, NULL
    FROM   r4_head h
    UNION ALL
    SELECT 4003, '04 AP INVOICES', 'of them partly paid (P)', h.h3, NULL
    FROM   r4_head h
    UNION ALL
    SELECT 4004, '04 AP INVOICES', 'of them prepayments (also in row 5 when never applied)', h.h4, NULL
    FROM   r4_head h
    UNION ALL
    SELECT 4005, '04 AP INVOICES', 'fully paid (left out)', h.h5, NULL
    FROM   r4_head h
    UNION ALL
    SELECT 4100 + d.rn, '04 AP INVOICES',
           TO_CHAR(d.reason || ' | ' || d.d1 || ' | PAYMENT_STATUS_FLAG ' || d.d2),
           d.n, TO_CHAR('latest: ' || d.examples)
    FROM   r4_det d
    UNION ALL
    SELECT 5001, '05 PREPAYMENTS', 'F7.1 row 5 Open prepayments - must equal the F7.1 run', h.h1, NULL
    FROM   r5_head h
    UNION ALL
    SELECT 5002, '05 PREPAYMENTS', 'of them not yet paid (also counted in row 4)', h.h2, NULL
    FROM   r5_head h
    UNION ALL
    SELECT 5003, '05 PREPAYMENTS', 'applied to an invoice (left out)', h.h3, NULL
    FROM   r5_head h
    UNION ALL
    SELECT 5100 + d.rn, '05 PREPAYMENTS',
           TO_CHAR(d.reason || ' | ' || 'PAYMENT_STATUS_FLAG ' || d.d1),
           d.n, TO_CHAR('latest: ' || d.examples)
    FROM   r5_det d
    UNION ALL
    SELECT 6001, '06 SALES ORDERS', 'F7.1 row 6 Open sales orders - must equal the F7.1 run', h.h1, NULL
    FROM   r6_head h
    UNION ALL
    SELECT 6002, '06 SALES ORDERS', 'of them never submitted (draft / pending approval; F4.2 v1.3 leaves these out)', h.h2, NULL
    FROM   r6_head h
    UNION ALL
    SELECT 6003, '06 SALES ORDERS', 'of them submitted', h.h3, NULL
    FROM   r6_head h
    UNION ALL
    SELECT 6004, '06 SALES ORDERS', 'closed or cancelled (left out)', h.h4, NULL
    FROM   r6_head h
    UNION ALL
    SELECT 6100 + d.rn, '06 SALES ORDERS',
           TO_CHAR(d.reason || ' | ' || 'submitted ' || d.d1 || ' | STATUS_CODE ' || d.d2),
           d.n, TO_CHAR('latest: ' || d.examples)
    FROM   r6_det d
    UNION ALL
    SELECT 7001, '07 AR INVOICES', 'F7.1 row 7 Open Receivables invoices - must equal the F7.1 run', h.h1, NULL
    FROM   r7_head h
    UNION ALL
    SELECT 7002, '07 AR INVOICES', 'closed invoices (left out)', h.h2, NULL
    FROM   r7_head h
    UNION ALL
    SELECT 7003, '07 AR INVOICES', 'incomplete, no payment schedule (left out)', h.h3, NULL
    FROM   r7_head h
    UNION ALL
    SELECT 7004, '07 AR INVOICES', 'credit memos, debit memos and other classes (left out)', h.h4, NULL
    FROM   r7_head h
    UNION ALL
    SELECT 7100 + d.rn, '07 AR INVOICES',
           TO_CHAR(d.reason || ' | ' || 'schedule class ' || d.d1 || ' | COMPLETE_FLAG ' || d.d2),
           d.n, TO_CHAR('latest: ' || d.examples)
    FROM   r7_det d
    UNION ALL
    SELECT 8001, '08 RECEIPTS', 'F7.1 row 8 Open or unapplied receipts - must equal the F7.1 run', h.h1, NULL
    FROM   r8_head h
    UNION ALL
    SELECT 8002, '08 RECEIPTS', 'fully applied (left out)', h.h2, NULL
    FROM   r8_head h
    UNION ALL
    SELECT 8003, '08 RECEIPTS', 'reversed (left out)', h.h3, NULL
    FROM   r8_head h
    UNION ALL
    SELECT 8100 + d.rn, '08 RECEIPTS',
           TO_CHAR(d.reason || ' | ' || 'receipt STATUS ' || d.d1),
           d.n, TO_CHAR('latest: ' || d.examples)
    FROM   r8_det d
    UNION ALL
    SELECT 9001, '09 ON-HAND', 'F7.1 row 9 On-hand inventory (item-org) - must equal the F7.1 run', h.h1, NULL
    FROM   r9_head h
    UNION ALL
    SELECT 9002, '09 ON-HAND', 'pairs netting to zero (left out)', h.h2, NULL
    FROM   r9_head h
    UNION ALL
    SELECT 9003, '09 ON-HAND', 'pairs netting below zero (left out; cutover clean-up)', h.h3, NULL
    FROM   r9_head h
    UNION ALL
    SELECT 9100 + d.rn, '09 ON-HAND',
           TO_CHAR(d.reason || ' | ' || 'organization ' || d.d1),
           d.n, TO_CHAR('examples org/item: ' || d.examples)
    FROM   r9_det d
    UNION ALL
    SELECT 10001, '10 WORK ORDERS', 'F7.1 row 10 Open work orders - must equal the F7.1 run', h.h1, NULL
    FROM   r10_head h
    UNION ALL
    SELECT 10002, '10 WORK ORDERS', 'of them Released', h.h2, NULL
    FROM   r10_head h
    UNION ALL
    SELECT 10003, '10 WORK ORDERS', 'of them On Hold', h.h3, NULL
    FROM   r10_head h
    UNION ALL
    SELECT 10004, '10 WORK ORDERS', 'Unreleased (left out, the EBS open decision)', h.h4, NULL
    FROM   r10_head h
    UNION ALL
    SELECT 10100 + d.rn, '10 WORK ORDERS',
           TO_CHAR(d.reason || ' | ' || 'system status ' || d.d1),
           d.n, TO_CHAR('examples: ' || d.examples)
    FROM   r10_det d
)
SELECT  g.ord    AS ord,
        g.block  AS block,
        g.item   AS item,
        g.value  AS value,
        g.note   AS note
FROM    grid g
ORDER BY g.ord
