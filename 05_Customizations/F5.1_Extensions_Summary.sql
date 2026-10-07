-- ============================================================================
--  F5.1  Section 5.1 CEMLI summary (Fusion) - the 5 finalized cards
--  Version   : 2.1 (2026-10-06). Not yet run on a pod.
--              v2.1 (after R033 / R035 and the user's decision 2026-10-06):
--                card 3 counts DASHBOARDS, not dashboard pages. The catalog index
--                holds one Dashboard row per page (R033: custom 339 rows); the
--                dashboard is the page's parent folder, or the row itself when
--                it sits directly in a '_portal' folder, and a '/' inside a name
--                is stored as '\/' (R035 J: custom = 57 dashboards). The notes
--                give the page count too. Expected 35 + 57 = 92 (v2.0: 374).
--                card 1 notes give the ESS history start: ESS keeps only recent
--                history (R035: from 2026-09-21 on this pod), so the card is a
--                floor of the custom jobs that ran since then.
--                Expected on this pod: card 1 = 2, card 2 = 196, card 4 = 106,
--                card 5 = 36. Cards 2, 4 and 5 are unchanged from v2.0.
--              v2.0 (user decision 2026-10-05): "keep only these many in CEMLI" -
--              the five cards finalized earlier for the Fusion-to-Fusion report
--              (June draft 12_S5.1_CEMLI_Summary.sql, same labels and column
--              names). Each card now uses the rule verified on this pod:
--                1 Custom Scheduled Processes (ESS)  ESS job definitions under
--                  /oracle/apps/ess/custom/ (rule identical to F5.2)
--                2 Custom BIP Reports                BIP, path under /shared/Custom/
--                3 Custom OTBI Reports               Analysis + Dashboard, same path
--                4 Custom BIP Templates              card-2 reports that carry an ESS
--                  job definition (the June rule; see the note below)
--                5 Workflow / Approval Rule Customizations  POR_AMX_RULES active,
--                  not the sandbox copy (the June rule)
--              The v1.4 rows that are no longer cards (roles, flexfields, lookups,
--              value sets, accounting rules, alerts, sandboxes, personal folders,
--              VB Studio) were measured in R017 - R019 and stay in RUN_LOG; they
--              are not dropped silently. v1.4 is frozen in query_snapshots.
--              RUN V5_2a FIRST: card 1 reads ESS_REQUEST_HISTORY, which V5_0
--              (R016) could not see. If V5_2a errors, this query errors too -
--              send the error and the ESS card is moved to its own query.
--              Log every run in 06_Run_Results/RUN_LOG.md.
--  Source    : Oracle Fusion Cloud (BIP data model, data source ApplicationDB_FSCM)
--  Mirrors   : the finalized Fusion-to-Fusion 5.1 cards (June draft), which play
--              the role of EBS 5.1 (agent ebs_discover_cemli).
--  Window    : SNAPSHOT. The dates are accepted and ignored.
--  Scope     : pod-wide. The five standard binds are accepted for BIP parity.
--
--  CHANGES AGAINST THE JUNE DRAFT (rules, not cards)
--    card 1  June: COUNT(DISTINCT DEFINITION) with '/CUSTOM/' anywhere. Now: one
--            per JobDefinition under /oracle/apps/ess/custom/ (job sets are not
--            programs - EBS parity), so the card equals the F5.2 row count.
--            No DISTINCT (house rule).
--    card 2  June: REPORT_FOLDER LIKE '%/Custom/%'. Now: REPORT_PATH under
--            /shared/Custom/, compared lower-cased (R017: the 570 custom items
--            are exactly BIP 196 + Analysis 35 + Dashboard 339).
--    card 3  June: type 'Analysis' only (the June S8.1 draft used Analysis +
--            Dashboard + Story). Now: Analysis + Dashboard, split in the notes.
--    card 4  Same rule as June. NOTE: GL_FRC_REPORTS_B has no template column;
--            BIP_REPORT_JOB_DEFINITION "holds the ESS job definition of a BIP
--            report" (Oracle doc), so this card counts custom BIP reports set up
--            to run as scheduled processes. The notes say so.
--    card 5  Same rule as June; the notes add how many are unnamed default
--            rules (SoaOLabel.EmptyRule...).
--  GUARD: a card whose source table returns no rows to this report user shows
--  a blank count with "Not measured", never 0.
--  Last measured on this pod: card 2 = 196 (R017), card 3 = 35 analyses +
--  57 dashboards = 92 (R035; the 339 rows R017 counted are pages), card 4 = 106
--  (R032), card 5 = 36 (9 unnamed, R019), card 1 = 2 custom job definitions in
--  the ESS history kept since 2026-09-21 (R035).
-- ============================================================================
WITH
-- ---- PARAMS / WINDOW / SCOPE: copied unchanged from F1 (shared block v3.1).
--      Section 5 is pod-wide, so nothing here is read; it is kept for parity
--      with every other query.
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
-- ---- 1 Custom Scheduled Processes (ESS): one row per job definition --------
ess_def AS (
    SELECT erh.definition AS definition,
           COUNT(*)       AS req_cnt
    FROM   ess_request_history erh
    WHERE  erh.definition IS NOT NULL
    GROUP  BY erh.definition
),
ess_def_parsed AS (
    SELECT d.definition,
           SUBSTR(d.definition, 1, INSTR(d.definition, '://') - 1)        AS def_type,
           CASE WHEN INSTR(LOWER(d.definition), '/oracle/apps/ess/custom/') > 0
                THEN 'Y' ELSE 'N' END                                     AS custom_path
    FROM   ess_def d
),
-- the custom-job rule (identical in F5.1, F5.2 and V5_4)
custom_job AS (
    SELECT e.definition
    FROM   ess_def_parsed e
    WHERE  e.def_type    = 'JobDefinition'
    AND    e.custom_path = 'Y'
),
ess_cnt AS (
    SELECT COUNT(*) AS cnt FROM custom_job
),
ess_all AS (
    SELECT COUNT(*) AS n_all FROM ess_def
),
-- how far back ESS history reaches (R035: PROCESSSTART exists)
ess_hist AS (
    SELECT MIN(erh.processstart) AS hist_start
    FROM   ess_request_history erh
),
-- ---- 2-4 BI catalog: custom BIP reports, OTBI reports, BIP with a job --------
bi_tot AS (
    SELECT COUNT(*) AS n_all FROM gl_frc_reports_b r
),
bi_items AS (
    SELECT UPPER(r.report_type_code)                                         AS type_uc,
           r.report_path,
           MAX(CASE WHEN r.bip_report_job_definition IS NOT NULL THEN 1 ELSE 0 END) AS has_job
    FROM   gl_frc_reports_b r
    WHERE  LOWER(r.report_path) LIKE '/shared/custom/%'
    GROUP  BY UPPER(r.report_type_code), r.report_path
),
bi_cnt AS (
    -- NVL: with no custom item at all, SUM returns NULL, and a blank here
    -- would wrongly read as "not measured"
    SELECT NVL(SUM(CASE WHEN b.type_uc = 'BIP'       THEN 1 ELSE 0 END), 0) AS n_bip,
           NVL(SUM(CASE WHEN b.type_uc = 'ANALYSIS'  THEN 1 ELSE 0 END), 0) AS n_analysis,
           NVL(SUM(CASE WHEN b.type_uc = 'DASHBOARD' THEN 1 ELSE 0 END), 0) AS n_dashboard,
           NVL(SUM(CASE WHEN b.type_uc = 'BIP' AND b.has_job = 1
                        THEN 1 ELSE 0 END), 0)                              AS n_bip_job
    FROM   bi_items b
),
-- ---- 3 dashboards at DASHBOARD grain (v2.1). The index has one row per page;
--      the dashboard is the page's parent folder, or the row itself when it
--      sits directly in a '_portal' folder. A '/' inside a name is stored as
--      '\/': CHR(31) stands in for it while the path is split. Same rule as
--      the Section 8 block v1.1.
bi_dash AS (
    SELECT CASE WHEN LOWER(NVL(REGEXP_SUBSTR(
                         REGEXP_REPLACE(REPLACE(r.report_path, '\/', CHR(31)), '/[^/]*$', ''),
                         '[^/]+$'), '-')) = '_portal'
                THEN REPLACE(r.report_path, '\/', CHR(31))
                ELSE REGEXP_REPLACE(REPLACE(r.report_path, '\/', CHR(31)), '/[^/]*$', '')
           END                                                       AS dash_key
    FROM   gl_frc_reports_b r
    WHERE  UPPER(r.report_type_code) = 'DASHBOARD'
    AND    LOWER(r.report_path) LIKE '/shared/custom/%'
),
bi_dash_grp AS (
    SELECT b.dash_key, COUNT(*) AS n_pages
    FROM   bi_dash b
    GROUP  BY b.dash_key
),
bi_dash_cnt AS (
    SELECT COUNT(*) AS n_dash, NVL(SUM(g.n_pages), 0) AS n_pages
    FROM   bi_dash_grp g
),
-- ---- 5 Workflow / approval rules: active, not the sandbox copy ---------------
amx_cnt AS (
    SELECT COUNT(*)                                                   AS n_all,
           NVL(SUM(CASE WHEN ar.active_flag = 'Y'
                         AND NVL(ar.sandbox_flag, 'N') <> 'Y'
                        THEN 1 ELSE 0 END), 0)                        AS cnt,
           NVL(SUM(CASE WHEN ar.active_flag = 'Y'
                         AND NVL(ar.sandbox_flag, 'N') <> 'Y'
                         AND ar.display_rule_name LIKE 'SoaOLabel.%'
                        THEN 1 ELSE 0 END), 0)                        AS n_unnamed
    FROM   por_amx_rules ar
),
grid AS (
    SELECT 1                                                              AS sort_order,
           CAST('Custom Scheduled Processes (ESS)' AS VARCHAR2(200))      AS category,
           CASE WHEN ea.n_all > 0 THEN ec.cnt END                         AS cnt,
           CAST(CASE WHEN ea.n_all > 0
                     THEN 'ESS request history: job definitions under /oracle/apps/ess/custom/,'
                          || ' where Fusion creates every customer job. Floor: ESS keeps history'
                          || ' only from ' || NVL(TO_CHAR(eh.hist_start, 'YYYY-MM-DD'), '-')
                          || ' on this pod, so a custom job not run since then is not visible.'
                          || ' Listed in 5.2.'
                     ELSE 'Not measured: ESS_REQUEST_HISTORY returns no rows to this report user,'
                          || ' so a 0 here would be false.'
                END AS VARCHAR2(1000))                                    AS basis
    FROM   ess_cnt ec
    CROSS  JOIN ess_all ea
    CROSS  JOIN ess_hist eh
    UNION ALL
    SELECT 2, TO_CHAR('Custom BIP Reports'),
           CASE WHEN bt.n_all > 0 THEN bc.n_bip END,
           TO_CHAR(CASE WHEN bt.n_all > 0
                        THEN 'BI catalog (GL_FRC_REPORTS_B): BI Publisher reports under /shared/Custom/.'
                        ELSE 'Not measured: GL_FRC_REPORTS_B returns no rows to this report user,'
                             || ' so a 0 here would be false.'
                   END)
    FROM   bi_cnt bc
    CROSS  JOIN bi_tot bt
    UNION ALL
    SELECT 3, TO_CHAR('Custom OTBI Reports'),
           CASE WHEN bt.n_all > 0 THEN bc.n_analysis + dc.n_dash END,
           TO_CHAR(CASE WHEN bt.n_all > 0
                        THEN 'BI catalog (GL_FRC_REPORTS_B): OTBI analyses (' || bc.n_analysis
                             || ') and dashboards (' || dc.n_dash || ', holding ' || dc.n_pages
                             || ' pages) under /shared/Custom/.'
                        ELSE 'Not measured: GL_FRC_REPORTS_B returns no rows to this report user,'
                             || ' so a 0 here would be false.'
                   END)
    FROM   bi_cnt bc
    CROSS  JOIN bi_dash_cnt dc
    CROSS  JOIN bi_tot bt
    UNION ALL
    SELECT 4, TO_CHAR('Custom BIP Templates'),
           CASE WHEN bt.n_all > 0 THEN bc.n_bip_job END,
           TO_CHAR(CASE WHEN bt.n_all > 0
                        THEN 'BI catalog (GL_FRC_REPORTS_B): custom BI Publisher reports (card 2) that'
                             || ' carry an ESS job definition (BIP_REPORT_JOB_DEFINITION), i.e. are set'
                             || ' up to run as scheduled processes.'
                        ELSE 'Not measured: GL_FRC_REPORTS_B returns no rows to this report user,'
                             || ' so a 0 here would be false.'
                   END)
    FROM   bi_cnt bc
    CROSS  JOIN bi_tot bt
    UNION ALL
    SELECT 5, TO_CHAR('Workflow / Approval Rule Customizations'),
           CASE WHEN ax.n_all > 0 THEN ax.cnt END,
           TO_CHAR(CASE WHEN ax.n_all > 0
                        THEN 'POR_AMX_RULES: active procurement approval rules, the sandbox copy of'
                             || ' each rule excluded; ' || ax.n_unnamed
                             || ' of them are unnamed default rules (SoaOLabel.EmptyRule...).'
                        ELSE 'Not measured: POR_AMX_RULES returns no rows to this report user,'
                             || ' so a 0 here would be false.'
                   END)
    FROM   amx_cnt ax
)
SELECT
    g.category                                                AS "CEMLI Category",
    g.cnt                                                     AS "Count",
    g.basis                                                   AS "Source / Notes"
FROM        grid g
ORDER BY    g.sort_order
