-- ============================================================================
--  F3.1 WB  Setup Inventory workbook - sheet "AR Transaction Sources"
--  Version   : 1.0 (2026-10-05). Not yet run on a pod.
--              RUN V3_1 FIRST. Log every run in 06_Run_Results/RUN_LOG.md.
--  Mirrors   : EBS agent _setup_inventory_sql['ar_transaction_sources']
--  RECONCILES  row count = F3.1 row 4 "Transaction Sources" (every row of
--              RA_BATCH_SOURCES_ALL, pod-wide).
--
--  COLUMNS  EBS: NAME, DESCRIPTION, STATUS, BATCH_SOURCE_TYPE, START_DATE,
--           END_DATE, ORG_ID.
--    Fusion RA_BATCH_SOURCES_ALL has NO ORG_ID (verified 2026-10-05); a source
--    belongs to a reference data set (unique BATCH_SOURCE_ID + SET_ID), so
--    ORG_ID is replaced by REFERENCE_SET. BATCH_SOURCE_TYPE: INV = manual,
--    FOREIGN = imported (Oracle's description).
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
    bs.name                                                   AS "NAME",
    bs.description                                            AS "DESCRIPTION",
    NVL(sn.set_code, TO_CHAR(bs.set_id))                      AS "REFERENCE_SET",
    bs.status                                                 AS "STATUS",
    bs.batch_source_type                                      AS "BATCH_SOURCE_TYPE",
    TO_CHAR(bs.start_date, 'YYYY-MM-DD')                      AS "START_DATE",
    TO_CHAR(bs.end_date,   'YYYY-MM-DD')                      AS "END_DATE"
FROM        ra_batch_sources_all bs
LEFT JOIN   set_names            sn ON sn.set_id = bs.set_id
ORDER BY    bs.name, NVL(sn.set_code, TO_CHAR(bs.set_id))
