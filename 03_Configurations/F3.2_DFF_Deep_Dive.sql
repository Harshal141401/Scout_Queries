-- ============================================================================
--  F3.2  Section 3.2 Descriptive flexfield deep-dive
--  Version   : 1.0 (2026-10-05). Not yet run on a pod.
--              RUN V3_1 FIRST. Log every run in 06_Run_Results/RUN_LOG.md.
--  Source    : Oracle Fusion Cloud (BIP data model, data source ApplicationDB_FSCM)
--  Mirrors   : EBS agent _DFF_SUMMARY_SQL (report 30-Sep-2026, Vision: AR 17/196,
--              PA 4/187, INV 11/185 ... - EBS numbers, not targets)
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
            MAX(s.last_updated_by)  AS last_updated_by
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
    SELECT  k.application_id, k.descriptive_flexfield_code
    FROM        seg_keyed  k
    JOIN        user_accts ua ON ua.uname = UPPER(k.last_updated_by)
    WHERE       k.enabled_flag = 'Y'
),
dff_by_app AS (
    SELECT  application_id, COUNT(*) AS dffs
    FROM  ( SELECT application_id, descriptive_flexfield_code
            FROM   custom_segs
            GROUP  BY application_id, descriptive_flexfield_code )
    GROUP   BY application_id
),
seg_by_app AS (
    SELECT  application_id, COUNT(*) AS segs
    FROM    custom_segs
    GROUP   BY application_id
),
-- assessed applications: every one prints, zeros included
scoped_rows AS (
    SELECT  1                       AS grp,
            an.short_name           AS app_label,
            NVL(d.dffs, 0)          AS dffs,
            NVL(sg.segs, 0)         AS segs
    FROM        app_names  an
    LEFT JOIN   dff_by_app d  ON d.application_id  = an.application_id
    LEFT JOIN   seg_by_app sg ON sg.application_id = an.application_id
),
-- applications outside Section 1 that still hold counted segments
outside_rows AS (
    SELECT  2                                                   AS grp,
            NVL(aa.app_short, TO_CHAR(sg.application_id))
              || ' (outside Section 1 scope)'                   AS app_label,
            NVL(d.dffs, 0)                                      AS dffs,
            sg.segs                                             AS segs
    FROM        seg_by_app sg
    LEFT JOIN   dff_by_app d  ON d.application_id  = sg.application_id
    LEFT JOIN   all_apps   aa ON aa.application_id = sg.application_id
    WHERE   NOT EXISTS ( SELECT 1 FROM app_names an
                         WHERE  an.application_id = sg.application_id )
),
dff_table AS (
    SELECT grp, app_label, dffs, segs FROM scoped_rows
    UNION ALL
    SELECT grp, app_label, dffs, segs FROM outside_rows
)
SELECT
    t.app_label                                               AS "Application",
    t.dffs                                                    AS "DFFs",
    t.segs                                                    AS "Enabled Segments"
FROM        dff_table t
ORDER BY    t.grp, t.segs DESC, t.app_label
