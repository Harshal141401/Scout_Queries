-- ============================================================================
--  F5.2  Section 5.2 Custom scheduled processes (Fusion counterpart of the EBS
--        custom concurrent programs table) + workbook sheet
--  Version   : 1.1 (2026-10-05). Not yet run on a pod.
--              v1.1 (user, 2026-10-05: "use what Fusion uses"): custom = Fusion's
--              own marker only, the /oracle/apps/ess/custom/ path. The EBS
--              prefix (XOR) rule and its block are removed; :p_custom_prefix
--              is accepted and not used. Same rule as F5.1 v1.1 row 20.
--              RUN V5_0 AND V5_1 FIRST. Log every run in 06_Run_Results/RUN_LOG.md.
--  Source    : Oracle Fusion Cloud (BIP data model, data source ApplicationDB_FSCM)
--  Mirrors   : EBS agent _TOP_CUSTOM_PROGRAMS_SQL / ebs_discover_cemli 5.2
--              (agent 2026-09-23; report 30-Sep-2026, Vision: 11 programs, all
--              0 / 0 - EBS numbers, not targets)
--  Window    : WINDOWED. Executions (period) use the shared win block, the same
--              dates as F1 (report window: 2025-04-01 to 2026-03-31). Blank
--              dates = last 90 days. The all-time columns ignore the window.
--  Scope     : pod-wide (ESS is a pod service). :p_ledger_id / :p_bu_id /
--              :p_custom_prefix are accepted and not used (parameter parity).
--  Output    : the FULL list, one row per custom job definition, ordered by
--              executions in the period (EBS order). The report shows the
--              first 10 rows; the workbook
--              Fusion_Discovery_5_2_Custom_Scheduled_Processes.xlsx takes all.
--              Read with F5.2_ESS_History_Coverage (how far back history goes).
--
--  WHAT IS THE SAME AS EBS
--    * "Custom" = job definition under /oracle/apps/ess/custom/, the path
--      Fusion gives every customer-created job (the Fusion counterpart of the
--      EBS custom marker). The rule is identical to F5.1, so the row count
--      here = F5.1 row 20.
--    * Execution = a request that actually started: PROCESSSTART is populated
--      (EBS: ACTUAL_START_DATE). Requests never started are not executions.
--    * A job with requests but no execution still gets a row with 0 (EBS lists
--      every custom program, run or not).
--    * All-time columns disambiguate a 0 in the period:
--        period 0, all-time > 0 -> ran, just not in the period
--        period 0, all-time = 0 -> submitted but never started in retained history
--    * Identity = the full DEFINITION path (EBS: application_id + program_id),
--      so two jobs with the same name in different packages stay separate.
--
--  EBS COLUMN -> FUSION COLUMN
--    Program (short name)   -> JOB_NAME          last segment of DEFINITION
--    Program (user name)    -> NAME_AS_RECORDED  ESS_REQUEST_HISTORY.NAME, latest
--                                                request (V5_1 block H shows what
--                                                it holds)
--    Application            -> ESS_APPLICATION   ESS_REQUEST_HISTORY.APPLICATION,
--                                                latest request
--    (none)                 -> JOB_PATH          the package path; for a copied
--                                                Oracle job it names the product
--    Executable / SQL object-> BIP_REPORT        the reportID property of the
--                                                latest request (BIP job type)
--    Exec period / first / last / all-time / last run  -> same metrics
--
--  EBS COLUMNS WITH NO FUSION SQL SOURCE (not shown, not guessed)
--    Enabled, Created, Description, Execution method: these live on the job
--    definition in MDS, not in request history. Take them from Manage
--    Enterprise Scheduler Job Definitions if needed.
--
--  FLOOR: a job defined but never submitted, or whose requests were all
--  purged, has no row here. State that beside the table, as EBS states its
--  purge caveat.
-- ============================================================================
WITH
-- ---- PARAMS / WINDOW / SCOPE: copied unchanged from F1 (shared block v3.1).
--      Section 5 is pod-wide, so only params and win are read; the rest is
--      kept for parity with every other query.
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
-- ---- one pass over request history: per job definition, all-time and period
ess_def AS (
    SELECT erh.definition                                         AS definition,
           COUNT(*)                                               AS req_cnt,
           SUM(CASE WHEN erh.processstart IS NOT NULL
                    THEN 1 ELSE 0 END)                            AS exec_all,
           MAX(erh.processstart)                                  AS last_run_all,
           SUM(CASE WHEN erh.processstart >= w.start_date
                     AND erh.processstart <  w.end_date_excl
                    THEN 1 ELSE 0 END)                            AS exec_win,
           MIN(CASE WHEN erh.processstart >= w.start_date
                     AND erh.processstart <  w.end_date_excl
                    THEN erh.processstart END)                    AS first_run_win,
           MAX(CASE WHEN erh.processstart >= w.start_date
                     AND erh.processstart <  w.end_date_excl
                    THEN erh.processstart END)                    AS last_run_win,
           MAX(erh.requestid)                                     AS last_request_id,
           TO_CHAR(MAX(erh.name) KEEP (DENSE_RANK LAST ORDER BY erh.requestid))
                                                                  AS recorded_name,
           TO_CHAR(MAX(erh.application) KEEP (DENSE_RANK LAST ORDER BY erh.requestid))
                                                                  AS ess_application
    FROM   ess_request_history erh
    CROSS  JOIN win w
    WHERE  erh.definition IS NOT NULL
    GROUP  BY erh.definition
),
ess_def_parsed AS (
    SELECT d.definition,
           SUBSTR(d.definition, 1, INSTR(d.definition, '://') - 1)        AS def_type,
           CASE WHEN INSTR(LOWER(d.definition), '/oracle/apps/ess/custom/') > 0
                THEN 'Y' ELSE 'N' END                                     AS custom_path,
           SUBSTR(d.definition, INSTR(d.definition, '/', -1) + 1)         AS job_name,
           SUBSTR(d.definition, INSTR(d.definition, '://') + 2,
                  INSTR(d.definition, '/', -1) - INSTR(d.definition, '://') - 2)
                                                                          AS job_path,
           d.exec_all, d.last_run_all, d.exec_win, d.first_run_win, d.last_run_win,
           d.last_request_id, d.recorded_name, d.ess_application
    FROM   ess_def d
),
-- the custom-job rule (identical in F5.1, F5.2 and V5_1)
custom_job AS (
    SELECT e.definition, e.job_name, e.job_path,
           e.exec_all, e.last_run_all, e.exec_win, e.first_run_win, e.last_run_win,
           e.last_request_id, e.recorded_name, e.ess_application
    FROM   ess_def_parsed e
    WHERE  e.def_type    = 'JobDefinition'
    AND    e.custom_path = 'Y'
),
-- the BIP report behind each job: reportID of the latest request.
-- TO_CHAR(SUBSTR(...)) gives VARCHAR2 whether VALUE is VARCHAR2, NVARCHAR2 or CLOB.
last_rpt AS (
    SELECT cj.definition,
           MAX(TO_CHAR(SUBSTR(rp.value, 1, 400))) AS report_id
    FROM   custom_job cj
    JOIN   ess_request_property rp ON rp.requestid = cj.last_request_id
    WHERE  rp.name = 'reportID'
    GROUP  BY cj.definition
)
SELECT
    cj.job_name                                               AS "JOB_NAME",
    cj.recorded_name                                          AS "NAME_AS_RECORDED",
    cj.job_path                                               AS "JOB_PATH",
    cj.ess_application                                        AS "ESS_APPLICATION",
    r.report_id                                               AS "BIP_REPORT",
    cj.exec_win                                               AS "EXECUTIONS_PERIOD",
    TO_CHAR(cj.first_run_win, 'YYYY-MM-DD')                   AS "FIRST_RUN_PERIOD",
    TO_CHAR(cj.last_run_win,  'YYYY-MM-DD')                   AS "LAST_RUN_PERIOD",
    cj.exec_all                                               AS "EXECUTIONS_ALL_TIME",
    TO_CHAR(cj.last_run_all,  'YYYY-MM-DD')                   AS "LAST_RUN_ANY_TIME"
FROM        custom_job cj
LEFT JOIN   last_rpt   r ON r.definition = cj.definition
ORDER BY    cj.exec_win DESC, cj.exec_all DESC, cj.job_name, cj.definition
