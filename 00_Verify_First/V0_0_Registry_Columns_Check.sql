-- ============================================================================
--  V0_0  QUICK CHECK - Fusion application registry columns (run FIRST)
--  F0, F1, F1.2 and V0_3 read module names from the registry:
--      FND_TABLES.TABLE_NAME, FND_TABLES.APPLICATION_SHORT_NAME
--      FND_APPLICATION_VL.APPLICATION_SHORT_NAME, .APPLICATION_ID, .APPLICATION_NAME
--  This lists the real columns of those objects (and two neighbours) from the
--  data dictionary, so a wrong name is seen here instead of as ORA-00904.
--  Metadata only - it cannot fail on a missing object or column.
--
--  OUTPUT  object | needed columns OK? | every column the object really has
--  Paste the grid back. If row 1 or row 2 does not say ALL OK, do not run F1.
--  No binds. Pure SELECT. Nothing is written.
-- ============================================================================
WITH
cols AS (
    SELECT  table_name, column_name
    FROM    all_tab_columns
    WHERE   table_name IN ('FND_TABLES', 'FND_APPLICATION_VL', 'FND_APPLICATION',
                           'FND_APPLICATION_TL', 'FND_APPL_TAXONOMY_VL')
    GROUP   BY table_name, column_name
),
need AS (
    SELECT 1 AS ord, 'FND_TABLES' AS tab, 'TABLE_NAME' AS col FROM dual
    UNION ALL
    SELECT 1, 'FND_TABLES',         'APPLICATION_SHORT_NAME' FROM dual
    UNION ALL
    SELECT 2, 'FND_APPLICATION_VL', 'APPLICATION_SHORT_NAME' FROM dual
    UNION ALL
    SELECT 2, 'FND_APPLICATION_VL', 'APPLICATION_ID'         FROM dual
    UNION ALL
    SELECT 2, 'FND_APPLICATION_VL', 'APPLICATION_NAME'       FROM dual
),
need_check AS (
    SELECT  n.ord, n.tab,
            LISTAGG(CASE WHEN c.column_name IS NULL THEN n.col END, ', ')
                WITHIN GROUP (ORDER BY n.col)                 AS missing
    FROM        need n
    LEFT JOIN   cols c ON c.table_name = n.tab AND c.column_name = n.col
    GROUP   BY  n.ord, n.tab
),
all_cols AS (
    SELECT  table_name,
            LISTAGG(column_name, ' ' ON OVERFLOW TRUNCATE)
                WITHIN GROUP (ORDER BY column_name)           AS col_list
    FROM    cols
    GROUP   BY table_name
),
objs AS (
    SELECT 1 AS ord, 'FND_TABLES' AS tab FROM dual
    UNION ALL SELECT 2, 'FND_APPLICATION_VL'   FROM dual
    UNION ALL SELECT 3, 'FND_APPLICATION'      FROM dual
    UNION ALL SELECT 4, 'FND_APPLICATION_TL'   FROM dual
    UNION ALL SELECT 5, 'FND_APPL_TAXONOMY_VL' FROM dual
)
SELECT  o.ord                                               AS ord,
        o.tab                                               AS object_name,
        CASE WHEN a.table_name IS NULL THEN '*** OBJECT NOT VISIBLE ***'
             WHEN nc.ord IS NULL       THEN '(reference only)'
             WHEN nc.missing IS NULL   THEN 'ALL OK'
             ELSE '*** MISSING: ' || nc.missing || ' ***'
        END                                                 AS needed_columns,
        NVL(a.col_list, '-')                                AS columns_present
FROM        objs       o
LEFT JOIN   all_cols   a  ON a.table_name = o.tab
LEFT JOIN   need_check nc ON nc.tab       = o.tab
ORDER BY    o.ord
