-- ============================================================================
--  V5_0  QUICK CHECK - every table and column Section 5 reads (run FIRST)
--  Version   : 1.5 (2026-10-05)        Run log: 06_Run_Results/RUN_LOG.md
--              v1.5: list regenerated for the FINAL Section 5 set after the user
--              kept only the 5 CEMLI cards (F5.1 v2.0): F5.1, F5.2, F5.2b and the
--              checks still to run (V5_3, V5_4) - 12 objects / 37 columns.
--              V5_1 / V5_5 already ran (R017 / R019) and are not listed.
--              NO RE-RUN NEEDED: every column except ESS was printed by R016;
--              ESS is settled by V5_2a / V5_2b.
--              v1.4: adds XLA_JE_RULE_SETS_B (APPLICATION_ID, JERS_CODE,
--              JERS_TYPE_CODE), read by the FINAL F5.1 v1.4 row 61. Doc-verified
--              (26a page, 26 columns = the 26 R019 saw), but not yet proven on the
--              pod: RUN THIS ONCE before F5.1 v1.4 - ord 1 must say ALL OK.
--              23 objects / 87 columns. Rows 2-3 (ESS) will still read NOT
--              VISIBLE (R016); that does not block F5.1.
--              v1.3: list regenerated to include V5_5 and F5.1 v1.3: 22 objects /
--              83 columns. Still NO RE-RUN NEEDED on the R016 pod (every column
--              was printed by R016).
--              v1.2: list regenerated for F5.1 v1.2, V5_1 v1.2, V5_3 and V5_4:
--              22 objects / 74 columns (adds HRC_ALERTS_B, the sandbox tables and
--              the MDS views). NO RE-RUN NEEDED on the R016 pod: R016 printed
--              every one of these columns (block A ALL OK, block C lists); keep
--              it for other pods. ESS rows 1-2 read NOT VISIBLE on R016 - that
--              is what V5_2a / V5_2b settle.
--              v1.1: follows F5.1 v1.1 (Fusion customization inventory): 15
--              objects / 46 columns. ALL_OBJECTS dropped (no database rows any
--              more); BI catalog, roles, approval rules, lookups, value sets and
--              Subledger Accounting tables added.
--  For: F5.1_Extensions_Summary, F5.2_Custom_Scheduled_Processes,
--       F5.2_ESS_History_Coverage, V5_1, V5_3, V5_4, V5_5
--
--  WHY THIS MATTERS MORE THAN USUAL
--    ESS_REQUEST_HISTORY / ESS_REQUEST_PROPERTY are not in Oracle's Tables and
--    Views guides (the doc pages do not load), so their columns are proven
--    here, on the pod, before any Section 5 query uses them. The column names
--    come from published working queries, not from Oracle documentation.
--
--  Block A (ord 1-12) the objects the Section 5 queries read. The list is
--    GENERATED from the table.column references in the three F5 files and
--    V5_1 / V5_3 / V5_4 / V5_5 (07_Dev_Tools/colrefs.py), so it cannot miss a column.
--    Doc-verified: GL_FRC_REPORTS_B, POR_AMX_RULES, FND_VS_VALUE_SETS;
--    pod-verified by R006: FND_DF_SEGMENTS_B. The rest (ESS_*, PER_ROLES_DN,
--    FND_LOOKUP_TYPES, XLA_ACCTG_METHODS_B, XLA_PRODUCT_RULES_B) have no
--    loadable doc page, so THIS check is their proof.
--      needed_columns = 'ALL OK', '*** MISSING: <cols> ***' or
--                       '*** OBJECT NOT VISIBLE ***'
--      type_flags     = any needed column stored as NVARCHAR2 / NCHAR / NCLOB
--                       (ORA-12704 class) or CLOB / BLOB / LONG (cannot be
--                       grouped: ORA-00932). '-' means none.
--      visible_as     = owner.type of every object with that name, so a
--                       synonym-only object is visible here. Its columns are
--                       then read from the synonym's target.
--  Block B (ord 50)   how many candidate objects block C found.
--  Block C (ord 51+)  CANDIDATES (v1.0/v1.1 wording; the objects R016 found are now in block A), not used by any query yet: visible tables /
--    views / synonyms named ESS_*, MDS_*, HRC_ALERT* or *SANDBOX* (e.g.
--    ADF_SB_SANDBOX). They decide whether F5.1 rows 70 (Alerts Composer) and
--    80 (Sandboxes) can be measured with SQL at all. Up to 60 listed.
--
--  Every block A row must say ALL OK. Paste / export the whole grid back.
--  Metadata only (ALL_OBJECTS, ALL_SYNONYMS, ALL_TAB_COLUMNS) - it cannot
--  fail on a missing object. No binds. Pure SELECT. Nothing is written.
-- ============================================================================
WITH
need AS (
    SELECT  1 AS ord, 'ESS_REQUEST_HISTORY' AS tab, 'APPLICATION' AS col FROM dual
    UNION ALL SELECT  1, 'ESS_REQUEST_HISTORY', 'DEFINITION' FROM dual
    UNION ALL SELECT  1, 'ESS_REQUEST_HISTORY', 'NAME' FROM dual
    UNION ALL SELECT  1, 'ESS_REQUEST_HISTORY', 'PROCESSSTART' FROM dual
    UNION ALL SELECT  1, 'ESS_REQUEST_HISTORY', 'REQUESTID' FROM dual
    UNION ALL SELECT  2, 'ESS_REQUEST_PROPERTY', 'NAME' FROM dual
    UNION ALL SELECT  2, 'ESS_REQUEST_PROPERTY', 'REQUESTID' FROM dual
    UNION ALL SELECT  2, 'ESS_REQUEST_PROPERTY', 'VALUE' FROM dual
    UNION ALL SELECT  3, 'GL_FRC_REPORTS_B', 'BIP_REPORT_JOB_DEFINITION' FROM dual
    UNION ALL SELECT  3, 'GL_FRC_REPORTS_B', 'REPORT_PATH' FROM dual
    UNION ALL SELECT  3, 'GL_FRC_REPORTS_B', 'REPORT_TYPE_CODE' FROM dual
    UNION ALL SELECT  4, 'POR_AMX_RULES', 'ACTIVE_FLAG' FROM dual
    UNION ALL SELECT  4, 'POR_AMX_RULES', 'DISPLAY_RULE_NAME' FROM dual
    UNION ALL SELECT  4, 'POR_AMX_RULES', 'SANDBOX_FLAG' FROM dual
    UNION ALL SELECT  5, 'MDS_PATHS', 'PATH_DOC_ELEM_NAME' FROM dual
    UNION ALL SELECT  5, 'MDS_PATHS', 'PATH_FULLNAME' FROM dual
    UNION ALL SELECT  5, 'MDS_PATHS', 'PATH_HIGH_CN' FROM dual
    UNION ALL SELECT  5, 'MDS_PATHS', 'PATH_LOW_CN' FROM dual
    UNION ALL SELECT  5, 'MDS_PATHS', 'PATH_OPERATION' FROM dual
    UNION ALL SELECT  5, 'MDS_PATHS', 'PATH_PARTITION_ID' FROM dual
    UNION ALL SELECT  5, 'MDS_PATHS', 'PATH_TYPE' FROM dual
    UNION ALL SELECT  6, 'MDS_PARTITIONS', 'PARTITION_ID' FROM dual
    UNION ALL SELECT  6, 'MDS_PARTITIONS', 'PARTITION_NAME' FROM dual
    UNION ALL SELECT  7, 'MDS_TRANSACTIONS', 'TXN_CN' FROM dual
    UNION ALL SELECT  7, 'MDS_TRANSACTIONS', 'TXN_CREATOR' FROM dual
    UNION ALL SELECT  7, 'MDS_TRANSACTIONS', 'TXN_PARTITION_ID' FROM dual
    UNION ALL SELECT  8, 'PER_USERS', 'USERNAME' FROM dual
    UNION ALL SELECT  9, 'GL_LEDGERS', 'COMPLETE_FLAG' FROM dual
    UNION ALL SELECT  9, 'GL_LEDGERS', 'LEDGER_ID' FROM dual
    UNION ALL SELECT  9, 'GL_LEDGERS', 'OBJECT_TYPE_CODE' FROM dual
    UNION ALL SELECT 10, 'FUN_ALL_BUSINESS_UNITS_V', 'BU_ID' FROM dual
    UNION ALL SELECT 10, 'FUN_ALL_BUSINESS_UNITS_V', 'PRIMARY_LEDGER_ID' FROM dual
    UNION ALL SELECT 10, 'FUN_ALL_BUSINESS_UNITS_V', 'STATUS' FROM dual
    UNION ALL SELECT 11, 'INV_ORGANIZATION_DEFINITIONS_V', 'ORGANIZATION_ID' FROM dual
    UNION ALL SELECT 11, 'INV_ORGANIZATION_DEFINITIONS_V', 'SET_OF_BOOKS_ID' FROM dual
    UNION ALL SELECT 12, 'FA_BOOK_CONTROLS', 'BOOK_TYPE_CODE' FROM dual
    UNION ALL SELECT 12, 'FA_BOOK_CONTROLS', 'SET_OF_BOOKS_ID' FROM dual
),
need_tab AS (
    SELECT n.ord, n.tab FROM need n GROUP BY n.ord, n.tab
),
-- ---- block C candidates: decide whether F5.1 rows 2-4 can ever be measured
cand_obj AS (
    SELECT o.object_name AS tab,
           LISTAGG(o.owner || '.' || o.object_type, ', ')
               WITHIN GROUP (ORDER BY o.owner, o.object_type)   AS visible_as
    FROM   all_objects o
    WHERE  o.object_type IN ('TABLE', 'VIEW', 'SYNONYM')
    AND    REGEXP_LIKE(o.object_name, '^(ESS_|MDS_|HRC_ALERT)|SANDBOX')
    AND    o.object_name NOT IN ( SELECT n.tab FROM need_tab n )
    GROUP  BY o.object_name
),
need_obj AS (
    SELECT o.object_name AS tab,
           LISTAGG(o.owner || '.' || o.object_type, ', ')
               WITHIN GROUP (ORDER BY o.owner, o.object_type)   AS visible_as
    FROM   all_objects o
    WHERE  o.object_name IN ( SELECT n.tab FROM need_tab n )
    GROUP  BY o.object_name
),
all_names AS (
    SELECT n.tab FROM need_tab n
    UNION ALL
    SELECT c.tab FROM cand_obj c
),
-- a name that is only a synonym has its columns under the synonym's target
syn AS (
    SELECT s.synonym_name,
           MAX(s.table_name)                         AS target_tab,
           MAX(s.table_owner || '.' || s.table_name) AS target_full
    FROM   all_synonyms s
    WHERE  s.synonym_name IN ( SELECT a.tab FROM all_names a )
    GROUP  BY s.synonym_name
),
cols AS (
    SELECT c.table_name, c.column_name, MAX(c.data_type) AS data_type
    FROM   all_tab_columns c
    WHERE  c.table_name IN ( SELECT a.tab FROM all_names a )
    OR     c.table_name IN ( SELECT s.target_tab FROM syn s )
    GROUP  BY c.table_name, c.column_name
),
tab_has AS (
    SELECT c.table_name FROM cols c GROUP BY c.table_name
),
resolved AS (
    SELECT a.tab,
           CASE WHEN th.table_name IS NOT NULL THEN a.tab ELSE s.target_tab END AS col_tab,
           s.target_full
    FROM        all_names a
    LEFT JOIN   tab_has   th ON th.table_name   = a.tab
    LEFT JOIN   syn       s  ON s.synonym_name  = a.tab
),
need_check AS (
    SELECT  n.ord, n.tab,
            LISTAGG(CASE WHEN c.column_name IS NULL THEN n.col END, ', ')
                WITHIN GROUP (ORDER BY n.col)                 AS missing,
            LISTAGG(CASE WHEN c.data_type IN ('NVARCHAR2', 'NCHAR', 'NCLOB',
                                              'CLOB', 'BLOB', 'LONG')
                         THEN n.col || ' ' || c.data_type END, ', ')
                WITHIN GROUP (ORDER BY n.col)                 AS type_flags
    FROM        need     n
    JOIN        resolved r ON r.tab = n.tab
    LEFT JOIN   cols     c ON c.table_name = r.col_tab AND c.column_name = n.col
    GROUP   BY  n.ord, n.tab
),
col_lists AS (
    SELECT  c.table_name,
            LISTAGG(c.column_name, ' ' ON OVERFLOW TRUNCATE)
                WITHIN GROUP (ORDER BY c.column_name)         AS col_list
    FROM    cols c
    GROUP   BY c.table_name
),
cand_cnt AS (
    SELECT COUNT(*) AS n FROM cand_obj
),
cand_rows AS (
    SELECT c.tab, c.visible_as,
           ROW_NUMBER() OVER (ORDER BY CASE WHEN c.tab LIKE 'HRC%' THEN 0
                                            WHEN c.tab LIKE 'ESS%' THEN 1
                                            WHEN c.tab LIKE 'MDS%' THEN 2
                                            ELSE 3 END,
                                       c.tab)                 AS rn
    FROM   cand_obj c
),
grid AS (
    SELECT  nc.ord                                                    AS ord,
            CAST(nc.tab AS VARCHAR2(400))                             AS object_name,
            CAST(CASE WHEN r.col_tab IS NULL OR cl.table_name IS NULL
                      THEN '*** OBJECT NOT VISIBLE ***'
                      WHEN nc.missing IS NULL THEN 'ALL OK'
                      ELSE '*** MISSING: ' || nc.missing || ' ***'
                 END AS VARCHAR2(4000))                               AS needed_columns,
            CAST(NVL(nc.type_flags, '-') AS VARCHAR2(4000))           AS type_flags,
            CAST(NVL(nob.visible_as, '-')
                 || CASE WHEN r.col_tab <> nc.tab
                         THEN ' (columns read from ' || r.target_full || ')' END
                 AS VARCHAR2(4000))                                   AS visible_as,
            CAST(NVL(cl.col_list, '-') AS VARCHAR2(4000))             AS columns_present
    FROM        need_check nc
    JOIN        resolved   r  ON r.tab  = nc.tab
    LEFT JOIN   need_obj   nob ON nob.tab = nc.tab
    LEFT JOIN   col_lists  cl ON cl.table_name = r.col_tab
    UNION ALL
    SELECT  50,
            TO_CHAR('CANDIDATES'),
            TO_CHAR('INFO: ' || cc.n || ' candidate object(s) visible (ESS_*, MDS_*, HRC_ALERT*,'
                    || ' *SANDBOX*); up to 60 listed below. 0 = none of them can be read with SQL.'),
            TO_CHAR('-'),
            TO_CHAR('-'),
            TO_CHAR('-')
    FROM    cand_cnt cc
    UNION ALL
    SELECT  50 + cr.rn,
            TO_CHAR(cr.tab),
            TO_CHAR('CANDIDATE: not used by any query yet'),
            TO_CHAR('-'),
            TO_CHAR(cr.visible_as
                    || CASE WHEN r.col_tab <> cr.tab
                            THEN ' (columns read from ' || r.target_full || ')' END),
            TO_CHAR(NVL(cl.col_list, '-'))
    FROM        cand_rows  cr
    JOIN        resolved   r  ON r.tab = cr.tab
    LEFT JOIN   col_lists  cl ON cl.table_name = r.col_tab
    WHERE       cr.rn <= 60
)
SELECT  g.ord              AS ord,
        g.object_name      AS object_name,
        g.needed_columns   AS needed_columns,
        g.type_flags       AS type_flags,
        g.visible_as       AS visible_as,
        g.columns_present  AS columns_present
FROM    grid g
ORDER BY g.ord
