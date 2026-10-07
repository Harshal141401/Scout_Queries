-- ============================================================================
--  F4.4  Section 4.4 Other process areas
--  Version   : 1.1 (2026-10-05). v1.0 failed on the pod with ORA-12704 (R009):
--              UNISTR returns NVARCHAR2 and was mixed with VARCHAR2 rows in a
--              UNION ALL. The middle dot is now TO_CHAR(UNISTR('\00B7')),
--              i.e. plain VARCHAR2. Logic unchanged.
--              RUN V4_0 FIRST. Log every run in 06_Run_Results/RUN_LOG.md.
--  Source    : Oracle Fusion Cloud (BIP data model, data source ApplicationDB_FSCM)
--  Mirrors   : EBS agent ebs_discover_business_processes, "other" block
--              (report 30-Sep-2026, Vision: 3,131 items - 38 orgs; 1,037
--              assets, 13 books; 112 projects - 4 OUs - EBS numbers)
--
--  OUTPUT  Process Area | Metric   (3 rows, EBS order and wording)
--    Inventory / cycle count      "<n> active items <dot> <m> orgs"
--    Fixed Assets / depreciation  "<n> assets on corporate books <dot> <book
--                                  caption, same wording as 3.1>"
--    Projects / project costing   "<n> projects (<t> templates) <dot> <b>
--                                  business units"
--  SNAPSHOT  no date window (EBS rule: these are populations, not activity).
--
--  PARAMETERS  the five standard binds, all optional - same meaning as F1:
--    :p_ledger_id / :p_bu_id narrow the scope; :p_from_date / :p_to_date
--    ('YYYY-MM-DD') set the window, blank = the last 90 days up to today.
--    Run every Section 4 query with the SAME values as F1, or the numbers
--    stop being comparable (see 06_Run_Results/RUN_LOG.md).
--  SCOPE (identical to F1, which is the EBS 1.1 / 4.x rule with BU for OU)
--    ledger-scoped    GL (led_scope), FA (book -> SET_OF_BOOKS_ID)
--    business units   requisitions, POs, AP, payments, orders, AR, receipts,
--                     projects (bu_scope: active BUs whose primary ledger is
--                     in scope, narrowed by :p_bu_id)
--    inventory orgs   receipts, deliveries, items, costing (inv_org_scope)
--
--  ROW-BY-ROW PORT (verified on the Oracle pages 2026-10-05; V4_0)
--    Items  EBS: distinct enabled items (ENABLED_FLAG 'Y') in the ledger's
--        inventory orgs. Fusion EGP_SYSTEM_ITEMS_B, same rule, PLUS
--        TEMPLATE_ITEM_FLAG <> 'Y': in Fusion an item TEMPLATE is stored as an
--        item row (see F3.1 row 8), and a template is not an item.
--        orgs = inventory orgs in scope (inv_org_scope, as F1 / F2.1).
--    Assets  EBS: distinct ASSET_ID on CORPORATE books of the ledger, current
--        rows only (TRANSACTION_HEADER_ID_OUT IS NULL - FA_BOOKS keeps
--        history). Same tables and columns in Fusion. The book caption uses the
--        F3.1b rule (corporate + tax, disabled = DATE_INEFFECTIVE <= today).
--    Projects  EBS: distinct projects in the OUs in scope. Fusion
--        PJF_PROJECTS_ALL_B, BU = ORG_ID ("the business unit associated to the
--        row"). EBS counted project TEMPLATES as projects; the count here keeps
--        the EBS rule and states how many of them are templates
--        (TEMPLATE_FLAG = 'Y'), so nothing is hidden and the reader can subtract.
--        business units = BUs in scope (EBS: operating units).
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
item_cnt AS (
    SELECT COUNT(*) AS cnt
    FROM  ( SELECT i.inventory_item_id
            FROM   egp_system_items_b i
            JOIN   inv_org_scope ios ON ios.organization_id = i.organization_id
            WHERE  i.enabled_flag = 'Y'
            AND    NVL(i.template_item_flag, 'N') <> 'Y'
            GROUP  BY i.inventory_item_id )
),
org_cnt AS (
    SELECT COUNT(*) AS cnt FROM inv_org_scope
),
fa_asset_cnt AS (
    SELECT COUNT(*) AS cnt
    FROM  ( SELECT fb.asset_id
            FROM        fa_books         fb
            JOIN        fa_book_controls fbc ON fbc.book_type_code = fb.book_type_code
            CROSS JOIN  params           p
            WHERE  UPPER(fbc.book_class) = 'CORPORATE'
            AND    fb.transaction_header_id_out IS NULL
            AND    ( p.p_ledger_id IS NULL
                     OR fbc.set_of_books_id = TO_NUMBER(p.p_ledger_id) )
            GROUP  BY fb.asset_id )
),
-- same population as F3.1b (corporate + tax, by ledger when bound)
book_rows AS (
    SELECT UPPER(fbc.book_class)                                       AS cls,
           CASE WHEN fbc.date_ineffective <= SYSDATE THEN 1 ELSE 0 END AS is_disabled
    FROM        fa_book_controls fbc
    CROSS JOIN  params           p
    WHERE       UPPER(fbc.book_class) IN ('CORPORATE', 'TAX')
    AND         ( p.p_ledger_id IS NULL
                  OR fbc.set_of_books_id = TO_NUMBER(p.p_ledger_id) )
),
book_agg AS (
    SELECT COUNT(*)                                                   AS total_books,
           NVL(SUM(CASE WHEN cls = 'CORPORATE' THEN 1 ELSE 0 END), 0) AS corp_books,
           NVL(SUM(CASE WHEN cls = 'TAX'       THEN 1 ELSE 0 END), 0) AS tax_books,
           NVL(SUM(1 - is_disabled), 0)                               AS not_disabled,
           NVL(SUM(is_disabled), 0)                                   AS disabled
    FROM   book_rows
),
proj AS (
    SELECT pp.project_id, MAX(pp.template_flag) AS template_flag
    FROM   pjf_projects_all_b pp
    JOIN   bu_scope b ON b.bu_id = pp.org_id
    GROUP  BY pp.project_id
),
proj_cnt AS (
    SELECT COUNT(*)                                                       AS projects,
           NVL(SUM(CASE WHEN template_flag = 'Y' THEN 1 ELSE 0 END), 0)  AS templates
    FROM   proj
),
bu_cnt AS (
    SELECT COUNT(*) AS cnt FROM bu_scope
),
other_rows AS (
    SELECT 1 AS seq,
           'Inventory / cycle count' AS process_area,
           TO_CHAR(ic.cnt, 'FM999,999,990') || ' active items ' || TO_CHAR(UNISTR('\00B7')) || ' '
             || TO_CHAR(oc.cnt, 'FM999,999,990') || ' orgs'     AS metric
    FROM   item_cnt ic CROSS JOIN org_cnt oc
    UNION ALL
    SELECT 2,
           'Fixed Assets / depreciation',
           TO_CHAR(fa.cnt, 'FM999,999,990') || ' assets on corporate books ' || TO_CHAR(UNISTR('\00B7')) || ' '
             || TO_CHAR(ba.total_books, 'FM999,990') || ' configured asset books: '
             || TO_CHAR(ba.corp_books, 'FM999,990') || ' corporate, '
             || TO_CHAR(ba.tax_books, 'FM999,990') || ' tax; '
             || TO_CHAR(ba.not_disabled, 'FM999,990') || ' not disabled, '
             || TO_CHAR(ba.disabled, 'FM999,990') || ' disabled.'
    FROM   fa_asset_cnt fa CROSS JOIN book_agg ba
    UNION ALL
    SELECT 3,
           'Projects / project costing',
           TO_CHAR(pc.projects, 'FM999,999,990') || ' projects ('
             || TO_CHAR(pc.templates, 'FM999,999,990') || ' templates) ' || TO_CHAR(UNISTR('\00B7')) || ' '
             || TO_CHAR(bc.cnt, 'FM999,990') || ' business units'
    FROM   proj_cnt pc CROSS JOIN bu_cnt bc
)
SELECT
    r.process_area                                            AS "Process Area",
    r.metric                                                  AS "Metric"
FROM        other_rows r
ORDER BY    r.seq
