-- ============================================================================
--  V4_3  O2C RECONCILIATION - why F4.2 differs from the consultant's counts
--  Version   : 1.2 (2026-10-13). Not yet run. v1.2 adds blocks C (AR
--              transactions) and D (cash receipts): the consultant counts
--              2,359 receipts where F4.2 counts 2,424, and F4.2 counts every
--              receipt and every AR transaction, reversed / incomplete /
--              future-dated included. Blocks A and B unchanged.
--              v1.1 (2026-10-13). v1.0 ran 2026-10-13 (blank dates): rows 7 /
--              6 / 1002 = 5,913 / 327 / 8,744, the consultant's figures; rows
--              1 / 2 / 1001 = the F4.2 v1.2 run (6,656 / 335 / 8,322). F4.2
--              v1.3 adopts the consultant's rules. v1.1: the "must equal" rows
--              now test F4.2 v1.3 (rows 6, 7, 1004); rows 1, 2, 1001 keep the
--              v1.2 rules for comparison. Counts unchanged.
--              Run log: 06_Run_Results/RUN_LOG.md
--  Run AFTER V4_0 reads ALL OK, with EXACTLY the parameters of the F4.2 run
--  being explained (blank dates = all history, shared block v3.2).
--
--  WHY  F4.2 v1.2 with blank dates (2026-10-13) gave Sales Orders 6,656,
--  Deliveries 8,322 and RMA 335. The functional consultant's figures are
--  about 5,913 / 8,744 / 327.
--    Orders: F4.2 counts every order, including those never submitted
--    (README_SECTION_7: 1,077 drafts or approval-pending orders, counted for
--    EBS parity). 6,656 + 335 - 1,077 = 5,914, so the consultant most likely
--    counts submitted orders, returns included. Block A proves the split.
--    Deliveries: F4.2 counts STATUS_CODE 'CL' with a pickup date only. Block
--    B shows every status, so the rows that make up 8,744 can be read off.
--
--  OUTPUT  ord | block | item | value   (value = a count)
--    A  ORDERS, one per order, the F4.2 rule: revisions collapsed, the
--       submitted version counted when one exists
--       1-2     the F4.2 v1.2 rules (drafts in, returns out of Sales Orders)
--       3-7     the same split into submitted / never submitted; row 6 =
--               F4.2 v1.3 RMA, row 7 = F4.2 v1.3 Sales Orders (submitted,
--               returns included) - both must equal the F4.2 run
--       8-10    submitted and not cancelled (CANCELED_FLAG on that version)
--       100+    every combination inside F4.2's count: return / submitted /
--               STATUS_CODE / CANCELED_FLAG of the counted version
--       900+    orders F4.2 leaves out, and why (BU not in scope; ordered date
--               empty or outside the window)
--    B  DELIVERIES (WSH_NEW_DELIVERIES)
--       1001    the F4.2 v1.2 rule (CL only)
--       1002    every delivery in an organization in scope, any status
--       1003    every delivery on the pod
--       1004    F4.2 v1.3 Deliveries (any status, pickup date in the window)
--               - must equal the F4.2 run
--       1100+   every combination: STATUS_CODE / organization in scope /
--               pickup date in the window (N = empty, or outside the window)
--    C  AR TRANSACTIONS (RA_CUSTOMER_TRX_ALL, F4.2 population)
--       2001    F4.2's own AR transactions - must equal the F4.2 run
--       2002-5  complete / incomplete (COMPLETE_FLAG), dated after today,
--               complete and dated up to today
--       2100+   every combination: class (type's TYPE) / COMPLETE_FLAG /
--               dated after today
--       2900+   transactions F4.2 leaves out, and why
--    D  CASH RECEIPTS (AR_CASH_RECEIPTS_ALL, F4.2 population)
--       3001    F4.2's own Cash receipts - must equal the F4.2 run
--       3002-8  not reversed (the F7.1 row 8 rule: REVERSAL_DATE empty and
--               STATUS not REV), reversed, standard (TYPE CASH), misc
--               (TYPE MISC), standard not reversed, dated after today,
--               not reversed and dated up to today
--       3100+   every combination: TYPE / STATUS / reversed / dated after
--               today
--       3900+   receipts F4.2 leaves out, and why
--  Columns: those V4_0 / V7_0 already proved on this pod (R042), plus
--  AR_CASH_RECEIPTS_ALL.TYPE (not yet proved; an ORA-00904 on TYPE means
--  the column is missing - report it).
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
-- ---- A. orders ----------------------------------------------------------------
-- one row per order, the version F4.2 counts (submitted first, then the
-- latest header row), and whether ANY version was ever submitted
ord_all AS (
    SELECT dh.order_number,
           dh.source_order_system,
           MAX(dh.ordered_date) KEEP (DENSE_RANK FIRST ORDER BY
               CASE WHEN dh.submitted_flag = 'Y' THEN 0 ELSE 1 END, dh.header_id DESC)
                                                                    AS ordered_date,
           MAX(dh.org_id) KEEP (DENSE_RANK FIRST ORDER BY
               CASE WHEN dh.submitted_flag = 'Y' THEN 0 ELSE 1 END, dh.header_id DESC)
                                                                    AS org_id,
           MAX(dh.status_code) KEEP (DENSE_RANK FIRST ORDER BY
               CASE WHEN dh.submitted_flag = 'Y' THEN 0 ELSE 1 END, dh.header_id DESC)
                                                                    AS status_code,
           MAX(dh.canceled_flag) KEEP (DENSE_RANK FIRST ORDER BY
               CASE WHEN dh.submitted_flag = 'Y' THEN 0 ELSE 1 END, dh.header_id DESC)
                                                                    AS canceled_flag,
           MAX(CASE WHEN dh.submitted_flag = 'Y' THEN 1 ELSE 0 END)  AS ever_submitted
    FROM   doo_headers_all dh
    GROUP  BY dh.order_number, dh.source_order_system
),
-- orders with at least one return line on any of their header rows
return_orders AS (
    SELECT dh.order_number, dh.source_order_system
    FROM   doo_headers_all dh
    WHERE  EXISTS ( SELECT 1
                    FROM   doo_lines_all dl
                    WHERE  dl.header_id     = dh.header_id
                    AND    dl.category_code = 'RETURN' )
    GROUP  BY dh.order_number, dh.source_order_system
),
-- every order tagged: return, submitted, status, and whether F4.2 counts it
ord_tag AS (
    SELECT CASE WHEN r.order_number IS NOT NULL THEN 'Y' ELSE 'N' END   AS is_return,
           CASE WHEN o.ever_submitted = 1 THEN 'Y' ELSE 'N' END          AS submitted,
           NVL(TO_CHAR(o.status_code), '(null)')                         AS status_code,
           NVL(TO_CHAR(o.canceled_flag), '(null)')                       AS canceled_flag,
           CASE WHEN b.bu_id IS NULL THEN 'N' ELSE 'Y' END               AS bu_ok,
           CASE WHEN o.ordered_date IS NULL                THEN 'empty'
                WHEN o.ordered_date >= w.start_date
                 AND o.ordered_date <  w.end_date_excl     THEN 'Y'
                ELSE 'N'
           END                                                           AS win_ok
    FROM        ord_all       o
    CROSS JOIN  win           w
    LEFT JOIN   bu_scope      b ON b.bu_id = o.org_id
    LEFT JOIN   return_orders r ON r.order_number = o.order_number
                               AND NVL(r.source_order_system, '~')
                                 = NVL(o.source_order_system, '~')
),
ord_grp AS (
    SELECT is_return, submitted, status_code, canceled_flag, bu_ok, win_ok,
           COUNT(*) AS n
    FROM   ord_tag
    GROUP  BY is_return, submitted, status_code, canceled_flag, bu_ok, win_ok
),
ord_head AS (
    SELECT NVL(SUM(CASE WHEN bu_ok = 'Y' AND win_ok = 'Y' AND is_return = 'N'
                        THEN n END), 0)                                  AS so_f42,
           NVL(SUM(CASE WHEN bu_ok = 'Y' AND win_ok = 'Y' AND is_return = 'Y'
                        THEN n END), 0)                                  AS rma_f42,
           NVL(SUM(CASE WHEN bu_ok = 'Y' AND win_ok = 'Y' AND is_return = 'N'
                         AND submitted = 'N' THEN n END), 0)             AS so_draft,
           NVL(SUM(CASE WHEN bu_ok = 'Y' AND win_ok = 'Y' AND is_return = 'N'
                         AND submitted = 'Y' THEN n END), 0)             AS so_sub,
           NVL(SUM(CASE WHEN bu_ok = 'Y' AND win_ok = 'Y' AND is_return = 'Y'
                         AND submitted = 'N' THEN n END), 0)             AS rma_draft,
           NVL(SUM(CASE WHEN bu_ok = 'Y' AND win_ok = 'Y' AND is_return = 'Y'
                         AND submitted = 'Y' THEN n END), 0)             AS rma_sub,
           NVL(SUM(CASE WHEN bu_ok = 'Y' AND win_ok = 'Y' AND is_return = 'N'
                         AND submitted = 'Y' AND canceled_flag <> 'Y'
                        THEN n END), 0)                                  AS so_sub_nc,
           NVL(SUM(CASE WHEN bu_ok = 'Y' AND win_ok = 'Y' AND is_return = 'Y'
                         AND submitted = 'Y' AND canceled_flag <> 'Y'
                        THEN n END), 0)                                  AS rma_sub_nc
    FROM   ord_grp
),
-- inside F4.2's count, one row per combination
ord_det AS (
    SELECT is_return, submitted, status_code, canceled_flag, n,
           ROW_NUMBER() OVER (ORDER BY is_return, submitted, status_code,
                                       canceled_flag)                    AS rn
    FROM   ord_grp
    WHERE  bu_ok = 'Y' AND win_ok = 'Y'
),
-- left out of F4.2's count, by reason
ord_out_grp AS (
    SELECT bu_ok, win_ok, is_return, SUM(n) AS n
    FROM   ord_grp
    WHERE  NOT (bu_ok = 'Y' AND win_ok = 'Y')
    GROUP  BY bu_ok, win_ok, is_return
),
ord_out AS (
    SELECT bu_ok, win_ok, is_return, n,
           ROW_NUMBER() OVER (ORDER BY bu_ok, win_ok, is_return)         AS rn
    FROM   ord_out_grp
),
-- ---- B. deliveries -------------------------------------------------------------
dlv_tag AS (
    SELECT NVL(TO_CHAR(wnd.status_code), '(null)')                       AS status_code,
           CASE WHEN ios.organization_id IS NULL THEN 'N' ELSE 'Y' END   AS org_ok,
           CASE WHEN wnd.initial_pickup_date >= w.start_date
                 AND wnd.initial_pickup_date <  w.end_date_excl THEN 'Y'
                ELSE 'N'
           END                                                           AS win_ok
    FROM        wsh_new_deliveries wnd
    CROSS JOIN  win                w
    LEFT JOIN   inv_org_scope      ios ON ios.organization_id = wnd.organization_id
),
dlv_grp AS (
    SELECT status_code, org_ok, win_ok, COUNT(*) AS n
    FROM   dlv_tag
    GROUP  BY status_code, org_ok, win_ok
),
dlv_head AS (
    SELECT NVL(SUM(CASE WHEN status_code = 'CL' AND org_ok = 'Y' AND win_ok = 'Y'
                        THEN n END), 0)                                  AS dlv_f42,
           NVL(SUM(CASE WHEN org_ok = 'Y' THEN n END), 0)                AS dlv_scope,
           NVL(SUM(CASE WHEN org_ok = 'Y' AND win_ok = 'Y'
                        THEN n END), 0)                                  AS dlv_f43,
           NVL(SUM(n), 0)                                                AS dlv_pod
    FROM   dlv_grp
),
dlv_det AS (
    SELECT status_code, org_ok, win_ok, n,
           ROW_NUMBER() OVER (ORDER BY org_ok DESC, status_code, win_ok DESC) AS rn
    FROM   dlv_grp
),
-- ---- C. AR transactions --------------------------------------------------------
-- the F4.2 population (BU in scope, TRX_DATE in the window), every row tagged
ar_tag AS (
    SELECT NVL(TO_CHAR(tt.type), '(no type)')                            AS trx_class,
           NVL(TO_CHAR(ct.complete_flag), '(null)')                      AS complete_flag,
           CASE WHEN ct.trx_date >= TRUNC(SYSDATE) + 1 THEN 'Y' ELSE 'N' END AS future,
           CASE WHEN b.bu_id IS NULL THEN 'N' ELSE 'Y' END               AS bu_ok,
           CASE WHEN ct.trx_date IS NULL                THEN 'empty'
                WHEN ct.trx_date >= w.start_date
                 AND ct.trx_date <  w.end_date_excl     THEN 'Y'
                ELSE 'N'
           END                                                           AS win_ok
    FROM        ra_customer_trx_all   ct
    CROSS JOIN  win                   w
    LEFT JOIN   bu_scope              b  ON b.bu_id = ct.org_id
    LEFT JOIN   ra_cust_trx_types_all tt ON tt.cust_trx_type_seq_id = ct.cust_trx_type_seq_id
),
ar_grp AS (
    SELECT trx_class, complete_flag, future, bu_ok, win_ok, COUNT(*) AS n
    FROM   ar_tag
    GROUP  BY trx_class, complete_flag, future, bu_ok, win_ok
),
ar_head AS (
    SELECT NVL(SUM(CASE WHEN bu_ok = 'Y' AND win_ok = 'Y' THEN n END), 0)   AS ar_f42,
           NVL(SUM(CASE WHEN bu_ok = 'Y' AND win_ok = 'Y'
                         AND complete_flag = 'Y' THEN n END), 0)            AS ar_complete,
           NVL(SUM(CASE WHEN bu_ok = 'Y' AND win_ok = 'Y'
                         AND complete_flag <> 'Y' THEN n END), 0)           AS ar_incomplete,
           NVL(SUM(CASE WHEN bu_ok = 'Y' AND win_ok = 'Y'
                         AND future = 'Y' THEN n END), 0)                   AS ar_future,
           NVL(SUM(CASE WHEN bu_ok = 'Y' AND win_ok = 'Y'
                         AND complete_flag = 'Y' AND future = 'N'
                        THEN n END), 0)                                     AS ar_complete_todate
    FROM   ar_grp
),
ar_det AS (
    SELECT trx_class, complete_flag, future, n,
           ROW_NUMBER() OVER (ORDER BY trx_class, complete_flag, future)    AS rn
    FROM   ar_grp
    WHERE  bu_ok = 'Y' AND win_ok = 'Y'
),
ar_out_grp AS (
    SELECT bu_ok, win_ok, SUM(n) AS n
    FROM   ar_grp
    WHERE  NOT (bu_ok = 'Y' AND win_ok = 'Y')
    GROUP  BY bu_ok, win_ok
),
ar_out AS (
    SELECT bu_ok, win_ok, n,
           ROW_NUMBER() OVER (ORDER BY bu_ok, win_ok)                       AS rn
    FROM   ar_out_grp
),
-- ---- D. cash receipts -----------------------------------------------------------
-- the F4.2 population (BU in scope, RECEIPT_DATE in the window), every row tagged
rc_tag AS (
    SELECT NVL(TO_CHAR(cr.type), '(null)')                               AS rc_type,
           NVL(TO_CHAR(cr.status), '(null)')                             AS rc_status,
           CASE WHEN cr.reversal_date IS NULL THEN 'N' ELSE 'Y' END      AS reversed,
           CASE WHEN cr.receipt_date >= TRUNC(SYSDATE) + 1 THEN 'Y' ELSE 'N' END AS future,
           CASE WHEN b.bu_id IS NULL THEN 'N' ELSE 'Y' END               AS bu_ok,
           CASE WHEN cr.receipt_date IS NULL            THEN 'empty'
                WHEN cr.receipt_date >= w.start_date
                 AND cr.receipt_date <  w.end_date_excl THEN 'Y'
                ELSE 'N'
           END                                                           AS win_ok
    FROM        ar_cash_receipts_all cr
    CROSS JOIN  win                  w
    LEFT JOIN   bu_scope             b ON b.bu_id = cr.org_id
),
rc_grp AS (
    SELECT rc_type, rc_status, reversed, future, bu_ok, win_ok, COUNT(*) AS n
    FROM   rc_tag
    GROUP  BY rc_type, rc_status, reversed, future, bu_ok, win_ok
),
-- "live" = not reversed, the F7.1 row 8 rule: REVERSAL_DATE empty, STATUS not REV
rc_head AS (
    SELECT NVL(SUM(CASE WHEN bu_ok = 'Y' AND win_ok = 'Y' THEN n END), 0)   AS rc_f42,
           NVL(SUM(CASE WHEN bu_ok = 'Y' AND win_ok = 'Y'
                         AND reversed = 'N' AND rc_status <> 'REV'
                        THEN n END), 0)                                     AS rc_live,
           NVL(SUM(CASE WHEN bu_ok = 'Y' AND win_ok = 'Y'
                         AND NOT (reversed = 'N' AND rc_status <> 'REV')
                        THEN n END), 0)                                     AS rc_reversed,
           NVL(SUM(CASE WHEN bu_ok = 'Y' AND win_ok = 'Y'
                         AND rc_type = 'CASH' THEN n END), 0)               AS rc_std,
           NVL(SUM(CASE WHEN bu_ok = 'Y' AND win_ok = 'Y'
                         AND rc_type = 'MISC' THEN n END), 0)               AS rc_misc,
           NVL(SUM(CASE WHEN bu_ok = 'Y' AND win_ok = 'Y' AND rc_type = 'CASH'
                         AND reversed = 'N' AND rc_status <> 'REV'
                        THEN n END), 0)                                     AS rc_std_live,
           NVL(SUM(CASE WHEN bu_ok = 'Y' AND win_ok = 'Y'
                         AND future = 'Y' THEN n END), 0)                   AS rc_future,
           NVL(SUM(CASE WHEN bu_ok = 'Y' AND win_ok = 'Y'
                         AND reversed = 'N' AND rc_status <> 'REV'
                         AND future = 'N' THEN n END), 0)                   AS rc_live_todate
    FROM   rc_grp
),
rc_det AS (
    SELECT rc_type, rc_status, reversed, future, n,
           ROW_NUMBER() OVER (ORDER BY rc_type, rc_status, reversed, future) AS rn
    FROM   rc_grp
    WHERE  bu_ok = 'Y' AND win_ok = 'Y'
),
rc_out_grp AS (
    SELECT bu_ok, win_ok, SUM(n) AS n
    FROM   rc_grp
    WHERE  NOT (bu_ok = 'Y' AND win_ok = 'Y')
    GROUP  BY bu_ok, win_ok
),
rc_out AS (
    SELECT bu_ok, win_ok, n,
           ROW_NUMBER() OVER (ORDER BY bu_ok, win_ok)                       AS rn
    FROM   rc_out_grp
),
grid AS (
    SELECT 1 AS ord, CAST('A ORDERS' AS VARCHAR2(20)) AS block,
           CAST('F4.2 v1.2 rule: Sales Orders (no return line, drafts in)'
                AS VARCHAR2(400)) AS item,
           h.so_f42 AS value
    FROM   ord_head h
    UNION ALL
    SELECT 2, 'A ORDERS', 'F4.2 v1.2 rule: RMA (drafts in)', h.rma_f42
    FROM   ord_head h
    UNION ALL
    SELECT 3, 'A ORDERS', 'Sales Orders never submitted (draft / pending approval)', h.so_draft
    FROM   ord_head h
    UNION ALL
    SELECT 4, 'A ORDERS', 'Sales Orders submitted', h.so_sub
    FROM   ord_head h
    UNION ALL
    SELECT 5, 'A ORDERS', 'RMA never submitted', h.rma_draft
    FROM   ord_head h
    UNION ALL
    SELECT 6, 'A ORDERS', 'RMA submitted - F4.2 v1.3 RMA, must equal the F4.2 run', h.rma_sub
    FROM   ord_head h
    UNION ALL
    SELECT 7, 'A ORDERS', 'submitted orders, returns included (4 + 6) - F4.2 v1.3 Sales Orders, must equal the F4.2 run',
           h.so_sub + h.rma_sub
    FROM   ord_head h
    UNION ALL
    SELECT 8, 'A ORDERS', 'Sales Orders submitted, not cancelled', h.so_sub_nc
    FROM   ord_head h
    UNION ALL
    SELECT 9, 'A ORDERS', 'RMA submitted, not cancelled', h.rma_sub_nc
    FROM   ord_head h
    UNION ALL
    SELECT 10, 'A ORDERS', 'submitted, not cancelled, returns included (8 + 9)',
           h.so_sub_nc + h.rma_sub_nc
    FROM   ord_head h
    UNION ALL
    SELECT 100 + d.rn, 'A ORDERS',
           TO_CHAR('in F4.2 | return ' || d.is_return || ' | submitted ' || d.submitted
                   || ' | STATUS_CODE ' || d.status_code
                   || ' | CANCELED_FLAG ' || d.canceled_flag),
           d.n
    FROM   ord_det d
    UNION ALL
    SELECT 900 + o.rn, 'A ORDERS',
           TO_CHAR('left out of F4.2 | BU in scope ' || o.bu_ok
                   || ' | ordered date in window ' || o.win_ok
                   || ' | return ' || o.is_return),
           o.n
    FROM   ord_out o
    UNION ALL
    SELECT 1001, 'B DELIVERIES', 'F4.2 v1.2 rule: Deliveries (CL only, pickup date in window)',
           h.dlv_f42
    FROM   dlv_head h
    UNION ALL
    SELECT 1002, 'B DELIVERIES', 'every delivery in an organization in scope, any status',
           h.dlv_scope
    FROM   dlv_head h
    UNION ALL
    SELECT 1003, 'B DELIVERIES', 'every delivery on the pod', h.dlv_pod
    FROM   dlv_head h
    UNION ALL
    SELECT 1004, 'B DELIVERIES',
           'F4.2 v1.3 Deliveries (any status, pickup date in window) - must equal the F4.2 run',
           h.dlv_f43
    FROM   dlv_head h
    UNION ALL
    SELECT 1100 + d.rn, 'B DELIVERIES',
           TO_CHAR('STATUS_CODE ' || d.status_code
                   || ' | organization in scope ' || d.org_ok
                   || ' | pickup date in window ' || d.win_ok),
           d.n
    FROM   dlv_det d
    UNION ALL
    SELECT 2001, 'C AR TRANSACTIONS',
           'F4.2 AR transactions (every class, complete or not) - must equal the F4.2 run',
           h.ar_f42
    FROM   ar_head h
    UNION ALL
    SELECT 2002, 'C AR TRANSACTIONS', 'complete (COMPLETE_FLAG Y)', h.ar_complete
    FROM   ar_head h
    UNION ALL
    SELECT 2003, 'C AR TRANSACTIONS', 'incomplete (COMPLETE_FLAG not Y)', h.ar_incomplete
    FROM   ar_head h
    UNION ALL
    SELECT 2004, 'C AR TRANSACTIONS', 'dated after today', h.ar_future
    FROM   ar_head h
    UNION ALL
    SELECT 2005, 'C AR TRANSACTIONS', 'complete, dated up to today', h.ar_complete_todate
    FROM   ar_head h
    UNION ALL
    SELECT 2100 + d.rn, 'C AR TRANSACTIONS',
           TO_CHAR('in F4.2 | class ' || d.trx_class
                   || ' | COMPLETE_FLAG ' || d.complete_flag
                   || ' | dated after today ' || d.future),
           d.n
    FROM   ar_det d
    UNION ALL
    SELECT 2900 + o.rn, 'C AR TRANSACTIONS',
           TO_CHAR('left out of F4.2 | BU in scope ' || o.bu_ok
                   || ' | transaction date in window ' || o.win_ok),
           o.n
    FROM   ar_out o
    UNION ALL
    SELECT 3001, 'D CASH RECEIPTS',
           'F4.2 Cash receipts (every receipt) - must equal the F4.2 run', h.rc_f42
    FROM   rc_head h
    UNION ALL
    SELECT 3002, 'D CASH RECEIPTS', 'not reversed (F7.1 row 8 rule)', h.rc_live
    FROM   rc_head h
    UNION ALL
    SELECT 3003, 'D CASH RECEIPTS', 'reversed (REVERSAL_DATE set or STATUS REV)', h.rc_reversed
    FROM   rc_head h
    UNION ALL
    SELECT 3004, 'D CASH RECEIPTS', 'standard receipts (TYPE CASH)', h.rc_std
    FROM   rc_head h
    UNION ALL
    SELECT 3005, 'D CASH RECEIPTS', 'miscellaneous receipts (TYPE MISC)', h.rc_misc
    FROM   rc_head h
    UNION ALL
    SELECT 3006, 'D CASH RECEIPTS', 'standard receipts, not reversed', h.rc_std_live
    FROM   rc_head h
    UNION ALL
    SELECT 3007, 'D CASH RECEIPTS', 'dated after today', h.rc_future
    FROM   rc_head h
    UNION ALL
    SELECT 3008, 'D CASH RECEIPTS', 'not reversed, dated up to today', h.rc_live_todate
    FROM   rc_head h
    UNION ALL
    SELECT 3100 + d.rn, 'D CASH RECEIPTS',
           TO_CHAR('in F4.2 | TYPE ' || d.rc_type || ' | STATUS ' || d.rc_status
                   || ' | reversed ' || d.reversed
                   || ' | dated after today ' || d.future),
           d.n
    FROM   rc_det d
    UNION ALL
    SELECT 3900 + o.rn, 'D CASH RECEIPTS',
           TO_CHAR('left out of F4.2 | BU in scope ' || o.bu_ok
                   || ' | receipt date in window ' || o.win_ok),
           o.n
    FROM   rc_out o
)
SELECT  g.ord    AS ord,
        g.block  AS block,
        g.item   AS item,
        g.value  AS value
FROM    grid g
ORDER BY g.ord
