-- ============================================================================
--  F2.2 detail  Workbook WB2 sheet 1 "COA Segment Values"
--               (EBS: EBS_Discovery_2_2_COA_Segment_Values.xlsx, 844 rows)
--  Source    : Oracle Fusion Cloud (BIP data model, data source ApplicationDB_FSCM)
--  Mirrors   : EBS 2.2_Chart_of_Accounts_Values_Detail_v2.sql
--  No Fusion draft existed for this workbook.
--
--  GRAIN  one row per ENABLED value of every enabled segment of the COA(s) in
--         scope. Row count per segment = F2.2 "Values" for that segment -
--         the same population, the same grouping key.
--
--  OUTPUT  Ledgers | COA Structure | Seg Num | Segment | Segment Name |
--          Value Set | Parent Value | Value | Description | Account Type |
--          Allow Posting | Allow Budgeting | Summary | Start Date | End Date
--
--  FUSION DIFFERENCES - do NOT port the EBS token parsing
--    EBS kept qualifiers in COMPILED_VALUE_ATTRIBUTES (a space-delimited
--    string). Fusion keeps them in FND_VS_VALUES_B.FLEX_VALUE_ATTRIBUTE1..20,
--    and FND_VS_KF_VALUE_ATTRS says which attribute code lives in which
--    column (VALUE_TABLE_COLUMN_NAME) for each value set. This query
--    unpivots the 20 columns once and picks each qualifier by its code.
--    The codes are matched by pattern (%ACCOUNT_TYPE%, %POSTING%, %BUDGET%)
--    because the exact code strings are printed by V0_2 block F - confirm
--    them there before publishing these three columns.
--    EBS PARENT_LOW / PARENT_HIGH do not exist in Fusion (hierarchies are
--    account trees) and are not output. "Parent Value" here is the
--    INDEPENDENT value of a dependent value set, blank otherwise.
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
    SELECT  gl.ledger_id, gl.name, gl.ledger_category_code, gl.chart_of_accounts_id
    FROM        gl_ledgers gl
    LEFT JOIN   led_parent pr ON pr.ledger_id = gl.ledger_id
    CROSS JOIN  params p
    WHERE   gl.object_type_code = 'L'
    AND     NVL(gl.complete_flag, 'Y') = 'Y'
    AND     gl.chart_of_accounts_id IS NOT NULL
    AND     ( p.p_ledger_id IS NULL
              OR gl.ledger_id = TO_NUMBER(p.p_ledger_id)
              OR NVL(pr.primary_ledger_id, gl.ledger_id) = TO_NUMBER(p.p_ledger_id) )
),
coa AS (
    SELECT  chart_of_accounts_id,
            LISTAGG(name, ', ') WITHIN GROUP (ORDER BY name) AS ledgers
    FROM    led
    GROUP   BY chart_of_accounts_id
),
seg AS (
    SELECT  fs.id_flex_num,
            fs.application_column_name,
            fs.segment_num,
            COALESCE(fs.form_left_prompt, fs.segment_name) AS seg_label,
            fs.flex_value_set_id
    FROM    fnd_id_flex_segments_vl fs
    JOIN    coa c ON c.chart_of_accounts_id = fs.id_flex_num
    WHERE   fs.application_id = 101
    AND     fs.id_flex_code   = 'GL#'
    AND     fs.enabled_flag   = 'Y'
),
-- one row per (value set, parent, value) read from the BASE table - the same
-- table and key F2.2 counts - so the row count equals F2.2 "Values" exactly.
-- The description comes from FND_VS_VALUES_VL by VALUE_ID in the final
-- SELECT: a value with no row in the session language keeps its row here
-- and just shows a blank description.
vals AS (
    SELECT  *
    FROM  ( SELECT  v.value_id, v.value_set_id, v.independent_value, v.value,
                    v.summary_flag,
                    v.start_date_active, v.end_date_active,
                    v.flex_value_attribute1,  v.flex_value_attribute2,
                    v.flex_value_attribute3,  v.flex_value_attribute4,
                    v.flex_value_attribute5,  v.flex_value_attribute6,
                    v.flex_value_attribute7,  v.flex_value_attribute8,
                    v.flex_value_attribute9,  v.flex_value_attribute10,
                    v.flex_value_attribute11, v.flex_value_attribute12,
                    v.flex_value_attribute13, v.flex_value_attribute14,
                    v.flex_value_attribute15, v.flex_value_attribute16,
                    v.flex_value_attribute17, v.flex_value_attribute18,
                    v.flex_value_attribute19, v.flex_value_attribute20,
                    ROW_NUMBER() OVER (PARTITION BY v.value_set_id,
                                                    v.independent_value,
                                                    v.value
                                       ORDER BY v.value_id) AS rn
            FROM    fnd_vs_values_b v
            WHERE   v.enabled_flag = 'Y'
            AND     EXISTS ( SELECT 1 FROM seg s WHERE s.flex_value_set_id = v.value_set_id ) )
    WHERE   rn = 1
),
vals_attr AS (
    SELECT  value_id, value_set_id, col_name, attr_value
    FROM    vals
    UNPIVOT INCLUDE NULLS ( attr_value FOR col_name IN (
            flex_value_attribute1  AS 'FLEX_VALUE_ATTRIBUTE1',
            flex_value_attribute2  AS 'FLEX_VALUE_ATTRIBUTE2',
            flex_value_attribute3  AS 'FLEX_VALUE_ATTRIBUTE3',
            flex_value_attribute4  AS 'FLEX_VALUE_ATTRIBUTE4',
            flex_value_attribute5  AS 'FLEX_VALUE_ATTRIBUTE5',
            flex_value_attribute6  AS 'FLEX_VALUE_ATTRIBUTE6',
            flex_value_attribute7  AS 'FLEX_VALUE_ATTRIBUTE7',
            flex_value_attribute8  AS 'FLEX_VALUE_ATTRIBUTE8',
            flex_value_attribute9  AS 'FLEX_VALUE_ATTRIBUTE9',
            flex_value_attribute10 AS 'FLEX_VALUE_ATTRIBUTE10',
            flex_value_attribute11 AS 'FLEX_VALUE_ATTRIBUTE11',
            flex_value_attribute12 AS 'FLEX_VALUE_ATTRIBUTE12',
            flex_value_attribute13 AS 'FLEX_VALUE_ATTRIBUTE13',
            flex_value_attribute14 AS 'FLEX_VALUE_ATTRIBUTE14',
            flex_value_attribute15 AS 'FLEX_VALUE_ATTRIBUTE15',
            flex_value_attribute16 AS 'FLEX_VALUE_ATTRIBUTE16',
            flex_value_attribute17 AS 'FLEX_VALUE_ATTRIBUTE17',
            flex_value_attribute18 AS 'FLEX_VALUE_ATTRIBUTE18',
            flex_value_attribute19 AS 'FLEX_VALUE_ATTRIBUTE19',
            flex_value_attribute20 AS 'FLEX_VALUE_ATTRIBUTE20' ) )
),
qual_map AS (
    SELECT  va.value_set_id, va.value_attribute_code, va.value_table_column_name
    FROM    fnd_vs_kf_value_attrs va
    WHERE   va.application_id     = 101
    AND     va.key_flexfield_code = 'GL#'
    GROUP   BY va.value_set_id, va.value_attribute_code, va.value_table_column_name
),
quals AS (
    SELECT  a.value_id,
            MAX(CASE WHEN m.value_attribute_code LIKE '%ACCOUNT_TYPE%' THEN a.attr_value END) AS account_type,
            MAX(CASE WHEN m.value_attribute_code LIKE '%POSTING%'      THEN a.attr_value END) AS allow_posting,
            MAX(CASE WHEN m.value_attribute_code LIKE '%BUDGET%'       THEN a.attr_value END) AS allow_budgeting
    FROM    vals_attr a
    JOIN    qual_map  m ON m.value_set_id            = a.value_set_id
                       AND m.value_table_column_name = a.col_name
    GROUP   BY a.value_id
)
SELECT
    c.ledgers                                                 AS "Ledgers",
    NVL(( SELECT MAX(fst.id_flex_structure_name)
          FROM   fnd_id_flex_structures_vl fst
          WHERE  fst.application_id = 101
          AND    fst.id_flex_code   = 'GL#'
          AND    fst.id_flex_num    = c.chart_of_accounts_id ), '(unnamed)')
                                                              AS "COA Structure",
    s.segment_num                                             AS "Seg Num",
    s.application_column_name                                 AS "Segment",
    s.seg_label                                               AS "Segment Name",
    vs.flex_value_set_name                                    AS "Value Set",
    v.independent_value                                       AS "Parent Value",
    v.value                                                   AS "Value",
    ( SELECT MAX(t.description)
      FROM   fnd_vs_values_vl t
      WHERE  t.value_id = v.value_id )                        AS "Description",
    q.account_type                                            AS "Account Type",
    q.allow_posting                                           AS "Allow Posting",
    q.allow_budgeting                                         AS "Allow Budgeting",
    v.summary_flag                                            AS "Summary",
    v.start_date_active                                       AS "Start Date",
    v.end_date_active                                         AS "End Date"
FROM        coa                 c
JOIN        seg                 s  ON s.id_flex_num = c.chart_of_accounts_id
JOIN        vals                v  ON v.value_set_id = s.flex_value_set_id
LEFT JOIN   fnd_flex_value_sets vs ON vs.flex_value_set_id = s.flex_value_set_id
LEFT JOIN   quals               q  ON q.value_id = v.value_id
ORDER BY
    c.ledgers,
    s.segment_num,
    v.independent_value,
    v.value
