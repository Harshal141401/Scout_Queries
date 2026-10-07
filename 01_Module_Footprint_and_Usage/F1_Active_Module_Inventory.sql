-- ============================================================================
--  F1  Section 1.1 Active module inventory - ACTIVE modules only
--  Version   : shared block v3.1 (2026-10-01) - modules read from FND_TABLES ->
--              FND_APPLICATION_VL. Run history: 06_Run_Results/RUN_LOG.md
--      (the modules with no activity are Section 1.2 -> F1.2_Modules_No_Activity.sql)
--  Source    : Oracle Fusion Cloud (BIP data model, data source ApplicationDB_FSCM)
--  Mirrors   : EBS 1Active_Module_Inventory_VisionOps.sql (report 30-Sep-2026)
--  Replaces  : Fusion draft 1Active_Module_Inventory.sql (10 modules, fixed
--              Jul-Sep 2025 window, FA/INV "active" from stock not activity,
--              PO counted pod-wide)
--
--  PARAMETERS  (all optional - BIP passes them as strings)
--    :p_ledger_id      GL_LEDGERS.LEDGER_ID        blank = every ledger
--    :p_bu_id          business unit (BU_ID)       blank = every BU of the ledger
--    :p_custom_prefix  accepted, not used here     (parameter parity)
--    :p_from_date      'YYYY-MM-DD'                blank = SYSDATE - 90
--    :p_to_date        'YYYY-MM-DD' (inclusive)    blank = today
--
--  OUTPUT  one row per ACTIVE module:
--    Module | Status ('Active') | Users (period)
--    Module = the Fusion application that owns the source table, name and
--    short code read from FND_TABLES -> FND_APPLICATION_VL. NOTHING about the
--    modules is typed in this query; ordered by application id.
--    Same rule as the EBS agent (html_report_generator._step1_html): 1.1 shows
--    only modules whose status is Active; the rest go to 1.2 as 'Dormant'.
--    Zero rows is valid - the report then prints
--    "No active modules detected for this scope in the period."
--    Row count of this query = F0 "Active Modules". Per-module activity row
--    counts are in V0_3 block E (same code block).
--
--  DEFINITIONS (same as the EBS report, Appendix A 1.1)
--    Active  = at least one transaction row in the window, in scope.
--    Users   = distinct CREATED_BY on those rows (Fusion CREATED_BY is the
--              user NAME, VARCHAR2(64), so it includes service/integration
--              accounts - same as EBS). Rows must not be summed across modules.
--    Assets use LAST_UPDATED_BY (EBS parity - EBS has no CREATED_BY there).
--    Intercompany is pod-wide and shows Users '-' (EBS parity: its rows key on
--    initiator/recipient, not one BU, so its users would import other ledgers).
--
--  SCOPE (same rule as EBS, BU replaces OU)
--    ledger-scoped   : GL, Cost Management (CST_COST_DISTRIBUTIONS.LEDGER_ID),
--                      Assets (book -> FA_BOOK_CONTROLS.SET_OF_BOOKS_ID)
--    inventory orgs  : INV, Manufacturing, BOM, Shipping. An org belongs to a
--                      ledger through INV_ORGANIZATION_DEFINITIONS_V.SET_OF_BOOKS_ID
--                      (Oracle derives it from the org's BU primary ledger).
--                      NOT narrowed by :p_bu_id - EBS parity.
--    business units  : AP, AR, PO, OM, CE, Projects, Expenses, Lease Accounting
--
--  WHAT CHANGED VS EBS (Fusion data model, verified against the Oracle
--  Fusion Tables and Views guides 25c-26b, 2026-09-30)
--    OE_ORDER_HEADERS_ALL          -> DOO_HEADERS_ALL (ORG_ID = BU, ORDERED_DATE)
--    MTL_MATERIAL_TRANSACTIONS     -> INV_MATERIAL_TXNS (TRANSACTION_DATE)
--    MTL_TRANSACTION_ACCOUNTS      -> CST_COST_DISTRIBUTIONS (LEDGER_ID, GL_DATE)
--    PA_EXPENDITURE_ITEMS_ALL      -> PJC_EXP_ITEMS_ALL (ORG_ID = BU)
--    WIP_DISCRETE_JOBS             -> WIE_WORK_ORDERS_B
--    BOM_BILL_OF_MATERIALS         -> EGP_STRUCTURES_B  (NO ORGANIZATION_ID
--                                     column; the org is PK2_VALUE - checked
--                                     by V0_2 block G before trusting it)
--    AP_EXPENSE_REPORT_HEADERS_ALL -> EXM_EXPENSE_REPORTS (ORG_ID = BU)
--    PN_LEASES_ALL                 -> FLA_LEASES_ALL (Lease Accounting, ORG_ID = BU)
--    PO_REQUISITION_HEADERS_ALL    -> POR_REQUISITION_HEADERS_ALL (REQ_BU_ID)
--    PO headers are in scope when ANY of PRC_BU_ID / REQ_BU_ID / BILLTO_BU_ID
--    is a BU of the ledger (a procurement BU often has no ledger of its own).
--
--  Pod runs and expected values: 06_Run_Results/RUN_LOG.md (log every run).
--  Rules kept: optional binds, no DISTINCT, no PL/SQL, one statement.
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
)
SELECT
    ml.module                                                   AS "Module",
    'Active'                                                    AS "Status",
    CASE WHEN a.who_rows = 0 THEN '-'
         ELSE TO_CHAR(NVL(u.users_cnt, 0), 'FM999,999,990')
    END                                                         AS "Users (period)"
FROM        mod_list ml
JOIN        act      a ON a.module = ml.module
LEFT JOIN   usr      u ON u.module = ml.module
WHERE       a.rows_cnt > 0
ORDER BY    ml.app_id NULLS LAST, ml.module
