-- ============================================================================
--  V4_4  P2P RECONCILIATION - what is inside each F4.1 count, and what is not
--  Version   : 1.0 (2026-10-13). Not yet run on a pod.
--              Run log: 06_Run_Results/RUN_LOG.md
--  Run AFTER V4_0 reads ALL OK, with EXACTLY the parameters of the F4.1 run
--  being defended (blank dates = all history, shared block v3.2).
--
--  WHY  F4.1 v1.4 with blank dates (2026-10-13) gave: requisitions sourced to
--  POs 4,647 / purchase orders 6,779 / PO receipts 9,635 / AP invoices 11,597
--  (Standard 11,348, Credit memo 207, Debit memo 41, Payment request 1) /
--  payments 3,402 (Wire 1,751, Check 1,552, AP/AR netting 99). V4_3 showed
--  F4.2 differed from the consultant because it counted drafts. This query
--  opens every F4.1 row the same way, so each count can be defended: what is
--  counted, what is left out and why, by status, with the latest three
--  document numbers of each group to open in the Fusion UI.
--
--  OUTPUT  ord | block | item | value | note
--    Each block: the F4.1 row (must equal the F4.1 run), alternative counts,
--    then one row per reason x status combination (counted first). note =
--    the latest three document numbers of that combination.
--    A  REQUISITIONS     POR_REQUISITION_HEADERS_ALL (F4.1 row 1)
--         1 F4.1 row | 2 every requisition in scope and window | 3 of them
--         with no line on a PO | 100+ reason x DOCUMENT_STATUS x transfer flag
--    B  PURCHASE ORDERS  PO_HEADERS_ALL (F4.1 row 2)
--         1001 F4.1 row | 1002-1004 of it STANDARD / BLANKET / PLANNED |
--         1005-1006 approved / not approved (APPROVED_FLAG) | 1007 cancelled,
--         left out | 1100+ reason x TYPE x DOCUMENT_STATUS x APPROVED_FLAG
--    C  PO RECEIPTS      RCV_TRANSACTIONS (F4.1 row 3, one per receipt header)
--         2001 F4.1 row | 2002 RECEIVE lines behind it | 2003 receipt headers
--         with a RECEIVE not against a PO | 2100+ scope x TRANSACTION_TYPE x
--         against a PO: value = receipt headers, note = lines + examples
--    D  AP INVOICES      AP_INVOICES_ALL (F4.1 row 4)
--         3001 F4.1 row | 3002 cancelled, left out | 3003 dated after today |
--         3004-3006 paid / partly paid / unpaid (PAYMENT_STATUS_FLAG) |
--         3100+ reason x type x PAYMENT_STATUS_FLAG x dated after today
--    E  PAYMENTS         AP_CHECKS_ALL (F4.1 row 6)
--         4001 F4.1 row | 4002 voided, left out | 4003 dated after today |
--         4100+ reason x method x STATUS_LOOKUP_CODE x dated after today
--  Columns: every counted column is proved (V4_0 / V7_0, R042). The document
--  numbers in "note" are not yet proved: PO_HEADERS_ALL.SEGMENT1,
--  POR_REQUISITION_HEADERS_ALL.REQUISITION_NUMBER, RCV_SHIPMENT_HEADERS
--  .RECEIPT_NUM, AP_INVOICES_ALL.INVOICE_NUM, AP_CHECKS_ALL.CHECK_ID and
--  CHECK_NUMBER. An ORA-00904 naming one of them: report it.
--  Pure SELECT, one statement, every aggregate in its own CTE, no DISTINCT.
-- ============================================================================
WITH
-- ---- PARAMS / WINDOW / SCOPE: copied unchanged from F1 (shared block v3.2),
--      so Section 4 measures the same population and window as Section 1.
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
    GROUP  BY iod.organization_id
),
fa_book_scope AS (
    SELECT fbc.book_type_code
    FROM   fa_book_controls fbc
    CROSS  JOIN params p
    WHERE  (p.p_ledger_id IS NULL OR fbc.set_of_books_id = TO_NUMBER(p.p_ledger_id))
    GROUP  BY fbc.book_type_code
),
-- ---- A. requisitions (F4.1 row 1) ------------------------------------------------
-- requisitions with at least one line on a PO (the F4.1 EXISTS test)
req_src AS (
    SELECT rl.requisition_header_id
    FROM   por_requisition_lines_all rl
    WHERE  rl.po_header_id IS NOT NULL
    GROUP  BY rl.requisition_header_id
),
req_tag AS (
    SELECT rh.requisition_header_id                                   AS id,
           TO_CHAR(rh.requisition_number)                             AS doc_num,
           NVL(TO_CHAR(rh.document_status), '(null)')                 AS doc_status,
           NVL(TO_CHAR(rh.internal_transfer_req_flag), '(null)')      AS transfer_req,
           CASE WHEN b.bu_id IS NULL                       THEN 'BU not in scope'
                WHEN rh.creation_date IS NULL
                  OR rh.creation_date <  w.start_date
                  OR rh.creation_date >= w.end_date_excl   THEN 'created outside the window'
                WHEN s.requisition_header_id IS NULL       THEN 'no line on a PO'
                ELSE 'counted'
           END                                                        AS reason
    FROM        por_requisition_headers_all rh
    CROSS JOIN  win      w
    LEFT JOIN   bu_scope b ON b.bu_id = rh.req_bu_id
    LEFT JOIN   req_src  s ON s.requisition_header_id = rh.requisition_header_id
),
req_grp AS (
    SELECT reason, doc_status, transfer_req, COUNT(*) AS n
    FROM   req_tag
    GROUP  BY reason, doc_status, transfer_req
),
req_ex AS (
    SELECT reason, doc_status, transfer_req,
           LISTAGG(doc_num, ', ') WITHIN GROUP (ORDER BY id DESC)     AS examples
    FROM  ( SELECT t.reason, t.doc_status, t.transfer_req, t.doc_num, t.id,
                   ROW_NUMBER() OVER (PARTITION BY t.reason, t.doc_status, t.transfer_req
                                      ORDER BY t.id DESC)             AS rn
            FROM   req_tag t )
    WHERE  rn <= 3
    GROUP  BY reason, doc_status, transfer_req
),
req_head AS (
    SELECT NVL(SUM(CASE WHEN reason = 'counted' THEN n END), 0)          AS f41,
           NVL(SUM(CASE WHEN reason IN ('counted', 'no line on a PO')
                        THEN n END), 0)                                 AS in_scope,
           NVL(SUM(CASE WHEN reason = 'no line on a PO' THEN n END), 0)  AS not_sourced
    FROM   req_grp
),
req_det AS (
    SELECT g.reason, g.doc_status, g.transfer_req, g.n, e.examples,
           ROW_NUMBER() OVER (ORDER BY CASE WHEN g.reason = 'counted' THEN 0 ELSE 1 END,
                                       g.reason, g.n DESC, g.doc_status,
                                       g.transfer_req)                AS rn
    FROM        req_grp g
    LEFT JOIN   req_ex  e ON  e.reason       = g.reason
                          AND e.doc_status   = g.doc_status
                          AND e.transfer_req = g.transfer_req
),
-- ---- B. purchase orders (F4.1 row 2) ----------------------------------------------
-- POs with at least one of their three BUs in scope (the F4.1 EXISTS test)
po_bu AS (
    SELECT ph.po_header_id
    FROM   po_headers_all ph
    JOIN   bu_scope       b ON b.bu_id IN (ph.prc_bu_id, ph.req_bu_id, ph.billto_bu_id)
    GROUP  BY ph.po_header_id
),
po_tag AS (
    SELECT ph.po_header_id                                            AS id,
           TO_CHAR(ph.segment1)                                       AS doc_num,
           NVL(TO_CHAR(ph.type_lookup_code), '(null)')                AS type_code,
           NVL(TO_CHAR(ph.document_status), '(null)')                 AS doc_status,
           NVL(TO_CHAR(ph.approved_flag), '(null)')                   AS approved,
           CASE WHEN NVL(ph.type_lookup_code, '~')
                     NOT IN ('STANDARD', 'BLANKET', 'PLANNED')    THEN 'type not counted'
                WHEN NVL(ph.cancel_flag, 'N') <> 'N'
                  OR REPLACE(UPPER(NVL(ph.document_status, 'OPEN')), '_', ' ')
                     IN ('CANCELED', 'CANCELLED')                 THEN 'cancelled'
                WHEN pb.po_header_id IS NULL                      THEN 'BU not in scope'
                WHEN ph.creation_date IS NULL
                  OR ph.creation_date <  w.start_date
                  OR ph.creation_date >= w.end_date_excl          THEN 'created outside the window'
                ELSE 'counted'
           END                                                        AS reason
    FROM        po_headers_all ph
    CROSS JOIN  win            w
    LEFT JOIN   po_bu          pb ON pb.po_header_id = ph.po_header_id
),
po_grp AS (
    SELECT reason, type_code, doc_status, approved, COUNT(*) AS n
    FROM   po_tag
    GROUP  BY reason, type_code, doc_status, approved
),
po_ex AS (
    SELECT reason, type_code, doc_status, approved,
           LISTAGG(doc_num, ', ') WITHIN GROUP (ORDER BY id DESC)     AS examples
    FROM  ( SELECT t.reason, t.type_code, t.doc_status, t.approved, t.doc_num, t.id,
                   ROW_NUMBER() OVER (PARTITION BY t.reason, t.type_code, t.doc_status,
                                                   t.approved
                                      ORDER BY t.id DESC)             AS rn
            FROM   po_tag t )
    WHERE  rn <= 3
    GROUP  BY reason, type_code, doc_status, approved
),
po_head AS (
    SELECT NVL(SUM(CASE WHEN reason = 'counted' THEN n END), 0)          AS f41,
           NVL(SUM(CASE WHEN reason = 'counted' AND type_code = 'STANDARD'
                        THEN n END), 0)                                 AS std,
           NVL(SUM(CASE WHEN reason = 'counted' AND type_code = 'BLANKET'
                        THEN n END), 0)                                 AS bpa,
           NVL(SUM(CASE WHEN reason = 'counted' AND type_code = 'PLANNED'
                        THEN n END), 0)                                 AS planned,
           NVL(SUM(CASE WHEN reason = 'counted' AND approved = 'Y'
                        THEN n END), 0)                                 AS appr_y,
           NVL(SUM(CASE WHEN reason = 'counted' AND approved <> 'Y'
                        THEN n END), 0)                                 AS appr_n,
           NVL(SUM(CASE WHEN reason = 'cancelled' THEN n END), 0)        AS cancelled
    FROM   po_grp
),
po_det AS (
    SELECT g.reason, g.type_code, g.doc_status, g.approved, g.n, e.examples,
           ROW_NUMBER() OVER (ORDER BY CASE WHEN g.reason = 'counted' THEN 0 ELSE 1 END,
                                       g.reason, g.n DESC, g.type_code,
                                       g.doc_status, g.approved)      AS rn
    FROM        po_grp g
    LEFT JOIN   po_ex  e ON  e.reason     = g.reason
                         AND e.type_code  = g.type_code
                         AND e.doc_status = g.doc_status
                         AND e.approved   = g.approved
),
-- ---- C. PO receipts (F4.1 row 3: one per receipt header) ---------------------------
rt_tag AS (
    SELECT rt.shipment_header_id                                      AS hdr_id,
           NVL(TO_CHAR(rt.transaction_type), '(null)')                AS ttype,
           CASE WHEN rt.po_header_id IS NULL THEN 'N' ELSE 'Y' END    AS on_po,
           CASE WHEN ios.organization_id IS NULL            THEN 'organization not in scope'
                WHEN rt.transaction_date IS NULL
                  OR rt.transaction_date <  w.start_date
                  OR rt.transaction_date >= w.end_date_excl THEN 'dated outside the window'
                WHEN rt.shipment_header_id IS NULL          THEN 'no receipt header'
                ELSE 'in scope'
           END                                                        AS scope_state
    FROM        rcv_transactions rt
    CROSS JOIN  win              w
    LEFT JOIN   inv_org_scope    ios ON ios.organization_id = rt.organization_id
),
-- one row per receipt header within each combination
rt_doc AS (
    SELECT scope_state, ttype, on_po, hdr_id, COUNT(*) AS lines
    FROM   rt_tag
    GROUP  BY scope_state, ttype, on_po, hdr_id
),
rt_grp AS (
    SELECT scope_state, ttype, on_po,
           COUNT(hdr_id) AS docs,
           SUM(lines)    AS lines
    FROM   rt_doc
    GROUP  BY scope_state, ttype, on_po
),
rt_ex AS (
    SELECT x.scope_state, x.ttype, x.on_po,
           LISTAGG(TO_CHAR(sh.receipt_num), ', ')
               WITHIN GROUP (ORDER BY x.hdr_id DESC)                  AS examples
    FROM  ( SELECT d.scope_state, d.ttype, d.on_po, d.hdr_id,
                   ROW_NUMBER() OVER (PARTITION BY d.scope_state, d.ttype, d.on_po
                                      ORDER BY d.hdr_id DESC)         AS rn
            FROM   rt_doc d
            WHERE  d.hdr_id IS NOT NULL ) x
    JOIN   rcv_shipment_headers sh ON sh.shipment_header_id = x.hdr_id
    WHERE  x.rn <= 3
    GROUP  BY x.scope_state, x.ttype, x.on_po
),
rt_head AS (
    SELECT NVL(SUM(CASE WHEN scope_state = 'in scope' AND ttype = 'RECEIVE'
                         AND on_po = 'Y' THEN docs END), 0)              AS f41,
           NVL(SUM(CASE WHEN scope_state = 'in scope' AND ttype = 'RECEIVE'
                         AND on_po = 'Y' THEN lines END), 0)             AS f41_lines,
           NVL(SUM(CASE WHEN scope_state = 'in scope' AND ttype = 'RECEIVE'
                         AND on_po = 'N' THEN docs END), 0)              AS not_po
    FROM   rt_grp
),
rt_det AS (
    SELECT g.scope_state, g.ttype, g.on_po, g.docs, g.lines, e.examples,
           CASE WHEN g.scope_state = 'in scope' AND g.ttype = 'RECEIVE'
                 AND g.on_po = 'Y' THEN 'counted'
                WHEN g.scope_state = 'in scope' AND g.ttype = 'RECEIVE'
                THEN 'not on a PO'
                WHEN g.scope_state = 'in scope'
                THEN 'not a RECEIVE'
                ELSE g.scope_state
           END                                                        AS reason,
           ROW_NUMBER() OVER (ORDER BY CASE WHEN g.scope_state = 'in scope'
                                             AND g.ttype = 'RECEIVE'
                                             AND g.on_po = 'Y' THEN 0 ELSE 1 END,
                                       g.scope_state, g.docs DESC, g.ttype,
                                       g.on_po)                       AS rn
    FROM        rt_grp g
    LEFT JOIN   rt_ex  e ON  e.scope_state = g.scope_state
                         AND e.ttype       = g.ttype
                         AND e.on_po       = g.on_po
),
-- ---- D. AP invoices (F4.1 row 4) ---------------------------------------------------
ap_tag AS (
    SELECT ai.invoice_id                                              AS id,
           TO_CHAR(ai.invoice_num)                                    AS doc_num,
           NVL(TO_CHAR(ai.invoice_type_lookup_code), '(no type)')     AS inv_type,
           NVL(TO_CHAR(ai.payment_status_flag), '(null)')             AS pay_status,
           CASE WHEN ai.invoice_date >= TRUNC(SYSDATE) + 1 THEN 'Y' ELSE 'N' END AS future,
           CASE WHEN b.bu_id IS NULL                        THEN 'BU not in scope'
                WHEN ai.cancelled_date IS NOT NULL          THEN 'cancelled'
                WHEN ai.invoice_date IS NULL
                  OR ai.invoice_date <  w.start_date
                  OR ai.invoice_date >= w.end_date_excl     THEN 'dated outside the window'
                ELSE 'counted'
           END                                                        AS reason
    FROM        ap_invoices_all ai
    CROSS JOIN  win             w
    LEFT JOIN   bu_scope        b ON b.bu_id = ai.org_id
),
ap_grp AS (
    SELECT reason, inv_type, pay_status, future, COUNT(*) AS n
    FROM   ap_tag
    GROUP  BY reason, inv_type, pay_status, future
),
ap_ex AS (
    SELECT reason, inv_type, pay_status, future,
           LISTAGG(doc_num, ', ') WITHIN GROUP (ORDER BY id DESC)     AS examples
    FROM  ( SELECT t.reason, t.inv_type, t.pay_status, t.future, t.doc_num, t.id,
                   ROW_NUMBER() OVER (PARTITION BY t.reason, t.inv_type, t.pay_status,
                                                   t.future
                                      ORDER BY t.id DESC)             AS rn
            FROM   ap_tag t )
    WHERE  rn <= 3
    GROUP  BY reason, inv_type, pay_status, future
),
ap_head AS (
    SELECT NVL(SUM(CASE WHEN reason = 'counted' THEN n END), 0)          AS f41,
           NVL(SUM(CASE WHEN reason = 'cancelled' THEN n END), 0)        AS cancelled,
           NVL(SUM(CASE WHEN reason = 'counted' AND future = 'Y'
                        THEN n END), 0)                                 AS future_n,
           NVL(SUM(CASE WHEN reason = 'counted' AND pay_status = 'Y'
                        THEN n END), 0)                                 AS paid,
           NVL(SUM(CASE WHEN reason = 'counted' AND pay_status = 'P'
                        THEN n END), 0)                                 AS part_paid,
           NVL(SUM(CASE WHEN reason = 'counted' AND pay_status = 'N'
                        THEN n END), 0)                                 AS unpaid
    FROM   ap_grp
),
ap_det AS (
    SELECT g.reason, g.inv_type, g.pay_status, g.future, g.n, e.examples,
           ROW_NUMBER() OVER (ORDER BY CASE WHEN g.reason = 'counted' THEN 0 ELSE 1 END,
                                       g.reason, g.n DESC, g.inv_type,
                                       g.pay_status, g.future)        AS rn
    FROM        ap_grp g
    LEFT JOIN   ap_ex  e ON  e.reason     = g.reason
                         AND e.inv_type   = g.inv_type
                         AND e.pay_status = g.pay_status
                         AND e.future     = g.future
),
-- ---- E. payments (F4.1 row 6) ------------------------------------------------------
pay_tag AS (
    SELECT ac.check_id                                                AS id,
           TO_CHAR(ac.check_number)                                   AS doc_num,
           ac.payment_method_code                                     AS method_code,
           NVL(TO_CHAR(ac.payment_method_code), '(no method)')        AS method,
           NVL(TO_CHAR(ac.status_lookup_code), '(null)')              AS pay_state,
           CASE WHEN ac.check_date >= TRUNC(SYSDATE) + 1 THEN 'Y' ELSE 'N' END AS future,
           CASE WHEN b.bu_id IS NULL                           THEN 'BU not in scope'
                WHEN NVL(ac.status_lookup_code, 'X') = 'VOIDED' THEN 'voided'
                WHEN ac.check_date IS NULL
                  OR ac.check_date <  w.start_date
                  OR ac.check_date >= w.end_date_excl          THEN 'dated outside the window'
                ELSE 'counted'
           END                                                        AS reason
    FROM        ap_checks_all ac
    CROSS JOIN  win           w
    LEFT JOIN   bu_scope      b ON b.bu_id = ac.org_id
),
method_names AS (
    SELECT pm.payment_method_code,
           TO_CHAR(MAX(pm.payment_method_name) KEEP (DENSE_RANK FIRST ORDER BY
               CASE WHEN pm.language = USERENV('LANG') THEN 0 ELSE 1 END)) AS method_name
    FROM   iby_payment_methods_tl pm
    WHERE  pm.language IN (USERENV('LANG'), 'US')
    GROUP  BY pm.payment_method_code
),
pay_grp AS (
    SELECT reason, method_code, method, pay_state, future, COUNT(*) AS n
    FROM   pay_tag
    GROUP  BY reason, method_code, method, pay_state, future
),
pay_ex AS (
    SELECT reason, method, pay_state, future,
           LISTAGG(doc_num, ', ') WITHIN GROUP (ORDER BY id DESC)     AS examples
    FROM  ( SELECT t.reason, t.method, t.pay_state, t.future, t.doc_num, t.id,
                   ROW_NUMBER() OVER (PARTITION BY t.reason, t.method, t.pay_state,
                                                   t.future
                                      ORDER BY t.id DESC)             AS rn
            FROM   pay_tag t )
    WHERE  rn <= 3
    GROUP  BY reason, method, pay_state, future
),
pay_head AS (
    SELECT NVL(SUM(CASE WHEN reason = 'counted' THEN n END), 0)          AS f41,
           NVL(SUM(CASE WHEN reason = 'voided' THEN n END), 0)           AS voided,
           NVL(SUM(CASE WHEN reason = 'counted' AND future = 'Y'
                        THEN n END), 0)                                 AS future_n
    FROM   pay_grp
),
pay_det AS (
    SELECT g.reason, g.method, mn.method_name, g.pay_state, g.future, g.n, e.examples,
           ROW_NUMBER() OVER (ORDER BY CASE WHEN g.reason = 'counted' THEN 0 ELSE 1 END,
                                       g.reason, g.n DESC, g.method,
                                       g.pay_state, g.future)         AS rn
    FROM        pay_grp      g
    LEFT JOIN   method_names mn ON mn.payment_method_code = g.method_code
    LEFT JOIN   pay_ex       e  ON  e.reason    = g.reason
                                AND e.method    = g.method
                                AND e.pay_state = g.pay_state
                                AND e.future    = g.future
),
grid AS (
    SELECT 1 AS ord, CAST('A REQUISITIONS' AS VARCHAR2(20)) AS block,
           CAST('F4.1 Requisitions sourced to POs - must equal the F4.1 run'
                AS VARCHAR2(400)) AS item,
           h.f41 AS value, CAST(NULL AS VARCHAR2(4000)) AS note
    FROM   req_head h
    UNION ALL
    SELECT 2, 'A REQUISITIONS', 'every requisition in scope and window, on a PO or not',
           h.in_scope, NULL
    FROM   req_head h
    UNION ALL
    SELECT 3, 'A REQUISITIONS', 'of them with no line on a PO (left out)', h.not_sourced, NULL
    FROM   req_head h
    UNION ALL
    SELECT 100 + d.rn, 'A REQUISITIONS',
           TO_CHAR(d.reason || ' | DOCUMENT_STATUS ' || d.doc_status
                   || ' | transfer requisition ' || d.transfer_req),
           d.n, TO_CHAR('latest: ' || d.examples)
    FROM   req_det d
    UNION ALL
    SELECT 1001, 'B PURCHASE ORDERS', 'F4.1 Total purchase orders - must equal the F4.1 run',
           h.f41, NULL
    FROM   po_head h
    UNION ALL
    SELECT 1002, 'B PURCHASE ORDERS', 'of it STANDARD purchase orders', h.std, NULL
    FROM   po_head h
    UNION ALL
    SELECT 1003, 'B PURCHASE ORDERS', 'of it BLANKET (in Fusion a purchase agreement)', h.bpa, NULL
    FROM   po_head h
    UNION ALL
    SELECT 1004, 'B PURCHASE ORDERS', 'of it PLANNED', h.planned, NULL
    FROM   po_head h
    UNION ALL
    SELECT 1005, 'B PURCHASE ORDERS', 'of it approved (APPROVED_FLAG Y)', h.appr_y, NULL
    FROM   po_head h
    UNION ALL
    SELECT 1006, 'B PURCHASE ORDERS', 'of it not approved (APPROVED_FLAG not Y)', h.appr_n, NULL
    FROM   po_head h
    UNION ALL
    SELECT 1007, 'B PURCHASE ORDERS', 'cancelled, left out (every type)', h.cancelled, NULL
    FROM   po_head h
    UNION ALL
    SELECT 1100 + d.rn, 'B PURCHASE ORDERS',
           TO_CHAR(d.reason || ' | ' || d.type_code || ' | DOCUMENT_STATUS ' || d.doc_status
                   || ' | APPROVED_FLAG ' || d.approved),
           d.n, TO_CHAR('latest: ' || d.examples)
    FROM   po_det d
    UNION ALL
    SELECT 2001, 'C PO RECEIPTS', 'F4.1 Total PO receipts (receipt headers) - must equal the F4.1 run',
           h.f41, NULL
    FROM   rt_head h
    UNION ALL
    SELECT 2002, 'C PO RECEIPTS', 'RECEIVE lines behind those receipt headers', h.f41_lines, NULL
    FROM   rt_head h
    UNION ALL
    SELECT 2003, 'C PO RECEIPTS', 'receipt headers with a RECEIVE line not against a PO (left out)',
           h.not_po, NULL
    FROM   rt_head h
    UNION ALL
    SELECT 2100 + d.rn, 'C PO RECEIPTS',
           TO_CHAR(d.reason || ' | ' || d.ttype || ' | against a PO ' || d.on_po),
           d.docs,
           TO_CHAR('lines: ' || TO_CHAR(d.lines) || ' | latest: ' || d.examples)
    FROM   rt_det d
    UNION ALL
    SELECT 3001, 'D AP INVOICES', 'F4.1 Total AP invoices - must equal the F4.1 run', h.f41, NULL
    FROM   ap_head h
    UNION ALL
    SELECT 3002, 'D AP INVOICES', 'cancelled, left out', h.cancelled, NULL
    FROM   ap_head h
    UNION ALL
    SELECT 3003, 'D AP INVOICES', 'counted, dated after today', h.future_n, NULL
    FROM   ap_head h
    UNION ALL
    SELECT 3004, 'D AP INVOICES', 'counted, fully paid (PAYMENT_STATUS_FLAG Y)', h.paid, NULL
    FROM   ap_head h
    UNION ALL
    SELECT 3005, 'D AP INVOICES', 'counted, partly paid (P)', h.part_paid, NULL
    FROM   ap_head h
    UNION ALL
    SELECT 3006, 'D AP INVOICES', 'counted, unpaid (N)', h.unpaid, NULL
    FROM   ap_head h
    UNION ALL
    SELECT 3100 + d.rn, 'D AP INVOICES',
           TO_CHAR(d.reason || ' | ' || d.inv_type || ' | PAYMENT_STATUS_FLAG '
                   || d.pay_status || ' | dated after today ' || d.future),
           d.n, TO_CHAR('latest: ' || d.examples)
    FROM   ap_det d
    UNION ALL
    SELECT 4001, 'E PAYMENTS', 'F4.1 Total payments - must equal the F4.1 run', h.f41, NULL
    FROM   pay_head h
    UNION ALL
    SELECT 4002, 'E PAYMENTS', 'voided, left out', h.voided, NULL
    FROM   pay_head h
    UNION ALL
    SELECT 4003, 'E PAYMENTS', 'counted, dated after today', h.future_n, NULL
    FROM   pay_head h
    UNION ALL
    SELECT 4100 + d.rn, 'E PAYMENTS',
           TO_CHAR(d.reason || ' | ' || NVL(d.method_name, d.method)
                   || ' | STATUS_LOOKUP_CODE ' || d.pay_state
                   || ' | dated after today ' || d.future),
           d.n, TO_CHAR('latest: ' || d.examples)
    FROM   pay_det d
)
SELECT  g.ord    AS ord,
        g.block  AS block,
        g.item   AS item,
        g.value  AS value,
        g.note   AS note
FROM    grid g
ORDER BY g.ord
