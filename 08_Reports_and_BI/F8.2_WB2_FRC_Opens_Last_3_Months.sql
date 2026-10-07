-- ============================================================================
--  F8.2_WB2  Section 8.2 workbook WB9, sheet 2: reports opened from the
--            Financial Reporting Center in the last 3 months
--  Version   : 1.0 (2026-10-06). Not yet run on a pod. New file.
--  Source    : Oracle Fusion Cloud (BIP data model, data source ApplicationDB_FSCM)
--  Window    : OPERATIONAL, from the run day: 6 months (logwin), 3 months for the
--              workbook (win3). The discovery-window dates are accepted and
--              ignored. ESS keeps only recent history (R035: from 2026-09-21 on
--              this pod), so ESS counts cover only the retained part.
--  Reads     : GL_FRC_REPORTS_B, GL_FRC_REPORTS_TL, GL_FRC_USER_ACCESS_REPORTS,
--              ESS_REQUEST_HISTORY (readable although the data dictionary shows
--              no column: R034 / R035) and the shared-block tables.
--  Run order : V8_1 v1.1 first (it prints every value these rules produce).
--              Log every run in 06_Run_Results/RUN_LOG.md.
--  Mirrors   : no EBS sheet. Added because Fusion's run log (ESS) misses reports
--              opened online; the FRC log records opens from the Financial
--              Reporting Center (one row per user and report, last open only).
--  File      : Fusion_Discovery_8_2_Reports_Run_Last_3_Months.xlsx, sheet 2
--
--  OUTPUT  User | Report | Report Type | Custom | Product Area | Last Open |
--          Catalog Path
--    One row per user and report (a dashboard page counts as its dashboard)
--    whose last FRC open falls in the window, most recent first.
--    Expected on this pod (R033): 4 rows (SVC and INDIRAR, financial reports).
-- ============================================================================
WITH
-- ---- PARAMS / WINDOW / SCOPE: copied unchanged from F1 (shared block v3.1).
--      Section 8 reads only led_scope (F8.1 account groups); the rest is kept
--      for parity with every other query. The discovery window (win) is NOT
--      used: Section 8 measures operational time (logwin / win3 below).
params AS (
    SELECT :p_ledger_id     AS p_ledger_id,
           :p_bu_id         AS p_bu_id,
           :p_custom_prefix AS p_custom_prefix,
           :p_from_date     AS p_from_date,
           :p_to_date       AS p_to_date
    FROM   dual
),
-- ---- WINDOW: identical in F0 and F1 -------------------------------------
win AS (
    SELECT NVL(TO_DATE(p.p_from_date, 'YYYY-MM-DD'), TRUNC(SYSDATE) - 90) AS start_date,
           NVL(TO_DATE(p.p_to_date,   'YYYY-MM-DD'), TRUNC(SYSDATE)) + 1  AS end_date_excl
    FROM   params p
),
-- ---- SCOPE BLOCK: identical in F0 and F1 --------------------------------
led_scope AS (
    SELECT gl.ledger_id
    FROM   gl_ledgers gl
    CROSS  JOIN params p
    WHERE  gl.object_type_code = 'L'
    AND    NVL(gl.complete_flag, 'Y') = 'Y'
    AND    (p.p_ledger_id IS NULL OR gl.ledger_id = TO_NUMBER(p.p_ledger_id))
),
-- FUN_ALL_BUSINESS_UNITS_V.PRIMARY_LEDGER_ID is ORG_INFORMATION3 (a string),
-- so it is compared as a string. A BU whose classification STATUS is
-- inactive ('I' / 'INACTIVE') is excluded - the Fusion counterpart of the EBS
-- W3-Houston "disabled OU" rule. The view itself already drops BUs whose
-- effective dates have ended. V0_2 block A prints the STATUS values present.
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
inv_org_scope AS (
    SELECT iod.organization_id
    FROM   inv_organization_definitions_v iod
    CROSS  JOIN params p
    WHERE  (p.p_ledger_id IS NULL OR iod.set_of_books_id = TO_NUMBER(p.p_ledger_id))
    GROUP  BY iod.organization_id
),
fa_book_scope AS (
    SELECT fbc.book_type_code
    FROM   fa_book_controls fbc
    CROSS  JOIN params p
    WHERE  (p.p_ledger_id IS NULL OR fbc.set_of_books_id = TO_NUMBER(p.p_ledger_id))
    GROUP  BY fbc.book_type_code
),
-- ---- SECTION 8 BLOCK v1.1 (2026-10-06): catalog objects + recorded use -----
--      Byte-identical in F8.1, F8.2a, F8.2b, F8.2c, F8.2_WB1, F8.2_WB2 and V8_1,
--      so every Section 8 number comes from one population. Change all seven
--      or none. v1.0 (catalog only) is frozen in 06_Run_Results/query_snapshots.
-- logwin / win3: operational windows measured from the run day (the EBS
-- agent's _logwin_cte and its 3-month workbook window), not the discovery
-- window.
logwin AS (
    SELECT ADD_MONTHS(TRUNC(SYSDATE), -6) AS start_date,
           TRUNC(SYSDATE) + 1             AS end_date_excl
    FROM   dual
),
win3 AS (
    SELECT ADD_MONTHS(TRUNC(SYSDATE), -3) AS start_date,
           SYSDATE                        AS end_date
    FROM   dual
),
-- s8_items: one row per item of the four report types in the SHARED BI
-- catalog (GL_FRC_REPORTS_B). Financial Reporting stores its paths as
-- '/Shared Folders/...' (R032): they are read as '/shared/...'. Grain = type +
-- path (R032 B0: no duplicate). Personal folders and the '... dummy'
-- placeholder rows are left out; account groups are counted from
-- GL_ACCOUNT_GROUPS in F8.1. LAST_ACCESSED_DATE is NOT read: it equals
-- LAST_MODIFIED_DATE on every item (R033), so it records edits, not use.
s8_items AS (
    SELECT UPPER(r.report_type_code)                                       AS type_code,
           TO_CHAR(REGEXP_REPLACE(r.report_path, '^/shared folders/', '/shared/',
                                  1, 1, 'i'))                              AS norm_path,
           MIN(r.report_id)                                                AS report_id,
           MAX(r.last_modified_date)                                       AS last_modified,
           MAX(TO_CHAR(r.author_display_name))                             AS author,
           MAX(TO_CHAR(r.bip_report_job_definition))                       AS job_def
    FROM   gl_frc_reports_b r
    WHERE  (   LOWER(r.report_path) LIKE '/shared/%'
            OR LOWER(r.report_path) LIKE '/shared folders/%' )
    AND    UPPER(r.report_type_code) IN ('BIP', 'ANALYSIS', 'DASHBOARD', 'FR')
    GROUP  BY UPPER(r.report_type_code),
              TO_CHAR(REGEXP_REPLACE(r.report_path, '^/shared folders/', '/shared/',
                                     1, 1, 'i'))
),
-- s8_path: the custom flag (the Section 5 marker: under /shared/Custom/,
-- compared lower-cased) and the path with every '/' inside a name (stored as
-- '\/', R033) replaced by CHR(31) while the path is split.
s8_path AS (
    SELECT i.type_code, i.norm_path, i.report_id, i.last_modified, i.author, i.job_def,
           CASE WHEN LOWER(i.norm_path) LIKE '/shared/custom/%'
                THEN 'Y' ELSE 'N' END                                      AS is_custom,
           REPLACE(i.norm_path, '\/', CHR(31))                             AS path_u
    FROM   s8_items i
),
-- s8_obj_row: the object each index row belongs to. A Dashboard row is a PAGE
-- (R033): its object is the dashboard, i.e. the parent folder, or the row
-- itself when it sits directly in a '_portal' folder (R035: custom 57).
s8_obj_row AS (
    SELECT p.type_code, p.report_id, p.last_modified, p.author, p.job_def, p.is_custom,
           CASE WHEN p.type_code = 'DASHBOARD'
                 AND LOWER(NVL(REGEXP_SUBSTR(REGEXP_REPLACE(p.path_u, '/[^/]*$', ''),
                                             '[^/]+$'), '-')) <> '_portal'
                THEN REGEXP_REPLACE(p.path_u, '/[^/]*$', '')
                ELSE p.path_u
           END                                                             AS obj_u
    FROM   s8_path p
),
-- s8_obj: one row per report, analysis, financial report or dashboard
-- (n_rows = the dashboard's pages; 1 for every other type)
s8_obj AS (
    SELECT o.type_code, o.obj_u,
           MAX(o.is_custom)                                                AS is_custom,
           COUNT(*)                                                        AS n_rows,
           MIN(o.report_id)                                                AS report_id,
           MAX(o.last_modified)                                            AS last_modified,
           MAX(o.author)                                                   AS author,
           MAX(o.job_def)                                                  AS job_def
    FROM   s8_obj_row o
    GROUP  BY o.type_code, o.obj_u
),
-- s8_name: the display name of each catalog item (GL_FRC_REPORTS_TL; R033:
-- every item has one), session language first, else US
s8_name AS (
    SELECT t.report_id,
           MAX(TO_CHAR(t.report_display_name)) KEEP (DENSE_RANK FIRST ORDER BY
               CASE WHEN t.language = USERENV('LANG') THEN 0 ELSE 1 END)   AS disp
    FROM   gl_frc_reports_tl t
    WHERE  t.language IN (USERENV('LANG'), 'US')
    GROUP  BY t.report_id
),
-- s8_fold / s8_lvl: the object's folder below /shared/ or /shared/Custom/,
-- '_portal' dashboard folders skipped, split into level 1 / level 2
s8_fold AS (
    SELECT o.type_code, o.obj_u, o.is_custom, o.n_rows, o.report_id, o.last_modified,
           o.author, o.job_def,
           REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(o.obj_u, '/[^/]*$', '') || '/',
                                         '/_portal/', '/', 1, 0, 'i'),
                          '^/shared/(custom/)?', '', 1, 1, 'i')            AS rel_u
    FROM   s8_obj o
),
s8_lvl AS (
    SELECT f.type_code, f.obj_u, f.is_custom, f.n_rows, f.report_id, f.last_modified,
           f.author, f.job_def,
           TO_CHAR(REPLACE(REGEXP_SUBSTR(f.rel_u, '[^/]+', 1, 1), CHR(31), '/')) AS lvl1,
           TO_CHAR(REPLACE(REGEXP_SUBSTR(f.rel_u, '[^/]+', 1, 2), CHR(31), '/')) AS lvl2
    FROM   s8_fold f
),
-- s8_okey: the product areas Oracle content defines (the catalog's family /
-- product folders), so no module name is typed in this SQL
s8_okey AS (
    SELECT LOWER(l.lvl1) || '/' || LOWER(NVL(l.lvl2, '-'))                AS area_key,
           MAX(l.lvl1 || CASE WHEN l.lvl2 IS NOT NULL THEN ' / ' || l.lvl2 END)
                                                                           AS area_label
    FROM   s8_lvl l
    WHERE  l.is_custom = 'N'
    AND    l.lvl1 IS NOT NULL
    GROUP  BY LOWER(l.lvl1) || '/' || LOWER(NVL(l.lvl2, '-'))
),
-- s8_area: product area (user decision B, 2026-10-06). Oracle content -> its
-- family / product area. Custom content -> the same Oracle area when it is
-- filed in an Oracle family / product folder below /shared/Custom/, else one
-- area per top-level client folder ("Custom: <folder>"). Report name = the
-- display name; a dashboard is named after its folder.
s8_area AS (
    SELECT l.type_code, l.obj_u, l.is_custom, l.n_rows, l.report_id, l.last_modified,
           l.author, l.job_def,
           TO_CHAR(CASE WHEN l.lvl1 IS NULL
                        THEN CASE l.is_custom WHEN 'Y' THEN 'custom:(top)' ELSE 'oracle:(top)' END
                        WHEN l.is_custom = 'N' OR k.area_key IS NOT NULL
                        THEN LOWER(l.lvl1) || '/' || LOWER(NVL(l.lvl2, '-'))
                        ELSE 'custom:' || LOWER(l.lvl1)
                   END)                                                    AS area_key,
           TO_CHAR(CASE WHEN l.lvl1 IS NULL
                        THEN CASE l.is_custom WHEN 'Y' THEN 'Custom: (top of /shared/Custom)'
                                              ELSE '(top of /shared)' END
                        WHEN l.is_custom = 'N'
                        THEN l.lvl1 || CASE WHEN l.lvl2 IS NOT NULL THEN ' / ' || l.lvl2 END
                        WHEN k.area_key IS NOT NULL THEN k.area_label
                        ELSE 'Custom: ' || l.lvl1
                   END)                                                    AS area_label,
           CAST(CASE l.type_code WHEN 'BIP'       THEN 'BI Publisher report'
                                 WHEN 'ANALYSIS'  THEN 'OTBI analysis'
                                 WHEN 'DASHBOARD' THEN 'OTBI dashboard'
                                 WHEN 'FR'        THEN 'Financial report'
                END AS VARCHAR2(100))                                      AS type_label,
           TO_CHAR(CASE WHEN l.type_code = 'DASHBOARD'
                        THEN REPLACE(REGEXP_SUBSTR(l.obj_u, '[^/]+$'), CHR(31), '/')
                        ELSE NVL(n.disp, REPLACE(REGEXP_SUBSTR(l.obj_u, '[^/]+$'), CHR(31), '/'))
                   END)                                                    AS report_name,
           TO_CHAR(REPLACE(l.obj_u, CHR(31), '/'))                         AS report_path
    FROM   s8_lvl l
    LEFT   JOIN s8_okey k
           ON  l.is_custom = 'Y'
           AND k.area_key  = LOWER(l.lvl1) || '/' || LOWER(NVL(l.lvl2, '-'))
    LEFT   JOIN s8_name n ON n.report_id = l.report_id
),
-- ---- recorded use. Fusion keeps no 6-month run log (R033 / R035). ----------
-- ESS: a run = a request with PROCESSSTART (it started, whatever the outcome),
-- as EBS counts ACTUAL_START_DATE; schedule parents never start (R035 B). ESS
-- keeps a limited history (R035: from 2026-09-21 on this pod), so every ESS
-- count covers only the retained part of a window; s8_ess_hist gives its start.
s8_ess_run AS (
    SELECT TO_CHAR(h.definition)                                           AS definition,
           TO_CHAR(h.submitter)                                            AS submitter,
           TO_CHAR(h.name)                                                 AS job_name,
           TO_CHAR(REGEXP_SUBSTR(h.jobtype, '[^/]+$'))                     AS job_type,
           TO_CHAR(h.product)                                              AS product,
           h.processstart                                                  AS processstart
    FROM   ess_request_history h
    WHERE  h.processstart IS NOT NULL
),
s8_ess_hist AS (
    SELECT COUNT(*) AS n_runs, MIN(r.processstart) AS hist_start
    FROM   s8_ess_run r
),
s8_ess_sub AS (
    SELECT r.definition, r.submitter,
           MAX(r.job_name)                                                 AS job_name,
           MAX(r.job_type)                                                 AS job_type,
           MAX(r.product)                                                  AS product,
           NVL(SUM(CASE WHEN r.processstart >= w.start_date
                         AND r.processstart <  w.end_date_excl
                        THEN 1 ELSE 0 END), 0)                             AS n_6m,
           NVL(SUM(CASE WHEN r.processstart >= w3.start_date
                         AND r.processstart <= w3.end_date
                        THEN 1 ELSE 0 END), 0)                             AS n_3m,
           MIN(CASE WHEN r.processstart >= w.start_date
                     AND r.processstart <  w.end_date_excl
                    THEN r.processstart END)                               AS first_6m,
           MAX(CASE WHEN r.processstart >= w.start_date
                     AND r.processstart <  w.end_date_excl
                    THEN r.processstart END)                               AS last_6m,
           MIN(CASE WHEN r.processstart >= w3.start_date
                     AND r.processstart <= w3.end_date
                    THEN r.processstart END)                               AS first_3m,
           MAX(CASE WHEN r.processstart >= w3.start_date
                     AND r.processstart <= w3.end_date
                    THEN r.processstart END)                               AS last_3m
    FROM   s8_ess_run r
    CROSS  JOIN logwin w
    CROSS  JOIN win3   w3
    WHERE  r.definition IS NOT NULL
    GROUP  BY r.definition, r.submitter
),
s8_ess_def AS (
    SELECT s.definition,
           MAX(s.job_name)                                                 AS job_name,
           MAX(s.job_type)                                                 AS job_type,
           MAX(s.product)                                                  AS product,
           NVL(SUM(s.n_6m), 0)                                             AS runs_6m,
           NVL(SUM(s.n_3m), 0)                                             AS runs_3m,
           MIN(s.first_6m)                                                 AS first_6m,
           MAX(s.last_6m)                                                  AS last_6m,
           MIN(s.first_3m)                                                 AS first_3m,
           MAX(s.last_3m)                                                  AS last_3m,
           NVL(SUM(CASE WHEN s.n_6m > 0 THEN 1 ELSE 0 END), 0)             AS subs_6m,
           NVL(SUM(CASE WHEN s.n_3m > 0 THEN 1 ELSE 0 END), 0)             AS subs_3m
    FROM   s8_ess_sub s
    GROUP  BY s.definition
),
-- FRC log (GL_FRC_USER_ACCESS_REPORTS): one row per user and report, with
-- that user's LAST open from the Financial Reporting Center (R033). Opened in
-- a window = a user whose last open falls in it.
s8_frc AS (
    SELECT o.type_code, o.obj_u,
           TO_CHAR(u.user_name)                                            AS user_name,
           MAX(u.last_accessed_date)                                       AS last_open
    FROM   gl_frc_user_access_reports u
    JOIN   s8_obj_row o ON o.report_id = u.report_id
    WHERE  u.last_accessed_date IS NOT NULL
    GROUP  BY o.type_code, o.obj_u, TO_CHAR(u.user_name)
),
s8_frc_obj AS (
    SELECT f.type_code, f.obj_u,
           NVL(SUM(CASE WHEN f.last_open >= w.start_date
                         AND f.last_open <  w.end_date_excl
                        THEN 1 ELSE 0 END), 0)                             AS users_6m,
           NVL(SUM(CASE WHEN f.last_open >= w3.start_date
                         AND f.last_open <= w3.end_date
                        THEN 1 ELSE 0 END), 0)                             AS users_3m,
           MAX(f.last_open)                                                AS last_open
    FROM   s8_frc f
    CROSS  JOIN logwin w
    CROSS  JOIN win3   w3
    GROUP  BY f.type_code, f.obj_u
),
-- s8_use: every object with its recorded use. A job definition can be shared
-- by several catalog copies (R035: one custom case); its runs then show on
-- each copy, and job_copies says so.
s8_jobcopies AS (
    SELECT a.job_def, COUNT(*) AS n_copies
    FROM   s8_area a
    WHERE  a.job_def IS NOT NULL
    GROUP  BY a.job_def
),
s8_use AS (
    SELECT a.type_code, a.obj_u, a.is_custom, a.n_rows, a.report_id, a.last_modified,
           a.author, a.job_def, a.area_key, a.area_label, a.type_label, a.report_name,
           a.report_path,
           NVL(e.runs_6m, 0)                                               AS ess_runs_6m,
           NVL(e.runs_3m, 0)                                               AS ess_runs_3m,
           e.first_6m                                                      AS ess_first_6m,
           e.last_6m                                                       AS ess_last_6m,
           NVL(e.subs_6m, 0)                                               AS ess_subs_6m,
           NVL(jc.n_copies, 0)                                             AS job_copies,
           NVL(f.users_6m, 0)                                              AS frc_users_6m,
           NVL(f.users_3m, 0)                                              AS frc_users_3m,
           f.last_open                                                     AS frc_last_open
    FROM   s8_area a
    LEFT   JOIN s8_ess_def   e  ON e.definition = a.job_def
    LEFT   JOIN s8_jobcopies jc ON jc.job_def   = a.job_def
    LEFT   JOIN s8_frc_obj   f  ON f.type_code  = a.type_code
                               AND f.obj_u      = a.obj_u
),
-- source guards: a source that returns no rows gives a blank, never a 0
s8_src_idx AS (
    SELECT COUNT(*) AS n FROM gl_frc_reports_b r
),
s8_src_frc AS (
    SELECT COUNT(*) AS n FROM gl_frc_user_access_reports u
),
-- ---- END OF SECTION 8 BLOCK ---------------------------------------------------
wb_open AS (
    SELECT f.user_name, f.last_open, a.report_name, a.type_label, a.is_custom,
           a.area_label, a.report_path
    FROM   s8_frc  f
    JOIN   s8_area a ON a.type_code = f.type_code
                    AND a.obj_u     = f.obj_u
    CROSS  JOIN win3 w3
    WHERE  f.last_open >= w3.start_date
    AND    f.last_open <= w3.end_date
)
SELECT
    o.user_name                                               AS "User",
    o.report_name                                             AS "Report",
    o.type_label                                              AS "Report Type",
    o.is_custom                                               AS "Custom",
    o.area_label                                              AS "Product Area",
    TO_CHAR(o.last_open, 'YYYY-MM-DD HH24:MI')                AS "Last Open",
    o.report_path                                             AS "Catalog Path"
FROM        wb_open o
ORDER BY    o.last_open DESC, o.report_path, o.user_name
