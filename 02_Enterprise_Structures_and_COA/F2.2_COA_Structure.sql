-- ============================================================================
--  F2.2  Section 2.2 Chart of accounts structure
--  Source    : Oracle Fusion Cloud (BIP data model, data source ApplicationDB_FSCM)
--  Mirrors   : EBS 2.2_Chart_of_Accounts_Structure_v2.sql (report 30-Sep-2026:
--              5 segments - Company/Balancing 24, Department/Cost Center 100,
--              Account/Natural Account 526, Sub-Account 161, Product 33)
--  Replaces  : Fusion draft chart_of_accounts.sql, which had no Segment
--              column name, no Qualifier, no ledger list, the reserved word
--              VALUES as an alias (local copy), and a mandatory bind.
--
--  GRAIN  one row per COA structure x enabled segment. A chart shared by a
--         primary and its secondary prints once, with both ledgers listed -
--         the report heading reads "Vision Operations (USA), IAS Reporting
--         Vision Ops" for exactly this reason.
--
--  OUTPUT  Segment | Name | Qualifier | Values | Size   (the report's columns)
--    v1.1: the Ledgers and COA Structure columns were removed from the output
--    (user, 2026-10-01). Logic unchanged: same rows, same order - rows are
--    still sorted by ledger type and ledger list, so each chart's segments stay
--    together. The ledger names are the report HEADING ("Vision Operations
--    (USA), IAS Reporting Vision Ops"), not a column.
--
--  FUSION DIFFERENCES (verified 2026-09-30, Tables and Views for Common Features)
--    FND_ID_FLEX_SEGMENTS_VL is a compatibility view over FND_KF_* structure
--    INSTANCES. ID_FLEX_NUM = structure instance number = GL_LEDGERS
--    .CHART_OF_ACCOUNTS_ID. SEGMENT_NAME is the segment CODE; the display
--    name is FORM_LEFT_PROMPT (hence COALESCE in that order). The view joins
--    its _TL on USERENV('LANG'), one row per segment.
--    Values are counted from FND_VS_VALUES_B (the Fusion value table),
--    enabled only, grouped on (value set, parent value, value) so a value in
--    a dependent value set counts once per parent (EBS parity) and any
--    duplicate storage rows cannot inflate the count (V0_2 block E).
--    Qualifiers use FND_SEGMENT_ATTRIBUTE_VALUES - an EBS-compatibility view
--    that exists in Fusion. Its columns are CHECKED by V0_1 block B before
--    this runs. The qualifier rule is the EBS one unchanged: keep segment-
--    level qualifiers, drop any qualifier present on EVERY segment, expand
--    the abbreviations (GL_BALANCING -> Balancing Segment, GL_ACCOUNT ->
--    Natural Account Segment, FA_COST_CTR -> Cost Center Segment).
--
--  PARAMETERS  :p_ledger_id optional; bound -> that ledger's family (primary
--              + secondary/reporting). Others accepted, not used.
--  Version   : 1.1 (2026-10-01: output trimmed to the report's 5 columns;
--              1.0 built 2026-09-30). Not yet run on a pod.
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
            LISTAGG(name, ', ') WITHIN GROUP (
                ORDER BY CASE ledger_category_code WHEN 'PRIMARY' THEN 1
                                                   WHEN 'SECONDARY' THEN 2
                                                   WHEN 'ALC' THEN 3 ELSE 4 END,
                         name)                       AS ledgers,
            MIN(CASE ledger_category_code WHEN 'PRIMARY' THEN 1
                                          WHEN 'SECONDARY' THEN 2
                                          WHEN 'ALC' THEN 3 ELSE 4 END) AS type_rank
    FROM    led
    GROUP   BY chart_of_accounts_id
),
seg AS (
    SELECT  fs.id_flex_num,
            fs.application_column_name,
            fs.segment_num,
            COALESCE(fs.form_left_prompt, fs.segment_name) AS seg_label,
            fs.display_size,
            fs.flex_value_set_id
    FROM    fnd_id_flex_segments_vl fs
    JOIN    coa c ON c.chart_of_accounts_id = fs.id_flex_num
    WHERE   fs.application_id = 101
    AND     fs.id_flex_code   = 'GL#'
    AND     fs.enabled_flag   = 'Y'
),
val_cnt AS (
    SELECT  value_set_id, COUNT(*) AS n
    FROM  ( SELECT v.value_set_id, v.independent_value, v.value
            FROM   fnd_vs_values_b v
            WHERE  v.enabled_flag = 'Y'
            AND    EXISTS ( SELECT 1 FROM seg s WHERE s.flex_value_set_id = v.value_set_id )
            GROUP  BY v.value_set_id, v.independent_value, v.value )
    GROUP   BY value_set_id
),
-- ---- qualifiers (EBS rule, unchanged) -------------------------------------
seg_qual AS (
    SELECT  sav.id_flex_num,
            sav.application_column_name,
            sav.segment_attribute_type
    FROM    fnd_segment_attribute_values sav
    JOIN    coa c ON c.chart_of_accounts_id = sav.id_flex_num
    WHERE   sav.application_id = 101
    AND     sav.id_flex_code   = 'GL#'
    AND     NVL(sav.attribute_value, 'N') <> 'N'
    GROUP   BY sav.id_flex_num, sav.application_column_name, sav.segment_attribute_type
),
struct_seg AS (
    SELECT  id_flex_num, COUNT(*) AS seg_count
    FROM  ( SELECT id_flex_num, application_column_name
            FROM   seg_qual
            GROUP  BY id_flex_num, application_column_name )
    GROUP   BY id_flex_num
),
qual_spread AS (
    SELECT  id_flex_num, segment_attribute_type, COUNT(*) AS seg_hits
    FROM    seg_qual
    GROUP   BY id_flex_num, segment_attribute_type
),
qual_label AS (
    SELECT  sq.id_flex_num,
            sq.application_column_name,
            sq.segment_attribute_type,
            CASE WHEN lbl LIKE 'Account %' THEN 'Natural ' || lbl ELSE lbl END AS label
    FROM  ( SELECT  sq0.id_flex_num, sq0.application_column_name, sq0.segment_attribute_type,
                    REPLACE(REPLACE(
                        INITCAP(REPLACE(SUBSTR(sq0.segment_attribute_type,
                                               INSTR(sq0.segment_attribute_type, '_') + 1),
                                        '_', ' ')) || ' Segment',
                        'Ctr ', 'Center '), 'Ctre ', 'Centre ') AS lbl
            FROM    seg_qual sq0 ) sq
    JOIN    qual_spread qs
           ON qs.id_flex_num = sq.id_flex_num
          AND qs.segment_attribute_type = sq.segment_attribute_type
    JOIN    struct_seg ss
           ON ss.id_flex_num = sq.id_flex_num
    WHERE   ss.seg_count = 1
       OR   qs.seg_hits  < ss.seg_count
),
qual_rollup AS (
    SELECT  id_flex_num, application_column_name,
            LISTAGG(label, ', ') WITHIN GROUP (ORDER BY segment_attribute_type) AS qualifiers
    FROM    qual_label
    GROUP   BY id_flex_num, application_column_name
)
SELECT
    s.application_column_name                                 AS "Segment",
    s.seg_label                                               AS "Name",
    NVL(q.qualifiers, '-')                                    AS "Qualifier",
    NVL(vc.n, 0)                                              AS "Values",
    s.display_size                                            AS "Size"
FROM        coa         c
JOIN        seg         s  ON s.id_flex_num = c.chart_of_accounts_id
LEFT JOIN   val_cnt     vc ON vc.value_set_id = s.flex_value_set_id
LEFT JOIN   qual_rollup q  ON q.id_flex_num = s.id_flex_num
                          AND q.application_column_name = s.application_column_name
ORDER BY
    c.type_rank,
    c.ledgers,
    s.segment_num
