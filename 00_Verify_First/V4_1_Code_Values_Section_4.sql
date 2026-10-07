-- ============================================================================
--  V4_1  CODE VALUES - the values Section 4 filters on, as stored on THIS pod
--  Version   : 1.0 (2026-10-05)        Run log: 06_Run_Results/RUN_LOG.md
--  Run AFTER V4_0 reads ALL OK (this one reads data, so a missing column
--  would make it fail - V4_0 proves the columns first).
--
--  WHY  Section 4 classifies rows by code values taken from the EBS logic or
--  from Oracle's documentation (e.g. 'RETURN', 'CL', 'RECEIVE', 'VOIDED', 'P').
--  Some Oracle pages give no value list (DOO_LINES_ALL.CATEGORY_CODE has a
--  copy-paste description). Rule kept from the EBS project: print the codes
--  that are really stored BEFORE trusting a classification on them.
--
--  OUTPUT  ord | item | value | row_count   (all time, whole pod - no binds)
--    1  DOO_LINES_ALL.CATEGORY_CODE         F4.2 RMA uses 'RETURN'
--    2  DOO_HEADERS_ALL.SUBMITTED_FLAG      F4.2 collapses Y / N versions
--    3  orders in total / orders with more than one header row (evidence that
--       revisions exist and that F4.2 must group per order)
--    4  RCV_TRANSACTIONS.TRANSACTION_TYPE   F4.1 receipts use 'RECEIVE'
--    5  PO_HEADERS_ALL.TYPE_LOOKUP_CODE     F4.1 POs use STANDARD/BLANKET/PLANNED
--    6  AP_INVOICES_ALL.INVOICE_TYPE_LOOKUP_CODE  F4.1 invoice-type rows
--    7  FND_LOOKUP_VALUES 'INVOICE TYPE'    the names F4.1 prints for 6
--    8  AP_CHECKS_ALL.STATUS_LOOKUP_CODE    F4.1 excludes 'VOIDED'
--    9  AP_CHECKS_ALL.PAYMENT_METHOD_CODE   F4.1 payment-method rows
--   10  WSH_NEW_DELIVERIES.STATUS_CODE      F4.2 deliveries use 'CL'
--   11  GL_JE_HEADERS.STATUS                F4.3 / WB use 'P' (posted)
--   12  RA_CUST_TRX_TYPES_ALL.TYPE          F4.2 uses INV / CM / DM
--   13  CST_COST_PROFILES_B.COST_METHOD_CODE  F4.5 method codes
--   14  CST_COST_ORG_BOOKS.PRIMARY_BOOK_FLAG  F4.5 uses 'Y'
--   15  FND_LOOKUP_VALUES types like %COST%METHOD%  candidate names for 13
--   16  PJF_PROJECTS_ALL_B.TEMPLATE_FLAG    F4.4 template count uses 'Y'
--  Pure SELECT, one statement, every aggregate in its own CTE, no DISTINCT.
--  Some groups scan large tables once (GROUP BY one column) - allow it time.
-- ============================================================================
WITH
v01 AS (
    SELECT NVL(dl.category_code, '(null)') AS val, COUNT(*) AS n
    FROM   doo_lines_all dl
    GROUP  BY NVL(dl.category_code, '(null)')
),
v02 AS (
    SELECT NVL(dh.submitted_flag, '(null)') AS val, COUNT(*) AS n
    FROM   doo_headers_all dh
    GROUP  BY NVL(dh.submitted_flag, '(null)')
),
v03_orders AS (
    SELECT dh.order_number, dh.source_order_system, COUNT(*) AS hdr_rows
    FROM   doo_headers_all dh
    GROUP  BY dh.order_number, dh.source_order_system
),
v03_total AS (
    SELECT COUNT(*) AS n FROM v03_orders
),
v03_multi AS (
    SELECT COUNT(*) AS n FROM v03_orders WHERE hdr_rows > 1
),
v04 AS (
    SELECT NVL(rt.transaction_type, '(null)') AS val, COUNT(*) AS n
    FROM   rcv_transactions rt
    GROUP  BY NVL(rt.transaction_type, '(null)')
),
v05 AS (
    SELECT NVL(ph.type_lookup_code, '(null)') AS val, COUNT(*) AS n
    FROM   po_headers_all ph
    GROUP  BY NVL(ph.type_lookup_code, '(null)')
),
v06 AS (
    SELECT NVL(ai.invoice_type_lookup_code, '(null)') AS val, COUNT(*) AS n
    FROM   ap_invoices_all ai
    GROUP  BY NVL(ai.invoice_type_lookup_code, '(null)')
),
v07 AS (
    SELECT lv.lookup_code || ' = ' || MAX(lv.meaning) AS val, COUNT(*) AS n
    FROM   fnd_lookup_values lv
    WHERE  lv.lookup_type = 'INVOICE TYPE'
    AND    lv.language    = 'US'
    GROUP  BY lv.lookup_code
),
v08 AS (
    SELECT NVL(ac.status_lookup_code, '(null)') AS val, COUNT(*) AS n
    FROM   ap_checks_all ac
    GROUP  BY NVL(ac.status_lookup_code, '(null)')
),
v09 AS (
    SELECT NVL(ac.payment_method_code, '(null)') AS val, COUNT(*) AS n
    FROM   ap_checks_all ac
    GROUP  BY NVL(ac.payment_method_code, '(null)')
),
v10 AS (
    SELECT NVL(wnd.status_code, '(null)') AS val, COUNT(*) AS n
    FROM   wsh_new_deliveries wnd
    GROUP  BY NVL(wnd.status_code, '(null)')
),
v11 AS (
    SELECT NVL(h.status, '(null)') AS val, COUNT(*) AS n
    FROM   gl_je_headers h
    GROUP  BY NVL(h.status, '(null)')
),
v12 AS (
    SELECT NVL(tt.type, '(null)') AS val, COUNT(*) AS n
    FROM   ra_cust_trx_types_all tt
    GROUP  BY NVL(tt.type, '(null)')
),
v13 AS (
    SELECT NVL(cp.cost_method_code, '(null)') AS val, COUNT(*) AS n
    FROM   cst_cost_profiles_b cp
    GROUP  BY NVL(cp.cost_method_code, '(null)')
),
v14 AS (
    SELECT NVL(cob.primary_book_flag, '(null)') AS val, COUNT(*) AS n
    FROM   cst_cost_org_books cob
    GROUP  BY NVL(cob.primary_book_flag, '(null)')
),
v15 AS (
    SELECT lv.lookup_type || ' : ' || lv.lookup_code || ' = ' || MAX(lv.meaning) AS val,
           COUNT(*) AS n
    FROM   fnd_lookup_values lv
    WHERE  UPPER(lv.lookup_type) LIKE '%COST%METHOD%'
    AND    lv.language = 'US'
    GROUP  BY lv.lookup_type, lv.lookup_code
),
v16 AS (
    SELECT NVL(pp.template_flag, '(null)') AS val, COUNT(*) AS n
    FROM   pjf_projects_all_b pp
    GROUP  BY NVL(pp.template_flag, '(null)')
),
grid AS (
    SELECT 1 AS ord, 'DOO_LINES_ALL.CATEGORY_CODE' AS item, v.val AS val, v.n AS row_count
    FROM   v01 v
    UNION ALL
    SELECT 2, 'DOO_HEADERS_ALL.SUBMITTED_FLAG', v.val, v.n FROM v02 v
    UNION ALL
    SELECT 3, 'Orders (ORDER_NUMBER + SOURCE_ORDER_SYSTEM) in total', '-', v.n FROM v03_total v
    UNION ALL
    SELECT 3, 'Orders with more than one header row (revisions)', '-', v.n FROM v03_multi v
    UNION ALL
    SELECT 4, 'RCV_TRANSACTIONS.TRANSACTION_TYPE', v.val, v.n FROM v04 v
    UNION ALL
    SELECT 5, 'PO_HEADERS_ALL.TYPE_LOOKUP_CODE', v.val, v.n FROM v05 v
    UNION ALL
    SELECT 6, 'AP_INVOICES_ALL.INVOICE_TYPE_LOOKUP_CODE', v.val, v.n FROM v06 v
    UNION ALL
    SELECT 7, 'FND_LOOKUP_VALUES INVOICE TYPE (code = name)', v.val, v.n FROM v07 v
    UNION ALL
    SELECT 8, 'AP_CHECKS_ALL.STATUS_LOOKUP_CODE', v.val, v.n FROM v08 v
    UNION ALL
    SELECT 9, 'AP_CHECKS_ALL.PAYMENT_METHOD_CODE', v.val, v.n FROM v09 v
    UNION ALL
    SELECT 10, 'WSH_NEW_DELIVERIES.STATUS_CODE', v.val, v.n FROM v10 v
    UNION ALL
    SELECT 11, 'GL_JE_HEADERS.STATUS', v.val, v.n FROM v11 v
    UNION ALL
    SELECT 12, 'RA_CUST_TRX_TYPES_ALL.TYPE', v.val, v.n FROM v12 v
    UNION ALL
    SELECT 13, 'CST_COST_PROFILES_B.COST_METHOD_CODE', v.val, v.n FROM v13 v
    UNION ALL
    SELECT 14, 'CST_COST_ORG_BOOKS.PRIMARY_BOOK_FLAG', v.val, v.n FROM v14 v
    UNION ALL
    SELECT 15, 'FND_LOOKUP_VALUES types like %COST%METHOD%', v.val, v.n FROM v15 v
    UNION ALL
    SELECT 16, 'PJF_PROJECTS_ALL_B.TEMPLATE_FLAG', v.val, v.n FROM v16 v
)
SELECT  g.ord        AS ord,
        g.item       AS item,
        g.val        AS value,
        g.row_count  AS row_count
FROM    grid g
ORDER BY g.ord, g.row_count DESC, g.val
