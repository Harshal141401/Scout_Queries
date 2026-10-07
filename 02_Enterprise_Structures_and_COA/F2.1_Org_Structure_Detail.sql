-- ============================================================================
--  F2.1 detail  Workbook WB1 "Org Structure"
--               (EBS: EBS_Discovery_2_1_Org_Structure.xlsx)
--  Source    : Oracle Fusion Cloud (BIP data model, data source ApplicationDB_FSCM)
--  Mirrors   : EBS 2.1_Ledger_BG_LE_OU_InvOrg_Detail_v2.sql
--  No Fusion draft existed for this workbook.
--
--  HIERARCHY  Primary ledger -> Legal entity -> Business unit -> Inventory org
--    EBS "Business Group" is an HCM concept and is dropped (Fusion has one
--    Enterprise per pod). EBS "Operating Unit" -> Fusion "Business Unit".
--
--  GRAIN  one row per inventory org of a primary ledger, PLUS one row for each
--    business unit with no inventory org, PLUS one row for each legal entity
--    with no business unit - so every entity appears once and nothing is lost.
--
--  RECONCILES TO F2.1 (primary ledger row):
--    distinct INVENTORY_ORG   = Inv Orgs
--    distinct BUSINESS_UNIT with BU_ACTIVE = 'Y' = Business Units
--    distinct LEGAL_ENTITY with LE_ON_LEDGER = 'Y' = Legal Entities
--    LE_ON_LEDGER = 'N' flags a BU whose default legal entity is NOT assigned
--    to its ledger - a real configuration finding, not a query error.
--
--  PARAMETERS  :p_ledger_id optional (blank = every primary ledger).
--              Others accepted, not used.
--  Version   : 1.0 (built 2026-09-30, statically checked, not yet run on a pod)
--  RUN V0_1 AND V0_2 FIRST. Log every run in 06_Run_Results/RUN_LOG.md.
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
prim AS (
    SELECT  gl.ledger_id, gl.name AS ledger_name, gl.currency_code,
            gl.period_set_name, gl.sla_accounting_method_code,
            gl.sla_accounting_method_type
    FROM    gl_ledgers gl
    CROSS   JOIN params p
    WHERE   gl.object_type_code     = 'L'
    AND     gl.ledger_category_code = 'PRIMARY'
    AND     NVL(gl.complete_flag, 'Y') = 'Y'
    AND     (p.p_ledger_id IS NULL OR gl.ledger_id = TO_NUMBER(p.p_ledger_id))
),
acct_method AS (
    SELECT  amt.accounting_method_type_code,
            amt.accounting_method_code,
            MAX(amt.name) AS method_name
    FROM    xla_acctg_methods_tl amt
    WHERE   amt.language = USERENV('LANG')
    GROUP   BY amt.accounting_method_type_code,
               amt.accounting_method_code
),
-- reporting currencies = currencies of the primary's ALC ledgers
rep_cur AS (
    SELECT  primary_ledger_id,
            LISTAGG(currency_code, ', ') WITHIN GROUP (ORDER BY currency_code) AS currencies
    FROM  ( SELECT r.primary_ledger_id, t.currency_code
            FROM   gl_ledger_relationships r
            JOIN   gl_ledgers t ON t.ledger_id = r.target_ledger_id
            WHERE  r.application_id = 101
            AND    t.ledger_category_code = 'ALC'
            GROUP  BY r.primary_ledger_id, t.currency_code )
    GROUP   BY primary_ledger_id
),
-- legal entities assigned to each primary ledger
led_le AS (
    SELECT  v.ledger_id, v.legal_entity_id, MAX(v.legal_entity_name) AS le_name
    FROM    gl_ledger_le_v v
    JOIN    prim p ON p.ledger_id = v.ledger_id
    WHERE   v.legal_entity_id IS NOT NULL
    GROUP   BY v.ledger_id, v.legal_entity_id
),
-- balancing segment values per ledger + LE (collapsed to one string)
le_bsv AS (
    SELECT  ledger_id, legal_entity_id,
            LISTAGG(segment_value, ', ') WITHIN GROUP (ORDER BY segment_value) AS bsvs
    FROM  ( SELECT b.ledger_id, b.legal_entity_id, b.segment_value
            FROM   gl_ledger_le_bsv_specific_v b
            JOIN   prim p ON p.ledger_id = b.ledger_id
            GROUP  BY b.ledger_id, b.legal_entity_id, b.segment_value )
    GROUP   BY ledger_id, legal_entity_id
),
-- business units of each primary ledger (any status; BU_ACTIVE says which)
led_bu AS (
    SELECT  p.ledger_id, bu.bu_id, MAX(bu.bu_name) AS bu_name,
            MAX(bu.legal_entity_id) AS bu_le_id_char,
            MAX(CASE WHEN NVL(UPPER(bu.status), 'A') NOT IN ('I', 'INACTIVE')
                     THEN 'Y' ELSE 'N' END) AS bu_active
    FROM    fun_all_business_units_v bu
    JOIN    prim p ON bu.primary_ledger_id = TO_CHAR(p.ledger_id)
    GROUP   BY p.ledger_id, bu.bu_id
),
-- inventory orgs of each primary ledger
led_io AS (
    SELECT  iod.set_of_books_id AS ledger_id, iod.organization_id,
            MAX(iod.organization_code) AS org_code,
            MAX(iod.organization_name) AS org_name,
            MAX(iod.business_unit_id)  AS bu_id
    FROM    inv_organization_definitions_v iod
    JOIN    prim p ON p.ledger_id = iod.set_of_books_id
    GROUP   BY iod.set_of_books_id, iod.organization_id
),
rows_all AS (
    -- A. every inventory org, with its BU and that BU's legal entity
    SELECT  io.ledger_id,
            TO_NUMBER(bu.bu_le_id_char)            AS legal_entity_id,
            io.bu_id,
            bu.bu_name,
            bu.bu_active,
            io.org_code || ' - ' || io.org_name    AS inventory_org
    FROM        led_io io
    LEFT JOIN   led_bu bu ON bu.ledger_id = io.ledger_id AND bu.bu_id = io.bu_id
    UNION ALL
    -- B. business units with no inventory org
    SELECT  bu.ledger_id, TO_NUMBER(bu.bu_le_id_char), bu.bu_id, bu.bu_name,
            bu.bu_active, CAST(NULL AS VARCHAR2(400))
    FROM    led_bu bu
    WHERE   NOT EXISTS ( SELECT 1 FROM led_io io
                         WHERE  io.ledger_id = bu.ledger_id
                         AND    io.bu_id     = bu.bu_id )
    UNION ALL
    -- C. legal entities of the ledger with no business unit
    SELECT  le.ledger_id, le.legal_entity_id, CAST(NULL AS NUMBER),
            CAST(NULL AS VARCHAR2(240)), CAST(NULL AS VARCHAR2(1)),
            CAST(NULL AS VARCHAR2(400))
    FROM    led_le le
    WHERE   NOT EXISTS ( SELECT 1 FROM led_bu bu
                         WHERE  bu.ledger_id     = le.ledger_id
                         AND    bu.bu_le_id_char = TO_CHAR(le.legal_entity_id) )
)
SELECT
    p.ledger_name                                             AS "Ledger",
    p.currency_code                                           AS "Currency",
    NVL(rc.currencies, '-')                                   AS "Reporting Currency",
    p.period_set_name                                         AS "Calendar",
    NVL(am.method_name, NVL(p.sla_accounting_method_code, '-'))
                                                              AS "Accounting Method",
    NVL(le.le_name, xep.name)                                 AS "Legal Entity",
    CASE WHEN le.legal_entity_id IS NOT NULL THEN 'Y'
         WHEN r.legal_entity_id  IS NULL     THEN '-'
         ELSE 'N' END                                         AS "LE on Ledger",
    NVL(bsv.bsvs, '-')                                        AS "Balancing Segment Values",
    NVL(r.bu_name, '-')                                       AS "Business Unit",
    NVL(r.bu_active, '-')                                     AS "BU Active",
    NVL(r.inventory_org, '-')                                 AS "Inventory Org"
FROM        rows_all            r
JOIN        prim                p   ON p.ledger_id  = r.ledger_id
LEFT JOIN   led_le              le  ON le.ledger_id = r.ledger_id
                                   AND le.legal_entity_id = r.legal_entity_id
LEFT JOIN   xle_entity_profiles xep ON xep.legal_entity_id = r.legal_entity_id
LEFT JOIN   le_bsv              bsv ON bsv.ledger_id = r.ledger_id
                                   AND bsv.legal_entity_id = r.legal_entity_id
LEFT JOIN   rep_cur             rc  ON rc.primary_ledger_id = r.ledger_id
LEFT JOIN   acct_method         am  ON am.accounting_method_code      = p.sla_accounting_method_code
                                   AND am.accounting_method_type_code = p.sla_accounting_method_type
ORDER BY
    p.ledger_name,
    NVL(le.le_name, xep.name),
    r.bu_name,
    r.inventory_org
