-- ============================================================================
--  V1_1  Module activity EVIDENCE - why each module counts as Active in F1
--  Version   : 1.0 (2026-10-01), built on shared block v3.1 (same scope, same
--              window, same registry module names as F0 / F1 / F1.2)
--  Run log   : 06_Run_Results/RUN_LOG.md (log the output as the next Rnnn)
--
--  WHY THIS EXISTS
--    F1 (R004) says 13 modules are Active. The functional consultant says 6
--    modules are live. F1's rule is "the module's source table has at least
--    ONE row in the window, created by ANYONE, anywhere in scope" - a data
--    test, not a "live in production" test. This query prints the evidence
--    behind each module so the two can be reconciled module by module:
--      - how much activity (rows) and by how many users
--      - WHO created it: a real person, an account with no person behind it
--        (integration / service / supplier-portal accounts), or an identity
--        that is not a user account at all (system / application identities)
--      - whether it is steady usage (active most months of the last 12) or a
--        recent burst (testing, a pilot, a one-off load)
--
--  PARAMETERS  identical to F1 - run with EXACTLY the values used for F1
--    (blank = whole pod, last 90 days). Then "Users (window)" must equal F1's
--    "Users (period)" for every Active module; if not, this query is wrong.
--
--  CREATOR CLASS  (read from data, nothing typed)
--    CREATED_BY is matched to PER_USERS.USERNAME (case-insensitive; the table
--    has an UPPER(USERNAME) index). Columns verified on the Oracle HCM Tables
--    and Views page for PER_USERS, 2026-10-01:
--      person              PER_USERS.PERSON_ID is not null (a worker)
--      account, no person  in PER_USERS, PERSON_ID null
--      not a user account  CREATED_BY not found in PER_USERS
--
--  HISTORY  same branches, read back to the start of the month 11 months
--    before the window end (or the window start if that is earlier), so
--    "Months active" = calendar months with at least one row, out of the
--    months shown in "History from". Same date column per module as F1.
--
--  OUTPUT  one row per module (Active first, in F1 order, then Dormant).
--  No DISTINCT, no PL/SQL, one statement, nothing written.
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
-- history range: 12 calendar months ending with the window end month
win12 AS (
    SELECT  w.start_date,
            w.end_date_excl,
            LEAST(w.start_date,
                  ADD_MONTHS(TRUNC(w.end_date_excl - 1, 'MM'), -11)) AS hist_start
    FROM    win w
),
txn12 AS (
    -- 1 General Ledger: journal headers created in the window
    SELECT 'GL_JE_HEADERS' AS src_table, jh.created_by AS who, CAST(jh.creation_date AS DATE) AS act_date,
           CASE WHEN jh.creation_date >= w.start_date THEN 1 ELSE 0 END AS in_win
    FROM   gl_je_headers jh
    JOIN   led_scope l ON l.ledger_id = jh.ledger_id
    CROSS  JOIN win12 w
    WHERE  jh.creation_date >= w.hist_start
    AND    jh.creation_date <  w.end_date_excl
    UNION ALL
    -- 2 Payables: invoices by invoice date (business date, EBS parity)
    SELECT 'AP_INVOICES_ALL', ai.created_by, CAST(ai.invoice_date AS DATE),
           CASE WHEN ai.invoice_date >= w.start_date THEN 1 ELSE 0 END
    FROM   ap_invoices_all ai
    JOIN   bu_scope b ON b.bu_id = ai.org_id
    CROSS  JOIN win12 w
    WHERE  ai.invoice_date >= w.hist_start
    AND    ai.invoice_date <  w.end_date_excl
    UNION ALL
    -- 3 Receivables: transactions by transaction date
    SELECT 'RA_CUSTOMER_TRX_ALL', ct.created_by, CAST(ct.trx_date AS DATE),
           CASE WHEN ct.trx_date >= w.start_date THEN 1 ELSE 0 END
    FROM   ra_customer_trx_all ct
    JOIN   bu_scope b ON b.bu_id = ct.org_id
    CROSS  JOIN win12 w
    WHERE  ct.trx_date >= w.hist_start
    AND    ct.trx_date <  w.end_date_excl
    UNION ALL
    -- 4 Purchasing: purchase order headers (any document type)
    SELECT 'PO_HEADERS_ALL', ph.created_by, CAST(ph.creation_date AS DATE),
           CASE WHEN ph.creation_date >= w.start_date THEN 1 ELSE 0 END
    FROM   po_headers_all ph
    CROSS  JOIN win12 w
    WHERE  ph.creation_date >= w.hist_start
    AND    ph.creation_date <  w.end_date_excl
    AND    EXISTS ( SELECT 1
                    FROM   bu_scope b
                    WHERE  b.bu_id IN (ph.prc_bu_id, ph.req_bu_id, ph.billto_bu_id) )
    UNION ALL
    -- 4 Purchasing: requisition headers (same module, EBS parity)
    SELECT 'POR_REQUISITION_HEADERS_ALL', rh.created_by, CAST(rh.creation_date AS DATE),
           CASE WHEN rh.creation_date >= w.start_date THEN 1 ELSE 0 END
    FROM   por_requisition_headers_all rh
    JOIN   bu_scope b ON b.bu_id = rh.req_bu_id
    CROSS  JOIN win12 w
    WHERE  rh.creation_date >= w.hist_start
    AND    rh.creation_date <  w.end_date_excl
    UNION ALL
    -- 5 Order Management: order headers by ordered date
    SELECT 'DOO_HEADERS_ALL', dh.created_by, CAST(dh.ordered_date AS DATE),
           CASE WHEN dh.ordered_date >= w.start_date THEN 1 ELSE 0 END
    FROM   doo_headers_all dh
    JOIN   bu_scope b ON b.bu_id = dh.org_id
    CROSS  JOIN win12 w
    WHERE  dh.ordered_date >= w.hist_start
    AND    dh.ordered_date <  w.end_date_excl
    UNION ALL
    -- 6 Inventory: material transactions by transaction date
    SELECT 'INV_MATERIAL_TXNS', imt.created_by, CAST(imt.transaction_date AS DATE),
           CASE WHEN imt.transaction_date >= w.start_date THEN 1 ELSE 0 END
    FROM   inv_material_txns imt
    JOIN   inv_org_scope ios ON ios.organization_id = imt.organization_id
    CROSS  JOIN win12 w
    WHERE  imt.transaction_date >= w.hist_start
    AND    imt.transaction_date <  w.end_date_excl
    UNION ALL
    -- 7 Cash Management: bank statements on accounts used by a BU in scope.
    --   EXISTS, not JOIN: an account used by three BUs must not count three times.
    SELECT 'CE_STATEMENT_HEADERS', csh.created_by, CAST(csh.creation_date AS DATE),
           CASE WHEN csh.creation_date >= w.start_date THEN 1 ELSE 0 END
    FROM   ce_statement_headers csh
    CROSS  JOIN win12 w
    WHERE  csh.creation_date >= w.hist_start
    AND    csh.creation_date <  w.end_date_excl
    AND    EXISTS ( SELECT 1
                    FROM   ce_bank_acct_uses_all u
                    JOIN   bu_scope b ON b.bu_id = u.org_id
                    WHERE  u.bank_account_id = csh.bank_account_id )
    UNION ALL
    -- 8 Cost Management: cost distributions (costing's own accounting output,
    --   so a cost accountant who never moved stock still counts - EBS parity)
    SELECT 'CST_COST_DISTRIBUTIONS', cd.created_by, CAST(cd.gl_date AS DATE),
           CASE WHEN cd.gl_date >= w.start_date THEN 1 ELSE 0 END
    FROM   cst_cost_distributions cd
    JOIN   led_scope l ON l.ledger_id = cd.ledger_id
    CROSS  JOIN win12 w
    WHERE  cd.gl_date >= w.hist_start
    AND    cd.gl_date <  w.end_date_excl
    UNION ALL
    -- 9 Assets: asset transactions on the ledger's books
    SELECT 'FA_TRANSACTION_HEADERS', fth.last_updated_by, CAST(fth.transaction_date_entered AS DATE),
           CASE WHEN fth.transaction_date_entered >= w.start_date THEN 1 ELSE 0 END
    FROM   fa_transaction_headers fth
    JOIN   fa_book_scope fb ON fb.book_type_code = fth.book_type_code
    CROSS  JOIN win12 w
    WHERE  fth.transaction_date_entered >= w.hist_start
    AND    fth.transaction_date_entered <  w.end_date_excl
    UNION ALL
    -- 10 Project Costing: expenditure items by expenditure item date
    SELECT 'PJC_EXP_ITEMS_ALL', ei.created_by, CAST(ei.expenditure_item_date AS DATE),
           CASE WHEN ei.expenditure_item_date >= w.start_date THEN 1 ELSE 0 END
    FROM   pjc_exp_items_all ei
    JOIN   bu_scope b ON b.bu_id = ei.org_id
    CROSS  JOIN win12 w
    WHERE  ei.expenditure_item_date >= w.hist_start
    AND    ei.expenditure_item_date <  w.end_date_excl
    UNION ALL
    -- 11 Manufacturing (work execution): work orders created in the window
    SELECT 'WIE_WORK_ORDERS_B', wo.created_by, CAST(wo.creation_date AS DATE),
           CASE WHEN wo.creation_date >= w.start_date THEN 1 ELSE 0 END
    FROM   wie_work_orders_b wo
    JOIN   inv_org_scope ios ON ios.organization_id = wo.organization_id
    CROSS  JOIN win12 w
    WHERE  wo.creation_date >= w.hist_start
    AND    wo.creation_date <  w.end_date_excl
    UNION ALL
    -- 12 Item Structures (BOM): structures created in the window.
    --    EGP_STRUCTURES_B has no ORGANIZATION_ID; PK2_VALUE holds it (string).
    SELECT 'EGP_STRUCTURES_B', es.created_by, CAST(es.creation_date AS DATE),
           CASE WHEN es.creation_date >= w.start_date THEN 1 ELSE 0 END
    FROM   egp_structures_b es
    JOIN   inv_org_scope ios ON TO_CHAR(ios.organization_id) = es.pk2_value
    CROSS  JOIN win12 w
    WHERE  es.creation_date >= w.hist_start
    AND    es.creation_date <  w.end_date_excl
    UNION ALL
    -- 13 Shipping: deliveries created in the window
    SELECT 'WSH_NEW_DELIVERIES', wnd.created_by, CAST(wnd.creation_date AS DATE),
           CASE WHEN wnd.creation_date >= w.start_date THEN 1 ELSE 0 END
    FROM   wsh_new_deliveries wnd
    JOIN   inv_org_scope ios ON ios.organization_id = wnd.organization_id
    CROSS  JOIN win12 w
    WHERE  wnd.creation_date >= w.hist_start
    AND    wnd.creation_date <  w.end_date_excl
    UNION ALL
    -- 14 Expenses: expense reports created in the window (EBS parity:
    --    creation date). Overlaps Payables - expense reports become AP invoices.
    SELECT 'EXM_EXPENSE_REPORTS', er.created_by, CAST(er.creation_date AS DATE),
           CASE WHEN er.creation_date >= w.start_date THEN 1 ELSE 0 END
    FROM   exm_expense_reports er
    JOIN   bu_scope b ON b.bu_id = er.org_id
    CROSS  JOIN win12 w
    WHERE  er.creation_date >= w.hist_start
    AND    er.creation_date <  w.end_date_excl
    UNION ALL
    -- 15 Lease Accounting (Fusion counterpart of EBS Property Manager)
    SELECT 'FLA_LEASES_ALL', fl.created_by, CAST(fl.creation_date AS DATE),
           CASE WHEN fl.creation_date >= w.start_date THEN 1 ELSE 0 END
    FROM   fla_leases_all fl
    JOIN   bu_scope b ON b.bu_id = fl.org_id
    CROSS  JOIN win12 w
    WHERE  fl.creation_date >= w.hist_start
    AND    fl.creation_date <  w.end_date_excl
    UNION ALL
    -- 16 Intercompany: pod-wide on purpose; users not counted (see header)
    SELECT 'FUN_TRX_HEADERS', CAST(NULL AS VARCHAR2(64)), CAST(ft.creation_date AS DATE),
           CASE WHEN ft.creation_date >= w.start_date THEN 1 ELSE 0 END
    FROM   fun_trx_headers ft
    CROSS  JOIN win12 w
    WHERE  ft.creation_date >= w.hist_start
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
-- every history row tagged with its module; in_win = the F1 window test,
-- computed on the original column in each branch (exact F1 parity)
txn12_mod AS (
    SELECT  m.module, t.who, t.act_date,
            t.in_win
    FROM        txn12   t
    JOIN        modules m ON m.src_table = t.src_table
),
-- one row per user name, flagged when a person stands behind it
creator_acct AS (
    SELECT  UPPER(pu.username)                                   AS uname,
            MAX(CASE WHEN pu.person_id IS NOT NULL THEN 1 ELSE 0 END) AS has_person
    FROM    per_users pu
    WHERE   pu.username IS NOT NULL
    GROUP   BY UPPER(pu.username)
),
win_who AS (
    SELECT  module, who, COUNT(*) AS rows_cnt
    FROM    txn12_mod
    WHERE   in_win = 1
    AND     who IS NOT NULL
    GROUP   BY module, who
),
win_who_cls AS (
    SELECT  ww.module, ww.who, ww.rows_cnt,
            CASE WHEN ca.uname IS NULL      THEN 'not a user account'
                 WHEN ca.has_person = 1     THEN 'person'
                 ELSE 'account, no person'
            END                                                    AS who_class,
            ROW_NUMBER() OVER (PARTITION BY ww.module
                               ORDER BY ww.rows_cnt DESC, ww.who)   AS rn
    FROM        win_who      ww
    LEFT JOIN   creator_acct ca ON ca.uname = UPPER(ww.who)
),
win_agg AS (
    SELECT  module, COUNT(*) AS rows_win, COUNT(who) AS who_rows
    FROM    txn12_mod
    WHERE   in_win = 1
    GROUP   BY module
),
cls_agg AS (
    SELECT  module,
            COUNT(*)                                                         AS users_win,
            SUM(CASE WHEN who_class = 'person'             THEN 1 ELSE 0 END) AS person_users,
            SUM(CASE WHEN who_class = 'account, no person' THEN 1 ELSE 0 END) AS noperson_users,
            SUM(CASE WHEN who_class = 'not a user account' THEN 1 ELSE 0 END) AS system_ids,
            SUM(CASE WHEN who_class = 'person' THEN rows_cnt ELSE 0 END)      AS person_rows
    FROM    win_who_cls
    GROUP   BY module
),
top_who AS (
    SELECT  module,
            LISTAGG(who || ' ' || TO_CHAR(rows_cnt) || ' [' || who_class || ']', '; '
                    ON OVERFLOW TRUNCATE)
                WITHIN GROUP (ORDER BY rn)                                   AS top_creators
    FROM    win_who_cls
    WHERE   rn <= 5
    GROUP   BY module
),
hist_mon AS (
    SELECT  module, TRUNC(act_date, 'MM') AS mon
    FROM    txn12_mod
    GROUP   BY module, TRUNC(act_date, 'MM')
),
hist_agg AS (
    SELECT  module, COUNT(*) AS months_active
    FROM    hist_mon
    GROUP   BY module
),
hist_rng AS (
    SELECT  module, MIN(act_date) AS first_dt, MAX(act_date) AS last_dt,
            COUNT(*) AS rows_hist
    FROM    txn12_mod
    GROUP   BY module
),
src_list AS (
    SELECT  module,
            LISTAGG(src_table, ', ') WITHIN GROUP (ORDER BY src_table)       AS src_tables
    FROM    modules
    GROUP   BY module
),
run_ctx AS (
    SELECT  TO_CHAR(w.start_date, 'YYYY-MM-DD') || ' to '
              || TO_CHAR(w.end_date_excl - 1, 'YYYY-MM-DD')                  AS window_txt,
            TO_CHAR(w.hist_start, 'YYYY-MM-DD')                              AS hist_txt,
            MONTHS_BETWEEN(TRUNC(w.end_date_excl - 1, 'MM'),
                           TRUNC(w.hist_start, 'MM')) + 1                    AS hist_months,
            SYS_CONTEXT('USERENV', 'DB_NAME')                                AS pod_db
    FROM    win12 w
)
SELECT
    ml.module                                                   AS "Module",
    sl.src_tables                                               AS "Source table",
    CASE WHEN NVL(wa.rows_win, 0) > 0 THEN 'Active' ELSE 'Dormant' END
                                                                AS "F1 status",
    NVL(wa.rows_win, 0)                                         AS "Rows (window)",
    CASE WHEN NVL(wa.rows_win, 0) > 0 AND wa.who_rows = 0 THEN '-'
         ELSE TO_CHAR(NVL(ca.users_win, 0))
    END                                                         AS "Users (window)",
    NVL(ca.person_users, 0)                                     AS "Person users",
    NVL(ca.noperson_users, 0)                                   AS "Accounts no person",
    NVL(ca.system_ids, 0)                                       AS "Not a user account",
    NVL(ca.person_rows, 0)                                      AS "Rows by persons",
    TO_CHAR(NVL(ha.months_active, 0)) || ' of '
      || TO_CHAR(rc.hist_months)                                AS "Months active",
    NVL(hr.rows_hist, 0)                                        AS "Rows (history)",
    TO_CHAR(hr.first_dt, 'YYYY-MM-DD')                          AS "First in history",
    TO_CHAR(hr.last_dt,  'YYYY-MM-DD')                          AS "Last activity",
    tw.top_creators                                             AS "Top creators (window)",
    rc.window_txt                                               AS "Window",
    rc.hist_txt                                                 AS "History from",
    rc.pod_db                                                   AS "Pod DB"
FROM        mod_list ml
CROSS JOIN  run_ctx  rc
LEFT JOIN   src_list sl ON sl.module = ml.module
LEFT JOIN   win_agg  wa ON wa.module = ml.module
LEFT JOIN   cls_agg  ca ON ca.module = ml.module
LEFT JOIN   top_who  tw ON tw.module = ml.module
LEFT JOIN   hist_agg ha ON ha.module = ml.module
LEFT JOIN   hist_rng hr ON hr.module = ml.module
ORDER BY    CASE WHEN NVL(wa.rows_win, 0) > 0 THEN 0 ELSE 1 END,
            ml.app_id NULLS LAST, ml.module
