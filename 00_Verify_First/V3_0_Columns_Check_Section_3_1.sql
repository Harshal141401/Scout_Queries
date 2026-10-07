-- ============================================================================
--  V3_0  QUICK CHECK - every table and column Section 3.1 reads (run FIRST)
--  Version   : 1.0 (2026-10-05)        Run log: 06_Run_Results/RUN_LOG.md
--  For: F3.1_Setup_Area_by_Module.sql, F3.1_Asset_Books_By_Class.sql
--
--  Every name below was checked on the Oracle Fusion Tables and Views pages
--  (2026-10-05). This proves them on THIS pod, so a wrong or ungranted name
--  shows up here as a row instead of as ORA-00904 / ORA-00942 in F3.1.
--  Metadata only (ALL_TAB_COLUMNS) - it cannot fail on a missing object.
--
--  OUTPUT  ord | object_name | needed_columns | columns_present
--    needed_columns = 'ALL OK', '*** MISSING: <cols> ***' or
--                     '*** OBJECT NOT VISIBLE ***'
--  Every row must say ALL OK before F3.1 is run. Paste the grid back.
--  No binds. Pure SELECT. Nothing is written.
-- ============================================================================
WITH
need AS (
    SELECT  1 AS ord, 'AP_TERMS_B' AS tab, 'TERM_ID' AS col FROM dual
    UNION ALL SELECT  2, 'RA_TERMS_B',                'TERM_ID'                FROM dual
    UNION ALL SELECT  3, 'RA_CUST_TRX_TYPES_ALL',     'CUST_TRX_TYPE_ID'       FROM dual
    UNION ALL SELECT  3, 'RA_CUST_TRX_TYPES_ALL',     'SET_ID'                 FROM dual
    UNION ALL SELECT  4, 'RA_BATCH_SOURCES_ALL',      'BATCH_SOURCE_ID'        FROM dual
    UNION ALL SELECT  4, 'RA_BATCH_SOURCES_ALL',      'SET_ID'                 FROM dual
    UNION ALL SELECT  5, 'GL_JE_SOURCES_TL',          'JE_SOURCE_NAME'         FROM dual
    UNION ALL SELECT  5, 'GL_JE_SOURCES_TL',          'LANGUAGE'               FROM dual
    UNION ALL SELECT  6, 'GL_JE_CATEGORIES_TL',       'JE_CATEGORY_NAME'       FROM dual
    UNION ALL SELECT  6, 'GL_JE_CATEGORIES_TL',       'LANGUAGE'               FROM dual
    UNION ALL SELECT  7, 'PO_DOCUMENT_TYPES_ALL_B',   'DOCUMENT_TYPE_CODE'     FROM dual
    UNION ALL SELECT  7, 'PO_DOCUMENT_TYPES_ALL_B',   'PRC_BU_ID'              FROM dual
    UNION ALL SELECT  8, 'EGP_SYSTEM_ITEMS_B',        'INVENTORY_ITEM_ID'      FROM dual
    UNION ALL SELECT  8, 'EGP_SYSTEM_ITEMS_B',        'TEMPLATE_ITEM_FLAG'     FROM dual
    UNION ALL SELECT  9, 'INV_SECONDARY_INVENTORIES', 'SECONDARY_INVENTORY_NAME' FROM dual
    UNION ALL SELECT 10, 'CE_BANK_ACCOUNTS',          'BANK_ACCOUNT_ID'        FROM dual
    UNION ALL SELECT 10, 'CE_BANK_ACCOUNTS',          'ACCOUNT_CLASSIFICATION' FROM dual
    UNION ALL SELECT 10, 'CE_BANK_ACCOUNTS',          'END_DATE'               FROM dual
    UNION ALL SELECT 11, 'CE_BANK_ACCT_USES_ALL',     'BANK_ACCOUNT_ID'        FROM dual
    UNION ALL SELECT 11, 'CE_BANK_ACCT_USES_ALL',     'ORG_ID'                 FROM dual
    UNION ALL SELECT 12, 'CST_COST_BOOKS_B',          'COST_BOOK_ID'           FROM dual
    UNION ALL SELECT 13, 'FA_BOOK_CONTROLS',          'BOOK_TYPE_CODE'         FROM dual
    UNION ALL SELECT 13, 'FA_BOOK_CONTROLS',          'BOOK_CLASS'             FROM dual
    UNION ALL SELECT 13, 'FA_BOOK_CONTROLS',          'SET_OF_BOOKS_ID'        FROM dual
    UNION ALL SELECT 13, 'FA_BOOK_CONTROLS',          'DATE_INEFFECTIVE'       FROM dual
    UNION ALL SELECT 14, 'FUN_ALL_BUSINESS_UNITS_V',  'BU_ID'                  FROM dual
    UNION ALL SELECT 14, 'FUN_ALL_BUSINESS_UNITS_V',  'PRIMARY_LEDGER_ID'      FROM dual
    UNION ALL SELECT 14, 'FUN_ALL_BUSINESS_UNITS_V',  'STATUS'                 FROM dual
    UNION ALL SELECT 15, 'FND_TABLES',                'TABLE_NAME'             FROM dual
    UNION ALL SELECT 15, 'FND_TABLES',                'PHYSICAL_TABLE_NAME'    FROM dual
    UNION ALL SELECT 15, 'FND_TABLES',                'APPLICATION_SHORT_NAME' FROM dual
),
cols AS (
    SELECT  c.table_name, c.column_name
    FROM    all_tab_columns c
    WHERE   c.table_name IN ( SELECT n.tab FROM need n )
    GROUP   BY c.table_name, c.column_name
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
)
SELECT  nc.ord                                              AS ord,
        nc.tab                                              AS object_name,
        CASE WHEN a.table_name IS NULL THEN '*** OBJECT NOT VISIBLE ***'
             WHEN nc.missing IS NULL   THEN 'ALL OK'
             ELSE '*** MISSING: ' || nc.missing || ' ***'
        END                                                 AS needed_columns,
        NVL(a.col_list, '-')                                AS columns_present
FROM        need_check nc
LEFT JOIN   all_cols   a ON a.table_name = nc.tab
ORDER BY    nc.ord
