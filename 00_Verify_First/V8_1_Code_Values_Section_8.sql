-- ============================================================================
--  V8_1  CODE VALUES - every value the Section 8 v1.1 rules produce (run first)
--  Version   : 1.1 (2026-10-06)        Run log: 06_Run_Results/RUN_LOG.md
--              v1.1: carries the Section 8 block v1.1 (byte-identical with
--              F8.1 / F8.2a / F8.2b / F8.2c / F8.2_WB1 / F8.2_WB2), so each value
--              below is what those queries will print. v1.0 ran as R032.
--  For: F8.1, F8.2a, F8.2b, F8.2c, F8.2_WB1, F8.2_WB2; F5.1 v2.1 cards 2-4
--  Binds: none used (the five standard binds are accepted for BIP parity).
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
--
--  BLOCKS
--    A  population: index rows, items per type, objects per type x custom
--       (dashboard pages -> dashboards), items with an escaped '/'
--    B  names: objects whose name comes from GL_FRC_REPORTS_TL vs the path,
--       one sample per type
--    C  product areas (decision B): the BI Publisher rows F8.1 prints - Oracle
--       areas, Oracle areas holding custom reports, client folders (listed)
--    D  recorded use: ESS history start and runs, job definitions run in 6 / 3
--       months, objects per type x custom with a job / a run / an FRC open,
--       shared job definitions, and every object with recorded use (listed)
--    E  cross-checks with F5.1 v2.1: card 2 (custom BIP), card 3 (custom
--       analyses + dashboards), card 4 (custom BIP with a job)
--  Expected (R032-R035): custom dashboards 57 (339 pages), Oracle 875;
--  ESS from 2026-09-21; 8 BI Publisher reports ran (3 custom); 6 objects
--  opened from the FRC in 6 months (4 custom FR); card 3 = 92.
--
--  OUTPUT  ord | section | item | value_text   (one grid, paste it back whole)
--  Pure SELECT. Nothing is written.
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
-- ==== A population ===============================================================
a_tot AS (
    SELECT COUNT(*) AS n_rows, MAX(r.last_update_date) AS last_upd
    FROM   gl_frc_reports_b r
),
a_obj AS (
    SELECT o.type_code, o.is_custom,
           COUNT(*)                                     AS n_obj,
           NVL(SUM(o.n_rows), 0)                        AS n_rows
    FROM   s8_obj o
    GROUP  BY o.type_code, o.is_custom
),
a_obj_rows AS (
    SELECT a.type_code, a.is_custom, a.n_obj, a.n_rows,
           ROW_NUMBER() OVER (ORDER BY a.type_code, a.is_custom) AS rn
    FROM   a_obj a
),
a_esc AS (
    SELECT COUNT(*) AS n FROM s8_path p WHERE INSTR(p.path_u, CHR(31)) > 0
),
-- ==== B names ======================================================================
b_name AS (
    SELECT a.type_code,
           COUNT(*)                                                     AS n,
           SUM(CASE WHEN n.disp IS NOT NULL THEN 1 ELSE 0 END)          AS n_tl
    FROM   s8_area a
    LEFT   JOIN s8_name n ON n.report_id = a.report_id
    GROUP  BY a.type_code
),
b_name_rows AS (
    SELECT b.type_code, b.n, b.n_tl, ROW_NUMBER() OVER (ORDER BY b.type_code) AS rn
    FROM   b_name b
),
b_sample AS (
    SELECT a.type_code, a.is_custom, a.report_name, a.area_label, a.report_path,
           ROW_NUMBER() OVER (PARTITION BY a.type_code ORDER BY a.is_custom DESC,
                                                               a.report_path) AS rn
    FROM   s8_area a
),
b_sample_rows AS (
    SELECT s.type_code, s.is_custom, s.report_name, s.area_label, s.report_path,
           ROW_NUMBER() OVER (ORDER BY s.type_code) AS k
    FROM   b_sample s
    WHERE  s.rn = 1
),
-- ==== C product areas (BI Publisher rows of F8.1) =================================
c_area AS (
    SELECT u.area_key,
           MAX(u.area_label)                                            AS area_label,
           COUNT(*)                                                     AS n,
           SUM(CASE WHEN u.is_custom = 'Y' THEN 1 ELSE 0 END)           AS n_custom
    FROM   s8_use u
    WHERE  u.type_code = 'BIP'
    GROUP  BY u.area_key
),
c_sum AS (
    SELECT COUNT(*)                                                               AS n_rows,
           NVL(SUM(CASE WHEN c.area_key LIKE 'custom:%' THEN 1 ELSE 0 END), 0)    AS n_client_rows,
           NVL(SUM(CASE WHEN c.area_key NOT LIKE 'custom:%' AND c.n_custom > 0
                        THEN 1 ELSE 0 END), 0)                                    AS n_mixed_rows,
           NVL(SUM(CASE WHEN c.area_key NOT LIKE 'custom:%'
                        THEN c.n_custom ELSE 0 END), 0)                           AS n_custom_in_oracle,
           NVL(SUM(CASE WHEN c.area_key LIKE 'custom:%'
                        THEN c.n_custom ELSE 0 END), 0)                           AS n_custom_in_client,
           NVL(SUM(c.n), 0)                                                       AS n_total
    FROM   c_area c
),
c_client_rows AS (
    SELECT c.area_label, c.n, ROW_NUMBER() OVER (ORDER BY c.n DESC, c.area_key) AS rn
    FROM   c_area c
    WHERE  c.area_key LIKE 'custom:%'
),
c_mixed_rows AS (
    SELECT c.area_label, c.n, c.n_custom,
           ROW_NUMBER() OVER (ORDER BY c.n_custom DESC, c.area_key) AS rn
    FROM   c_area c
    WHERE  c.area_key NOT LIKE 'custom:%'
    AND    c.n_custom > 0
),
-- ==== D recorded use ===============================================================
d_def AS (
    SELECT COUNT(*)                                                     AS n_defs,
           NVL(SUM(CASE WHEN e.runs_6m > 0 THEN 1 ELSE 0 END), 0)       AS n_6m,
           NVL(SUM(CASE WHEN e.runs_3m > 0 THEN 1 ELSE 0 END), 0)       AS n_3m,
           NVL(SUM(e.runs_3m), 0)                                       AS runs_3m
    FROM   s8_ess_def e
),
d_use AS (
    SELECT u.type_code, u.is_custom,
           COUNT(*)                                                     AS n,
           SUM(CASE WHEN u.job_def IS NOT NULL THEN 1 ELSE 0 END)       AS n_job,
           SUM(CASE WHEN u.ess_runs_6m > 0 THEN 1 ELSE 0 END)           AS n_ran,
           SUM(u.ess_runs_6m)                                           AS runs,
           SUM(CASE WHEN u.frc_users_6m > 0 THEN 1 ELSE 0 END)          AS n_frc,
           SUM(CASE WHEN u.job_copies > 1 THEN 1 ELSE 0 END)            AS n_shared
    FROM   s8_use u
    GROUP  BY u.type_code, u.is_custom
),
d_use_rows AS (
    SELECT d.type_code, d.is_custom, d.n, d.n_job, d.n_ran, d.runs, d.n_frc, d.n_shared,
           ROW_NUMBER() OVER (ORDER BY d.type_code, d.is_custom) AS rn
    FROM   d_use d
),
d_used AS (
    SELECT u.type_code, u.is_custom, u.report_name, u.ess_runs_6m, u.frc_users_6m,
           u.report_path,
           ROW_NUMBER() OVER (ORDER BY u.is_custom DESC, u.ess_runs_6m DESC,
                                       u.frc_users_6m DESC, u.report_path) AS rn
    FROM   s8_use u
    WHERE  u.ess_runs_6m > 0 OR u.frc_users_6m > 0
),
-- ==== E F5.1 v2.1 cross-checks ======================================================
e_card AS (
    SELECT NVL(SUM(CASE WHEN o.is_custom = 'Y' AND o.type_code = 'BIP'
                        THEN 1 ELSE 0 END), 0)                          AS n_card2,
           NVL(SUM(CASE WHEN o.is_custom = 'Y' AND o.type_code IN ('ANALYSIS', 'DASHBOARD')
                        THEN 1 ELSE 0 END), 0)                          AS n_card3,
           NVL(SUM(CASE WHEN o.is_custom = 'Y' AND o.type_code = 'BIP'
                         AND o.job_def IS NOT NULL THEN 1 ELSE 0 END), 0) AS n_card4
    FROM   s8_obj o
),
grid AS (
    -- A ------------------------------------------------------------------------
    SELECT 100                                                      AS ord,
           CAST('A population' AS VARCHAR2(400))                    AS section,
           CAST('A0 summary (V8_1 v1.1, Section 8 block v1.1): index rows / latest row'
                || ' update / items with an escaped slash'
                AS VARCHAR2(400))                                   AS item,
           CAST(t.n_rows || ' / ' || TO_CHAR(t.last_upd, 'YYYY-MM-DD') || ' / ' || e.n
                AS VARCHAR2(4000))                                  AS value_text
    FROM   a_tot t
    CROSS  JOIN a_esc e
    UNION ALL
    SELECT 100 + a.rn, TO_CHAR('A population'),
           TO_CHAR('A1 type=' || a.type_code || ' custom=' || a.is_custom),
           TO_CHAR(a.n_obj || ' objects from ' || a.n_rows || ' index rows')
    FROM   a_obj_rows a
    WHERE  a.rn <= 9
    -- B ------------------------------------------------------------------------
    UNION ALL
    SELECT 200 + b.rn, TO_CHAR('B names'),
           TO_CHAR('B1 type=' || b.type_code || ': objects / named from GL_FRC_REPORTS_TL'),
           TO_CHAR(b.n || ' / ' || b.n_tl
                   || CASE WHEN b.type_code = 'DASHBOARD'
                           THEN ' (dashboards are named after their folder)' END)
    FROM   b_name_rows b
    WHERE  b.rn <= 4
    UNION ALL
    SELECT 210 + s.k, TO_CHAR('B names'),
           TO_CHAR('B2 sample type=' || s.type_code || ' custom=' || s.is_custom),
           TO_CHAR(s.report_name || ' | area: ' || s.area_label || ' | ' || s.report_path)
    FROM   b_sample_rows s
    WHERE  s.k <= 4
    -- C ------------------------------------------------------------------------
    UNION ALL
    SELECT 300, TO_CHAR('C product areas (BI Publisher)'),
           TO_CHAR('C0 rows F8.1 prints / client-folder rows / Oracle rows holding custom /'
                   || ' custom in Oracle rows / custom in client rows / reports'),
           TO_CHAR(c.n_rows || ' / ' || c.n_client_rows || ' / ' || c.n_mixed_rows || ' / '
                   || c.n_custom_in_oracle || ' / ' || c.n_custom_in_client || ' / '
                   || c.n_total)
    FROM   c_sum c
    UNION ALL
    SELECT 300 + r.rn, TO_CHAR('C product areas (BI Publisher)'),
           TO_CHAR('C1 ' || r.area_label),
           TO_CHAR(r.n || ' reports')
    FROM   c_client_rows r
    WHERE  r.rn <= 25
    UNION ALL
    SELECT 330 + m.rn, TO_CHAR('C product areas (BI Publisher)'),
           TO_CHAR('C2 Oracle area holding custom: ' || m.area_label),
           TO_CHAR(m.n_custom || ' custom of ' || m.n || ' reports')
    FROM   c_mixed_rows m
    WHERE  m.rn <= 10
    -- D ------------------------------------------------------------------------
    UNION ALL
    SELECT 400, TO_CHAR('D recorded use'),
           TO_CHAR('D0 ESS history from / runs retained / job definitions / run in 6 mth /'
                   || ' run in 3 mth / runs in 3 mth / FRC log rows'),
           TO_CHAR(NVL(TO_CHAR(h.hist_start, 'YYYY-MM-DD HH24:MI'), '-') || ' / ' || h.n_runs
                   || ' / ' || d.n_defs || ' / ' || d.n_6m || ' / ' || d.n_3m || ' / '
                   || d.runs_3m || ' / ' || sf.n)
    FROM   s8_ess_hist h
    CROSS  JOIN d_def d
    CROSS  JOIN s8_src_frc sf
    UNION ALL
    SELECT 400 + u.rn, TO_CHAR('D recorded use'),
           TO_CHAR('D1 type=' || u.type_code || ' custom=' || u.is_custom
                   || ': objects / with a job / ran / runs / opened in FRC / shared job'),
           TO_CHAR(u.n || ' / ' || u.n_job || ' / ' || u.n_ran || ' / ' || u.runs || ' / '
                   || u.n_frc || ' / ' || u.n_shared)
    FROM   d_use_rows u
    WHERE  u.rn <= 9
    UNION ALL
    SELECT 420 + x.rn, TO_CHAR('D recorded use'),
           TO_CHAR('D2 used: type=' || x.type_code || ' custom=' || x.is_custom),
           TO_CHAR(x.report_name || ' | ESS runs ' || x.ess_runs_6m || ' | FRC users '
                   || x.frc_users_6m || ' | ' || x.report_path)
    FROM   d_used x
    WHERE  x.rn <= 25
    -- E ------------------------------------------------------------------------
    UNION ALL
    SELECT 500, TO_CHAR('E F5.1 v2.1 cross-checks'),
           TO_CHAR('E1 card 2 custom BIP / card 3 custom analyses + dashboards / card 4'
                   || ' custom BIP with a job'),
           TO_CHAR(c.n_card2 || ' / ' || c.n_card3 || ' / ' || c.n_card4
                   || ' (expected 196 / 92 / 106)')
    FROM   e_card c
)
SELECT  g.ord         AS ord,
        g.section     AS section,
        g.item        AS item,
        g.value_text  AS value_text
FROM    grid g
ORDER BY g.ord
