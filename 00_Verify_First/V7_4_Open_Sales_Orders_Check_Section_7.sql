-- ============================================================================
--  V7_4  OPEN SALES ORDERS - every way to read the F7.1 row 6 count
--  Version   : 1.0 (2026-10-13). Not yet run on a pod.
--              Run log: 06_Run_Results/RUN_LOG.md
--  For: F7.1_Open_Transactions v1.4 row 6 (open-item block v1.4). Run AFTER
--  V7_0, with the SAME ledger / BU as the F7.1 run being defended. A run-day
--  snapshot: the dates are accepted and ignored.
--
--  WHY  F7.1 row 6 (6,973 in R041) is higher than F4.2 v1.3 Sales Orders
--  (5,913, run 2026-10-13). F7.1 counts the ~1,078 orders never submitted
--  (DOO_DRAFT / DOO_APPROVAL_PENDING, EBS parity); F4.2 v1.3 no longer does
--  (the consultant's rule); and only 16 orders were ever closed, so open is
--  nearly all. This query defends the row 6 count order by order and prints
--  the consultant-rule figure (A2) beside it.
--
--  RULE (F7.1 row 6, copied): one row per order (ORDER_NUMBER + SOURCE_ORDER_
--  SYSTEM; revisions collapsed to the submitted version, else the latest
--  header row); BU = that version's ORG_ID, in scope; open = OPEN_FLAG 'Y'
--  and CANCELED_FLAG not 'Y' on that version.
--
--  OUTPUT  ord | section | item | value | note
--          (note = the latest three order numbers of the group, to open in
--          Order Management)
--    A 1-12     the row 6 count (MUST EQUAL the F7.1 run); submitted (the
--               consultant rule) / never submitted; returns; fulfillment-line
--               state; header rows behind it; orders left out and why
--    B 2001+    every order: reason x submitted x STATUS_CODE
--    C 3001+    open orders: submitted x fulfillment-line state (open lines
--               not yet sent to billing / every line billed, closed or
--               cancelled / no line yet - the F7.1 row 6 value rule)
--    D 4001+    open orders: submitted x business unit
--    E 5001+    open orders: submitted x year ordered
--    F 6001+    open orders: submitted x return order (a RETURN line)
--    G 7001+    open orders: submitted x SOURCE_ORDER_SYSTEM
--  Columns: all proved (V7_0 v1.4, R042; FUN_ALL_BUSINESS_UNITS_V.BU_NAME by
--  V7_1, R030). No new column.
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
-- ---- one row per order: the F7.1 row 6 version, plus what this check needs
so_ord AS (
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
           MAX(dh.ordered_date) KEEP (DENSE_RANK FIRST ORDER BY
               CASE WHEN dh.submitted_flag = 'Y' THEN 0 ELSE 1 END, dh.header_id DESC)
                                                                    AS ordered_date,
           MAX(CASE WHEN dh.submitted_flag = 'Y' THEN 1 ELSE 0 END)  AS ever_submitted,
           COUNT(*)                                                  AS header_rows
    FROM   doo_headers_all dh
    GROUP  BY dh.order_number, dh.source_order_system
),
-- orders with a RETURN line on any of their header rows (the F4.2 rule)
so_ret AS (
    SELECT dh.order_number, dh.source_order_system
    FROM   doo_headers_all dh
    WHERE  EXISTS ( SELECT 1
                    FROM   doo_lines_all dl
                    WHERE  dl.header_id     = dh.header_id
                    AND    dl.category_code = 'RETURN' )
    GROUP  BY dh.order_number, dh.source_order_system
),
-- fulfillment lines per order version, and how many are still open and not
-- yet sent to billing (the F7.1 row 6 value rule, so_open_amt)
so_fl AS (
    SELECT fl.header_id,
           COUNT(*)                                                  AS n_lines,
           SUM(CASE WHEN NVL(fl.open_flag, 'N') = 'Y'
                     AND NVL(fl.canceled_flag, 'N') <> 'Y'
                     AND NVL(fl.invoice_interfaced_flag, 'N') <> 'Y'
                    THEN 1 ELSE 0 END)                               AS n_open
    FROM   doo_fulfill_lines_all fl
    GROUP  BY fl.header_id
),
bu_names AS (
    SELECT bu.bu_id, MAX(TO_CHAR(bu.bu_name)) AS bu_name
    FROM   fun_all_business_units_v bu
    GROUP  BY bu.bu_id
),
-- every order tagged with the F7.1 row 6 verdict and the breakdown columns
so_tag AS (
    SELECT o.header_id                                                AS id,
           TO_CHAR(o.order_number)                                    AS doc_num,
           CASE WHEN o.ever_submitted = 1 THEN 'Y' ELSE 'N' END       AS submitted,
           NVL(TO_CHAR(o.status_code), '(null)')                      AS status_code,
           CASE WHEN r.order_number IS NULL THEN 'N' ELSE 'Y' END     AS is_return,
           CASE WHEN f.header_id IS NULL THEN 'no fulfillment line yet'
                WHEN f.n_open > 0        THEN 'open lines not yet sent to billing'
                ELSE 'every line billed, closed or cancelled'
           END                                                        AS line_state,
           NVL(bn.bu_name, TO_CHAR(o.org_id))                         AS bu_name,
           NVL(TO_CHAR(o.ordered_date, 'YYYY'), '(no date)')          AS ord_year,
           NVL(TO_CHAR(o.source_order_system), '(null)')              AS src_sys,
           o.header_rows,
           CASE WHEN b.bu_id IS NULL                                  THEN 'BU not in scope'
                WHEN NVL(o.canceled_flag, 'N') <> 'N'                 THEN 'cancelled'
                WHEN NVL(o.open_flag, 'N') <> 'Y'                     THEN 'closed (OPEN_FLAG not Y)'
                ELSE 'counted'
           END                                                        AS reason
    FROM        so_ord   o
    LEFT JOIN   bu_scope b  ON b.bu_id  = o.org_id
    LEFT JOIN   bu_names bn ON bn.bu_id = o.org_id
    LEFT JOIN   so_ret   r  ON r.order_number = o.order_number
                           AND NVL(r.source_order_system, '~')
                             = NVL(o.source_order_system, '~')
    LEFT JOIN   so_fl    f  ON f.header_id = o.header_id
),
so_head AS (
    SELECT COUNT(CASE WHEN reason = 'counted' THEN 1 END)                         AS h1,
           COUNT(CASE WHEN reason = 'counted' AND submitted = 'Y' THEN 1 END)     AS h2,
           COUNT(CASE WHEN reason = 'counted' AND submitted = 'N' THEN 1 END)     AS h3,
           COUNT(CASE WHEN reason = 'counted' AND is_return = 'Y' THEN 1 END)     AS h4,
           COUNT(CASE WHEN reason = 'counted'
                       AND line_state = 'open lines not yet sent to billing'
                      THEN 1 END)                                                 AS h5,
           COUNT(CASE WHEN reason = 'counted'
                       AND line_state = 'no fulfillment line yet' THEN 1 END)     AS h6,
           COUNT(CASE WHEN reason = 'counted'
                       AND line_state = 'every line billed, closed or cancelled'
                      THEN 1 END)                                                 AS h7,
           NVL(SUM(CASE WHEN reason = 'counted' THEN header_rows END), 0)         AS h8,
           COUNT(CASE WHEN reason = 'closed (OPEN_FLAG not Y)' THEN 1 END)        AS h9,
           COUNT(CASE WHEN reason = 'cancelled' THEN 1 END)                       AS h10,
           COUNT(CASE WHEN reason = 'BU not in scope' THEN 1 END)                 AS h11,
           COUNT(*)                                                               AS h12
    FROM   so_tag
),
-- one row per (section, group) for every breakdown, then grouped once
so_dim AS (
    SELECT 'B' AS sec,
           TO_CHAR(t.reason || ' | submitted ' || t.submitted
                   || ' | STATUS_CODE ' || t.status_code)            AS dkey,
           t.id, t.doc_num
    FROM   so_tag t
    UNION ALL
    SELECT 'C', TO_CHAR('submitted ' || t.submitted || ' | ' || t.line_state), t.id, t.doc_num
    FROM   so_tag t
    WHERE  t.reason = 'counted'
    UNION ALL
    SELECT 'D', TO_CHAR('submitted ' || t.submitted || ' | BU ' || t.bu_name), t.id, t.doc_num
    FROM   so_tag t
    WHERE  t.reason = 'counted'
    UNION ALL
    SELECT 'E', TO_CHAR('submitted ' || t.submitted || ' | ordered in ' || t.ord_year), t.id, t.doc_num
    FROM   so_tag t
    WHERE  t.reason = 'counted'
    UNION ALL
    SELECT 'F', TO_CHAR('submitted ' || t.submitted || ' | return order ' || t.is_return), t.id, t.doc_num
    FROM   so_tag t
    WHERE  t.reason = 'counted'
    UNION ALL
    SELECT 'G', TO_CHAR('submitted ' || t.submitted || ' | SOURCE_ORDER_SYSTEM ' || t.src_sys),
           t.id, t.doc_num
    FROM   so_tag t
    WHERE  t.reason = 'counted'
),
so_dim_grp AS (
    SELECT sec, dkey, COUNT(*) AS n
    FROM   so_dim
    GROUP  BY sec, dkey
),
so_dim_ex AS (
    SELECT sec, dkey,
           LISTAGG(doc_num, ', ') WITHIN GROUP (ORDER BY id DESC)    AS examples
    FROM  ( SELECT d.sec, d.dkey, d.doc_num, d.id,
                   ROW_NUMBER() OVER (PARTITION BY d.sec, d.dkey
                                      ORDER BY d.id DESC)            AS rn
            FROM   so_dim d )
    WHERE  rn <= 3
    GROUP  BY sec, dkey
),
-- counted groups first; E (year) in year order, the others largest first
so_dim_det AS (
    SELECT g.sec, g.dkey, g.n, e.examples,
           ROW_NUMBER() OVER (PARTITION BY g.sec
                              ORDER BY CASE WHEN g.dkey LIKE 'counted%' THEN 0 ELSE 1 END,
                                       CASE WHEN g.sec = 'E' THEN g.dkey END,
                                       g.n DESC, g.dkey)             AS rn
    FROM        so_dim_grp g
    LEFT JOIN   so_dim_ex  e ON e.sec = g.sec AND e.dkey = g.dkey
),
grid AS (
    SELECT 1 AS ord, CAST('A OPEN SALES ORDERS' AS VARCHAR2(30)) AS section,
           CAST('F7.1 row 6 Open sales orders - must equal the F7.1 run' AS VARCHAR2(400)) AS item,
           h.h1 AS value, CAST(NULL AS VARCHAR2(4000)) AS note
    FROM   so_head h
    UNION ALL
    SELECT 2, 'A OPEN SALES ORDERS', 'of them submitted - the consultant rule (as F4.2 v1.3)', h.h2, NULL
    FROM   so_head h
    UNION ALL
    SELECT 3, 'A OPEN SALES ORDERS', 'of them never submitted (draft / pending approval)', h.h3, NULL
    FROM   so_head h
    UNION ALL
    SELECT 4, 'A OPEN SALES ORDERS', 'of them return orders (a RETURN line)', h.h4, NULL
    FROM   so_head h
    UNION ALL
    SELECT 5, 'A OPEN SALES ORDERS', 'of them with open lines not yet sent to billing', h.h5, NULL
    FROM   so_head h
    UNION ALL
    SELECT 6, 'A OPEN SALES ORDERS', 'of them with no fulfillment line yet', h.h6, NULL
    FROM   so_head h
    UNION ALL
    SELECT 7, 'A OPEN SALES ORDERS', 'of them open on the header, every line billed, closed or cancelled', h.h7, NULL
    FROM   so_head h
    UNION ALL
    SELECT 8, 'A OPEN SALES ORDERS', 'DOO header rows behind them (revisions collapsed to one per order)', h.h8, NULL
    FROM   so_head h
    UNION ALL
    SELECT 9, 'A OPEN SALES ORDERS', 'closed orders (left out)', h.h9, NULL
    FROM   so_head h
    UNION ALL
    SELECT 10, 'A OPEN SALES ORDERS', 'cancelled orders (left out)', h.h10, NULL
    FROM   so_head h
    UNION ALL
    SELECT 11, 'A OPEN SALES ORDERS', 'BU not in scope (left out)', h.h11, NULL
    FROM   so_head h
    UNION ALL
    SELECT 12, 'A OPEN SALES ORDERS', 'every order, one per order (for reference)', h.h12, NULL
    FROM   so_head h
    UNION ALL
    SELECT CASE d.sec WHEN 'B' THEN 2000 WHEN 'C' THEN 3000 WHEN 'D' THEN 4000
                      WHEN 'E' THEN 5000 WHEN 'F' THEN 6000 ELSE 7000 END + d.rn,
           CASE d.sec WHEN 'B' THEN 'B ALL ORDERS: STATUS'
                      WHEN 'C' THEN 'C OPEN: LINE STATE'
                      WHEN 'D' THEN 'D OPEN: BUSINESS UNIT'
                      WHEN 'E' THEN 'E OPEN: YEAR ORDERED'
                      WHEN 'F' THEN 'F OPEN: RETURNS'
                      ELSE 'G OPEN: SOURCE SYSTEM' END,
           d.dkey, d.n, TO_CHAR('latest: ' || d.examples)
    FROM   so_dim_det d
)
SELECT  g.ord      AS ord,
        g.section  AS section,
        g.item     AS item,
        g.value    AS value,
        g.note     AS note
FROM    grid g
ORDER BY g.ord
