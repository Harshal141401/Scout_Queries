-- ============================================================================
--  F3.1 WB  Setup Inventory workbook - sheet "AR Transaction Types"
--  Workbook  : Fusion_Discovery_3_1_Setup_Inventory.xlsx
--              (EBS: EBS_Discovery_3_1_Setup_Inventory.xlsx, one sheet per
--              3.1 count row, in 3.1 order)
--  Version   : 1.0 (2026-10-05). Not yet run on a pod.
--              RUN V3_1 FIRST. Log every run in 06_Run_Results/RUN_LOG.md.
--  Mirrors   : EBS agent _setup_inventory_sql['ar_transaction_types']
--  RECONCILES  row count = F3.1 row 3 "Transaction Types" (same table, same
--              population: every row, pod-wide).
--
--  COLUMNS  EBS: NAME, DESCRIPTION, TYPE, STATUS, POST_TO_GL, OPEN_RECEIVABLE,
--           START_DATE, END_DATE, ORG_ID.
--    Fusion: ORG_ID is replaced by REFERENCE_SET - a Fusion transaction type
--    belongs to a reference data set (unique key CUST_TRX_TYPE_ID + SET_ID),
--    so one row = one type in one set, and the set code tells two same-named
--    types apart. OPEN_RECEIVABLE = ACCOUNTING_AFFECT_FLAG (EBS parity).
--    Columns verified on the Oracle RA_CUST_TRX_TYPES_ALL page 2026-10-05.
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
set_names AS (
    SELECT  s.set_id, MAX(s.set_code) AS set_code
    FROM    fnd_setid_sets_vl s
    GROUP   BY s.set_id
)
SELECT
    t.name                                                    AS "NAME",
    t.description                                             AS "DESCRIPTION",
    NVL(sn.set_code, TO_CHAR(t.set_id))                       AS "REFERENCE_SET",
    t.type                                                    AS "TYPE",
    t.status                                                  AS "STATUS",
    t.post_to_gl                                              AS "POST_TO_GL",
    t.accounting_affect_flag                                  AS "OPEN_RECEIVABLE",
    TO_CHAR(t.start_date, 'YYYY-MM-DD')                       AS "START_DATE",
    TO_CHAR(t.end_date,   'YYYY-MM-DD')                       AS "END_DATE"
FROM        ra_cust_trx_types_all t
LEFT JOIN   set_names             sn ON sn.set_id = t.set_id
ORDER BY    t.name, NVL(sn.set_code, TO_CHAR(t.set_id))
