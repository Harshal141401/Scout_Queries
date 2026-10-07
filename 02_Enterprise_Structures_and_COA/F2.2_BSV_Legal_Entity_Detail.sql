-- ============================================================================
--  F2.2 detail  Workbook WB2 sheet "Balancing Segment -> Legal Entity"
--  Source    : Oracle Fusion Cloud (BIP data model, data source ApplicationDB_FSCM)
--  Mirrors   : EBS 2.2_Balancing_Segment_Legal_Entity_Detail.sql
--  No Fusion draft existed for this sheet.
--
--  GRAIN  one row per ledger x legal entity x balancing segment value.
--         A value assigned at LEDGER level (no legal entity) shows LE '-'.
--
--  SOURCE  GL_LEDGER_LE_BSV_SPECIFIC_V (verified 2026-09-30): Oracle's own view
--          over GL_LEDGER_NORM_SEG_VALS (segment_type_code 'B', not deleted)
--          + GL_LEDGERS + XLE_ENTITY_PROFILES. Columns LEDGER_ID, LEDGER_NAME,
--          LEGAL_ENTITY_ID, LEGAL_ENTITY_NAME, LEDGER_CATEGORY_CODE,
--          SEGMENT_VALUE, START_DATE, END_DATE.
--
--  CHECK   every Company value in F2.2_COA_Segment_Values_Detail should appear
--          here for a primary ledger that balances by legal entity; a value
--          missing here is unassigned - a migration finding.
--
--  PARAMETERS  :p_ledger_id optional; bound -> that ledger's family.
--  Version   : 1.0 (built 2026-09-30, statically checked, not yet run on a pod)
--  RUN V0_1 AND V0_2 FIRST. Log every run in 06_Run_Results/RUN_LOG.md.
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
led_parent AS (
    SELECT  r.target_ledger_id       AS ledger_id,
            MIN(r.primary_ledger_id) AS primary_ledger_id
    FROM    gl_ledger_relationships r
    WHERE   r.application_id = 101
    GROUP   BY r.target_ledger_id
),
led AS (
    SELECT  gl.ledger_id
    FROM        gl_ledgers gl
    LEFT JOIN   led_parent pr ON pr.ledger_id = gl.ledger_id
    CROSS JOIN  params p
    WHERE   gl.object_type_code = 'L'
    AND     ( p.p_ledger_id IS NULL
              OR gl.ledger_id = TO_NUMBER(p.p_ledger_id)
              OR NVL(pr.primary_ledger_id, gl.ledger_id) = TO_NUMBER(p.p_ledger_id) )
),
bsv AS (
    SELECT  b.ledger_name,
            b.ledger_category_code,
            b.legal_entity_name,
            b.segment_value,
            MIN(b.start_date) AS start_date,
            MAX(b.end_date)   AS end_date
    FROM    gl_ledger_le_bsv_specific_v b
    JOIN    led l ON l.ledger_id = b.ledger_id
    GROUP   BY b.ledger_name, b.ledger_category_code,
               b.legal_entity_name, b.segment_value
)
SELECT
    ledger_name                                               AS "Ledger",
    CASE ledger_category_code
         WHEN 'PRIMARY'   THEN 'Primary'
         WHEN 'SECONDARY' THEN 'Secondary'
         WHEN 'ALC'       THEN 'Reporting'
         ELSE ledger_category_code
    END                                                       AS "Ledger Type",
    NVL(legal_entity_name, '-')                               AS "Legal Entity",
    segment_value                                             AS "Balancing Segment Value",
    start_date                                                AS "Start Date",
    end_date                                                  AS "End Date"
FROM     bsv
ORDER BY ledger_name, NVL(legal_entity_name, '-'), segment_value
