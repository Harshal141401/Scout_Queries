-- ============================================================================
--  V0_1  VERIFY FIRST - objects and columns for Sections 0, 1 and 2
--  Run this BEFORE F0 / F1 / F2.x.  Metadata only (ALL_TAB_COLUMNS), so it
--  cannot fail with ORA-00942 even when a table is missing - a missing
--  object or column is printed as *** MISSING *** in the grid instead.
--
--  OUTPUT  ord | section | item | value      (paste the whole grid back)
--    Block A  one row per TABLE.COLUMN the Phase 2 queries use -> OK / MISSING
--    Block B  full column list of the objects whose documentation could not
--             be retrieved on 2026-09-30 (qualifier view, cross-validation
--             rules, FA transaction headers, XLA headers, BOM structures),
--             so the next query is written against what the pod really has
--    Block C  one row per object: how many columns are visible to this user
--             (0 = object missing OR not granted to the BIP user)
--
--  No binds. Pure SELECT. Nothing is written.
-- ============================================================================
WITH
req AS (
    SELECT    1 AS ord, 'SCOPE' AS section, 'GL_LEDGERS' AS tab, 'LEDGER_ID' AS col FROM dual
    UNION ALL
    SELECT    2 AS ord, 'SCOPE' AS section, 'GL_LEDGERS' AS tab, 'NAME' AS col FROM dual
    UNION ALL
    SELECT    3 AS ord, 'SCOPE' AS section, 'GL_LEDGERS' AS tab, 'OBJECT_TYPE_CODE' AS col FROM dual
    UNION ALL
    SELECT    4 AS ord, 'SCOPE' AS section, 'GL_LEDGERS' AS tab, 'COMPLETE_FLAG' AS col FROM dual
    UNION ALL
    SELECT    5 AS ord, 'SCOPE' AS section, 'GL_LEDGERS' AS tab, 'LEDGER_CATEGORY_CODE' AS col FROM dual
    UNION ALL
    SELECT    6 AS ord, 'SCOPE' AS section, 'GL_LEDGERS' AS tab, 'CURRENCY_CODE' AS col FROM dual
    UNION ALL
    SELECT    7 AS ord, 'SCOPE' AS section, 'GL_LEDGERS' AS tab, 'PERIOD_SET_NAME' AS col FROM dual
    UNION ALL
    SELECT    8 AS ord, 'SCOPE' AS section, 'GL_LEDGERS' AS tab, 'ACCOUNTED_PERIOD_TYPE' AS col FROM dual
    UNION ALL
    SELECT    9 AS ord, 'SCOPE' AS section, 'GL_LEDGERS' AS tab, 'CHART_OF_ACCOUNTS_ID' AS col FROM dual
    UNION ALL
    SELECT   10 AS ord, 'SCOPE' AS section, 'GL_LEDGERS' AS tab, 'SLA_ACCOUNTING_METHOD_CODE' AS col FROM dual
    UNION ALL
    SELECT   11 AS ord, 'SCOPE' AS section, 'GL_LEDGERS' AS tab, 'SLA_ACCOUNTING_METHOD_TYPE' AS col FROM dual
    UNION ALL
    SELECT   12 AS ord, 'SCOPE' AS section, 'GL_LEDGERS' AS tab, 'BAL_SEG_COLUMN_NAME' AS col FROM dual
    UNION ALL
    SELECT   13 AS ord, 'SCOPE' AS section, 'GL_LEDGER_RELATIONSHIPS' AS tab, 'TARGET_LEDGER_ID' AS col FROM dual
    UNION ALL
    SELECT   14 AS ord, 'SCOPE' AS section, 'GL_LEDGER_RELATIONSHIPS' AS tab, 'PRIMARY_LEDGER_ID' AS col FROM dual
    UNION ALL
    SELECT   15 AS ord, 'SCOPE' AS section, 'GL_LEDGER_RELATIONSHIPS' AS tab, 'APPLICATION_ID' AS col FROM dual
    UNION ALL
    SELECT   16 AS ord, 'SCOPE' AS section, 'GL_LEDGER_LE_V' AS tab, 'LEDGER_ID' AS col FROM dual
    UNION ALL
    SELECT   17 AS ord, 'SCOPE' AS section, 'GL_LEDGER_LE_V' AS tab, 'LEGAL_ENTITY_ID' AS col FROM dual
    UNION ALL
    SELECT   18 AS ord, 'SCOPE' AS section, 'GL_LEDGER_LE_V' AS tab, 'LEGAL_ENTITY_NAME' AS col FROM dual
    UNION ALL
    SELECT   19 AS ord, 'SCOPE' AS section, 'FUN_ALL_BUSINESS_UNITS_V' AS tab, 'BU_ID' AS col FROM dual
    UNION ALL
    SELECT   20 AS ord, 'SCOPE' AS section, 'FUN_ALL_BUSINESS_UNITS_V' AS tab, 'BU_NAME' AS col FROM dual
    UNION ALL
    SELECT   21 AS ord, 'SCOPE' AS section, 'FUN_ALL_BUSINESS_UNITS_V' AS tab, 'PRIMARY_LEDGER_ID' AS col FROM dual
    UNION ALL
    SELECT   22 AS ord, 'SCOPE' AS section, 'FUN_ALL_BUSINESS_UNITS_V' AS tab, 'LEGAL_ENTITY_ID' AS col FROM dual
    UNION ALL
    SELECT   23 AS ord, 'SCOPE' AS section, 'FUN_ALL_BUSINESS_UNITS_V' AS tab, 'STATUS' AS col FROM dual
    UNION ALL
    SELECT   24 AS ord, 'SCOPE' AS section, 'INV_ORGANIZATION_DEFINITIONS_V' AS tab, 'ORGANIZATION_ID' AS col FROM dual
    UNION ALL
    SELECT   25 AS ord, 'SCOPE' AS section, 'INV_ORGANIZATION_DEFINITIONS_V' AS tab, 'ORGANIZATION_CODE' AS col FROM dual
    UNION ALL
    SELECT   26 AS ord, 'SCOPE' AS section, 'INV_ORGANIZATION_DEFINITIONS_V' AS tab, 'ORGANIZATION_NAME' AS col FROM dual
    UNION ALL
    SELECT   27 AS ord, 'SCOPE' AS section, 'INV_ORGANIZATION_DEFINITIONS_V' AS tab, 'BUSINESS_UNIT_ID' AS col FROM dual
    UNION ALL
    SELECT   28 AS ord, 'SCOPE' AS section, 'INV_ORGANIZATION_DEFINITIONS_V' AS tab, 'SET_OF_BOOKS_ID' AS col FROM dual
    UNION ALL
    SELECT   29 AS ord, 'SCOPE' AS section, 'FA_BOOK_CONTROLS' AS tab, 'BOOK_TYPE_CODE' AS col FROM dual
    UNION ALL
    SELECT   30 AS ord, 'SCOPE' AS section, 'FA_BOOK_CONTROLS' AS tab, 'SET_OF_BOOKS_ID' AS col FROM dual
    UNION ALL
    SELECT   31 AS ord, 'S1 MODULES' AS section, 'GL_JE_HEADERS' AS tab, 'LEDGER_ID' AS col FROM dual
    UNION ALL
    SELECT   32 AS ord, 'S1 MODULES' AS section, 'GL_JE_HEADERS' AS tab, 'CREATED_BY' AS col FROM dual
    UNION ALL
    SELECT   33 AS ord, 'S1 MODULES' AS section, 'GL_JE_HEADERS' AS tab, 'CREATION_DATE' AS col FROM dual
    UNION ALL
    SELECT   34 AS ord, 'S1 MODULES' AS section, 'AP_INVOICES_ALL' AS tab, 'ORG_ID' AS col FROM dual
    UNION ALL
    SELECT   35 AS ord, 'S1 MODULES' AS section, 'AP_INVOICES_ALL' AS tab, 'INVOICE_DATE' AS col FROM dual
    UNION ALL
    SELECT   36 AS ord, 'S1 MODULES' AS section, 'AP_INVOICES_ALL' AS tab, 'CREATED_BY' AS col FROM dual
    UNION ALL
    SELECT   37 AS ord, 'S1 MODULES' AS section, 'RA_CUSTOMER_TRX_ALL' AS tab, 'ORG_ID' AS col FROM dual
    UNION ALL
    SELECT   38 AS ord, 'S1 MODULES' AS section, 'RA_CUSTOMER_TRX_ALL' AS tab, 'TRX_DATE' AS col FROM dual
    UNION ALL
    SELECT   39 AS ord, 'S1 MODULES' AS section, 'RA_CUSTOMER_TRX_ALL' AS tab, 'CREATED_BY' AS col FROM dual
    UNION ALL
    SELECT   40 AS ord, 'S1 MODULES' AS section, 'PO_HEADERS_ALL' AS tab, 'PRC_BU_ID' AS col FROM dual
    UNION ALL
    SELECT   41 AS ord, 'S1 MODULES' AS section, 'PO_HEADERS_ALL' AS tab, 'REQ_BU_ID' AS col FROM dual
    UNION ALL
    SELECT   42 AS ord, 'S1 MODULES' AS section, 'PO_HEADERS_ALL' AS tab, 'BILLTO_BU_ID' AS col FROM dual
    UNION ALL
    SELECT   43 AS ord, 'S1 MODULES' AS section, 'PO_HEADERS_ALL' AS tab, 'CREATION_DATE' AS col FROM dual
    UNION ALL
    SELECT   44 AS ord, 'S1 MODULES' AS section, 'PO_HEADERS_ALL' AS tab, 'CREATED_BY' AS col FROM dual
    UNION ALL
    SELECT   45 AS ord, 'S1 MODULES' AS section, 'POR_REQUISITION_HEADERS_ALL' AS tab, 'REQ_BU_ID' AS col FROM dual
    UNION ALL
    SELECT   46 AS ord, 'S1 MODULES' AS section, 'POR_REQUISITION_HEADERS_ALL' AS tab, 'CREATION_DATE' AS col FROM dual
    UNION ALL
    SELECT   47 AS ord, 'S1 MODULES' AS section, 'POR_REQUISITION_HEADERS_ALL' AS tab, 'CREATED_BY' AS col FROM dual
    UNION ALL
    SELECT   48 AS ord, 'S1 MODULES' AS section, 'DOO_HEADERS_ALL' AS tab, 'HEADER_ID' AS col FROM dual
    UNION ALL
    SELECT   49 AS ord, 'S1 MODULES' AS section, 'DOO_HEADERS_ALL' AS tab, 'ORDER_NUMBER' AS col FROM dual
    UNION ALL
    SELECT   50 AS ord, 'S1 MODULES' AS section, 'DOO_HEADERS_ALL' AS tab, 'ORG_ID' AS col FROM dual
    UNION ALL
    SELECT   51 AS ord, 'S1 MODULES' AS section, 'DOO_HEADERS_ALL' AS tab, 'ORDERED_DATE' AS col FROM dual
    UNION ALL
    SELECT   52 AS ord, 'S1 MODULES' AS section, 'DOO_HEADERS_ALL' AS tab, 'CREATED_BY' AS col FROM dual
    UNION ALL
    SELECT   53 AS ord, 'S1 MODULES' AS section, 'INV_MATERIAL_TXNS' AS tab, 'ORGANIZATION_ID' AS col FROM dual
    UNION ALL
    SELECT   54 AS ord, 'S1 MODULES' AS section, 'INV_MATERIAL_TXNS' AS tab, 'TRANSACTION_DATE' AS col FROM dual
    UNION ALL
    SELECT   55 AS ord, 'S1 MODULES' AS section, 'INV_MATERIAL_TXNS' AS tab, 'CREATED_BY' AS col FROM dual
    UNION ALL
    SELECT   56 AS ord, 'S1 MODULES' AS section, 'CE_STATEMENT_HEADERS' AS tab, 'BANK_ACCOUNT_ID' AS col FROM dual
    UNION ALL
    SELECT   57 AS ord, 'S1 MODULES' AS section, 'CE_STATEMENT_HEADERS' AS tab, 'CREATION_DATE' AS col FROM dual
    UNION ALL
    SELECT   58 AS ord, 'S1 MODULES' AS section, 'CE_STATEMENT_HEADERS' AS tab, 'CREATED_BY' AS col FROM dual
    UNION ALL
    SELECT   59 AS ord, 'S1 MODULES' AS section, 'CE_BANK_ACCT_USES_ALL' AS tab, 'BANK_ACCOUNT_ID' AS col FROM dual
    UNION ALL
    SELECT   60 AS ord, 'S1 MODULES' AS section, 'CE_BANK_ACCT_USES_ALL' AS tab, 'ORG_ID' AS col FROM dual
    UNION ALL
    SELECT   61 AS ord, 'S1 MODULES' AS section, 'CST_COST_DISTRIBUTIONS' AS tab, 'LEDGER_ID' AS col FROM dual
    UNION ALL
    SELECT   62 AS ord, 'S1 MODULES' AS section, 'CST_COST_DISTRIBUTIONS' AS tab, 'GL_DATE' AS col FROM dual
    UNION ALL
    SELECT   63 AS ord, 'S1 MODULES' AS section, 'CST_COST_DISTRIBUTIONS' AS tab, 'CREATED_BY' AS col FROM dual
    UNION ALL
    SELECT   64 AS ord, 'S1 MODULES' AS section, 'FA_TRANSACTION_HEADERS' AS tab, 'BOOK_TYPE_CODE' AS col FROM dual
    UNION ALL
    SELECT   65 AS ord, 'S1 MODULES' AS section, 'FA_TRANSACTION_HEADERS' AS tab, 'TRANSACTION_DATE_ENTERED' AS col FROM dual
    UNION ALL
    SELECT   66 AS ord, 'S1 MODULES' AS section, 'FA_TRANSACTION_HEADERS' AS tab, 'LAST_UPDATED_BY' AS col FROM dual
    UNION ALL
    SELECT   67 AS ord, 'S1 MODULES' AS section, 'PJC_EXP_ITEMS_ALL' AS tab, 'ORG_ID' AS col FROM dual
    UNION ALL
    SELECT   68 AS ord, 'S1 MODULES' AS section, 'PJC_EXP_ITEMS_ALL' AS tab, 'EXPENDITURE_ITEM_DATE' AS col FROM dual
    UNION ALL
    SELECT   69 AS ord, 'S1 MODULES' AS section, 'PJC_EXP_ITEMS_ALL' AS tab, 'CREATED_BY' AS col FROM dual
    UNION ALL
    SELECT   70 AS ord, 'S1 MODULES' AS section, 'WIE_WORK_ORDERS_B' AS tab, 'ORGANIZATION_ID' AS col FROM dual
    UNION ALL
    SELECT   71 AS ord, 'S1 MODULES' AS section, 'WIE_WORK_ORDERS_B' AS tab, 'CREATION_DATE' AS col FROM dual
    UNION ALL
    SELECT   72 AS ord, 'S1 MODULES' AS section, 'WIE_WORK_ORDERS_B' AS tab, 'CREATED_BY' AS col FROM dual
    UNION ALL
    SELECT   73 AS ord, 'S1 MODULES' AS section, 'EGP_STRUCTURES_B' AS tab, 'PK2_VALUE' AS col FROM dual
    UNION ALL
    SELECT   74 AS ord, 'S1 MODULES' AS section, 'EGP_STRUCTURES_B' AS tab, 'CREATION_DATE' AS col FROM dual
    UNION ALL
    SELECT   75 AS ord, 'S1 MODULES' AS section, 'EGP_STRUCTURES_B' AS tab, 'CREATED_BY' AS col FROM dual
    UNION ALL
    SELECT   76 AS ord, 'S1 MODULES' AS section, 'WSH_NEW_DELIVERIES' AS tab, 'ORGANIZATION_ID' AS col FROM dual
    UNION ALL
    SELECT   77 AS ord, 'S1 MODULES' AS section, 'WSH_NEW_DELIVERIES' AS tab, 'CREATION_DATE' AS col FROM dual
    UNION ALL
    SELECT   78 AS ord, 'S1 MODULES' AS section, 'WSH_NEW_DELIVERIES' AS tab, 'CREATED_BY' AS col FROM dual
    UNION ALL
    SELECT   79 AS ord, 'S1 MODULES' AS section, 'EXM_EXPENSE_REPORTS' AS tab, 'ORG_ID' AS col FROM dual
    UNION ALL
    SELECT   80 AS ord, 'S1 MODULES' AS section, 'EXM_EXPENSE_REPORTS' AS tab, 'CREATION_DATE' AS col FROM dual
    UNION ALL
    SELECT   81 AS ord, 'S1 MODULES' AS section, 'EXM_EXPENSE_REPORTS' AS tab, 'CREATED_BY' AS col FROM dual
    UNION ALL
    SELECT   82 AS ord, 'S1 MODULES' AS section, 'FLA_LEASES_ALL' AS tab, 'ORG_ID' AS col FROM dual
    UNION ALL
    SELECT   83 AS ord, 'S1 MODULES' AS section, 'FLA_LEASES_ALL' AS tab, 'CREATION_DATE' AS col FROM dual
    UNION ALL
    SELECT   84 AS ord, 'S1 MODULES' AS section, 'FLA_LEASES_ALL' AS tab, 'CREATED_BY' AS col FROM dual
    UNION ALL
    SELECT   85 AS ord, 'S1 MODULES' AS section, 'FUN_TRX_HEADERS' AS tab, 'CREATION_DATE' AS col FROM dual
    UNION ALL
    SELECT   86 AS ord, 'S2.1 MAP' AS section, 'GL_PERIODS' AS tab, 'PERIOD_SET_NAME' AS col FROM dual
    UNION ALL
    SELECT   87 AS ord, 'S2.1 MAP' AS section, 'GL_PERIODS' AS tab, 'PERIOD_TYPE' AS col FROM dual
    UNION ALL
    SELECT   88 AS ord, 'S2.1 MAP' AS section, 'GL_PERIODS' AS tab, 'PERIOD_YEAR' AS col FROM dual
    UNION ALL
    SELECT   89 AS ord, 'S2.1 MAP' AS section, 'GL_PERIODS' AS tab, 'START_DATE' AS col FROM dual
    UNION ALL
    SELECT   90 AS ord, 'S2.1 MAP' AS section, 'GL_PERIODS' AS tab, 'END_DATE' AS col FROM dual
    UNION ALL
    SELECT   91 AS ord, 'S2.1 MAP' AS section, 'GL_PERIODS' AS tab, 'ADJUSTMENT_PERIOD_FLAG' AS col FROM dual
    UNION ALL
    SELECT   92 AS ord, 'S2.1 MAP' AS section, 'XLA_ACCTG_METHODS_TL' AS tab, 'ACCOUNTING_METHOD_TYPE_CODE' AS col FROM dual
    UNION ALL
    SELECT   93 AS ord, 'S2.1 MAP' AS section, 'XLA_ACCTG_METHODS_TL' AS tab, 'ACCOUNTING_METHOD_CODE' AS col FROM dual
    UNION ALL
    SELECT   94 AS ord, 'S2.1 MAP' AS section, 'XLA_ACCTG_METHODS_TL' AS tab, 'NAME' AS col FROM dual
    UNION ALL
    SELECT   95 AS ord, 'S2.1 MAP' AS section, 'XLA_ACCTG_METHODS_TL' AS tab, 'LANGUAGE' AS col FROM dual
    UNION ALL
    SELECT   96 AS ord, 'S2.1 MAP' AS section, 'XLE_ENTITY_PROFILES' AS tab, 'LEGAL_ENTITY_ID' AS col FROM dual
    UNION ALL
    SELECT   97 AS ord, 'S2.1 MAP' AS section, 'XLE_ENTITY_PROFILES' AS tab, 'NAME' AS col FROM dual
    UNION ALL
    SELECT   98 AS ord, 'S2.1 MAP' AS section, 'GL_LEDGER_LE_BSV_SPECIFIC_V' AS tab, 'LEDGER_ID' AS col FROM dual
    UNION ALL
    SELECT   99 AS ord, 'S2.1 MAP' AS section, 'GL_LEDGER_LE_BSV_SPECIFIC_V' AS tab, 'LEDGER_NAME' AS col FROM dual
    UNION ALL
    SELECT  100 AS ord, 'S2.1 MAP' AS section, 'GL_LEDGER_LE_BSV_SPECIFIC_V' AS tab, 'LEDGER_CATEGORY_CODE' AS col FROM dual
    UNION ALL
    SELECT  101 AS ord, 'S2.1 MAP' AS section, 'GL_LEDGER_LE_BSV_SPECIFIC_V' AS tab, 'LEGAL_ENTITY_ID' AS col FROM dual
    UNION ALL
    SELECT  102 AS ord, 'S2.1 MAP' AS section, 'GL_LEDGER_LE_BSV_SPECIFIC_V' AS tab, 'LEGAL_ENTITY_NAME' AS col FROM dual
    UNION ALL
    SELECT  103 AS ord, 'S2.1 MAP' AS section, 'GL_LEDGER_LE_BSV_SPECIFIC_V' AS tab, 'SEGMENT_VALUE' AS col FROM dual
    UNION ALL
    SELECT  104 AS ord, 'S2.1 MAP' AS section, 'GL_LEDGER_LE_BSV_SPECIFIC_V' AS tab, 'START_DATE' AS col FROM dual
    UNION ALL
    SELECT  105 AS ord, 'S2.1 MAP' AS section, 'GL_LEDGER_LE_BSV_SPECIFIC_V' AS tab, 'END_DATE' AS col FROM dual
    UNION ALL
    SELECT  106 AS ord, 'S2.2 COA' AS section, 'FND_ID_FLEX_STRUCTURES_VL' AS tab, 'APPLICATION_ID' AS col FROM dual
    UNION ALL
    SELECT  107 AS ord, 'S2.2 COA' AS section, 'FND_ID_FLEX_STRUCTURES_VL' AS tab, 'ID_FLEX_CODE' AS col FROM dual
    UNION ALL
    SELECT  108 AS ord, 'S2.2 COA' AS section, 'FND_ID_FLEX_STRUCTURES_VL' AS tab, 'ID_FLEX_NUM' AS col FROM dual
    UNION ALL
    SELECT  109 AS ord, 'S2.2 COA' AS section, 'FND_ID_FLEX_STRUCTURES_VL' AS tab, 'ID_FLEX_STRUCTURE_NAME' AS col FROM dual
    UNION ALL
    SELECT  110 AS ord, 'S2.2 COA' AS section, 'FND_ID_FLEX_SEGMENTS_VL' AS tab, 'APPLICATION_ID' AS col FROM dual
    UNION ALL
    SELECT  111 AS ord, 'S2.2 COA' AS section, 'FND_ID_FLEX_SEGMENTS_VL' AS tab, 'ID_FLEX_CODE' AS col FROM dual
    UNION ALL
    SELECT  112 AS ord, 'S2.2 COA' AS section, 'FND_ID_FLEX_SEGMENTS_VL' AS tab, 'ID_FLEX_NUM' AS col FROM dual
    UNION ALL
    SELECT  113 AS ord, 'S2.2 COA' AS section, 'FND_ID_FLEX_SEGMENTS_VL' AS tab, 'APPLICATION_COLUMN_NAME' AS col FROM dual
    UNION ALL
    SELECT  114 AS ord, 'S2.2 COA' AS section, 'FND_ID_FLEX_SEGMENTS_VL' AS tab, 'SEGMENT_NAME' AS col FROM dual
    UNION ALL
    SELECT  115 AS ord, 'S2.2 COA' AS section, 'FND_ID_FLEX_SEGMENTS_VL' AS tab, 'SEGMENT_NUM' AS col FROM dual
    UNION ALL
    SELECT  116 AS ord, 'S2.2 COA' AS section, 'FND_ID_FLEX_SEGMENTS_VL' AS tab, 'FORM_LEFT_PROMPT' AS col FROM dual
    UNION ALL
    SELECT  117 AS ord, 'S2.2 COA' AS section, 'FND_ID_FLEX_SEGMENTS_VL' AS tab, 'DISPLAY_SIZE' AS col FROM dual
    UNION ALL
    SELECT  118 AS ord, 'S2.2 COA' AS section, 'FND_ID_FLEX_SEGMENTS_VL' AS tab, 'FLEX_VALUE_SET_ID' AS col FROM dual
    UNION ALL
    SELECT  119 AS ord, 'S2.2 COA' AS section, 'FND_ID_FLEX_SEGMENTS_VL' AS tab, 'ENABLED_FLAG' AS col FROM dual
    UNION ALL
    SELECT  120 AS ord, 'S2.2 COA' AS section, 'FND_VS_VALUES_B' AS tab, 'VALUE_ID' AS col FROM dual
    UNION ALL
    SELECT  121 AS ord, 'S2.2 COA' AS section, 'FND_VS_VALUES_B' AS tab, 'VALUE_SET_ID' AS col FROM dual
    UNION ALL
    SELECT  122 AS ord, 'S2.2 COA' AS section, 'FND_VS_VALUES_B' AS tab, 'INDEPENDENT_VALUE' AS col FROM dual
    UNION ALL
    SELECT  123 AS ord, 'S2.2 COA' AS section, 'FND_VS_VALUES_B' AS tab, 'VALUE' AS col FROM dual
    UNION ALL
    SELECT  124 AS ord, 'S2.2 COA' AS section, 'FND_VS_VALUES_B' AS tab, 'ENABLED_FLAG' AS col FROM dual
    UNION ALL
    SELECT  125 AS ord, 'S2.2 COA' AS section, 'FND_VS_VALUES_B' AS tab, 'SUMMARY_FLAG' AS col FROM dual
    UNION ALL
    SELECT  126 AS ord, 'S2.2 COA' AS section, 'FND_VS_VALUES_B' AS tab, 'START_DATE_ACTIVE' AS col FROM dual
    UNION ALL
    SELECT  127 AS ord, 'S2.2 COA' AS section, 'FND_VS_VALUES_B' AS tab, 'END_DATE_ACTIVE' AS col FROM dual
    UNION ALL
    SELECT  128 AS ord, 'S2.2 COA' AS section, 'FND_VS_VALUES_B' AS tab, 'SANDBOX_ID' AS col FROM dual
    UNION ALL
    SELECT  129 AS ord, 'S2.2 COA' AS section, 'FND_VS_VALUES_B' AS tab, 'FLEX_VALUE_ATTRIBUTE1' AS col FROM dual
    UNION ALL
    SELECT  130 AS ord, 'S2.2 COA' AS section, 'FND_VS_VALUES_B' AS tab, 'FLEX_VALUE_ATTRIBUTE20' AS col FROM dual
    UNION ALL
    SELECT  131 AS ord, 'S2.2 COA' AS section, 'FND_VS_VALUES_VL' AS tab, 'VALUE_ID' AS col FROM dual
    UNION ALL
    SELECT  132 AS ord, 'S2.2 COA' AS section, 'FND_VS_VALUES_VL' AS tab, 'DESCRIPTION' AS col FROM dual
    UNION ALL
    SELECT  133 AS ord, 'S2.2 COA' AS section, 'FND_FLEX_VALUE_SETS' AS tab, 'FLEX_VALUE_SET_ID' AS col FROM dual
    UNION ALL
    SELECT  134 AS ord, 'S2.2 COA' AS section, 'FND_FLEX_VALUE_SETS' AS tab, 'FLEX_VALUE_SET_NAME' AS col FROM dual
    UNION ALL
    SELECT  135 AS ord, 'S2.2 COA' AS section, 'FND_VS_KF_VALUE_ATTRS' AS tab, 'VALUE_SET_ID' AS col FROM dual
    UNION ALL
    SELECT  136 AS ord, 'S2.2 COA' AS section, 'FND_VS_KF_VALUE_ATTRS' AS tab, 'APPLICATION_ID' AS col FROM dual
    UNION ALL
    SELECT  137 AS ord, 'S2.2 COA' AS section, 'FND_VS_KF_VALUE_ATTRS' AS tab, 'KEY_FLEXFIELD_CODE' AS col FROM dual
    UNION ALL
    SELECT  138 AS ord, 'S2.2 COA' AS section, 'FND_VS_KF_VALUE_ATTRS' AS tab, 'VALUE_ATTRIBUTE_CODE' AS col FROM dual
    UNION ALL
    SELECT  139 AS ord, 'S2.2 COA' AS section, 'FND_VS_KF_VALUE_ATTRS' AS tab, 'VALUE_TABLE_COLUMN_NAME' AS col FROM dual
    UNION ALL
    SELECT  140 AS ord, 'S2.2 COA' AS section, 'FND_SEGMENT_ATTRIBUTE_VALUES' AS tab, 'APPLICATION_ID' AS col FROM dual
    UNION ALL
    SELECT  141 AS ord, 'S2.2 COA' AS section, 'FND_SEGMENT_ATTRIBUTE_VALUES' AS tab, 'ID_FLEX_CODE' AS col FROM dual
    UNION ALL
    SELECT  142 AS ord, 'S2.2 COA' AS section, 'FND_SEGMENT_ATTRIBUTE_VALUES' AS tab, 'ID_FLEX_NUM' AS col FROM dual
    UNION ALL
    SELECT  143 AS ord, 'S2.2 COA' AS section, 'FND_SEGMENT_ATTRIBUTE_VALUES' AS tab, 'APPLICATION_COLUMN_NAME' AS col FROM dual
    UNION ALL
    SELECT  144 AS ord, 'S2.2 COA' AS section, 'FND_SEGMENT_ATTRIBUTE_VALUES' AS tab, 'SEGMENT_ATTRIBUTE_TYPE' AS col FROM dual
    UNION ALL
    SELECT  145 AS ord, 'S2.2 COA' AS section, 'FND_SEGMENT_ATTRIBUTE_VALUES' AS tab, 'ATTRIBUTE_VALUE' AS col FROM dual
    UNION ALL
    SELECT  146 AS ord, 'V0_2 ONLY' AS section, 'XLE_LE_OU_LEDGER_V' AS tab, 'LEDGER_ID' AS col FROM dual
    UNION ALL
    SELECT  147 AS ord, 'V0_2 ONLY' AS section, 'XLE_LE_OU_LEDGER_V' AS tab, 'OPERATING_UNIT_ID' AS col FROM dual
    UNION ALL
    SELECT  148 AS ord, 'V0_2 ONLY' AS section, 'XLE_LE_OU_LEDGER_V' AS tab, 'LEGAL_ENTITY_ID' AS col FROM dual
    UNION ALL
    SELECT  149 AS ord, 'V0_2 ONLY' AS section, 'INV_ORG_PARAMETERS' AS tab, 'ORGANIZATION_ID' AS col FROM dual
    UNION ALL
    SELECT  150 AS ord, 'V0_2 ONLY' AS section, 'INV_ORG_PARAMETERS' AS tab, 'PROFIT_CENTER_BU_ID' AS col FROM dual
    UNION ALL
    SELECT  151 AS ord, 'S1 REGISTRY' AS section, 'FND_TABLES' AS tab, 'APPLICATION_SHORT_NAME' AS col FROM dual
    UNION ALL
    SELECT  152 AS ord, 'S1 REGISTRY' AS section, 'FND_TABLES' AS tab, 'TABLE_NAME' AS col FROM dual
    UNION ALL
    SELECT  153 AS ord, 'S1 REGISTRY' AS section, 'FND_APPLICATION_VL' AS tab, 'APPLICATION_ID' AS col FROM dual
    UNION ALL
    SELECT  154 AS ord, 'S1 REGISTRY' AS section, 'FND_APPLICATION_VL' AS tab, 'APPLICATION_SHORT_NAME' AS col FROM dual
    UNION ALL
    SELECT  155 AS ord, 'S1 REGISTRY' AS section, 'FND_APPLICATION_VL' AS tab, 'APPLICATION_NAME' AS col FROM dual
),
cols AS (
    SELECT  table_name, column_name
    FROM    all_tab_columns
    WHERE   table_name IN ('FND_TABLES', 'FND_APPLICATION_VL',
                          'AP_INVOICES_ALL',
                          'CE_BANK_ACCT_USES_ALL',
                          'CE_STATEMENT_HEADERS',
                          'CST_COST_DISTRIBUTIONS',
                          'DOO_HEADERS_ALL',
                          'EGP_STRUCTURES_B',
                          'EXM_EXPENSE_REPORTS',
                          'FA_BOOK_CONTROLS',
                          'FA_TRANSACTION_HEADERS',
                          'FLA_LEASES_ALL',
                          'FND_FLEX_VALUE_SETS',
                          'FND_ID_FLEX_SEGMENTS_VL',
                          'FND_ID_FLEX_STRUCTURES_VL',
                          'FND_KF_CROSS_VAL_RULES',
                          'FND_KF_CROSS_VAL_RULES_TL',
                          'FND_SEGMENT_ATTRIBUTE_VALUES',
                          'FND_VS_KF_VALUE_ATTRS',
                          'FND_VS_VALUES_B',
                          'FND_VS_VALUES_VL',
                          'FUN_ALL_BUSINESS_UNITS_V',
                          'FUN_TRX_HEADERS',
                          'GL_JE_HEADERS',
                          'GL_LEDGERS',
                          'GL_LEDGER_LE_BSV_SPECIFIC_V',
                          'GL_LEDGER_LE_V',
                          'GL_LEDGER_RELATIONSHIPS',
                          'GL_PERIODS',
                          'INV_MATERIAL_TXNS',
                          'INV_ORGANIZATION_DEFINITIONS_V',
                          'INV_ORG_PARAMETERS',
                          'PJC_EXP_ITEMS_ALL',
                          'POR_REQUISITION_HEADERS_ALL',
                          'PO_HEADERS_ALL',
                          'RA_CUSTOMER_TRX_ALL',
                          'WIE_WORK_ORDERS_B',
                          'WSH_NEW_DELIVERIES',
                          'XLA_ACCTG_METHODS_TL',
                          'XLA_AE_HEADERS',
                          'XLE_ENTITY_PROFILES',
                          'XLE_LE_OU_LEDGER_V')
    GROUP   BY table_name, column_name
),
dump AS (
    SELECT  table_name,
            LISTAGG(column_name, ' ' ON OVERFLOW TRUNCATE) WITHIN GROUP (ORDER BY column_name) AS col_list
    FROM    cols
    WHERE   table_name IN ('FND_TABLES', 'FND_APPLICATION_VL', 'FND_SEGMENT_ATTRIBUTE_VALUES', 'FND_KF_CROSS_VAL_RULES', 'FND_KF_CROSS_VAL_RULES_TL', 'FND_VS_KF_VALUE_ATTRS', 'FA_TRANSACTION_HEADERS', 'XLA_AE_HEADERS', 'EGP_STRUCTURES_B')
    GROUP   BY table_name
),
obj AS (
    SELECT  t.tab, COUNT(c.column_name) AS n_cols
    FROM  ( SELECT tab FROM req GROUP BY tab ) t
    LEFT JOIN cols c ON c.table_name = t.tab
    GROUP   BY t.tab
),
grid AS (
    SELECT  r.ord                                   AS ord,
            'A ' || r.section                       AS section,
            r.tab || '.' || r.col                   AS item,
            CASE WHEN c.column_name IS NOT NULL THEN 'OK'
                 ELSE '*** MISSING ***' END         AS value
    FROM        req  r
    LEFT JOIN   cols c ON c.table_name = r.tab AND c.column_name = r.col
    UNION ALL
    SELECT  5000 + ROWNUM, 'B COLUMN DUMP', d.table_name, d.col_list
    FROM    dump d
    UNION ALL
    SELECT  6000 + ROWNUM, 'C OBJECT VISIBLE', o.tab,
            CASE WHEN o.n_cols > 0 THEN 'OK - ' || o.n_cols || ' columns visible'
                 ELSE '*** NOT VISIBLE (missing or not granted) ***' END
    FROM    obj o
)
SELECT ord, section, item, value
FROM   grid
ORDER  BY ord
