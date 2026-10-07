-- ============================================================================
--  V7_0  QUICK CHECK - every table and column Section 7 reads (run FIRST)
--  Version   : 1.3 (2026-10-05)        Run log: 06_Run_Results/RUN_LOG.md
--  v1.3 regenerated after R026 for F7.1 v1.3 / V7_1 v1.3: adds
--       POR_REQUISITION_LINES_ALL.TO_HEADER_ID (beyond the cut-off of R025's
--       column list, so NOT yet proven - this version must be run) and
--       LIFECYCLE_STATUS, INV_ONHAND_QUANTITIES_DETAIL.OWNING_ENTITY_ID (both in
--       R025's lists). v1.2 ran as R025: 18 / 18 ALL OK.
--  v1.2 regenerated for F7.1 v1.2's rows 9-10 (on-hand, open work orders):
--       adds INV_ONHAND_QUANTITIES_DETAIL and WIE_WO_STATUSES_B (NEW on this pod -
--       this version must be run), WIE_WORK_ORDERS_B, FND_LOOKUP_VALUES and
--       INV_ORGANIZATION_DEFINITIONS_V.BUSINESS_UNIT_ID (seen in R020 / R015).
--  v1.1 regenerated after F7.1 / V7_1 v1.1 (R024): adds the columns those now
--       read. v1.0 ran as R023 (14 / 14 ALL OK) and every added column appears in
--       R023's own column lists, so no re-run is needed.
--  For: F7.1_Open_Transactions, F7.1_WB_Open_Transactions_By_BU, V7_1_Code_Values_Section_7
--
--  The list is GENERATED from the table.column references in those files
--  (07_Dev_Tools/colrefs.py), so it cannot miss a column they use:
--  18 objects / 88 columns. Proven on this pod before: DOO_HEADERS_ALL,
--  PO_HEADERS_ALL, AP_INVOICES_ALL, RA_CUSTOMER_TRX_ALL, FUN_ALL_BUSINESS_UNITS_V
--  and the scope tables (R020 column lists), POR_REQUISITION_HEADERS_ALL.REQ_BU_ID
--  and POR_REQUISITION_LINES_ALL.PO_HEADER_ID (F4.1 ran, R015). Checked in Oracle's
--  table docs (25C / 25D / 26A) and new on this pod: the requisition and schedule
--  status columns, PO_LINE_LOCATIONS_ALL, AP_INVOICE_DISTRIBUTIONS_ALL,
--  AR_PAYMENT_SCHEDULES_ALL, AR_CASH_RECEIPTS_ALL.
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
    SELECT  1 AS ord, 'POR_REQUISITION_HEADERS_ALL' AS tab, 'DOCUMENT_STATUS' AS col FROM dual
    UNION ALL SELECT  1, 'POR_REQUISITION_HEADERS_ALL', 'INTERNAL_TRANSFER_REQ_FLAG' FROM dual
    UNION ALL SELECT  1, 'POR_REQUISITION_HEADERS_ALL', 'REQUISITION_HEADER_ID' FROM dual
    UNION ALL SELECT  1, 'POR_REQUISITION_HEADERS_ALL', 'REQ_BU_ID' FROM dual
    UNION ALL SELECT  2, 'POR_REQUISITION_LINES_ALL', 'CANCEL_FLAG' FROM dual
    UNION ALL SELECT  2, 'POR_REQUISITION_LINES_ALL', 'DESTINATION_TYPE_CODE' FROM dual
    UNION ALL SELECT  2, 'POR_REQUISITION_LINES_ALL', 'LIFECYCLE_STATUS' FROM dual
    UNION ALL SELECT  2, 'POR_REQUISITION_LINES_ALL', 'LINE_LOCATION_ID' FROM dual
    UNION ALL SELECT  2, 'POR_REQUISITION_LINES_ALL', 'LINE_STATUS' FROM dual
    UNION ALL SELECT  2, 'POR_REQUISITION_LINES_ALL', 'PO_HEADER_ID' FROM dual
    UNION ALL SELECT  2, 'POR_REQUISITION_LINES_ALL', 'REQUISITION_HEADER_ID' FROM dual
    UNION ALL SELECT  2, 'POR_REQUISITION_LINES_ALL', 'TO_HEADER_ID' FROM dual
    UNION ALL SELECT  3, 'PO_HEADERS_ALL', 'APPROVED_FLAG' FROM dual
    UNION ALL SELECT  3, 'PO_HEADERS_ALL', 'BILLTO_BU_ID' FROM dual
    UNION ALL SELECT  3, 'PO_HEADERS_ALL', 'CANCEL_FLAG' FROM dual
    UNION ALL SELECT  3, 'PO_HEADERS_ALL', 'DOCUMENT_STATUS' FROM dual
    UNION ALL SELECT  3, 'PO_HEADERS_ALL', 'PO_HEADER_ID' FROM dual
    UNION ALL SELECT  3, 'PO_HEADERS_ALL', 'PRC_BU_ID' FROM dual
    UNION ALL SELECT  3, 'PO_HEADERS_ALL', 'REQ_BU_ID' FROM dual
    UNION ALL SELECT  3, 'PO_HEADERS_ALL', 'TYPE_LOOKUP_CODE' FROM dual
    UNION ALL SELECT  4, 'PO_LINE_LOCATIONS_ALL', 'AMOUNT_BILLED' FROM dual
    UNION ALL SELECT  4, 'PO_LINE_LOCATIONS_ALL', 'AMOUNT_RECEIVED' FROM dual
    UNION ALL SELECT  4, 'PO_LINE_LOCATIONS_ALL', 'CANCEL_FLAG' FROM dual
    UNION ALL SELECT  4, 'PO_LINE_LOCATIONS_ALL', 'PO_HEADER_ID' FROM dual
    UNION ALL SELECT  4, 'PO_LINE_LOCATIONS_ALL', 'QUANTITY_BILLED' FROM dual
    UNION ALL SELECT  4, 'PO_LINE_LOCATIONS_ALL', 'QUANTITY_RECEIVED' FROM dual
    UNION ALL SELECT  4, 'PO_LINE_LOCATIONS_ALL', 'SCHEDULE_STATUS' FROM dual
    UNION ALL SELECT  5, 'AP_INVOICES_ALL', 'AMOUNT_PAID' FROM dual
    UNION ALL SELECT  5, 'AP_INVOICES_ALL', 'CANCELLED_AMOUNT' FROM dual
    UNION ALL SELECT  5, 'AP_INVOICES_ALL', 'CANCELLED_BY' FROM dual
    UNION ALL SELECT  5, 'AP_INVOICES_ALL', 'CANCELLED_DATE' FROM dual
    UNION ALL SELECT  5, 'AP_INVOICES_ALL', 'INVOICE_AMOUNT' FROM dual
    UNION ALL SELECT  5, 'AP_INVOICES_ALL', 'INVOICE_CURRENCY_CODE' FROM dual
    UNION ALL SELECT  5, 'AP_INVOICES_ALL', 'INVOICE_ID' FROM dual
    UNION ALL SELECT  5, 'AP_INVOICES_ALL', 'INVOICE_TYPE_LOOKUP_CODE' FROM dual
    UNION ALL SELECT  5, 'AP_INVOICES_ALL', 'ORG_ID' FROM dual
    UNION ALL SELECT  5, 'AP_INVOICES_ALL', 'PAYMENT_STATUS_FLAG' FROM dual
    UNION ALL SELECT  6, 'AP_INVOICE_DISTRIBUTIONS_ALL', 'INVOICE_DISTRIBUTION_ID' FROM dual
    UNION ALL SELECT  6, 'AP_INVOICE_DISTRIBUTIONS_ALL', 'INVOICE_ID' FROM dual
    UNION ALL SELECT  6, 'AP_INVOICE_DISTRIBUTIONS_ALL', 'PREPAY_DISTRIBUTION_ID' FROM dual
    UNION ALL SELECT  7, 'DOO_HEADERS_ALL', 'CANCELED_FLAG' FROM dual
    UNION ALL SELECT  7, 'DOO_HEADERS_ALL', 'HEADER_ID' FROM dual
    UNION ALL SELECT  7, 'DOO_HEADERS_ALL', 'OPEN_FLAG' FROM dual
    UNION ALL SELECT  7, 'DOO_HEADERS_ALL', 'ORDER_NUMBER' FROM dual
    UNION ALL SELECT  7, 'DOO_HEADERS_ALL', 'ORG_ID' FROM dual
    UNION ALL SELECT  7, 'DOO_HEADERS_ALL', 'SOURCE_ORDER_SYSTEM' FROM dual
    UNION ALL SELECT  7, 'DOO_HEADERS_ALL', 'STATUS_CODE' FROM dual
    UNION ALL SELECT  7, 'DOO_HEADERS_ALL', 'SUBMITTED_FLAG' FROM dual
    UNION ALL SELECT  8, 'AR_PAYMENT_SCHEDULES_ALL', 'AMOUNT_DUE_REMAINING' FROM dual
    UNION ALL SELECT  8, 'AR_PAYMENT_SCHEDULES_ALL', 'CASH_RECEIPT_ID' FROM dual
    UNION ALL SELECT  8, 'AR_PAYMENT_SCHEDULES_ALL', 'CLASS' FROM dual
    UNION ALL SELECT  8, 'AR_PAYMENT_SCHEDULES_ALL', 'CUSTOMER_TRX_ID' FROM dual
    UNION ALL SELECT  8, 'AR_PAYMENT_SCHEDULES_ALL', 'INVOICE_CURRENCY_CODE' FROM dual
    UNION ALL SELECT  8, 'AR_PAYMENT_SCHEDULES_ALL', 'STATUS' FROM dual
    UNION ALL SELECT  9, 'RA_CUSTOMER_TRX_ALL', 'CUSTOMER_TRX_ID' FROM dual
    UNION ALL SELECT  9, 'RA_CUSTOMER_TRX_ALL', 'ORG_ID' FROM dual
    UNION ALL SELECT 10, 'AR_CASH_RECEIPTS_ALL', 'CASH_RECEIPT_ID' FROM dual
    UNION ALL SELECT 10, 'AR_CASH_RECEIPTS_ALL', 'ORG_ID' FROM dual
    UNION ALL SELECT 10, 'AR_CASH_RECEIPTS_ALL', 'REVERSAL_DATE' FROM dual
    UNION ALL SELECT 10, 'AR_CASH_RECEIPTS_ALL', 'STATUS' FROM dual
    UNION ALL SELECT 11, 'INV_ONHAND_QUANTITIES_DETAIL', 'INVENTORY_ITEM_ID' FROM dual
    UNION ALL SELECT 11, 'INV_ONHAND_QUANTITIES_DETAIL', 'ORGANIZATION_ID' FROM dual
    UNION ALL SELECT 11, 'INV_ONHAND_QUANTITIES_DETAIL', 'OWNING_ENTITY_ID' FROM dual
    UNION ALL SELECT 11, 'INV_ONHAND_QUANTITIES_DETAIL', 'OWNING_TYPE' FROM dual
    UNION ALL SELECT 11, 'INV_ONHAND_QUANTITIES_DETAIL', 'PRIMARY_TRANSACTION_QUANTITY' FROM dual
    UNION ALL SELECT 12, 'WIE_WORK_ORDERS_B', 'ORGANIZATION_ID' FROM dual
    UNION ALL SELECT 12, 'WIE_WORK_ORDERS_B', 'WORK_ORDER_STATUS_ID' FROM dual
    UNION ALL SELECT 12, 'WIE_WORK_ORDERS_B', 'WORK_ORDER_SUB_TYPE' FROM dual
    UNION ALL SELECT 12, 'WIE_WORK_ORDERS_B', 'WORK_ORDER_TYPE' FROM dual
    UNION ALL SELECT 13, 'WIE_WO_STATUSES_B', 'WO_STATUS_CODE' FROM dual
    UNION ALL SELECT 13, 'WIE_WO_STATUSES_B', 'WO_STATUS_ID' FROM dual
    UNION ALL SELECT 13, 'WIE_WO_STATUSES_B', 'WO_SYSTEM_STATUS_CODE' FROM dual
    UNION ALL SELECT 14, 'FND_LOOKUP_VALUES', 'LANGUAGE' FROM dual
    UNION ALL SELECT 14, 'FND_LOOKUP_VALUES', 'LOOKUP_CODE' FROM dual
    UNION ALL SELECT 14, 'FND_LOOKUP_VALUES', 'LOOKUP_TYPE' FROM dual
    UNION ALL SELECT 14, 'FND_LOOKUP_VALUES', 'MEANING' FROM dual
    UNION ALL SELECT 15, 'FUN_ALL_BUSINESS_UNITS_V', 'BU_ID' FROM dual
    UNION ALL SELECT 15, 'FUN_ALL_BUSINESS_UNITS_V', 'BU_NAME' FROM dual
    UNION ALL SELECT 15, 'FUN_ALL_BUSINESS_UNITS_V', 'PRIMARY_LEDGER_ID' FROM dual
    UNION ALL SELECT 15, 'FUN_ALL_BUSINESS_UNITS_V', 'STATUS' FROM dual
    UNION ALL SELECT 16, 'GL_LEDGERS', 'COMPLETE_FLAG' FROM dual
    UNION ALL SELECT 16, 'GL_LEDGERS', 'LEDGER_ID' FROM dual
    UNION ALL SELECT 16, 'GL_LEDGERS', 'OBJECT_TYPE_CODE' FROM dual
    UNION ALL SELECT 17, 'INV_ORGANIZATION_DEFINITIONS_V', 'BUSINESS_UNIT_ID' FROM dual
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
