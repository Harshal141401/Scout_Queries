-- ============================================================================
--  V8_3  ESS RUN FACTS - how scheduled-process runs are recorded, and which
--        catalog reports actually ran (Section 8 v1.1; also F5.2)
--  Version   : 1.0 (2026-10-06)        Run log: 06_Run_Results/RUN_LOG.md
--  For: the Section 8 v1.1 redesign after V8_2 (R033) and V5_2a (R034), and
--       F5.2 / F5.2b, which count executions on PROCESSSTART.
--  Binds: none used (the five standard binds are accepted for BIP parity).
--  RUN AFTER V5_2c. This query NAMES the ESS columns PROCESSSTART and
--  PROCESSEND, which no output has shown yet (R034's XML left them out because
--  they were NULL on its one row). If it fails with ORA-00904, send the error:
--  V5_2c's export then shows the right column names.
--  Proven by R034's row: REQUESTID, DEFINITION, STATE, JOBTYPE, REQUESTTYPE,
--  PARENTREQUESTID, SUBMITTER, SUBMISSION, ENTERPRISE_ID, DELETED, PRODUCT.
--  Proven by R031: GL_FRC_REPORTS_B, GL_FRC_USER_ACCESS_REPORTS, FND_LOOKUP_VALUES.
-- ============================================================================
WITH
-- ---- PARAMS / WINDOW / SCOPE: copied unchanged from F1 (shared block v3.1).
--      Nothing in it is read here; it is kept for parity with every other
--      query. The discovery window (win) is NOT used.
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
-- logwin / win3: the Section 8 operational windows, from the run day
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
-- ==== ESS base: the columns used, read once ======================================
es_base AS (
    SELECT /*+ MATERIALIZE */
           h.requestid                   AS requestid,
           TO_CHAR(h.definition)         AS definition,
           h.state                       AS req_state,
           TO_CHAR(h.jobtype)            AS jobtype,
           h.requesttype                 AS requesttype,
           h.parentrequestid             AS parentrequestid,
           TO_CHAR(h.submitter)          AS submitter,
           h.submission                  AS submission,
           h.processstart                AS processstart,
           h.processend                  AS processend,
           h.enterprise_id               AS enterprise_id,
           TO_CHAR(h.deleted)            AS deleted,
           TO_CHAR(h.product)            AS product
    FROM   ess_request_history h
),
-- ==== 0 summary ===================================================================
es_tot AS (
    SELECT COUNT(*)                                                         AS n_rows,
           MIN(e.submission)                                                AS min_sub,
           MAX(e.submission)                                                AS max_sub,
           COUNT(e.processstart)                                            AS n_ps,
           MIN(e.processstart)                                              AS min_ps,
           MAX(e.processstart)                                              AS max_ps,
           COUNT(e.processend)                                              AS n_pe,
           NVL(SUM(CASE WHEN e.processstart >= w.start_date
                         AND e.processstart <  w.end_date_excl
                        THEN 1 ELSE 0 END), 0)                              AS n_6m,
           NVL(SUM(CASE WHEN e.processstart >= w3.start_date
                         AND e.processstart <= w3.end_date
                        THEN 1 ELSE 0 END), 0)                              AS n_3m
    FROM   es_base e
    CROSS  JOIN logwin w
    CROSS  JOIN win3   w3
),
-- ==== A states =====================================================================
a_state AS (
    SELECT e.req_state,
           COUNT(*)                                                         AS n,
           COUNT(e.processstart)                                            AS n_ps,
           COUNT(e.processend)                                              AS n_pe,
           NVL(SUM(CASE WHEN e.processstart >= w.start_date
                         AND e.processstart <  w.end_date_excl
                        THEN 1 ELSE 0 END), 0)                              AS n_6m,
           MAX(e.submission)                                                AS last_sub
    FROM   es_base e
    CROSS  JOIN logwin w
    GROUP  BY e.req_state
),
a_state_rows AS (
    SELECT s.req_state, s.n, s.n_ps, s.n_pe, s.n_6m, s.last_sub,
           ROW_NUMBER() OVER (ORDER BY s.req_state) AS rn
    FROM   a_state s
),
a_lk AS (
    SELECT TO_CHAR(lv.lookup_type)                                          AS lookup_type,
           TO_CHAR(lv.lookup_code)                                          AS lookup_code,
           MAX(TO_CHAR(lv.meaning)) KEEP (DENSE_RANK FIRST ORDER BY
               CASE WHEN lv.language = USERENV('LANG') THEN 0 ELSE 1 END)   AS meaning
    FROM   fnd_lookup_values lv
    WHERE  lv.language IN (USERENV('LANG'), 'US')
    AND    UPPER(lv.lookup_type) LIKE '%ESS%'
    AND    (   UPPER(lv.lookup_type) LIKE '%STATE%'
            OR UPPER(lv.lookup_type) LIKE '%STATUS%' )
    GROUP  BY TO_CHAR(lv.lookup_type), TO_CHAR(lv.lookup_code)
),
a_lk_cnt AS (
    SELECT COUNT(*) AS n FROM a_lk
),
a_lk_rows AS (
    SELECT l.lookup_type, l.lookup_code, l.meaning,
           ROW_NUMBER() OVER (ORDER BY l.lookup_type, l.lookup_code) AS rn
    FROM   a_lk l
),
-- ==== B request types ==============================================================
b_rt AS (
    SELECT e.requesttype,
           COUNT(*)                                                         AS n,
           COUNT(e.processstart)                                            AS n_ps,
           NVL(SUM(CASE WHEN e.parentrequestid > 0 THEN 1 ELSE 0 END), 0)   AS n_child
    FROM   es_base e
    GROUP  BY e.requesttype
),
b_rt_rows AS (
    SELECT b.requesttype, b.n, b.n_ps, b.n_child,
           ROW_NUMBER() OVER (ORDER BY b.requesttype) AS rn
    FROM   b_rt b
),
-- ==== C job types ==================================================================
c_jt AS (
    SELECT NVL(e.jobtype, '(none)')                                         AS jobtype,
           COUNT(*)                                                         AS n,
           COUNT(e.processstart)                                            AS n_ps,
           NVL(SUM(CASE WHEN e.processstart >= w.start_date
                         AND e.processstart <  w.end_date_excl
                        THEN 1 ELSE 0 END), 0)                              AS n_6m
    FROM   es_base e
    CROSS  JOIN logwin w
    GROUP  BY NVL(e.jobtype, '(none)')
),
c_jt_rows AS (
    SELECT c.jobtype, c.n, c.n_ps, c.n_6m,
           ROW_NUMBER() OVER (ORDER BY c.n DESC, c.jobtype) AS rn
    FROM   c_jt c
),
-- ==== D one row per definition ======================================================
d_def AS (
    SELECT e.definition,
           COUNT(*)                                                         AS req_all,
           COUNT(e.processstart)                                            AS exec_all,
           NVL(SUM(CASE WHEN e.processstart >= w.start_date
                         AND e.processstart <  w.end_date_excl
                        THEN 1 ELSE 0 END), 0)                              AS exec_6m,
           NVL(SUM(CASE WHEN e.processstart >= w3.start_date
                         AND e.processstart <= w3.end_date
                        THEN 1 ELSE 0 END), 0)                              AS exec_3m,
           MAX(e.processstart)                                              AS last_run,
           MAX(e.jobtype) KEEP (DENSE_RANK LAST ORDER BY e.requestid)       AS jobtype,
           MAX(e.product) KEEP (DENSE_RANK LAST ORDER BY e.requestid)       AS product
    FROM   es_base e
    CROSS  JOIN logwin w
    CROSS  JOIN win3   w3
    WHERE  e.definition IS NOT NULL
    GROUP  BY e.definition
),
d_type AS (
    SELECT NVL(SUBSTR(d.definition, 1, INSTR(d.definition, '://') - 1), '(no ://)')
                                                                            AS def_type,
           COUNT(*)                                                         AS n_defs,
           NVL(SUM(d.req_all), 0)                                           AS n_req,
           NVL(SUM(CASE WHEN INSTR(LOWER(d.definition), '/oracle/apps/ess/custom/') > 0
                        THEN 1 ELSE 0 END), 0)                              AS n_custom,
           NVL(SUM(CASE WHEN d.exec_6m > 0 THEN 1 ELSE 0 END), 0)           AS n_run_6m,
           NVL(SUM(CASE WHEN d.exec_3m > 0 THEN 1 ELSE 0 END), 0)           AS n_run_3m
    FROM   d_def d
    GROUP  BY NVL(SUBSTR(d.definition, 1, INSTR(d.definition, '://') - 1), '(no ://)')
),
d_type_rows AS (
    SELECT t.def_type, t.n_defs, t.n_req, t.n_custom, t.n_run_6m, t.n_run_3m,
           ROW_NUMBER() OVER (ORDER BY t.n_defs DESC, t.def_type) AS rn
    FROM   d_type t
),
-- ==== E BI Publisher reports (shared catalog, proposed v1.1 path rule) and their runs
e_cat AS (
    SELECT TO_CHAR(r.bip_report_job_definition)                             AS job_def,
           TO_CHAR(r.report_path)                                           AS report_path,
           CASE WHEN LOWER(REGEXP_REPLACE(r.report_path, '^/shared folders/', '/shared/',
                                          1, 1, 'i')) LIKE '/shared/custom/%'
                THEN 'Y' ELSE 'N' END                                       AS is_custom
    FROM   gl_frc_reports_b r
    WHERE  UPPER(r.report_type_code) = 'BIP'
    AND    (   LOWER(r.report_path) LIKE '/shared/%'
            OR LOWER(r.report_path) LIKE '/shared folders/%' )
    AND    r.bip_report_job_definition IS NOT NULL
),
e_link AS (
    SELECT c.is_custom, c.report_path, c.job_def,
           NVL(d.req_all, 0)  AS req_all,
           NVL(d.exec_all, 0) AS exec_all,
           NVL(d.exec_6m, 0)  AS exec_6m,
           NVL(d.exec_3m, 0)  AS exec_3m,
           d.last_run
    FROM   e_cat c
    LEFT   JOIN d_def d ON d.definition = c.job_def
),
e_sum AS (
    SELECT l.is_custom,
           COUNT(*)                                                         AS n_rep,
           NVL(SUM(CASE WHEN l.req_all > 0 THEN 1 ELSE 0 END), 0)           AS n_any,
           NVL(SUM(CASE WHEN l.exec_6m > 0 THEN 1 ELSE 0 END), 0)           AS n_6m,
           NVL(SUM(CASE WHEN l.exec_3m > 0 THEN 1 ELSE 0 END), 0)           AS n_3m,
           NVL(SUM(l.exec_6m), 0)                                           AS runs_6m
    FROM   e_link l
    GROUP  BY l.is_custom
),
e_sum_rows AS (
    SELECT s.is_custom, s.n_rep, s.n_any, s.n_6m, s.n_3m, s.runs_6m,
           ROW_NUMBER() OVER (ORDER BY s.is_custom DESC) AS rn
    FROM   e_sum s
),
e_case AS (
    SELECT COUNT(*) AS n_ci
    FROM   e_cat c
    WHERE  NOT EXISTS ( SELECT 1 FROM d_def d WHERE d.definition = c.job_def )
    AND    EXISTS     ( SELECT 1 FROM d_def d WHERE UPPER(d.definition) = UPPER(c.job_def) )
),
e_bipjobs AS (
    SELECT COUNT(*)                                                         AS n,
           NVL(SUM(CASE WHEN d.exec_6m > 0 THEN 1 ELSE 0 END), 0)           AS n_6m
    FROM   d_def d
    WHERE  UPPER(d.jobtype) LIKE '%BIP%'
    AND    NOT EXISTS ( SELECT 1 FROM e_cat c WHERE c.job_def = d.definition )
),
e_top AS (
    SELECT l.is_custom, l.report_path, l.exec_6m, l.last_run,
           ROW_NUMBER() OVER (PARTITION BY l.is_custom
                              ORDER BY l.exec_6m DESC, l.report_path) AS rn
    FROM   e_link l
    WHERE  l.exec_6m > 0
),
e_top_rows AS (
    SELECT t.is_custom, t.report_path, t.exec_6m, t.last_run,
           ROW_NUMBER() OVER (ORDER BY t.is_custom DESC, t.rn) AS k
    FROM   e_top t
    WHERE  t.rn <= 8
),
-- ==== F workbook preview (3 months) ================================================
f_sum AS (
    SELECT COUNT(*)                                                         AS n_defs,
           NVL(SUM(d.exec_3m), 0)                                           AS n_runs,
           NVL(SUM(CASE WHEN INSTR(LOWER(d.definition), '/oracle/apps/ess/custom/') > 0
                        THEN 1 ELSE 0 END), 0)                              AS n_custom
    FROM   d_def d
    WHERE  d.exec_3m > 0
),
f_top AS (
    SELECT TO_CHAR(SUBSTR(d.definition, INSTR(d.definition, '/', -1) + 1))  AS job_name,
           d.exec_3m, d.jobtype, d.product,
           ROW_NUMBER() OVER (ORDER BY d.exec_3m DESC, d.definition)        AS rn
    FROM   d_def d
    WHERE  d.exec_3m > 0
),
-- ==== G submitters of runs in 6 months ==============================================
g_sub AS (
    SELECT NVL(e.submitter, '(none)') AS submitter, COUNT(*) AS n
    FROM   es_base e
    CROSS  JOIN logwin w
    WHERE  e.processstart >= w.start_date
    AND    e.processstart <  w.end_date_excl
    GROUP  BY NVL(e.submitter, '(none)')
),
g_sub_cnt AS (
    SELECT COUNT(*) AS n_sub, NVL(SUM(g.n), 0) AS n_req FROM g_sub g
),
g_sub_rows AS (
    SELECT g.submitter, g.n, ROW_NUMBER() OVER (ORDER BY g.n DESC, g.submitter) AS rn
    FROM   g_sub g
),
-- ==== H enterprise and deleted ======================================================
h_ent AS (
    SELECT NVL(TO_CHAR(e.enterprise_id), '(null)') AS val, COUNT(*) AS n
    FROM   es_base e
    GROUP  BY NVL(TO_CHAR(e.enterprise_id), '(null)')
),
h_ent_rows AS (
    SELECT v.val, v.n, ROW_NUMBER() OVER (ORDER BY v.n DESC, v.val) AS rn FROM h_ent v
),
h_del AS (
    SELECT NVL(e.deleted, '(null)') AS val, COUNT(*) AS n
    FROM   es_base e
    GROUP  BY NVL(e.deleted, '(null)')
),
h_del_rows AS (
    SELECT v.val, v.n, ROW_NUMBER() OVER (ORDER BY v.n DESC, v.val) AS rn FROM h_del v
),
-- ==== I Financial Reporting Center access log vs ESS =================================
i_all AS (
    SELECT NVL(TO_CHAR(u.last_accessed_bip_ess_req_id), '(null)') AS val, COUNT(*) AS n
    FROM   gl_frc_user_access_reports u
    GROUP  BY NVL(TO_CHAR(u.last_accessed_bip_ess_req_id), '(null)')
),
i_all_rows AS (
    SELECT v.val, v.n, ROW_NUMBER() OVER (ORDER BY v.n DESC, v.val) AS rn FROM i_all v
),
i_dated AS (
    SELECT NVL(TO_CHAR(u.last_accessed_bip_ess_req_id), '(null)') AS val, COUNT(*) AS n
    FROM   gl_frc_user_access_reports u
    WHERE  u.last_accessed_date IS NOT NULL
    GROUP  BY NVL(TO_CHAR(u.last_accessed_bip_ess_req_id), '(null)')
),
i_dated_rows AS (
    SELECT v.val, v.n, ROW_NUMBER() OVER (ORDER BY v.n DESC, v.val) AS rn FROM i_dated v
),
i_match AS (
    SELECT COUNT(*)                                                         AS n_dated,
           NVL(SUM(CASE WHEN e.requestid IS NOT NULL THEN 1 ELSE 0 END), 0) AS n_in_ess
    FROM   gl_frc_user_access_reports u
    LEFT   JOIN es_base e ON e.requestid = u.last_accessed_bip_ess_req_id
    WHERE  u.last_accessed_date IS NOT NULL
),
-- ==== J dashboard grain, escaped slashes handled ====================================
-- A name may hold '/', stored as '\/' (R033 H3). CHR(31) stands in for it
-- while the path is split, then becomes '/' again.
j_dash AS (
    SELECT CASE WHEN LOWER(r.report_path) LIKE '/shared/custom/%'
                THEN 'Y' ELSE 'N' END                                       AS is_custom,
           TO_CHAR(REPLACE(REGEXP_REPLACE(REPLACE(r.report_path, '\/', CHR(31)),
                                          '/[^/]*$', ''),
                           CHR(31), '/'))                                   AS dash_path,
           TO_CHAR(REGEXP_SUBSTR(REGEXP_REPLACE(REPLACE(r.report_path, '\/', CHR(31)),
                                                '/[^/]*$', ''),
                                 '[^/]+$'))                                 AS dash_leaf,
           CASE WHEN INSTR(r.report_path, '\/') > 0 THEN 1 ELSE 0 END       AS has_esc
    FROM   gl_frc_reports_b r
    WHERE  UPPER(r.report_type_code) = 'DASHBOARD'
    AND    LOWER(r.report_path) LIKE '/shared/%'
),
j_grp AS (
    SELECT j.is_custom, j.dash_path,
           MAX(j.dash_leaf)  AS dash_leaf,
           COUNT(*)          AS n_pages,
           SUM(j.has_esc)    AS n_esc
    FROM   j_dash j
    GROUP  BY j.is_custom, j.dash_path
),
j_sum AS (
    SELECT g.is_custom,
           COUNT(*)                                                         AS n_dash,
           NVL(SUM(g.n_pages), 0)                                           AS n_rows,
           NVL(SUM(CASE WHEN LOWER(g.dash_leaf) = '_portal' THEN 1 ELSE 0 END), 0)
                                                                            AS n_portal_parent,
           NVL(SUM(CASE WHEN LOWER(g.dash_leaf) = '_portal' THEN g.n_pages ELSE 0 END), 0)
                                                                            AS n_rows_portal_parent,
           NVL(SUM(g.n_esc), 0)                                             AS n_esc_rows
    FROM   j_grp g
    GROUP  BY g.is_custom
),
j_sum_rows AS (
    SELECT s.is_custom, s.n_dash, s.n_rows, s.n_portal_parent, s.n_rows_portal_parent,
           s.n_esc_rows,
           ROW_NUMBER() OVER (ORDER BY s.is_custom DESC) AS rn
    FROM   j_sum s
),
j_esc AS (
    SELECT TO_CHAR(r.report_type_code) AS type_code, COUNT(*) AS n
    FROM   gl_frc_reports_b r
    WHERE  INSTR(r.report_path, '\/') > 0
    GROUP  BY TO_CHAR(r.report_type_code)
),
j_esc_rows AS (
    SELECT v.type_code, v.n, ROW_NUMBER() OVER (ORDER BY v.n DESC, v.type_code) AS rn
    FROM   j_esc v
),
grid AS (
    -- 0 ------------------------------------------------------------------------
    SELECT 100                                                      AS ord,
           CAST('0 ESS history' AS VARCHAR2(400))                   AS section,
           CAST('00 summary (V8_3 v1.0): rows / submitted from .. to / with PROCESSSTART'
                || ' (range) / with PROCESSEND / runs in 6 mth / runs in 3 mth'
                AS VARCHAR2(400))                                   AS item,
           CAST(t.n_rows || ' / ' || NVL(TO_CHAR(t.min_sub, 'YYYY-MM-DD'), '-') || ' .. '
                || NVL(TO_CHAR(t.max_sub, 'YYYY-MM-DD'), '-') || ' / ' || t.n_ps || ' ('
                || NVL(TO_CHAR(t.min_ps, 'YYYY-MM-DD'), '-') || ' .. '
                || NVL(TO_CHAR(t.max_ps, 'YYYY-MM-DD'), '-') || ') / ' || t.n_pe
                || ' / ' || t.n_6m || ' / ' || t.n_3m
                AS VARCHAR2(4000))                                  AS value_text
    FROM   es_tot t
    -- A ------------------------------------------------------------------------
    UNION ALL
    SELECT 200 + s.rn, TO_CHAR('A states'),
           TO_CHAR('A1 STATE=' || s.req_state),
           TO_CHAR(s.n || ' requests | with PROCESSSTART ' || s.n_ps || ' | with PROCESSEND '
                   || s.n_pe || ' | started in 6 mth ' || s.n_6m || ' | latest submitted '
                   || NVL(TO_CHAR(s.last_sub, 'YYYY-MM-DD'), '-'))
    FROM   a_state_rows s
    WHERE  s.rn <= 30
    UNION ALL
    SELECT 240, TO_CHAR('A states'),
           TO_CHAR('A2 lookup values in a type named *ESS* and *STATE* / *STATUS*'),
           TO_CHAR(c.n || ' found (up to 40 listed)')
    FROM   a_lk_cnt c
    UNION ALL
    SELECT 240 + l.rn, TO_CHAR('A states'),
           TO_CHAR('A2 ' || l.lookup_type || ' / ' || l.lookup_code),
           TO_CHAR(NVL(l.meaning, '(no meaning)'))
    FROM   a_lk_rows l
    WHERE  l.rn <= 40
    -- B ------------------------------------------------------------------------
    UNION ALL
    SELECT 300 + b.rn, TO_CHAR('B request types'),
           TO_CHAR('B1 REQUESTTYPE=' || b.requesttype),
           TO_CHAR(b.n || ' requests | with PROCESSSTART ' || b.n_ps
                   || ' | with a parent request ' || b.n_child)
    FROM   b_rt_rows b
    WHERE  b.rn <= 10
    -- C ------------------------------------------------------------------------
    UNION ALL
    SELECT 400 + c.rn, TO_CHAR('C job types'),
           TO_CHAR('C1 ' || c.jobtype),
           TO_CHAR(c.n || ' requests | with PROCESSSTART ' || c.n_ps
                   || ' | started in 6 mth ' || c.n_6m)
    FROM   c_jt_rows c
    WHERE  c.rn <= 12
    -- D ------------------------------------------------------------------------
    UNION ALL
    SELECT 500 + d.rn, TO_CHAR('D definitions'),
           TO_CHAR('D1 type=' || d.def_type),
           TO_CHAR(d.n_defs || ' definitions | ' || d.n_req || ' requests | custom path '
                   || d.n_custom || ' | run in 6 mth ' || d.n_run_6m || ' | run in 3 mth '
                   || d.n_run_3m)
    FROM   d_type_rows d
    WHERE  d.rn <= 6
    -- E ------------------------------------------------------------------------
    UNION ALL
    SELECT 600 + s.rn, TO_CHAR('E BI Publisher runs'),
           TO_CHAR('E1 custom=' || s.is_custom || ': catalog BIP reports with a job definition'
                   || ' / with any ESS request / run in 6 mth / run in 3 mth / runs in 6 mth'),
           TO_CHAR(s.n_rep || ' / ' || s.n_any || ' / ' || s.n_6m || ' / ' || s.n_3m
                   || ' / ' || s.runs_6m)
    FROM   e_sum_rows s
    WHERE  s.rn <= 2
    UNION ALL
    SELECT 605, TO_CHAR('E BI Publisher runs'),
           TO_CHAR('E2 job definitions that match ESS only when case is ignored'),
           TO_CHAR(c.n_ci || ' (0 = the exact match is enough)')
    FROM   e_case c
    UNION ALL
    SELECT 606, TO_CHAR('E BI Publisher runs'),
           TO_CHAR('E3 ESS definitions of a *BIP* job type matching no catalog report / run in 6 mth'),
           TO_CHAR(b.n || ' / ' || b.n_6m)
    FROM   e_bipjobs b
    UNION ALL
    SELECT 610 + t.k, TO_CHAR('E BI Publisher runs'),
           TO_CHAR('E4 busiest, custom=' || t.is_custom),
           TO_CHAR(t.report_path || ' | runs in 6 mth ' || t.exec_6m || ' | last run '
                   || NVL(TO_CHAR(t.last_run, 'YYYY-MM-DD'), '-'))
    FROM   e_top_rows t
    WHERE  t.k <= 16
    -- F ------------------------------------------------------------------------
    UNION ALL
    SELECT 700, TO_CHAR('F workbook preview (3 mth)'),
           TO_CHAR('F0 job definitions run in 3 mth / runs / custom-path definitions'),
           TO_CHAR(s.n_defs || ' / ' || s.n_runs || ' / ' || s.n_custom)
    FROM   f_sum s
    UNION ALL
    SELECT 700 + f.rn, TO_CHAR('F workbook preview (3 mth)'),
           TO_CHAR('F1 ' || f.job_name),
           TO_CHAR(f.exec_3m || ' runs | ' || NVL(f.jobtype, '-') || ' | product '
                   || NVL(f.product, '-'))
    FROM   f_top f
    WHERE  f.rn <= 10
    -- G ------------------------------------------------------------------------
    UNION ALL
    SELECT 800, TO_CHAR('G submitters (6 mth)'),
           TO_CHAR('G0 submitters of runs in 6 mth / runs'),
           TO_CHAR(c.n_sub || ' / ' || c.n_req)
    FROM   g_sub_cnt c
    UNION ALL
    SELECT 800 + g.rn, TO_CHAR('G submitters (6 mth)'),
           TO_CHAR('G1 ' || g.submitter),
           TO_CHAR(g.n || ' runs')
    FROM   g_sub_rows g
    WHERE  g.rn <= 8
    -- H ------------------------------------------------------------------------
    UNION ALL
    SELECT 900 + v.rn, TO_CHAR('H enterprise / deleted'),
           TO_CHAR('H1 ENTERPRISE_ID=' || v.val),
           TO_CHAR(v.n || ' requests')
    FROM   h_ent_rows v
    WHERE  v.rn <= 5
    UNION ALL
    SELECT 910 + v.rn, TO_CHAR('H enterprise / deleted'),
           TO_CHAR('H2 DELETED=' || v.val),
           TO_CHAR(v.n || ' requests')
    FROM   h_del_rows v
    WHERE  v.rn <= 5
    -- I ------------------------------------------------------------------------
    UNION ALL
    SELECT 1000, TO_CHAR('I FRC log vs ESS'),
           TO_CHAR('I0 dated rows in the access log / whose request id is an ESS request'),
           TO_CHAR(m.n_dated || ' / ' || m.n_in_ess)
    FROM   i_match m
    UNION ALL
    SELECT 1000 + v.rn, TO_CHAR('I FRC log vs ESS'),
           TO_CHAR('I1 all rows: LAST_ACCESSED_BIP_ESS_REQ_ID=' || v.val),
           TO_CHAR(v.n || ' rows')
    FROM   i_all_rows v
    WHERE  v.rn <= 3
    UNION ALL
    SELECT 1010 + v.rn, TO_CHAR('I FRC log vs ESS'),
           TO_CHAR('I2 dated rows: LAST_ACCESSED_BIP_ESS_REQ_ID=' || v.val),
           TO_CHAR(v.n || ' rows')
    FROM   i_dated_rows v
    WHERE  v.rn <= 8
    -- J ------------------------------------------------------------------------
    UNION ALL
    SELECT 1100 + s.rn, TO_CHAR('J dashboard grain'),
           TO_CHAR('J1 custom=' || s.is_custom || ': Dashboard rows / dashboards (escape-aware'
                   || ' parents) / parents named _portal (rows under them) / rows with an'
                   || ' escaped slash'),
           TO_CHAR(s.n_rows || ' / ' || s.n_dash || ' / ' || s.n_portal_parent || ' ('
                   || s.n_rows_portal_parent || ') / ' || s.n_esc_rows)
    FROM   j_sum_rows s
    WHERE  s.rn <= 2
    UNION ALL
    SELECT 1110 + v.rn, TO_CHAR('J dashboard grain'),
           TO_CHAR('J2 items with an escaped slash, type=' || v.type_code),
           TO_CHAR(v.n || ' items')
    FROM   j_esc_rows v
    WHERE  v.rn <= 6
)
SELECT  g.ord         AS ord,
        g.section     AS section,
        g.item        AS item,
        g.value_text  AS value_text
FROM    grid g
ORDER BY g.ord
