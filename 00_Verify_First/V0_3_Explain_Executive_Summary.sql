-- ============================================================================
--  V0_3  EXPLAIN THE EXECUTIVE SUMMARY - who and what is behind each F0 card
--  Version   : shared block v3.1 (2026-10-01) - modules read from FND_TABLES ->
--              FND_APPLICATION_VL. Run history: 06_Run_Results/RUN_LOG.md
--  Run with EXACTLY the same parameter values as F0. Paste the grid back.
--
--  The block from "params" to "txn_mod" is copied byte-for-byte from F1 (and
--  so is identical to F0), so every name listed here is exactly what F0 counted.
--
--  OUTPUT  ord | section | item | value
--    A  parameters actually received + the date window used
--    B  card 2 Ledgers        - each ledger counted
--    C  card 3 Legal Entities - each legal entity counted
--    D  card 4 Business Units - each BU counted, and each BU of the ledger
--                               EXCLUDED because its status is inactive
--    E  cards 1 and 5         - every module: Active/Dormant, rows, users
--    G  module source         - each source table -> owning application short
--                               name (FND_TABLES) -> module name, how many times
--                               the table is registered, and its rows in window
--    F  card 1 Users          - each user counted, with row count and the
--                               modules they touched (top 200 by rows)
--    Z  totals that MUST equal the F0 cards
--
--  How to check against the Fusion UI:
--    B -> Setup and Maintenance > Manage Primary Ledgers
--    C -> Manage Legal Entities / the ledger's Assign Legal Entities step
--    D -> Manage Business Units (primary ledger column)
--    F -> Security Console > Users (service / integration accounts such as
--         FIN_IMPL or *_APPID count, exactly as EBS counted them)
--
--  Pure SELECT, one statement. Nothing is written.
-- ============================================================================
WITH
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
-- ---- ACTIVITY ROWS: identical in F0 and F1 -------------------------------
--  One row per transaction document in scope and window. seq = module.
txn AS (
    -- 1 General Ledger: journal headers created in the window
    SELECT 'GL_JE_HEADERS' AS src_table, jh.created_by AS who
    FROM   gl_je_headers jh
    JOIN   led_scope l ON l.ledger_id = jh.ledger_id
    CROSS  JOIN win w
    WHERE  jh.creation_date >= w.start_date
    AND    jh.creation_date <  w.end_date_excl
    UNION ALL
    -- 2 Payables: invoices by invoice date (business date, EBS parity)
    SELECT 'AP_INVOICES_ALL', ai.created_by
    FROM   ap_invoices_all ai
    JOIN   bu_scope b ON b.bu_id = ai.org_id
    CROSS  JOIN win w
    WHERE  ai.invoice_date >= w.start_date
    AND    ai.invoice_date <  w.end_date_excl
    UNION ALL
    -- 3 Receivables: transactions by transaction date
    SELECT 'RA_CUSTOMER_TRX_ALL', ct.created_by
    FROM   ra_customer_trx_all ct
    JOIN   bu_scope b ON b.bu_id = ct.org_id
    CROSS  JOIN win w
    WHERE  ct.trx_date >= w.start_date
    AND    ct.trx_date <  w.end_date_excl
    UNION ALL
    -- 4 Purchasing: purchase order headers (any document type)
    SELECT 'PO_HEADERS_ALL', ph.created_by
    FROM   po_headers_all ph
    CROSS  JOIN win w
    WHERE  ph.creation_date >= w.start_date
    AND    ph.creation_date <  w.end_date_excl
    AND    EXISTS ( SELECT 1
                    FROM   bu_scope b
                    WHERE  b.bu_id IN (ph.prc_bu_id, ph.req_bu_id, ph.billto_bu_id) )
    UNION ALL
    -- 4 Purchasing: requisition headers (same module, EBS parity)
    SELECT 'POR_REQUISITION_HEADERS_ALL', rh.created_by
    FROM   por_requisition_headers_all rh
    JOIN   bu_scope b ON b.bu_id = rh.req_bu_id
    CROSS  JOIN win w
    WHERE  rh.creation_date >= w.start_date
    AND    rh.creation_date <  w.end_date_excl
    UNION ALL
    -- 5 Order Management: order headers by ordered date
    SELECT 'DOO_HEADERS_ALL', dh.created_by
    FROM   doo_headers_all dh
    JOIN   bu_scope b ON b.bu_id = dh.org_id
    CROSS  JOIN win w
    WHERE  dh.ordered_date >= w.start_date
    AND    dh.ordered_date <  w.end_date_excl
    UNION ALL
    -- 6 Inventory: material transactions by transaction date
    SELECT 'INV_MATERIAL_TXNS', imt.created_by
    FROM   inv_material_txns imt
    JOIN   inv_org_scope ios ON ios.organization_id = imt.organization_id
    CROSS  JOIN win w
    WHERE  imt.transaction_date >= w.start_date
    AND    imt.transaction_date <  w.end_date_excl
    UNION ALL
    -- 7 Cash Management: bank statements on accounts used by a BU in scope.
    --   EXISTS, not JOIN: an account used by three BUs must not count three times.
    SELECT 'CE_STATEMENT_HEADERS', csh.created_by
    FROM   ce_statement_headers csh
    CROSS  JOIN win w
    WHERE  csh.creation_date >= w.start_date
    AND    csh.creation_date <  w.end_date_excl
    AND    EXISTS ( SELECT 1
                    FROM   ce_bank_acct_uses_all u
                    JOIN   bu_scope b ON b.bu_id = u.org_id
                    WHERE  u.bank_account_id = csh.bank_account_id )
    UNION ALL
    -- 8 Cost Management: cost distributions (costing's own accounting output,
    --   so a cost accountant who never moved stock still counts - EBS parity)
    SELECT 'CST_COST_DISTRIBUTIONS', cd.created_by
    FROM   cst_cost_distributions cd
    JOIN   led_scope l ON l.ledger_id = cd.ledger_id
    CROSS  JOIN win w
    WHERE  cd.gl_date >= w.start_date
    AND    cd.gl_date <  w.end_date_excl
    UNION ALL
    -- 9 Assets: asset transactions on the ledger's books
    SELECT 'FA_TRANSACTION_HEADERS', fth.last_updated_by
    FROM   fa_transaction_headers fth
    JOIN   fa_book_scope fb ON fb.book_type_code = fth.book_type_code
    CROSS  JOIN win w
    WHERE  fth.transaction_date_entered >= w.start_date
    AND    fth.transaction_date_entered <  w.end_date_excl
    UNION ALL
    -- 10 Project Costing: expenditure items by expenditure item date
    SELECT 'PJC_EXP_ITEMS_ALL', ei.created_by
    FROM   pjc_exp_items_all ei
    JOIN   bu_scope b ON b.bu_id = ei.org_id
    CROSS  JOIN win w
    WHERE  ei.expenditure_item_date >= w.start_date
    AND    ei.expenditure_item_date <  w.end_date_excl
    UNION ALL
    -- 11 Manufacturing (work execution): work orders created in the window
    SELECT 'WIE_WORK_ORDERS_B', wo.created_by
    FROM   wie_work_orders_b wo
    JOIN   inv_org_scope ios ON ios.organization_id = wo.organization_id
    CROSS  JOIN win w
    WHERE  wo.creation_date >= w.start_date
    AND    wo.creation_date <  w.end_date_excl
    UNION ALL
    -- 12 Item Structures (BOM): structures created in the window.
    --    EGP_STRUCTURES_B has no ORGANIZATION_ID; PK2_VALUE holds it (string).
    SELECT 'EGP_STRUCTURES_B', es.created_by
    FROM   egp_structures_b es
    JOIN   inv_org_scope ios ON TO_CHAR(ios.organization_id) = es.pk2_value
    CROSS  JOIN win w
    WHERE  es.creation_date >= w.start_date
    AND    es.creation_date <  w.end_date_excl
    UNION ALL
    -- 13 Shipping: deliveries created in the window
    SELECT 'WSH_NEW_DELIVERIES', wnd.created_by
    FROM   wsh_new_deliveries wnd
    JOIN   inv_org_scope ios ON ios.organization_id = wnd.organization_id
    CROSS  JOIN win w
    WHERE  wnd.creation_date >= w.start_date
    AND    wnd.creation_date <  w.end_date_excl
    UNION ALL
    -- 14 Expenses: expense reports created in the window (EBS parity:
    --    creation date). Overlaps Payables - expense reports become AP invoices.
    SELECT 'EXM_EXPENSE_REPORTS', er.created_by
    FROM   exm_expense_reports er
    JOIN   bu_scope b ON b.bu_id = er.org_id
    CROSS  JOIN win w
    WHERE  er.creation_date >= w.start_date
    AND    er.creation_date <  w.end_date_excl
    UNION ALL
    -- 15 Lease Accounting (Fusion counterpart of EBS Property Manager)
    SELECT 'FLA_LEASES_ALL', fl.created_by
    FROM   fla_leases_all fl
    JOIN   bu_scope b ON b.bu_id = fl.org_id
    CROSS  JOIN win w
    WHERE  fl.creation_date >= w.start_date
    AND    fl.creation_date <  w.end_date_excl
    UNION ALL
    -- 16 Intercompany: pod-wide on purpose; users not counted (see header)
    SELECT 'FUN_TRX_HEADERS', CAST(NULL AS VARCHAR2(64))
    FROM   fun_trx_headers ft
    CROSS  JOIN win w
    WHERE  ft.creation_date >= w.start_date
    AND    ft.creation_date <  w.end_date_excl
),
-- ---- ASSESSED TABLES: exactly the tables read by txn, one row each --------
--  Generated from the txn branches above (same table names, same order), so a
--  table with ZERO rows in the window still appears - and its module can be
--  reported as Dormant in 1.2. Keep in step with txn if a branch is added.
src_tables AS (
    SELECT 'GL_JE_HEADERS' AS src_table FROM dual
    UNION ALL
    SELECT 'AP_INVOICES_ALL' FROM dual
    UNION ALL
    SELECT 'RA_CUSTOMER_TRX_ALL' FROM dual
    UNION ALL
    SELECT 'PO_HEADERS_ALL' FROM dual
    UNION ALL
    SELECT 'POR_REQUISITION_HEADERS_ALL' FROM dual
    UNION ALL
    SELECT 'DOO_HEADERS_ALL' FROM dual
    UNION ALL
    SELECT 'INV_MATERIAL_TXNS' FROM dual
    UNION ALL
    SELECT 'CE_STATEMENT_HEADERS' FROM dual
    UNION ALL
    SELECT 'CST_COST_DISTRIBUTIONS' FROM dual
    UNION ALL
    SELECT 'FA_TRANSACTION_HEADERS' FROM dual
    UNION ALL
    SELECT 'PJC_EXP_ITEMS_ALL' FROM dual
    UNION ALL
    SELECT 'WIE_WORK_ORDERS_B' FROM dual
    UNION ALL
    SELECT 'EGP_STRUCTURES_B' FROM dual
    UNION ALL
    SELECT 'WSH_NEW_DELIVERIES' FROM dual
    UNION ALL
    SELECT 'EXM_EXPENSE_REPORTS' FROM dual
    UNION ALL
    SELECT 'FLA_LEASES_ALL' FROM dual
    UNION ALL
    SELECT 'FUN_TRX_HEADERS' FROM dual
),
-- ---- MODULE = OWNING APPLICATION, READ FROM FUSION'S OWN REGISTRY -----------
--  No module name or code is typed in this query. Each assessed table is
--  looked up in FND_TABLES (the Fusion table registry), whose
--  APPLICATION_SHORT_NAME is the application that owns the table. The display
--  name and application id come from FND_APPLICATION_VL, matched on
--  APPLICATION_SHORT_NAME. (Fusion FND_TABLES has NO APPLICATION_ID column -
--  ORA-00904 on the pod, 2026-10-01.)
--    - registered and named      -> '<application name> (<short name>)'
--    - registered, no name row   -> '<short name>'   (still read from data)
--    - not registered            -> 'Not registered: <TABLE>' (never guessed)
--  The table is matched on TABLE_NAME or PHYSICAL_TABLE_NAME (both confirmed
--  on the pod by V0_0, 2026-10-01), so a logical/physical naming difference
--  cannot turn a registered table into 'Not registered'.
--  MIN() makes the lookup one row per table even if a table were registered
--  under two applications (V0_3 block G prints the registration count).
tab_app AS (
    SELECT  s.src_table,
            MIN(ft.application_short_name) AS app_short
    FROM        src_tables s
    LEFT JOIN   fnd_tables ft
           ON   ft.table_name          = s.src_table
            OR  ft.physical_table_name = s.src_table
    GROUP   BY  s.src_table
),
app_names AS (
    SELECT  a.application_short_name      AS short_name,
            MIN(a.application_id)         AS application_id,
            MAX(a.application_name)       AS app_name
    FROM    fnd_application_vl a
    WHERE   EXISTS ( SELECT 1 FROM tab_app t
                     WHERE  t.app_short = a.application_short_name )
    GROUP   BY a.application_short_name
),
modules AS (
    SELECT  t.src_table,
            t.app_short,
            n.application_id,
            CASE WHEN n.app_name  IS NOT NULL THEN n.app_name || ' (' || t.app_short || ')'
                 WHEN t.app_short IS NOT NULL THEN t.app_short
                 ELSE 'Not registered: ' || t.src_table
            END                                   AS module
    FROM        tab_app   t
    LEFT JOIN   app_names n ON n.short_name = t.app_short
),
-- one row per module (application); app_id orders the report
mod_list AS (
    SELECT  module, MIN(application_id) AS app_id
    FROM    modules
    GROUP   BY module
),
-- every activity row tagged with its module
txn_mod AS (
    SELECT  m.module, t.who
    FROM    txn t
    JOIN    modules m ON m.src_table = t.src_table
),
-- ---- END OF SHARED BLOCK -------------------------------------------------
act AS (
    SELECT  module, COUNT(*) AS rows_cnt, COUNT(who) AS who_rows
    FROM    txn_mod
    GROUP   BY module
),
usr AS (
    SELECT  module, COUNT(*) AS users_cnt
    FROM  ( SELECT module, who
            FROM   txn_mod
            WHERE  who IS NOT NULL
            GROUP  BY module, who )
    GROUP   BY module
),
mod_rows AS (
    SELECT  ml.module,
            ml.app_id,
            NVL(a.rows_cnt, 0)  AS rows_cnt,
            NVL(a.who_rows, 0)  AS who_rows,
            NVL(u.users_cnt, 0) AS users_cnt,
            ROW_NUMBER() OVER (ORDER BY ml.app_id NULLS LAST, ml.module) AS rn
    FROM        mod_list ml
    LEFT JOIN   act a ON a.module = ml.module
    LEFT JOIN   usr u ON u.module = ml.module
),
user_mod AS (
    SELECT  t.who, t.module, COUNT(*) AS n
    FROM    txn_mod t
    WHERE   t.who IS NOT NULL
    GROUP   BY t.who, t.module
),
user_rows AS (
    SELECT  um.who,
            SUM(um.n)                                                   AS rows_cnt,
            LISTAGG(um.module, ', ' ON OVERFLOW TRUNCATE)
                WITHIN GROUP (ORDER BY um.module)                       AS mods,
            ROW_NUMBER() OVER (ORDER BY SUM(um.n) DESC, um.who)         AS rn
    FROM    user_mod um
    GROUP   BY um.who
),
tab_reg AS (
    SELECT  s.src_table, COUNT(ft.table_name) AS regs
    FROM        src_tables s
    LEFT JOIN   fnd_tables ft
           ON   ft.table_name          = s.src_table
            OR  ft.physical_table_name = s.src_table
    GROUP   BY  s.src_table
),
tab_rows AS (
    SELECT  src_table, COUNT(*) AS n
    FROM    txn
    GROUP   BY src_table
),
tab_map AS (
    SELECT  m.src_table,
            m.app_short,
            m.module,
            r.regs,
            NVL(tr.n, 0) AS rows_cnt,
            ROW_NUMBER() OVER (ORDER BY m.src_table) AS rn
    FROM        modules  m
    JOIN        tab_reg  r  ON r.src_table  = m.src_table
    LEFT JOIN   tab_rows tr ON tr.src_table = m.src_table
),
led_rows AS (
    SELECT  gl.ledger_id, gl.name AS led_name, gl.ledger_category_code,
            ROW_NUMBER() OVER (ORDER BY gl.name) AS rn
    FROM    gl_ledgers gl
    JOIN    led_scope l ON l.ledger_id = gl.ledger_id
),
le_rows AS (
    SELECT  v.legal_entity_id,
            MAX(v.legal_entity_name)                                    AS le_name,
            ROW_NUMBER() OVER (ORDER BY MAX(v.legal_entity_name))       AS rn
    FROM    gl_ledger_le_v v
    JOIN    led_scope l ON l.ledger_id = v.ledger_id
    WHERE   v.legal_entity_id IS NOT NULL
    GROUP   BY v.legal_entity_id
),
bu_rows AS (
    SELECT  b.bu_id,
            MAX(bu.bu_name)                                             AS bu_name,
            MAX(bu.status)                                              AS status,
            MAX(bu.legal_entity_id)                                     AS le_id,
            ROW_NUMBER() OVER (ORDER BY MAX(bu.bu_name))                AS rn
    FROM    bu_scope b
    JOIN    fun_all_business_units_v bu ON bu.bu_id = b.bu_id
    GROUP   BY b.bu_id
),
bu_excl AS (
    SELECT  bu.bu_id,
            MAX(bu.bu_name)                                             AS bu_name,
            MAX(bu.status)                                              AS status,
            ROW_NUMBER() OVER (ORDER BY MAX(bu.bu_name))                AS rn
    FROM    fun_all_business_units_v bu
    CROSS   JOIN params p
    WHERE   bu.primary_ledger_id IS NOT NULL
    AND     NVL(UPPER(bu.status), 'A') IN ('I', 'INACTIVE')
    AND     (p.p_ledger_id IS NULL OR bu.primary_ledger_id = TRIM(p.p_ledger_id))
    GROUP   BY bu.bu_id
),
t_users AS (
    SELECT COUNT(*) AS n FROM user_rows
),
t_mods AS (
    SELECT COUNT(*) AS n FROM mod_rows WHERE rows_cnt > 0
),
t_dormant AS (
    SELECT COUNT(*) AS n FROM mod_rows WHERE rows_cnt = 0
),
t_les AS (
    SELECT COUNT(*) AS n FROM le_rows
),
t_bus AS (
    SELECT COUNT(*) AS n FROM bu_rows
),
t_leds AS (
    SELECT COUNT(*) AS n FROM led_rows
),
grid AS (
    SELECT  10 AS ord, 'A PARAMETERS' AS section,
            'p_ledger_id / p_bu_id' AS item,
            NVL(p.p_ledger_id, '(blank = every ledger)') || ' / ' ||
            NVL(p.p_bu_id, '(blank = every BU of the ledger)') AS value
    FROM    params p
    UNION ALL
    SELECT  11, 'A PARAMETERS', 'date window used (inclusive)',
            TO_CHAR(w.start_date, 'YYYY-MM-DD') || ' to ' ||
            TO_CHAR(w.end_date_excl - 1, 'YYYY-MM-DD')
    FROM    win w
    UNION ALL
    SELECT  10000 + r.rn, 'B LEDGERS (card 2)', r.led_name,
            r.ledger_category_code || ' / ledger_id ' || r.ledger_id
    FROM    led_rows r
    UNION ALL
    SELECT  20000 + r.rn, 'C LEGAL ENTITIES (card 3)', r.le_name,
            'legal_entity_id ' || r.legal_entity_id
    FROM    le_rows r
    UNION ALL
    SELECT  30000 + r.rn, 'D BUSINESS UNITS (card 4)', r.bu_name,
            'bu_id ' || r.bu_id || ' / status ' || NVL(r.status, '(null)') ||
            ' / default LE id ' || NVL(r.le_id, '(none)')
    FROM    bu_rows r
    UNION ALL
    SELECT  39000 + r.rn, 'D BUs EXCLUDED (inactive status)', r.bu_name,
            'bu_id ' || r.bu_id || ' / status ' || r.status
    FROM    bu_excl r
    UNION ALL
    SELECT  40000 + r.rn, 'E MODULES (cards 1 and 5)', r.module,
            CASE WHEN r.rows_cnt > 0 THEN 'Active' ELSE 'Dormant' END ||
            ' / application_id ' || NVL(TO_CHAR(r.app_id), '(none)') ||
            ' / rows ' || r.rows_cnt ||
            CASE WHEN r.rows_cnt > 0 AND r.who_rows = 0
                 THEN ' / users not counted (pod-wide)'
                 ELSE ' / users ' || r.users_cnt END
    FROM    mod_rows r
    UNION ALL
    SELECT  50000 + r.rn, 'F USERS (card 1)', r.who,
            r.rows_cnt || ' rows / modules: ' || r.mods
    FROM    user_rows r
    WHERE   r.rn <= 200
    UNION ALL
    SELECT  60000 + r.rn, 'G MODULE SOURCE (registry)', r.src_table,
            'owning application ' || NVL(r.app_short, '(none)') ||
            ' -> ' || r.module ||
            ' / registered ' || r.regs || 'x in FND_TABLES' ||
            CASE WHEN r.regs = 0 THEN '  *** NOT REGISTERED ***'
                 WHEN r.regs > 1 THEN '  *** REGISTERED MORE THAN ONCE - lowest id used ***'
                 ELSE '' END ||
            ' / rows in window ' || r.rows_cnt
    FROM    tab_map r
    UNION ALL
    SELECT  90001, 'Z TOTALS', 'Users who transacted  - must equal F0 card 1', TO_CHAR(t.n) FROM t_users   t
    UNION ALL
    SELECT  90002, 'Z TOTALS', 'Ledgers               - must equal F0 card 2', TO_CHAR(t.n) FROM t_leds    t
    UNION ALL
    SELECT  90003, 'Z TOTALS', 'Legal Entities        - must equal F0 card 3', TO_CHAR(t.n) FROM t_les     t
    UNION ALL
    SELECT  90004, 'Z TOTALS', 'Business Units        - must equal F0 card 4', TO_CHAR(t.n) FROM t_bus     t
    UNION ALL
    SELECT  90005, 'Z TOTALS', 'Active Modules        - must equal F0 card 5 and F1 rows', TO_CHAR(t.n) FROM t_mods t
    UNION ALL
    SELECT  90006, 'Z TOTALS', 'Dormant Modules       - must equal F1.2 rows', TO_CHAR(t.n) FROM t_dormant t
)
SELECT ord, section, item, value
FROM   grid
ORDER  BY ord
