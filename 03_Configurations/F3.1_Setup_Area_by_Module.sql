-- ============================================================================
--  F3.1  Section 3.1 Setup area by module
--  Version   : 1.0 (2026-10-05). Not yet run on a pod.
--              RUN V3_0 FIRST. Log every run in 06_Run_Results/RUN_LOG.md.
--  Source    : Oracle Fusion Cloud (BIP data model, data source ApplicationDB_FSCM)
--  Mirrors   : the EBS logic that PRODUCED the report (agent
--              ebs_discover_configurations, ebs_discovery-main 2026-09-23), not
--              the SQL pack: the report prints these 12 rows; the pack's 3.1 had
--              16 (FA categories / methods, PA rows) and an older CE / FA rule.
--              Report 30-Sep-2026 (Vision): 41 / 26 / 124 / 77 / 101 / 288 / 76
--              / 69 / 1,084 / 23 / 28 / 13. Those are EBS numbers, not targets.
--
--  OUTPUT  Module | Setup Area | Count   (the report's three columns, 12 rows)
--    Module = APPLICATION_SHORT_NAME of the table the row counts, read from
--    FND_TABLES (same registry rule as F1; nothing typed). A table missing from
--    the registry prints 'Not registered: <TABLE>' instead of a guessed code.
--    Setup Area = the report's label for the metric.
--
--  PARAMETERS  same five as F0 / F1, all optional. Setup has no date window.
--    :p_ledger_id / :p_bu_id narrow ONLY the rows EBS narrowed (see SCOPE).
--    All blank = whole pod = every row counts in full (EBS parity).
--
--  ROW-BY-ROW PORT  (EBS rule -> Fusion table, verified on the Oracle Fusion
--  Tables and Views pages 2026-10-05; V3_0 re-checks every column on the pod)
--   1 AP Payment Terms        EBS distinct TERM_ID in AP_TERMS_TL (all terms,
--                             incl. disabled) -> AP_TERMS_B, PK TERM_ID = one
--                             row per term. COUNT(*). Pod-wide.
--   2 AR Payment Terms        EBS COUNT(*) RA_TERMS_B -> same table in Fusion
--                             (PK TERM_ID). Pod-wide.
--   3 AR Transaction Types    RA_CUST_TRX_TYPES_ALL. In Fusion the unique key is
--                             CUST_TRX_TYPE_ID + SET_ID: types belong to a
--                             reference data SET, one row per type per set.
--                             COUNT(*) = every defined type in every set.
--   4 AR Transaction Sources  RA_BATCH_SOURCES_ALL. Fusion has NO ORG_ID on this
--                             table (SET_ID instead; unique BATCH_SOURCE_ID +
--                             SET_ID). COUNT(*).
--   5 GL Journal Sources      EBS distinct JE_SOURCE_NAME in GL_JE_SOURCES_TL,
--                             LANGUAGE IN (USERENV('LANG'),'US') -> identical
--                             (PK JE_SOURCE_NAME + LANGUAGE). Counts GROUPS, so
--                             a source in two languages counts once.
--   6 GL Journal Categories   same rule on GL_JE_CATEGORIES_TL.
--   7 PO Document Types       PO_DOCUMENT_TYPES_ALL_B. Fusion PK is
--                             DOCUMENT_TYPE_CODE + DOCUMENT_SUBTYPE + PRC_BU_ID;
--                             there is NO ORG_ID - the owner is the procurement
--                             BU (PRC_BU_ID). COUNT(*).
--   8 Item Templates          EBS COUNT(*) MTL_ITEM_TEMPLATES_B. Fusion has no
--                             item-template table (EGP_ITEM_TEMPLATES_B absent on
--                             the dev pod, June verifier): a template is an item
--                             row in EGP_SYSTEM_ITEMS_B with TEMPLATE_ITEM_FLAG =
--                             'Y' ("Attribute used to mark the item as a
--                             template"). PK is item + org, so grouped on
--                             INVENTORY_ITEM_ID: one template counts once.
--                             Module prints the registry owner (EGP, Product
--                             Model) - in Fusion templates are not INV setup.
--   9 Subinventories          EBS COUNT(*) MTL_SECONDARY_INVENTORIES (all, incl.
--                             disabled) -> INV_SECONDARY_INVENTORIES, PK
--                             SECONDARY_INVENTORY_NAME + ORGANIZATION_ID. Pod-wide.
--  10 Active internal bank    EBS: CE_BANK_ACCOUNTS ACCOUNT_CLASSIFICATION =
--     accounts               'INTERNAL', NVL(END_DATE, SYSDATE+1) > SYSDATE;
--                             bound runs add EXISTS a use by an in-scope OU.
--                             Fusion: same columns; CE_BANK_ACCT_USES_ALL.ORG_ID
--                             is "the business unit associated to the row", so
--                             the bound test uses the in-scope BUs. EXISTS keeps
--                             an account shared by several BUs counted once.
--  11 Cost Books              EBS COUNT(*) CST_COST_TYPES. Fusion has NO cost
--                             types. The Fusion setup that plays that role is the
--                             COST BOOK (CST_COST_BOOKS_B: "Cost books help to
--                             achieve the multiple representation"), so the row
--                             is labelled in Fusion terms. COUNT(*). Pod-wide.
--  12 Configured asset books  EBS: FA_BOOK_CONTROLS, UPPER(BOOK_CLASS) IN
--                             ('CORPORATE','TAX') (reviewer: budget excluded),
--                             disabled books INCLUDED, SET_OF_BOOKS_ID = ledger
--                             when bound -> identical columns in Fusion.
--                             Equals the Total / Configured of
--                             F3.1_Asset_Books_By_Class.sql by construction.
--
--  SCOPE  (EBS rule: a row is narrowed only if its table carries the owning
--          org; system-wide setup is never narrowed - it would undercount)
--    narrowed when :p_ledger_id or :p_bu_id is set
--      7 PO Document Types        PRC_BU_ID in the in-scope BUs
--      10 Bank accounts           a use (ORG_ID) by an in-scope BU
--      12 Asset books             SET_OF_BOOKS_ID = :p_ledger_id (BU ignored -
--                                 a book follows its ledger, EBS parity)
--    never narrowed (pod-wide in every mode)
--      1, 2, 5, 6, 8, 9, 11       system-wide setup, exactly as EBS
--      3, 4 AR types / sources    EBS narrowed these by ORG_ID. In Fusion they
--                                 are owned by a reference data SET, not a BU
--                                 (sources have no ORG_ID at all), so they are
--                                 pod-wide here. Narrowing by set assignment is
--                                 a Fusion-only refinement, NOT built: it needs
--                                 the reference-group codes, which V3_0 does
--                                 not prove. Unbound runs are unaffected.
--    In-scope BUs = the shared-block rule (F0 / F1): active BUs whose primary
--    ledger is :p_ledger_id, narrowed by :p_bu_id. A procurement BU with no
--    primary ledger of its own therefore drops out of a BOUND row 7 - run
--    unbound for the full count.
--
--  Rules kept: optional binds, no DISTINCT, no PL/SQL, one statement, every
--  aggregate in its own CTE, no CTE named after a table.
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
-- 0 = unbound (whole pod), 1 = a ledger and/or BU was given
scope_flag AS (
    SELECT CASE WHEN p.p_ledger_id IS NULL AND p.p_bu_id IS NULL
                THEN 0 ELSE 1 END                          AS is_bound
    FROM   params p
),
-- same BU rule as the F0 / F1 shared block (PRIMARY_LEDGER_ID is a string)
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
-- ---- 1 AP Payment Terms (pod-wide) -----------------------------------------
ap_terms_cnt AS (
    SELECT COUNT(*) AS cnt
    FROM   ap_terms_b
),
-- ---- 2 AR Payment Terms (pod-wide) -----------------------------------------
ar_terms_cnt AS (
    SELECT COUNT(*) AS cnt
    FROM   ra_terms_b
),
-- ---- 3 AR Transaction Types (pod-wide; set-owned in Fusion) ----------------
ar_trx_type_cnt AS (
    SELECT COUNT(*) AS cnt
    FROM   ra_cust_trx_types_all
),
-- ---- 4 AR Transaction Sources (pod-wide; no ORG_ID in Fusion) --------------
ar_trx_source_cnt AS (
    SELECT COUNT(*) AS cnt
    FROM   ra_batch_sources_all
),
-- ---- 5 / 6 GL Journal Sources / Categories (pod-wide, grouped by name) -----
gl_source_cnt AS (
    SELECT COUNT(*) AS cnt
    FROM  ( SELECT s.je_source_name
            FROM   gl_je_sources_tl s
            WHERE  s.language IN (USERENV('LANG'), 'US')
            GROUP  BY s.je_source_name )
),
gl_category_cnt AS (
    SELECT COUNT(*) AS cnt
    FROM  ( SELECT c.je_category_name
            FROM   gl_je_categories_tl c
            WHERE  c.language IN (USERENV('LANG'), 'US')
            GROUP  BY c.je_category_name )
),
-- ---- 7 PO Document Types (narrowed by procurement BU when bound) -----------
po_doc_type_cnt AS (
    SELECT COUNT(*) AS cnt
    FROM        po_document_types_all_b d
    CROSS JOIN  scope_flag f
    WHERE       f.is_bound = 0
       OR       d.prc_bu_id IN ( SELECT b.bu_id FROM bu_scope b )
),
-- ---- 8 Item Templates (pod-wide; template = flagged item, once per item) ---
item_template_cnt AS (
    SELECT COUNT(*) AS cnt
    FROM  ( SELECT i.inventory_item_id
            FROM   egp_system_items_b i
            WHERE  NVL(i.template_item_flag, 'N') = 'Y'
            GROUP  BY i.inventory_item_id )
),
-- ---- 9 Subinventories (pod-wide, incl. disabled - EBS parity) --------------
subinv_cnt AS (
    SELECT COUNT(*) AS cnt
    FROM   inv_secondary_inventories
),
-- ---- 10 Active internal bank accounts (narrowed by BU use when bound) ------
int_bank_acct_cnt AS (
    SELECT COUNT(*) AS cnt
    FROM        ce_bank_accounts ba
    CROSS JOIN  scope_flag f
    WHERE       ba.account_classification = 'INTERNAL'
    AND         NVL(ba.end_date, SYSDATE + 1) > SYSDATE
    AND         ( f.is_bound = 0
                  OR EXISTS ( SELECT 1
                              FROM   ce_bank_acct_uses_all u
                              JOIN   bu_scope b ON b.bu_id = u.org_id
                              WHERE  u.bank_account_id = ba.bank_account_id ) )
),
-- ---- 11 Cost Books (pod-wide; Fusion counterpart of EBS cost types) --------
cost_book_cnt AS (
    SELECT COUNT(*) AS cnt
    FROM   cst_cost_books_b
),
-- ---- 12 Configured asset books (corporate + tax, by ledger when bound) -----
asset_book_cnt AS (
    SELECT COUNT(*) AS cnt
    FROM        fa_book_controls fbc
    CROSS JOIN  params p
    WHERE       UPPER(fbc.book_class) IN ('CORPORATE', 'TAX')
    AND         ( p.p_ledger_id IS NULL
                  OR fbc.set_of_books_id = TO_NUMBER(p.p_ledger_id) )
),
-- ---- the 12 rows, report order; src_table = the table the row counts -------
setup_rows AS (
    SELECT  1 AS seq, 'AP_TERMS_B' AS src_table,
            'Payment Terms' AS setup_area, c.cnt AS setup_count
    FROM    ap_terms_cnt c
    UNION ALL
    SELECT  2, 'RA_TERMS_B', 'Payment Terms', c.cnt
    FROM    ar_terms_cnt c
    UNION ALL
    SELECT  3, 'RA_CUST_TRX_TYPES_ALL', 'Transaction Types', c.cnt
    FROM    ar_trx_type_cnt c
    UNION ALL
    SELECT  4, 'RA_BATCH_SOURCES_ALL', 'Transaction Sources', c.cnt
    FROM    ar_trx_source_cnt c
    UNION ALL
    SELECT  5, 'GL_JE_SOURCES_TL', 'Journal Sources', c.cnt
    FROM    gl_source_cnt c
    UNION ALL
    SELECT  6, 'GL_JE_CATEGORIES_TL', 'Journal Categories', c.cnt
    FROM    gl_category_cnt c
    UNION ALL
    SELECT  7, 'PO_DOCUMENT_TYPES_ALL_B', 'Document Types', c.cnt
    FROM    po_doc_type_cnt c
    UNION ALL
    SELECT  8, 'EGP_SYSTEM_ITEMS_B', 'Item Templates', c.cnt
    FROM    item_template_cnt c
    UNION ALL
    SELECT  9, 'INV_SECONDARY_INVENTORIES', 'Subinventories', c.cnt
    FROM    subinv_cnt c
    UNION ALL
    SELECT 10, 'CE_BANK_ACCOUNTS', 'Active internal bank accounts', c.cnt
    FROM    int_bank_acct_cnt c
    UNION ALL
    SELECT 11, 'CST_COST_BOOKS_B', 'Cost Books', c.cnt
    FROM    cost_book_cnt c
    UNION ALL
    SELECT 12, 'FA_BOOK_CONTROLS', 'Configured asset books', c.cnt
    FROM    asset_book_cnt c
),
-- ---- module = owning application of the counted table (FND_TABLES) ---------
--  Same lookup as F1 (FND_TABLES has APPLICATION_SHORT_NAME, no APPLICATION_ID;
--  confirmed on the pod by V0_0 / R003). Matched on TABLE_NAME or
--  PHYSICAL_TABLE_NAME; MIN() keeps one row per table.
tab_app AS (
    SELECT  r.src_table,
            MIN(ft.application_short_name) AS app_short
    FROM        setup_rows r
    LEFT JOIN   fnd_tables ft
           ON   ft.table_name          = r.src_table
            OR  ft.physical_table_name = r.src_table
    GROUP   BY  r.src_table
)
SELECT
    NVL(t.app_short, 'Not registered: ' || r.src_table)       AS "Module",
    r.setup_area                                              AS "Setup Area",
    r.setup_count                                             AS "Count"
FROM        setup_rows r
LEFT JOIN   tab_app    t ON t.src_table = r.src_table
ORDER BY    r.seq
