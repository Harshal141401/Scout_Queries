-- ============================================================================
--  F4.2  Section 4.2 Order-to-cash (O2C) flow
--  Version   : 1.1 (2026-10-05). v1.0 failed on the pod with ORA-12704 (R009):
--              UNISTR returns NVARCHAR2 and was mixed with VARCHAR2 rows in a
--              UNION ALL. The middle dot is now TO_CHAR(UNISTR('\00B7')),
--              i.e. plain VARCHAR2. Logic unchanged.
--              RUN V4_0 AND V4_1 FIRST. Log every run in 06_Run_Results/RUN_LOG.md.
--  Source    : Oracle Fusion Cloud (BIP data model, data source ApplicationDB_FSCM)
--  Mirrors   : EBS agent ebs_discover_business_processes, O2C block
--              (report 30-Sep-2026, Vision: 943 / 266 / 30 / 3,190 (3,091 /
--              99 / 0) / 1,142 - EBS numbers, not targets)

-- ============================================================================
WITH
-- ---- PARAMS / WINDOW / SCOPE: copied unchanged from F1 (shared block v3.1),
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
    SELECT NVL(TO_DATE(p.p_from_date, 'YYYY-MM-DD'), TRUNC(SYSDATE) - 90) AS start_date,
           NVL(TO_DATE(p.p_to_date,   'YYYY-MM-DD'), TRUNC(SYSDATE)) + 1  AS end_date_excl
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
-- ---- orders: one row per order (revisions collapsed) --------------------------
order_hdr AS (
    SELECT dh.order_number,
           dh.source_order_system,
           MAX(dh.ordered_date) KEEP (DENSE_RANK FIRST ORDER BY
               CASE WHEN dh.submitted_flag = 'Y' THEN 0 ELSE 1 END, dh.header_id DESC)
                                                                    AS ordered_date,
           MAX(dh.org_id) KEEP (DENSE_RANK FIRST ORDER BY
               CASE WHEN dh.submitted_flag = 'Y' THEN 0 ELSE 1 END, dh.header_id DESC)
                                                                    AS org_id
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
orders_in_win AS (
    SELECT CASE WHEN r.order_number IS NOT NULL THEN 1 ELSE 0 END AS is_return
    FROM        order_hdr     o
    JOIN        bu_scope      b ON b.bu_id = o.org_id
    CROSS JOIN  win           w
    LEFT JOIN   return_orders r ON r.order_number = o.order_number
                               AND NVL(r.source_order_system, '~')
                                 = NVL(o.source_order_system, '~')
    WHERE       o.ordered_date >= w.start_date
    AND         o.ordered_date <  w.end_date_excl
),
so_cnt AS (
    SELECT NVL(SUM(1 - is_return), 0) AS sales_orders,
           NVL(SUM(is_return), 0)     AS rma
    FROM   orders_in_win
),
-- ---- deliveries: ship-confirmed, by first pickup date ------------------------
dlv_cnt AS (
    SELECT COUNT(*) AS cnt
    FROM   wsh_new_deliveries wnd
    JOIN   inv_org_scope ios ON ios.organization_id = wnd.organization_id
    CROSS  JOIN win w
    WHERE  wnd.status_code = 'CL'
    AND    wnd.initial_pickup_date >= w.start_date
    AND    wnd.initial_pickup_date <  w.end_date_excl
),
-- ---- AR transactions, typed through the type's primary key ------------------
ar_base AS (
    SELECT tt.type AS trx_type
    FROM        ra_customer_trx_all   ct
    JOIN        bu_scope              b  ON b.bu_id = ct.org_id
    CROSS JOIN  win                   w
    LEFT JOIN   ra_cust_trx_types_all tt ON tt.cust_trx_type_seq_id = ct.cust_trx_type_seq_id
    WHERE       ct.trx_date >= w.start_date
    AND         ct.trx_date <  w.end_date_excl
),
ar_cnt AS (
    SELECT COUNT(*)                                                 AS all_trx,
           NVL(SUM(CASE WHEN trx_type = 'INV' THEN 1 ELSE 0 END), 0) AS invoices,
           NVL(SUM(CASE WHEN trx_type = 'CM'  THEN 1 ELSE 0 END), 0) AS credit_memos,
           NVL(SUM(CASE WHEN trx_type = 'DM'  THEN 1 ELSE 0 END), 0) AS debit_memos
    FROM   ar_base
),
-- ---- cash receipts -----------------------------------------------------------
rcpt_cnt AS (
    SELECT COUNT(*) AS cnt
    FROM   ar_cash_receipts_all cr
    JOIN   bu_scope b ON b.bu_id = cr.org_id
    CROSS  JOIN win w
    WHERE  cr.receipt_date >= w.start_date
    AND    cr.receipt_date <  w.end_date_excl
),
o2c_rows AS (
    SELECT 1 AS seq, 'Sales Orders' AS process_variant, s.sales_orders AS volume
    FROM   so_cnt s
    UNION ALL
    SELECT 2, 'Deliveries', d.cnt FROM dlv_cnt d
    UNION ALL
    SELECT 3, 'RMA', s.rma FROM so_cnt s
    UNION ALL
    SELECT 4, 'AR transactions', a.all_trx FROM ar_cnt a
    UNION ALL
    SELECT 5, TO_CHAR(UNISTR('\00B7')) || ' Invoices', a.invoices FROM ar_cnt a
    UNION ALL
    SELECT 6, TO_CHAR(UNISTR('\00B7')) || ' Credit memos', a.credit_memos FROM ar_cnt a
    UNION ALL
    SELECT 7, TO_CHAR(UNISTR('\00B7')) || ' Debit memos', a.debit_memos FROM ar_cnt a
    UNION ALL
    SELECT 8, 'Cash receipts', c.cnt FROM rcpt_cnt c
)
SELECT
    r.process_variant                                         AS "Process Variant",
    r.volume                                                  AS "Volume"
FROM        o2c_rows r
ORDER BY    r.seq
