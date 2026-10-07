-- ============================================================================
--  V0_2  VERIFY SECOND - data rules behind Sections 0, 1 and 2
--  Run AFTER V0_1 shows no *** MISSING *** row. Bind :p_ledger_id to the
--  primary ledger you will report on (use 00_find_ledger_id.sql).
--
--  Each block answers one question that would otherwise make a published
--  number silently wrong. Paste the whole grid back.
--
--    A  What STATUS values does FUN_ALL_BUSINESS_UNITS_V hold? F0/F1/F2.1
--       treat a BU as active unless STATUS is 'I' / 'INACTIVE'.
--    B  BUs of the ledger: active vs all -> the F0 "Business Units" card.
--    C  Does XLE_LE_OU_LEDGER_V fan out? (the Fusion draft used it; on EBS
--       the same view is an LE x OU cross product - the 234-row bug)
--    D  Inventory orgs of the ledger: Oracle's SET_OF_BOOKS_ID rule (used by
--       Phase 2) vs the draft's PROFIT_CENTER_BU_ID rule. A gap means the two
--       rules disagree and the difference must be explained before publishing.
--    E  COA value rows: storage rows vs distinct (value set, parent, value),
--       and the SANDBOX_ID spread - any gap means duplicate storage rows,
--       which F2.2 already de-duplicates.
--    F  Which value-attribute CODE lives in which FLEX_VALUE_ATTRIBUTEn column
--       (drives Account Type / Allow Posting / Allow Budgeting in F2.2 detail)
--    G  Is EGP_STRUCTURES_B.PK2_VALUE really the organization id? (F1 BOM row)
--    H  Segment qualifiers on the ledger's COA, and the balancing segment
--       column GL_LEDGERS reports - they must name the same segment.
--    I  Order Management: header rows vs distinct orders (revision copies?)
--    J  GL_LEDGER_LE_V: rows vs distinct legal entities (location fan-out)
--
--  Pure SELECT, one statement, every aggregate in its own CTE.
-- ============================================================================
WITH
params AS (
    SELECT :p_ledger_id AS p_ledger_id
    FROM   dual
),
led_bu AS (
    SELECT  bu.bu_id,
            MAX(CASE WHEN NVL(UPPER(bu.status), 'A') NOT IN ('I', 'INACTIVE')
                     THEN 'Y' ELSE 'N' END) AS active_flag
    FROM    fun_all_business_units_v bu
    CROSS   JOIN params p
    WHERE   bu.primary_ledger_id = TRIM(p.p_ledger_id)
    GROUP   BY bu.bu_id
),
-- A
a_list AS (
    SELECT  LISTAGG(st || '=' || n, ', ') WITHIN GROUP (ORDER BY st) AS v
    FROM  ( SELECT NVL(bu.status, '(null)') AS st, COUNT(*) AS n
            FROM   fun_all_business_units_v bu
            GROUP  BY NVL(bu.status, '(null)') )
),
-- B
b_cnt AS (
    SELECT  SUM(CASE WHEN active_flag = 'Y' THEN 1 ELSE 0 END) AS active_n,
            COUNT(*)                                     AS all_n
    FROM    led_bu
),
-- C
c_rows AS (
    SELECT  COUNT(*) AS n
    FROM    xle_le_ou_ledger_v x
    CROSS   JOIN params p
    WHERE   x.ledger_id = TO_NUMBER(p.p_ledger_id)
),
c_ou AS (
    SELECT  COUNT(*) AS n
    FROM  ( SELECT x.operating_unit_id
            FROM   xle_le_ou_ledger_v x
            CROSS  JOIN params p
            WHERE  x.ledger_id = TO_NUMBER(p.p_ledger_id)
            GROUP  BY x.operating_unit_id )
),
c_le AS (
    SELECT  COUNT(*) AS n
    FROM  ( SELECT x.legal_entity_id
            FROM   xle_le_ou_ledger_v x
            CROSS  JOIN params p
            WHERE  x.ledger_id = TO_NUMBER(p.p_ledger_id)
            GROUP  BY x.legal_entity_id )
),
-- D
d_sob AS (
    SELECT  COUNT(*) AS n
    FROM  ( SELECT iod.organization_id
            FROM   inv_organization_definitions_v iod
            CROSS  JOIN params p
            WHERE  iod.set_of_books_id = TO_NUMBER(p.p_ledger_id)
            GROUP  BY iod.organization_id )
),
d_pc AS (
    SELECT  COUNT(*) AS n
    FROM  ( SELECT iop.organization_id
            FROM   inv_org_parameters iop
            JOIN   led_bu b ON b.bu_id = iop.profit_center_bu_id AND b.active_flag = 'Y'
            GROUP  BY iop.organization_id )
),
-- E
e_vs AS (
    SELECT  fs.flex_value_set_id
    FROM    fnd_id_flex_segments_vl fs
    JOIN    gl_ledgers gl ON gl.chart_of_accounts_id = fs.id_flex_num
    CROSS   JOIN params p
    WHERE   gl.ledger_id      = TO_NUMBER(p.p_ledger_id)
    AND     fs.application_id = 101
    AND     fs.id_flex_code   = 'GL#'
    AND     fs.enabled_flag   = 'Y'
    GROUP   BY fs.flex_value_set_id
),
e_rows AS (
    SELECT  COUNT(*) AS n
    FROM    fnd_vs_values_b v
    JOIN    e_vs s ON s.flex_value_set_id = v.value_set_id
    WHERE   v.enabled_flag = 'Y'
),
e_keys AS (
    SELECT  COUNT(*) AS n
    FROM  ( SELECT v.value_set_id, v.independent_value, v.value
            FROM   fnd_vs_values_b v
            JOIN   e_vs s ON s.flex_value_set_id = v.value_set_id
            WHERE  v.enabled_flag = 'Y'
            GROUP  BY v.value_set_id, v.independent_value, v.value )
),
e_sb AS (
    SELECT  LISTAGG(sb || '=' || n, ', ' ON OVERFLOW TRUNCATE)
                WITHIN GROUP (ORDER BY sb) AS v
    FROM  ( SELECT NVL(v.sandbox_id, '(null)') AS sb, COUNT(*) AS n
            FROM   fnd_vs_values_b v
            JOIN   e_vs s ON s.flex_value_set_id = v.value_set_id
            GROUP  BY NVL(v.sandbox_id, '(null)') )
),
-- F
f_codes AS (
    SELECT  LISTAGG(code || ' -> ' || col, ', ' ON OVERFLOW TRUNCATE)
                WITHIN GROUP (ORDER BY code, col) AS v
    FROM  ( SELECT va.value_attribute_code AS code, va.value_table_column_name AS col
            FROM   fnd_vs_kf_value_attrs va
            JOIN   e_vs s ON s.flex_value_set_id = va.value_set_id
            WHERE  va.application_id     = 101
            AND    va.key_flexfield_code = 'GL#'
            GROUP  BY va.value_attribute_code, va.value_table_column_name )
),
-- G
g_all AS (
    SELECT COUNT(*) AS n FROM egp_structures_b
),
g_any_org AS (
    SELECT  COUNT(*) AS n
    FROM    egp_structures_b es
    WHERE   EXISTS ( SELECT 1 FROM inv_organization_definitions_v iod
                     WHERE  TO_CHAR(iod.organization_id) = es.pk2_value )
),
g_led_org AS (
    SELECT  COUNT(*) AS n
    FROM    egp_structures_b es
    CROSS   JOIN params p
    WHERE   EXISTS ( SELECT 1 FROM inv_organization_definitions_v iod
                     WHERE  TO_CHAR(iod.organization_id) = es.pk2_value
                     AND    iod.set_of_books_id = TO_NUMBER(p.p_ledger_id) )
),
-- H
h_quals AS (
    SELECT  LISTAGG(t || '=' || n, ', ' ON OVERFLOW TRUNCATE)
                WITHIN GROUP (ORDER BY t) AS v
    FROM  ( SELECT sav.segment_attribute_type AS t, COUNT(*) AS n
            FROM   fnd_segment_attribute_values sav
            JOIN   gl_ledgers gl ON gl.chart_of_accounts_id = sav.id_flex_num
            CROSS  JOIN params p
            WHERE  gl.ledger_id        = TO_NUMBER(p.p_ledger_id)
            AND    sav.application_id  = 101
            AND    sav.id_flex_code    = 'GL#'
            AND    NVL(sav.attribute_value, 'N') <> 'N'
            GROUP  BY sav.segment_attribute_type )
),
h_bal AS (
    SELECT  MAX(gl.bal_seg_column_name) AS ledger_bal_col,
            MAX(sq.bal_col)             AS label_bal_col
    FROM    gl_ledgers gl
    CROSS   JOIN params p
    LEFT JOIN ( SELECT sav.id_flex_num,
                       MAX(sav.application_column_name) AS bal_col
                FROM   fnd_segment_attribute_values sav
                WHERE  sav.application_id         = 101
                AND    sav.id_flex_code           = 'GL#'
                AND    sav.segment_attribute_type = 'GL_BALANCING'
                AND    NVL(sav.attribute_value, 'N') <> 'N'
                GROUP  BY sav.id_flex_num ) sq
           ON  sq.id_flex_num = gl.chart_of_accounts_id
    WHERE   gl.ledger_id = TO_NUMBER(p.p_ledger_id)
),
-- I
i_rows AS (
    SELECT  COUNT(*) AS n
    FROM    doo_headers_all dh
    JOIN    led_bu b ON b.bu_id = dh.org_id
    WHERE   dh.ordered_date >= TRUNC(SYSDATE) - 90
),
i_keys AS (
    SELECT  COUNT(*) AS n
    FROM  ( SELECT dh.org_id, dh.order_number
            FROM   doo_headers_all dh
            JOIN   led_bu b ON b.bu_id = dh.org_id
            WHERE  dh.ordered_date >= TRUNC(SYSDATE) - 90
            GROUP  BY dh.org_id, dh.order_number )
),
-- J
j_rows AS (
    SELECT  COUNT(*) AS n
    FROM    gl_ledger_le_v v
    CROSS   JOIN params p
    WHERE   v.ledger_id = TO_NUMBER(p.p_ledger_id)
),
j_les AS (
    SELECT  COUNT(*) AS n
    FROM  ( SELECT v.legal_entity_id
            FROM   gl_ledger_le_v v
            CROSS  JOIN params p
            WHERE  v.ledger_id = TO_NUMBER(p.p_ledger_id)
            AND    v.legal_entity_id IS NOT NULL
            GROUP  BY v.legal_entity_id )
),
grid AS (
    SELECT 10 AS ord, 'A BU STATUS' AS section, 'values in FUN_ALL_BUSINESS_UNITS_V (pod)' AS item,
           NVL(a.v, '(no rows)') AS value
    FROM   a_list a
    UNION ALL
    SELECT 20, 'B BUs OF LEDGER', 'active (card 4) / all',
           TO_CHAR(NVL(b.active_n, 0)) || ' / ' || TO_CHAR(NVL(b.all_n, 0))
    FROM   b_cnt b
    UNION ALL
    SELECT 30, 'C XLE_LE_OU_LEDGER_V', 'rows / distinct OUs / distinct LEs',
           r.n || ' / ' || o.n || ' / ' || l.n ||
           CASE WHEN r.n > o.n AND r.n > l.n
                THEN '  -> FAN-OUT: rows exceed both; do NOT use this view as an OU map'
                ELSE '  -> no fan-out on this pod' END
    FROM   c_rows r, c_ou o, c_le l
    UNION ALL
    SELECT 40, 'D INV ORGS', 'SET_OF_BOOKS_ID rule / PROFIT_CENTER_BU rule',
           s.n || ' / ' || c.n ||
           CASE WHEN s.n = c.n THEN '  -> rules agree'
                ELSE '  -> RULES DISAGREE: explain before publishing 2.1 Inv Orgs' END
    FROM   d_sob s, d_pc c
    UNION ALL
    SELECT 50, 'E COA VALUES', 'enabled storage rows / distinct keys',
           r.n || ' / ' || k.n ||
           CASE WHEN r.n = k.n THEN '  -> no duplicates'
                ELSE '  -> DUPLICATE ROWS present (F2.2 de-duplicates them)' END
    FROM   e_rows r, e_keys k
    UNION ALL
    SELECT 51, 'E COA VALUES', 'SANDBOX_ID spread (all rows)', NVL(b.v, '(no rows)')
    FROM   e_sb b
    UNION ALL
    SELECT 60, 'F VALUE ATTRIBUTES', 'code -> FLEX_VALUE_ATTRIBUTEn', NVL(f.v, '(none)')
    FROM   f_codes f
    UNION ALL
    SELECT 70, 'G BOM PK2_VALUE', 'all rows / PK2 = any org / PK2 = org of ledger',
           a.n || ' / ' || o.n || ' / ' || l.n ||
           CASE WHEN a.n = 0         THEN '  -> no structures on this pod'
                WHEN o.n >= 0.9 * a.n THEN '  -> PK2_VALUE is the organization'
                ELSE '  -> PK2_VALUE is NOT the organization: F1 BOM row must change' END
    FROM   g_all a, g_any_org o, g_led_org l
    UNION ALL
    SELECT 80, 'H QUALIFIERS', 'segment_attribute_type = segments', NVL(h.v, '(none)')
    FROM   h_quals h
    UNION ALL
    SELECT 81, 'H QUALIFIERS', 'GL_LEDGERS.BAL_SEG_COLUMN_NAME / GL_BALANCING segment',
           NVL(b.ledger_bal_col, '(null)') || ' / ' || NVL(b.label_bal_col, '(null)') ||
           CASE WHEN b.ledger_bal_col = b.label_bal_col THEN '  -> agree'
                ELSE '  -> DISAGREE: qualifier source is wrong' END
    FROM   h_bal b
    UNION ALL
    SELECT 90, 'I DOO HEADERS', 'rows / distinct orders (last 90 days, ledger BUs)',
           r.n || ' / ' || k.n ||
           CASE WHEN r.n = k.n THEN '  -> one row per order'
                ELSE '  -> REVISION COPIES: count orders, not header rows, in 4.2' END
    FROM   i_rows r, i_keys k
    UNION ALL
    SELECT 100, 'J GL_LEDGER_LE_V', 'rows / distinct LEs (card 3 = second number)',
           r.n || ' / ' || l.n
    FROM   j_rows r, j_les l
)
SELECT ord, section, item, value
FROM   grid
ORDER  BY ord
