-- ============================================================================
--  F3.1 WB  Setup Inventory workbook - sheet "PO Document Types"
--  Version   : 1.0 (2026-10-05). Not yet run on a pod.
--              RUN V3_1 FIRST. Log every run in 06_Run_Results/RUN_LOG.md.
--  Mirrors   : EBS agent _setup_inventory_sql['po_document_types']
--  RECONCILES  row count = F3.1 row 7 "Document Types" - same table, same
--              scope test (scope_flag / bu_scope copied from F3.1 unchanged).
--
--  COLUMNS  DOCUMENT_TYPE_CODE, DOCUMENT_SUBTYPE, TYPE_NAME, PROCUREMENT_BU
--    Fusion PO_DOCUMENT_TYPES_ALL_B: PK DOCUMENT_TYPE_CODE + DOCUMENT_SUBTYPE +
--    PRC_BU_ID, NO ORG_ID (verified 2026-10-05). EBS ORG_ID -> the procurement
--    BU, printed by NAME (FUN_ALL_BUSINESS_UNITS_V.BU_NAME, grouped per BU so
--    the view cannot fan the row out); the id is printed only if the BU has
--    no current row. EBS QUOTATION_CLASS is not on the Fusion table - dropped.
--    TYPE_NAME from PO_DOCUMENT_TYPES_ALL_TL on the full key, one language per
--    key (session first, then 'US'), so a translated type stays one row.
--
--  SCOPE  blank ledger and BU = every row (whole pod). Bound = rows whose
--         PRC_BU_ID is an in-scope BU (same rule as F3.1 row 7).
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
doc_type_names AS (
    SELECT  t.document_type_code,
            t.document_subtype,
            t.prc_bu_id,
            MAX(t.type_name) KEEP (DENSE_RANK FIRST ORDER BY
                CASE WHEN t.language = USERENV('LANG') THEN 0 ELSE 1 END)  AS type_name
    FROM    po_document_types_all_tl t
    WHERE   t.language IN (USERENV('LANG'), 'US')
    GROUP   BY t.document_type_code, t.document_subtype, t.prc_bu_id
),
bu_names AS (
    SELECT  bu.bu_id, MAX(bu.bu_name) AS bu_name
    FROM    fun_all_business_units_v bu
    GROUP   BY bu.bu_id
)
SELECT
    d.document_type_code                                      AS "DOCUMENT_TYPE_CODE",
    d.document_subtype                                        AS "DOCUMENT_SUBTYPE",
    tn.type_name                                              AS "TYPE_NAME",
    NVL(bn.bu_name, TO_CHAR(d.prc_bu_id))                     AS "PROCUREMENT_BU"
FROM        po_document_types_all_b d
CROSS JOIN  scope_flag              f
LEFT JOIN   doc_type_names          tn ON tn.document_type_code = d.document_type_code
                                      AND tn.document_subtype   = d.document_subtype
                                      AND tn.prc_bu_id          = d.prc_bu_id
LEFT JOIN   bu_names                bn ON bn.bu_id              = d.prc_bu_id
WHERE       f.is_bound = 0
   OR       d.prc_bu_id IN ( SELECT b.bu_id FROM bu_scope b )
ORDER BY    NVL(bn.bu_name, TO_CHAR(d.prc_bu_id)),
            d.document_type_code, d.document_subtype
