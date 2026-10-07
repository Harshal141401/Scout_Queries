-- ============================================================================
--  V6_0  QUICK CHECK - every table and column Section 6 reads (run FIRST)
--  Version   : 1.1 (2026-10-05)        Run log: 06_Run_Results/RUN_LOG.md
--  v1.1 adds PO_HEADERS_ALL.DOCUMENT_STATUS (F6.1 v1.2 now reads it, R024).
--       v1.0 ran as R020 (ALL OK); the column is in R020's own PO_HEADERS_ALL
--       list, so no re-run is needed.
--  For: F6.1_Data_Volume_Trends, F6.2_Master_Data, V6_1_Code_Values_Section_6
--
--  The list is GENERATED from the table.column references in those files
--  (07_Dev_Tools/colrefs.py), so it cannot miss a column they use:
--  18 objects / 51 columns. Already proven elsewhere on this pod: AP_INVOICES_ALL,
--  PO_HEADERS_ALL, RA_CUSTOMER_TRX_ALL (incl. COMPLETE_FLAG), GL_JE_HEADERS,
--  EGP_SYSTEM_ITEMS_B, POZ_SUPPLIER_SITES_ALL_M, CE_BANK_ACCOUNTS,
--  CE_BANK_ACCT_USES_ALL (R006), WIE_WORK_ORDERS_B (R004 ran F1). New here:
--  DOO_HEADERS_ALL order columns, POZ_SUPPLIERS, HZ_PARTIES, HZ_CUST_ACCOUNTS,
--  HZ_CUST_ACCT_SITES_ALL.
--
--  OUTPUT  ord | object_name | needed_columns | type_flags | visible_as | columns_present
--    needed_columns = 'ALL OK', '*** MISSING: <cols> ***' or '*** OBJECT NOT VISIBLE ***'
--    type_flags     = needed columns stored as NVARCHAR2 / NCHAR / NCLOB (ORA-12704)
--                     or CLOB / BLOB / LONG (cannot be grouped). '-' means none.
--    visible_as     = owner.type of every object with that name; a synonym-only
--                     object has its columns read from the synonym's target.
--  Every row must say ALL OK. Paste / export the grid back.
--  Metadata only (ALL_OBJECTS, ALL_SYNONYMS, ALL_TAB_COLUMNS) - it cannot fail
--  on a missing object. No binds. Pure SELECT. Nothing is written.
-- ============================================================================
WITH
need AS (
    SELECT  1 AS ord, 'DOO_HEADERS_ALL' AS tab, 'HEADER_ID' AS col FROM dual
    UNION ALL SELECT  1, 'DOO_HEADERS_ALL', 'ORDERED_DATE' FROM dual
    UNION ALL SELECT  1, 'DOO_HEADERS_ALL', 'ORDER_NUMBER' FROM dual
    UNION ALL SELECT  1, 'DOO_HEADERS_ALL', 'ORG_ID' FROM dual
    UNION ALL SELECT  1, 'DOO_HEADERS_ALL', 'SOURCE_ORDER_SYSTEM' FROM dual
    UNION ALL SELECT  1, 'DOO_HEADERS_ALL', 'SUBMITTED_FLAG' FROM dual
    UNION ALL SELECT  2, 'PO_HEADERS_ALL', 'BILLTO_BU_ID' FROM dual
    UNION ALL SELECT  2, 'PO_HEADERS_ALL', 'CANCEL_FLAG' FROM dual
    UNION ALL SELECT  2, 'PO_HEADERS_ALL', 'CREATION_DATE' FROM dual
    UNION ALL SELECT  2, 'PO_HEADERS_ALL', 'DOCUMENT_STATUS' FROM dual
    UNION ALL SELECT  2, 'PO_HEADERS_ALL', 'PRC_BU_ID' FROM dual
    UNION ALL SELECT  2, 'PO_HEADERS_ALL', 'REQ_BU_ID' FROM dual
    UNION ALL SELECT  2, 'PO_HEADERS_ALL', 'TYPE_LOOKUP_CODE' FROM dual
    UNION ALL SELECT  3, 'WIE_WORK_ORDERS_B', 'CREATION_DATE' FROM dual
    UNION ALL SELECT  3, 'WIE_WORK_ORDERS_B', 'ORGANIZATION_ID' FROM dual
    UNION ALL SELECT  4, 'RA_CUSTOMER_TRX_ALL', 'COMPLETE_FLAG' FROM dual
    UNION ALL SELECT  4, 'RA_CUSTOMER_TRX_ALL', 'ORG_ID' FROM dual
    UNION ALL SELECT  4, 'RA_CUSTOMER_TRX_ALL', 'TRX_DATE' FROM dual
    UNION ALL SELECT  5, 'AP_INVOICES_ALL', 'CANCELLED_DATE' FROM dual
    UNION ALL SELECT  5, 'AP_INVOICES_ALL', 'INVOICE_DATE' FROM dual
    UNION ALL SELECT  5, 'AP_INVOICES_ALL', 'ORG_ID' FROM dual
    UNION ALL SELECT  6, 'GL_JE_HEADERS', 'CREATION_DATE' FROM dual
    UNION ALL SELECT  6, 'GL_JE_HEADERS', 'LEDGER_ID' FROM dual
    UNION ALL SELECT  6, 'GL_JE_HEADERS', 'STATUS' FROM dual
    UNION ALL SELECT  7, 'POZ_SUPPLIERS', 'END_DATE_ACTIVE' FROM dual
    UNION ALL SELECT  8, 'POZ_SUPPLIER_SITES_ALL_M', 'INACTIVE_DATE' FROM dual
    UNION ALL SELECT  8, 'POZ_SUPPLIER_SITES_ALL_M', 'VENDOR_SITE_ID' FROM dual
    UNION ALL SELECT  9, 'HZ_PARTIES', 'PARTY_ID' FROM dual
    UNION ALL SELECT  9, 'HZ_PARTIES', 'STATUS' FROM dual
    UNION ALL SELECT 10, 'HZ_CUST_ACCOUNTS', 'PARTY_ID' FROM dual
    UNION ALL SELECT 10, 'HZ_CUST_ACCOUNTS', 'STATUS' FROM dual
    UNION ALL SELECT 11, 'HZ_CUST_ACCT_SITES_ALL', 'CUST_ACCT_SITE_ID' FROM dual
    UNION ALL SELECT 11, 'HZ_CUST_ACCT_SITES_ALL', 'STATUS' FROM dual
    UNION ALL SELECT 12, 'EGP_SYSTEM_ITEMS_B', 'ENABLED_FLAG' FROM dual
    UNION ALL SELECT 12, 'EGP_SYSTEM_ITEMS_B', 'INVENTORY_ITEM_ID' FROM dual
    UNION ALL SELECT 12, 'EGP_SYSTEM_ITEMS_B', 'TEMPLATE_ITEM_FLAG' FROM dual
    UNION ALL SELECT 13, 'CE_BANK_ACCOUNTS', 'ACCOUNT_CLASSIFICATION' FROM dual
    UNION ALL SELECT 13, 'CE_BANK_ACCOUNTS', 'BANK_ACCOUNT_ID' FROM dual
    UNION ALL SELECT 13, 'CE_BANK_ACCOUNTS', 'END_DATE' FROM dual
    UNION ALL SELECT 14, 'CE_BANK_ACCT_USES_ALL', 'BANK_ACCOUNT_ID' FROM dual
    UNION ALL SELECT 14, 'CE_BANK_ACCT_USES_ALL', 'ORG_ID' FROM dual
    UNION ALL SELECT 15, 'GL_LEDGERS', 'COMPLETE_FLAG' FROM dual
    UNION ALL SELECT 15, 'GL_LEDGERS', 'LEDGER_ID' FROM dual
    UNION ALL SELECT 15, 'GL_LEDGERS', 'OBJECT_TYPE_CODE' FROM dual
    UNION ALL SELECT 16, 'FUN_ALL_BUSINESS_UNITS_V', 'BU_ID' FROM dual
    UNION ALL SELECT 16, 'FUN_ALL_BUSINESS_UNITS_V', 'PRIMARY_LEDGER_ID' FROM dual
    UNION ALL SELECT 16, 'FUN_ALL_BUSINESS_UNITS_V', 'STATUS' FROM dual
    UNION ALL SELECT 17, 'INV_ORGANIZATION_DEFINITIONS_V', 'ORGANIZATION_ID' FROM dual
    UNION ALL SELECT 17, 'INV_ORGANIZATION_DEFINITIONS_V', 'SET_OF_BOOKS_ID' FROM dual
    UNION ALL SELECT 18, 'FA_BOOK_CONTROLS', 'BOOK_TYPE_CODE' FROM dual
    UNION ALL SELECT 18, 'FA_BOOK_CONTROLS', 'SET_OF_BOOKS_ID' FROM dual
),
need_tab AS (
    SELECT n.ord, n.tab FROM need n GROUP BY n.ord, n.tab
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
)
SELECT  g.ord              AS ord,
        g.object_name      AS object_name,
        g.needed_columns   AS needed_columns,
        g.type_flags       AS type_flags,
        g.visible_as       AS visible_as,
        g.columns_present  AS columns_present
FROM    grid g
ORDER BY g.ord
