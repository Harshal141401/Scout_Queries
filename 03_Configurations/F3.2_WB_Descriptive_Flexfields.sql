-- ============================================================================
--  F3.2 WB  Descriptive Flexfields workbook - one row per counted segment
--  Workbook  : Fusion_Discovery_3_2_Descriptive_Flexfields.xlsx
--              (EBS: EBS_Discovery_3_2_Descriptive_Flexfields.xlsx, 695 rows)
--  Version   : 1.0 (2026-10-05). Not yet run on a pod.
--              RUN V3_1 FIRST. Log every run in 06_Run_Results/RUN_LOG.md.
--  Mirrors   : EBS agent _DFF_DETAIL_SQL
--  RECONCILES  F3.2 summary: per APPLICATION, distinct DFF_NAME = DFFs and row
--              count = Enabled Segments. Same population, built from the same
--              CTEs (seg_keyed / user_accts / filters copied unchanged).
--
--  COLUMNS (EBS order) APPLICATION, DFF_NAME, DFF_TITLE, BASE_TABLE,
--    CONTEXT_CODE, CONTEXT_NAME, SEGMENT_SEQ, SEGMENT_NAME, COLUMN_NAME, PROMPT,
--    REQUIRED, DISPLAYED, SIZE_CHARS, VALUE_SET
--    + CREATED_BY, LAST_UPDATED_BY (Fusion addition: the evidence behind the
--      "customer-edited" rule, so a reviewer can see why a segment counts).
--    DFF_NAME      DESCRIPTIVE_FLEXFIELD_CODE (EBS DESCRIPTIVE_FLEXFIELD_NAME)
--    SEGMENT_NAME  SEGMENT_CODE (EBS END_USER_COLUMN_NAME - same mapping as
--                  Oracle's own FND_DESCR_FLEX_COLUMN_USAGES view)
--    DISPLAYED     'N' when DISPLAY_TYPE = 'HIDDEN', else 'Y' (Oracle's own
--                  compatibility-view rule)
--    SIZE_CHARS    DISPLAY_WIDTH
--    DFF_TITLE / CONTEXT_NAME / PROMPT  from the _TL tables with ONE language
--                  per key (session first, then 'US'). The _VL views are not
--                  used: they filter T.LANGUAGE = USERENV('LANG') and would
--                  drop a row whose text exists only in 'US'.
--    BASE_TABLE    FND_DESCRIPTIVE_FLEXS.APPLICATION_TABLE_NAME (Oracle's
--                  compatibility view), listed once per DFF; a DFF used on
--                  several tables lists them all, so it never adds rows.
--    VALUE_SET     FND_FLEX_VALUE_SETS.FLEX_VALUE_SET_NAME (as F2.2).
--
--  WHAT COUNTS (EBS rule, ported; columns verified on the Oracle Fusion
--  Common Features pages 2026-10-05, re-checked on the pod by V3_1)
--    EBS read FND_DESCR_FLEX_COLUMN_USAGES. In Fusion that name is a
--    compatibility VIEW over FND_DF_SEGMENTS_B with one filter:
--    CONTEXT_CODE <> 'Context Data Element' (the context switch itself, not a
--    business segment). This query reads FND_DF_SEGMENTS_B with that same
--    filter, so it counts exactly what the EBS-named view would.
--    ENABLED      segment ENABLED_FLAG = 'Y' (EBS parity)
--    CUSTOMER     EBS: NVL(LAST_UPDATE_LOGIN,0) > 0 = "last edited in a real
--                 user session". Fusion LAST_UPDATE_LOGIN is a session string,
--                 not a number, so the same idea is read from data instead:
--                 LAST_UPDATED_BY is a real user account (UPPER match on
--                 PER_USERS.USERNAME). Oracle seed / patch identities are not
--                 user accounts and drop out - no typed list of seed users
--                 (the June draft's typed list zeroed every segment).
--    EXCLUDED     DFF code LIKE '$SRS$.%' (EBS report-parameter flexfield;
--                 matches nothing in Fusion, kept for parity) and DFF code
--                 containing INTERFACE (import staging tables - EBS rule).
--    ONE ROW PER SEGMENT  FND_DF_SEGMENTS_B is keyed on application, DFF,
--                 context, segment PLUS ENTERPRISE_ID and SANDBOX_ID, so the
--                 segments are grouped on the four business keys first -
--                 a sandbox copy can never count twice.
--  APPLICATIONS  EBS limited 3.2 to the 16 assessed modules (typed list).
--    Here the assessed applications are read from the registry exactly as
--    Section 1 does (block copied from F1: the 17 assessed tables ->
--    FND_TABLES -> FND_APPLICATION_VL), and every one prints, zeros included.
--    Fusion moved some flexfields into applications Section 1 does not assess
--    (e.g. supplier DFFs under POZ, customer DFFs under HZ). Those segments
--    are NOT dropped: they print as extra rows labelled
--    '<APP> (outside Section 1 scope)', after the assessed applications.
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
-- ---- SECTION 1 ASSESSED APPLICATIONS (copied unchanged from F1) ----------
--  The 17 tables Section 1 reads, looked up in FND_TABLES ->
--  FND_APPLICATION_VL, so 3.2 covers exactly the applications Section 1
--  assesses. Keep in step with F1 if a table is added there.
src_tables AS (
    SELECT 'GL_JE_HEADERS' AS src_table FROM dual
    UNION ALL
    SELECT 'AP_INVOICES_ALL' FROM dual
    UNION ALL
    SELECT 'RA_CUSTOMER_TRX_ALL' FROM dual
    UNION ALL
    SELECT 'PO_HEADERS_ALL' FROM dual
    UNION ALL
    SELECT 'POR_REQUISITION_HEADERS_ALL' FROM dual
    UNION ALL
    SELECT 'DOO_HEADERS_ALL' FROM dual
    UNION ALL
    SELECT 'INV_MATERIAL_TXNS' FROM dual
    UNION ALL
    SELECT 'CE_STATEMENT_HEADERS' FROM dual
    UNION ALL
    SELECT 'CST_COST_DISTRIBUTIONS' FROM dual
    UNION ALL
    SELECT 'FA_TRANSACTION_HEADERS' FROM dual
    UNION ALL
    SELECT 'PJC_EXP_ITEMS_ALL' FROM dual
    UNION ALL
    SELECT 'WIE_WORK_ORDERS_B' FROM dual
    UNION ALL
    SELECT 'EGP_STRUCTURES_B' FROM dual
    UNION ALL
    SELECT 'WSH_NEW_DELIVERIES' FROM dual
    UNION ALL
    SELECT 'EXM_EXPENSE_REPORTS' FROM dual
    UNION ALL
    SELECT 'FLA_LEASES_ALL' FROM dual
    UNION ALL
    SELECT 'FUN_TRX_HEADERS' FROM dual
),
-- ---- MODULE = OWNING APPLICATION, READ FROM FUSION'S OWN REGISTRY -----------
--  No module name or code is typed in this query. Each assessed table is
--  looked up in FND_TABLES (the Fusion table registry), whose
--  APPLICATION_SHORT_NAME is the application that owns the table. The display
--  name and application id come from FND_APPLICATION_VL, matched on
--  APPLICATION_SHORT_NAME. (Fusion FND_TABLES has NO APPLICATION_ID column -
--  ORA-00904 on the pod, 2026-10-01.)
--    - registered and named      -> '<application name> (<short name>)'
--    - registered, no name row   -> '<short name>'   (still read from data)
--    - not registered            -> 'Not registered: <TABLE>' (never guessed)
--  The table is matched on TABLE_NAME or PHYSICAL_TABLE_NAME (both confirmed
--  on the pod by V0_0, 2026-10-01), so a logical/physical naming difference
--  cannot turn a registered table into 'Not registered'.
--  MIN() makes the lookup one row per table even if a table were registered
--  under two applications (V0_3 block G prints the registration count).
tab_app AS (
    SELECT  s.src_table,
            MIN(ft.application_short_name) AS app_short
    FROM        src_tables s
    LEFT JOIN   fnd_tables ft
           ON   ft.table_name          = s.src_table
            OR  ft.physical_table_name = s.src_table
    GROUP   BY  s.src_table
),
app_names AS (
    SELECT  a.application_short_name      AS short_name,
            MIN(a.application_id)         AS application_id,
            MAX(a.application_name)       AS app_name
    FROM    fnd_application_vl a
    WHERE   EXISTS ( SELECT 1 FROM tab_app t
                     WHERE  t.app_short = a.application_short_name )
    GROUP   BY a.application_short_name
),
-- ---- segments: one row per business key -----------------------------------
seg_keyed AS (
    SELECT  s.application_id,
            s.descriptive_flexfield_code,
            s.context_code,
            s.segment_code,
            MAX(s.enabled_flag)     AS enabled_flag,
            MAX(s.last_updated_by)  AS last_updated_by,
            MAX(s.created_by)       AS created_by,
            MAX(s.column_name)      AS column_name,
            MAX(s.sequence_number)  AS seg_seq,
            MAX(s.required_flag)    AS required_flag,
            MAX(s.display_type)     AS display_type,
            MAX(s.display_width)    AS display_width,
            MAX(s.value_set_id)     AS value_set_id
    FROM    fnd_df_segments_b s
    WHERE   s.context_code <> 'Context Data Element'
    AND     s.descriptive_flexfield_code NOT LIKE '$SRS$.%'
    AND     UPPER(s.descriptive_flexfield_code) NOT LIKE '%INTERFACE%'
    GROUP   BY s.application_id, s.descriptive_flexfield_code,
               s.context_code, s.segment_code
),
-- user accounts (a person, an implementer, an integration user...) - one row each
user_accts AS (
    SELECT  UPPER(pu.username) AS uname
    FROM    per_users pu
    WHERE   pu.username IS NOT NULL
    GROUP   BY UPPER(pu.username)
),
-- application short name for ANY application id (labels outside-scope rows)
all_apps AS (
    SELECT  a.application_id, MAX(a.application_short_name) AS app_short
    FROM    fnd_application_vl a
    GROUP   BY a.application_id
),
-- the counted segments: enabled AND last edited by a user account
custom_segs AS (
    SELECT  k.*
    FROM        seg_keyed  k
    JOIN        user_accts ua ON ua.uname = UPPER(k.last_updated_by)
    WHERE       k.enabled_flag = 'Y'
),
-- ---- names, one language per key ------------------------------------------
flex_titles AS (
    SELECT  t.application_id, t.descriptive_flexfield_code,
            MAX(t.name) KEEP (DENSE_RANK FIRST ORDER BY
                CASE WHEN t.language = USERENV('LANG') THEN 0 ELSE 1 END)  AS dff_title
    FROM    fnd_df_flexfields_tl t
    WHERE   t.language IN (USERENV('LANG'), 'US')
    GROUP   BY t.application_id, t.descriptive_flexfield_code
),
ctx_names AS (
    SELECT  t.application_id, t.descriptive_flexfield_code, t.context_code,
            MAX(t.name) KEEP (DENSE_RANK FIRST ORDER BY
                CASE WHEN t.language = USERENV('LANG') THEN 0 ELSE 1 END)  AS ctx_name
    FROM    fnd_df_contexts_tl t
    WHERE   t.language IN (USERENV('LANG'), 'US')
    GROUP   BY t.application_id, t.descriptive_flexfield_code, t.context_code
),
seg_prompts AS (
    SELECT  t.application_id, t.descriptive_flexfield_code, t.context_code,
            t.segment_code,
            MAX(t.prompt) KEEP (DENSE_RANK FIRST ORDER BY
                CASE WHEN t.language = USERENV('LANG') THEN 0 ELSE 1 END)  AS prompt
    FROM    fnd_df_segments_tl t
    WHERE   t.language IN (USERENV('LANG'), 'US')
    GROUP   BY t.application_id, t.descriptive_flexfield_code, t.context_code,
               t.segment_code
),
-- base table(s) per DFF, only for DFFs that have counted segments
base_tables AS (
    SELECT  application_id, descriptive_flexfield_name,
            LISTAGG(application_table_name, ', ')
                WITHIN GROUP (ORDER BY application_table_name)      AS base_table
    FROM  ( SELECT f.application_id, f.descriptive_flexfield_name,
                   f.application_table_name
            FROM   fnd_descriptive_flexs f
            WHERE  f.application_table_name IS NOT NULL
            AND    EXISTS ( SELECT 1 FROM custom_segs c
                            WHERE  c.application_id             = f.application_id
                            AND    c.descriptive_flexfield_code = f.descriptive_flexfield_name )
            GROUP  BY f.application_id, f.descriptive_flexfield_name,
                      f.application_table_name )
    GROUP   BY application_id, descriptive_flexfield_name
),
value_sets AS (
    SELECT  vs.flex_value_set_id, MAX(vs.flex_value_set_name) AS vs_name
    FROM    fnd_flex_value_sets vs
    GROUP   BY vs.flex_value_set_id
),
-- application label, identical to the F3.2 summary
app_label AS (
    SELECT  c.application_id,
            CASE WHEN MAX(an.short_name) IS NOT NULL THEN 1 ELSE 2 END    AS grp,
            NVL(MAX(an.short_name),
                NVL(MAX(aa.app_short), TO_CHAR(c.application_id))
                  || ' (outside Section 1 scope)')                       AS app_label
    FROM        ( SELECT application_id FROM custom_segs GROUP BY application_id ) c
    LEFT JOIN   app_names an ON an.application_id = c.application_id
    LEFT JOIN   all_apps  aa ON aa.application_id = c.application_id
    GROUP   BY  c.application_id
)
SELECT
    al.app_label                                              AS "APPLICATION",
    c.descriptive_flexfield_code                              AS "DFF_NAME",
    ft.dff_title                                              AS "DFF_TITLE",
    bt.base_table                                             AS "BASE_TABLE",
    c.context_code                                            AS "CONTEXT_CODE",
    cn.ctx_name                                               AS "CONTEXT_NAME",
    c.seg_seq                                                 AS "SEGMENT_SEQ",
    c.segment_code                                            AS "SEGMENT_NAME",
    c.column_name                                             AS "COLUMN_NAME",
    sp.prompt                                                 AS "PROMPT",
    c.required_flag                                           AS "REQUIRED",
    CASE WHEN c.display_type = 'HIDDEN' THEN 'N' ELSE 'Y' END AS "DISPLAYED",
    c.display_width                                           AS "SIZE_CHARS",
    vs.vs_name                                                AS "VALUE_SET",
    c.created_by                                              AS "CREATED_BY",
    c.last_updated_by                                         AS "LAST_UPDATED_BY"
FROM        custom_segs c
JOIN        app_label   al ON al.application_id = c.application_id
LEFT JOIN   flex_titles ft ON ft.application_id             = c.application_id
                          AND ft.descriptive_flexfield_code = c.descriptive_flexfield_code
LEFT JOIN   base_tables bt ON bt.application_id             = c.application_id
                          AND bt.descriptive_flexfield_name = c.descriptive_flexfield_code
LEFT JOIN   ctx_names   cn ON cn.application_id             = c.application_id
                          AND cn.descriptive_flexfield_code = c.descriptive_flexfield_code
                          AND cn.context_code               = c.context_code
LEFT JOIN   seg_prompts sp ON sp.application_id             = c.application_id
                          AND sp.descriptive_flexfield_code = c.descriptive_flexfield_code
                          AND sp.context_code               = c.context_code
                          AND sp.segment_code               = c.segment_code
LEFT JOIN   value_sets  vs ON vs.flex_value_set_id          = c.value_set_id
ORDER BY    al.grp, al.app_label, c.descriptive_flexfield_code,
            c.context_code, c.seg_seq, c.segment_code
