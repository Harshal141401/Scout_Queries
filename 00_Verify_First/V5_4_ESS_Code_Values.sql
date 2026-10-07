-- ============================================================================
--  V5_4  ESS CODE VALUES - run ONLY after V5_2a shows ESS_REQUEST_HISTORY is readable
--  Version   : 1.0 (2026-10-05)        Run log: 06_Run_Results/RUN_LOG.md
--              Blocks A-H moved here unchanged from V5_1 v1.1, because V5_0
--              (R016) found ESS_REQUEST_HISTORY / ESS_REQUEST_PROPERTY to be
--              FUSION synonyms whose target columns this report user cannot
--              see. Kept apart so an unreadable ESS view cannot fail V5_1.
--  For: F5.2_Custom_Scheduled_Processes, F5.2_ESS_History_Coverage, and
--       F5.1 row 20 once ESS is proven
--  Binds: none used (the five standard binds are accepted for BIP parity).
--
--  WHY: the ESS rules rest on stored values; each is printed with a verdict:
--    definitions are 'JobDefinition://<path>/<job>'          block B
--    customer jobs sit under /oracle/apps/ess/custom/        block C
--    the BIP report of a job is request property 'reportID' block G
--
--  OUTPUT  ord | section | item | value_text   (one grid, paste it back whole)
--    A 101-105  ESS retained history (A1 = F5.2b REQUESTS_RETAINED)
--    B 200-210  ESS definition types; 200 = verdict
--    C 301-303  custom-path rule vs the June draft rule ('/custom/' anywhere)
--    D 401-430  job-name prefixes of custom jobs (first 2 / 3 letters): the
--               client's naming convention, for the migration document
--    E 501      custom scheduled processes = F5.2 rows
--    F 601-610  ESS application values of the custom jobs
--    G 700-710  request properties of the custom jobs' latest requests
--    H 801-810  sample custom jobs: what NAME / APPLICATION / path hold
--  Pure SELECT. Nothing is written.
-- ============================================================================
WITH
-- ---- PARAMS / WINDOW / SCOPE: copied unchanged from F1 (shared block v3.1).
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
-- user accounts - copied from F3.2 / F5.1
user_accts AS (
    SELECT  UPPER(pu.username) AS uname
    FROM    per_users pu
    WHERE   pu.username IS NOT NULL
    GROUP   BY UPPER(pu.username)
),
-- ==== ESS ===================================================================
-- one pass over request history (NULL definitions kept, so A1 = F5.2b)
ess_def AS (
    SELECT erh.definition                                         AS definition,
           COUNT(*)                                               AS req_cnt,
           SUM(CASE WHEN erh.processstart IS NOT NULL
                    THEN 1 ELSE 0 END)                            AS exec_all,
           MIN(erh.processstart)                                  AS first_start,
           MAX(erh.processstart)                                  AS last_start,
           MAX(erh.requestid)                                     AS last_request_id,
           TO_CHAR(MAX(erh.name) KEEP (DENSE_RANK LAST ORDER BY erh.requestid))
                                                                  AS recorded_name,
           TO_CHAR(MAX(erh.application) KEEP (DENSE_RANK LAST ORDER BY erh.requestid))
                                                                  AS ess_application
    FROM   ess_request_history erh
    GROUP  BY erh.definition
),
ess_def_parsed AS (
    SELECT d.definition,
           SUBSTR(d.definition, 1, INSTR(d.definition, '://') - 1)        AS def_type,
           UPPER(SUBSTR(d.definition, INSTR(d.definition, '/', -1) + 1))  AS job_name_uc,
           CASE WHEN INSTR(LOWER(d.definition), '/oracle/apps/ess/custom/') > 0
                THEN 'Y' ELSE 'N' END                                     AS custom_path,
           CASE WHEN INSTR(UPPER(d.definition), '/CUSTOM/') > 0
                THEN 'Y' ELSE 'N' END                                     AS custom_anywhere,
           SUBSTR(d.definition, INSTR(d.definition, '/', -1) + 1)         AS job_name,
           SUBSTR(d.definition, INSTR(d.definition, '://') + 2,
                  INSTR(d.definition, '/', -1) - INSTR(d.definition, '://') - 2)
                                                                          AS job_path,
           d.req_cnt, d.exec_all, d.last_request_id, d.recorded_name, d.ess_application
    FROM   ess_def d
    WHERE  d.definition IS NOT NULL
),
-- the custom-job rule (identical in F5.1, F5.2 and V5_1)
custom_job AS (
    SELECT e.definition, e.job_name, e.job_path, e.job_name_uc,
           e.req_cnt, e.exec_all, e.last_request_id, e.recorded_name, e.ess_application
    FROM   ess_def_parsed e
    WHERE  e.def_type    = 'JobDefinition'
    AND    e.custom_path = 'Y'
),
cov AS (
    SELECT SUM(d.exec_all)                                          AS started,
           SUM(d.req_cnt - d.exec_all)                              AS never_started,
           MIN(d.first_start)                                       AS first_start,
           MAX(d.last_start)                                        AS last_start,
           SUM(CASE WHEN d.definition IS NOT NULL THEN 1 ELSE 0 END) AS n_defs
    FROM   ess_def d
),
def_types AS (
    SELECT NVL(TO_CHAR(e.def_type), '(no ://)') AS def_type,
           COUNT(*)                             AS n_def,
           SUM(e.req_cnt)                       AS n_req
    FROM   ess_def_parsed e
    GROUP  BY NVL(TO_CHAR(e.def_type), '(no ://)')
),
def_type_rows AS (
    SELECT t.def_type, t.n_def, t.n_req,
           ROW_NUMBER() OVER (ORDER BY t.n_def DESC, t.def_type) AS rn
    FROM   def_types t
),
def_type_chk AS (
    SELECT NVL(SUM(CASE WHEN t.def_type = 'JobDefinition' THEN t.n_def END), 0) AS n_jobdef
    FROM   def_types t
),
path_chk AS (
    SELECT NVL(SUM(CASE WHEN e.custom_path     = 'Y' THEN 1 ELSE 0 END), 0) AS n_path,
           NVL(SUM(CASE WHEN e.custom_anywhere = 'Y' THEN 1 ELSE 0 END), 0) AS n_anywhere,
           NVL(SUM(CASE WHEN e.custom_anywhere = 'Y' AND e.custom_path = 'N'
                        THEN 1 ELSE 0 END), 0)                              AS n_diff
    FROM   ess_def_parsed e
    WHERE  e.def_type = 'JobDefinition'
),
pfx2 AS (
    SELECT TO_CHAR(SUBSTR(cj.job_name_uc, 1, 2)) AS pf, COUNT(*) AS n
    FROM   custom_job cj
    GROUP  BY TO_CHAR(SUBSTR(cj.job_name_uc, 1, 2))
),
pfx2_rows AS (
    SELECT x.pf, x.n, ROW_NUMBER() OVER (ORDER BY x.n DESC, x.pf) AS rn FROM pfx2 x
),
pfx3 AS (
    SELECT TO_CHAR(SUBSTR(cj.job_name_uc, 1, 3)) AS pf, COUNT(*) AS n
    FROM   custom_job cj
    GROUP  BY TO_CHAR(SUBSTR(cj.job_name_uc, 1, 3))
),
pfx3_rows AS (
    SELECT x.pf, x.n, ROW_NUMBER() OVER (ORDER BY x.n DESC, x.pf) AS rn FROM pfx3 x
),
job_cnt AS (
    SELECT COUNT(*) AS n_custom FROM custom_job
),
app_vals AS (
    SELECT NVL(cj.ess_application, '(blank)') AS app, COUNT(*) AS n
    FROM   custom_job cj
    GROUP  BY NVL(cj.ess_application, '(blank)')
),
app_rows AS (
    SELECT a.app, a.n, ROW_NUMBER() OVER (ORDER BY a.n DESC, a.app) AS rn FROM app_vals a
),
prop_vals AS (
    SELECT TO_CHAR(rp.name) AS prop_name, COUNT(*) AS n
    FROM   custom_job cj
    JOIN   ess_request_property rp ON rp.requestid = cj.last_request_id
    GROUP  BY TO_CHAR(rp.name)
),
prop_rows AS (
    SELECT pv.prop_name, pv.n, ROW_NUMBER() OVER (ORDER BY pv.n DESC, pv.prop_name) AS rn
    FROM   prop_vals pv
),
rpt_cov AS (
    SELECT COUNT(*) AS n_with_rpt
    FROM  ( SELECT cj.definition
            FROM   custom_job cj
            JOIN   ess_request_property rp ON rp.requestid = cj.last_request_id
            WHERE  rp.name = 'reportID'
            GROUP  BY cj.definition )
),
sample_rows AS (
    SELECT cj.job_name, cj.job_path, cj.recorded_name, cj.ess_application, cj.exec_all,
           ROW_NUMBER() OVER (ORDER BY cj.exec_all DESC, cj.job_name, cj.definition) AS rn
    FROM   custom_job cj
),
grid AS (
    -- A ------------------------------------------------------------------------
    SELECT 101                                         AS ord,
           CAST('A ESS history' AS VARCHAR2(400))      AS section,
           CAST('A1 requests that started (PROCESSSTART set) = F5.2b REQUESTS_RETAINED'
                AS VARCHAR2(400))                      AS item,
           CAST(TO_CHAR(cv.started) AS VARCHAR2(4000)) AS value_text
    FROM   cov cv
    UNION ALL
    SELECT 102, TO_CHAR('A ESS history'), TO_CHAR('A2 requests never started (no PROCESSSTART)'),
           TO_CHAR(cv.never_started)
    FROM   cov cv
    UNION ALL
    SELECT 103, TO_CHAR('A ESS history'), TO_CHAR('A3 first start in retained history'),
           NVL(TO_CHAR(cv.first_start, 'YYYY-MM-DD HH24:MI'), '-')
    FROM   cov cv
    UNION ALL
    SELECT 104, TO_CHAR('A ESS history'), TO_CHAR('A4 last start in retained history'),
           NVL(TO_CHAR(cv.last_start, 'YYYY-MM-DD HH24:MI'), '-')
    FROM   cov cv
    UNION ALL
    SELECT 105, TO_CHAR('A ESS history'), TO_CHAR('A5 job definitions in retained history'),
           TO_CHAR(cv.n_defs)
    FROM   cov cv
    -- B ------------------------------------------------------------------------
    UNION ALL
    SELECT 200, TO_CHAR('B ESS definition types'), TO_CHAR('B0 verdict'),
           TO_CHAR(CASE WHEN tc.n_jobdef > 0
                        THEN 'OK: ' || tc.n_jobdef || ' JobDefinition definitions found'
                        ELSE '*** JobDefinition NOT FOUND: F5.2 would read 0.'
                             || ' Send this grid back before running F5. ***'
                   END)
    FROM   def_type_chk tc
    UNION ALL
    SELECT 200 + tr.rn, TO_CHAR('B ESS definition types'), TO_CHAR('B ' || tr.def_type),
           TO_CHAR(tr.n_def || ' definitions, ' || tr.n_req || ' requests')
    FROM   def_type_rows tr
    WHERE  tr.rn <= 10
    -- C ------------------------------------------------------------------------
    UNION ALL
    SELECT 301, TO_CHAR('C ESS custom path'),
           TO_CHAR('C1 JobDefinitions under /oracle/apps/ess/custom/ (rule used)'),
           TO_CHAR(pc.n_path)
    FROM   path_chk pc
    UNION ALL
    SELECT 302, TO_CHAR('C ESS custom path'),
           TO_CHAR('C2 JobDefinitions with /custom/ anywhere (June draft rule)'),
           TO_CHAR(pc.n_anywhere)
    FROM   path_chk pc
    UNION ALL
    SELECT 303, TO_CHAR('C ESS custom path'), TO_CHAR('C3 verdict'),
           TO_CHAR(CASE WHEN pc.n_diff = 0
                        THEN 'OK: the two rules agree'
                        ELSE 'CHECK: ' || pc.n_diff || ' definitions have /custom/ outside'
                             || ' /oracle/apps/ess/custom/ - send this grid back'
                   END)
    FROM   path_chk pc
    -- D ------------------------------------------------------------------------
    UNION ALL
    SELECT 400 + p2.rn, TO_CHAR('D ESS job-name prefix, 2 letters'), TO_CHAR('D ' || p2.pf || '*'),
           TO_CHAR(p2.n || ' custom job definitions')
    FROM   pfx2_rows p2
    WHERE  p2.rn <= 10
    UNION ALL
    SELECT 420 + p3.rn, TO_CHAR('D ESS job-name prefix, 3 letters'), TO_CHAR('D ' || p3.pf || '*'),
           TO_CHAR(p3.n || ' custom job definitions')
    FROM   pfx3_rows p3
    WHERE  p3.rn <= 10
    -- E ------------------------------------------------------------------------
    UNION ALL
    SELECT 501, TO_CHAR('E ESS custom jobs'),
           TO_CHAR('E1 custom scheduled processes = F5.2 rows'),
           TO_CHAR(jc.n_custom)
    FROM   job_cnt jc
    -- F ------------------------------------------------------------------------
    UNION ALL
    SELECT 600 + ar.rn, TO_CHAR('F ESS application'), TO_CHAR('F ' || ar.app),
           TO_CHAR(ar.n || ' custom job definitions')
    FROM   app_rows ar
    WHERE  ar.rn <= 10
    -- G ------------------------------------------------------------------------
    UNION ALL
    SELECT 700, TO_CHAR('G ESS request properties'),
           TO_CHAR('G0 custom jobs whose latest request has a reportID property'),
           TO_CHAR(rc.n_with_rpt || ' of ' || jc.n_custom)
    FROM   rpt_cov rc
    CROSS  JOIN job_cnt jc
    UNION ALL
    SELECT 700 + pr.rn, TO_CHAR('G ESS request properties'), TO_CHAR('G ' || pr.prop_name),
           TO_CHAR(pr.n || ' latest requests carry it')
    FROM   prop_rows pr
    WHERE  pr.rn <= 10
    -- H ------------------------------------------------------------------------
    UNION ALL
    SELECT 800 + sr.rn, TO_CHAR('H sample custom jobs'), TO_CHAR('H ' || sr.job_name),
           TO_CHAR('NAME=' || NVL(sr.recorded_name, '(null)')
                   || ' | APPLICATION=' || NVL(sr.ess_application, '(null)')
                   || ' | PATH=' || sr.job_path
                   || ' | started=' || sr.exec_all)
    FROM   sample_rows sr
    WHERE  sr.rn <= 10
)
SELECT  g.ord         AS ord,
        g.section     AS section,
        g.item        AS item,
        g.value_text  AS value_text
FROM    grid g
ORDER BY g.ord
