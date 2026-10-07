-- ============================================================================
--  V10_1  CODE VALUES - every value the Section 10 rules use (run first)
--  Version   : 1.0 (2026-10-07)        Run log: 06_Run_Results/RUN_LOG.md
--  For: F10.2 rows 11 / 12 and F10.3 (same Section 10 block, byte-identical)
--  RUN AFTER V10_0: every object row of V10_0 must say ALL OK. This query
--  reads FND_LANGUAGES_B / _TL, FND_PROFILE_OPTIONS_B, FND_PROFILE_OPTION_VALUES,
--  FND_TIMEZONES_TL, ADF_SB_SANDBOXES and FND_LOOKUP_VALUES (V10_0 checks
--  them) and ESS_REQUEST_HISTORY (proven by reads: R034 / R035). It reads no
--  V$ / DBA_ / NLS_ / AD_ object: those have their own read tests, V10_2a-f.
--  Binds: none used (the five standard binds are accepted for BIP parity).
--  Source    : Oracle Fusion Cloud (BIP data model, data source ApplicationDB_FSCM)
--  Window    : the load window is the last 90 days up to the run moment
--              (SYSDATE - 90), as EBS; everything else is a snapshot.
--
--  BLOCKS
--    A  scheduled-process load: retained history, window and coverage (A0);
--       F10.2 rows 11 / 12 exactly as printed (A1); the clock behind
--       PROCESSSTART - stored type (DUMP), latest submission and run against
--       SYSDATE, SYSTIMESTAMP offset, DBTIMEZONE, SESSIONTIMEZONE - with a
--       verdict on the UTC label (A2); all 24 hours, runs (the F10.2 rule) and
--       requests by NVL(PROCESSSTART, SUBMISSION) (the EBS rule) side by side
--       (A3); the peak / off-peak pick under both rules (A4); requests in the
--       window that never started, by request type and state, named from
--       lookup BEN_ESS_REQ_STATE (A5)
--    B  languages: rows vs codes (B0); every INSTALLED_FLAG x ACTIVATION_STATUS
--       with "counted Y/N" = B or I (B1); the counted languages (B2); the
--       session language and character set (B3); F10.3 row 1 as printed (B4)
--    C  default user time zone: the FND_TIMEZONE option rows (C0); every value
--       of the option with level, ENTERPRISE_ID, seed sets and "counted Y/N" =
--       site level (C1); values / site values / F10.3 row 2 as printed (C2);
--       the LEVEL_NAME codes stored across all profile values (C3)
--    D  sandboxes: rows vs sandboxes and F10.3 row 3 as printed (D0); every
--       state x publish flag x publish date x private flag with "counted Y/N" =
--       never published and not destroyed (D1); the counted sandboxes (D2)
--    E  F10.3 row 4 as printed
--  Expected: A0 history from 2026-09-21 (R035: 29,661 requests / 29,473 runs on
--  the morning of 2026-10-06; ESS grows every day, compare within this run
--  only); A2 OK (UTC); A5 mostly REQUESTTYPE 2 (89 schedule parents in R035)
--  and state 1; D1 R017: COMMITTED / Y / Y 36 (N), ACTIVE / N / N 4 (Y),
--  DESTROYED / Y / N 2 (N).
--  Decide from the printed values, not from the Oracle doc: a column that
--  exists may never be written (R024 / R026 / R037).
--
--  OUTPUT  ord | section | item | value_text   (one grid, paste it back whole)
--  Pure SELECT. Nothing is written.
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
-- ---- SECTION 10 BLOCK v1.0 (2026-10-07): scheduled-process load, languages,
--      default user time zone, sandboxes ---------------------------------------
--      Byte-identical in F10.2, F10.3 and V10_1, so the check prints exactly
--      what the report shows. Change all three or none. The ESS columns are
--      proven by reads (R034 / R035); every other column is checked by V10_0.
-- s10_win: the window of the load rows, as EBS: the last 90 days up to the run
-- moment (SYSDATE - 90), not the discovery window.
s10_win AS (
    SELECT SYSDATE - 90                                                    AS start_date
    FROM   dual
),
-- s10_ess: every request in the retained ESS history, read once. ENTERPRISE_ID
-- is 1 and DELETED is N on every row (R035 H), so nothing is filtered.
s10_ess AS (
    SELECT /*+ MATERIALIZE */
           h.requestid                                                     AS requestid,
           h.requesttype                                                   AS requesttype,
           h.state                                                         AS req_state,
           h.submission                                                    AS submission,
           h.processstart                                                  AS processstart
    FROM   ess_request_history h
),
-- s10_span: what the retained history holds. On this pod it starts on
-- 2026-09-21 (R035: 29,661 requests, 29,473 runs), so the 90 days are only
-- partly covered.
s10_span AS (
    SELECT COUNT(*)                                                        AS n_req,
           MIN(e.submission)                                               AS min_sub,
           MAX(e.submission)                                               AS max_sub,
           COUNT(e.processstart)                                           AS n_runs,
           MIN(e.processstart)                                             AS min_ps,
           MAX(e.processstart)                                             AS max_ps
    FROM   s10_ess e
),
-- s10_cover: whether the history covers the whole 90 days, how many days it
-- does cover (for the per-day figure) and the span the load rows print
s10_cover AS (
    SELECT s.n_req,
           s.n_runs,
           CASE WHEN s.min_ps IS NULL THEN NULL
                WHEN CAST(s.min_ps AS DATE) <= w.start_date THEN 'Y'
                ELSE 'N'
           END                                                             AS full_window,
           SYSDATE - GREATEST(w.start_date,
                              NVL(CAST(s.min_ps AS DATE), w.start_date))   AS cover_days,
           CASE WHEN s.min_ps IS NULL THEN NULL
                WHEN CAST(s.min_ps AS DATE) <= w.start_date THEN 'last 90 days'
                ELSE 'ESS history ' || TO_CHAR(s.min_ps, 'YYYY-MM-DD')
                     || ' to ' || TO_CHAR(s.max_ps, 'YYYY-MM-DD')
           END                                                             AS span_text
    FROM   s10_span s
    CROSS  JOIN s10_win w
),
-- s10_run_hour: runs in the window per hour of day. A run = a request with
-- PROCESSSTART (it started, whatever the outcome), as Section 8 counts runs
-- and as EBS counts ACTUAL_START_DATE. EBS also counts requests that never
-- started, at their request date; in ESS those are mostly schedule parents
-- (REQUESTTYPE 2), which never run themselves, so they are left out. V10_1
-- A3 / A4 print both rules. The hour is read from PROCESSSTART as stored;
-- V10_1 A2 proves its clock (the report labels it UTC).
s10_run_hour AS (
    SELECT TO_CHAR(e.processstart, 'HH24')                                 AS hod,
           COUNT(*)                                                        AS n_runs
    FROM   s10_ess e
    CROSS  JOIN s10_win w
    WHERE  e.processstart >= w.start_date
    GROUP  BY TO_CHAR(e.processstart, 'HH24')
),
-- s10_load: the EBS pick. Peak = the hour of day with the most runs; off-peak
-- = the hour with the fewest runs among the hours that have any (an hour with
-- no run has no row). A tie goes to the later hour, as EBS's KEEP (DENSE_RANK
-- LAST ...) does.
s10_load AS (
    SELECT MAX(r.n_runs)                                                   AS peak_runs,
           MIN(r.n_runs)                                                   AS offpeak_runs,
           MAX(r.hod) KEEP (DENSE_RANK LAST ORDER BY r.n_runs)             AS peak_hod,
           MAX(r.hod) KEEP (DENSE_RANK LAST ORDER BY r.n_runs DESC)        AS offpeak_hod,
           COUNT(*)                                                        AS n_hours,
           NVL(SUM(r.n_runs), 0)                                           AS n_runs_win
    FROM   s10_run_hour r
),
-- s10_lang: one row per language (FND_LANGUAGES_B, key LANGUAGE_CODE).
-- INSTALLED_FLAG B = base, I = installed, D = disabled are the EBS codes;
-- V10_1 B1 prints the values stored. Base and installed languages count.
s10_lang AS (
    SELECT TO_CHAR(b.language_code)                                        AS language_code,
           MAX(TO_CHAR(b.nls_language))                                    AS nls_language,
           MAX(UPPER(TO_CHAR(b.installed_flag)))                           AS installed_flag,
           MAX(TO_CHAR(b.activation_status))                               AS activation_status
    FROM   fnd_languages_b b
    GROUP  BY TO_CHAR(b.language_code)
),
-- s10_lang_name: each language's name (FND_LANGUAGES_TL.DESCRIPTION) in the
-- session language, else US. FND_LANGUAGES_VL keeps USERENV('LANG') only.
s10_lang_name AS (
    SELECT TO_CHAR(t.language_code)                                        AS language_code,
           MAX(TO_CHAR(t.description)) KEEP (DENSE_RANK FIRST ORDER BY
               CASE WHEN t.language = USERENV('LANG') THEN 0 ELSE 1 END)   AS lang_name
    FROM   fnd_languages_tl t
    WHERE  t.language IN (USERENV('LANG'), 'US')
    GROUP  BY TO_CHAR(t.language_code)
),
s10_lang_all AS (
    SELECT l.language_code,
           l.nls_language,
           l.installed_flag,
           l.activation_status,
           NVL(n.lang_name, INITCAP(l.nls_language))                       AS lang_name,
           CASE WHEN l.installed_flag IN ('B', 'I') THEN 'Y' ELSE 'N' END  AS counted
    FROM        s10_lang      l
    LEFT JOIN   s10_lang_name n ON n.language_code = l.language_code
),
s10_lang_sum AS (
    SELECT COUNT(*)                                                        AS n_rows,
           NVL(SUM(CASE WHEN a.counted = 'Y' THEN 1 ELSE 0 END), 0)        AS n_installed,
           LISTAGG(CASE WHEN a.counted = 'Y'
                        THEN a.lang_name
                             || CASE WHEN a.installed_flag = 'B' THEN ' (base)' END
                   END, ', ')
               WITHIN GROUP (ORDER BY CASE WHEN a.installed_flag = 'B' THEN 0 ELSE 1 END,
                                      a.lang_name)                         AS lang_list
    FROM   s10_lang_all a
),
-- s10_tz_opt: profile option FND_TIMEZONE, "Default User Time Zone". Its site
-- value is the default every user starts with (Setup and Maintenance, Manage
-- Administrator Profile Values).
s10_tz_opt AS (
    SELECT o.application_id,
           o.profile_option_id
    FROM   fnd_profile_options_b o
    WHERE  o.profile_option_name = 'FND_TIMEZONE'
    GROUP  BY o.application_id, o.profile_option_id
),
s10_tz_opt_cnt AS (
    SELECT COUNT(*)                                                        AS n_opt
    FROM   s10_tz_opt
),
-- s10_tz_site: the site-level value. FND_PROFILE_OPTION_VALUES is keyed by
-- option, level, level value and ENTERPRISE_ID; if several site rows exist,
-- the highest ENTERPRISE_ID, then the latest update, wins (V10_1 C1 prints
-- every row of the option).
s10_tz_site AS (
    SELECT COUNT(*)                                                        AS n_site,
           MAX(TO_CHAR(v.profile_option_value)) KEEP (DENSE_RANK LAST ORDER BY
               v.enterprise_id, v.last_update_date)                        AS tz_code
    FROM   fnd_profile_option_values v
    JOIN   s10_tz_opt o ON  o.application_id    = v.application_id
                        AND o.profile_option_id = v.profile_option_id
    WHERE  UPPER(TO_CHAR(v.level_name)) = 'SITE'
),
-- s10_tz_name: time-zone names (FND_TIMEZONES_TL.NAME) in the session
-- language, else US
s10_tz_name AS (
    SELECT TO_CHAR(t.timezone_code)                                        AS tz_code,
           MAX(TO_CHAR(t.name)) KEEP (DENSE_RANK FIRST ORDER BY
               CASE WHEN t.language = USERENV('LANG') THEN 0 ELSE 1 END)   AS tz_name
    FROM   fnd_timezones_tl t
    WHERE  t.language IN (USERENV('LANG'), 'US')
    GROUP  BY TO_CHAR(t.timezone_code)
),
-- s10_sbx: one row per sandbox. ADF_SB_SANDBOXES holds this pod's sandboxes
-- (ADF_SB_SANDBOXES_B is empty, R017). Oracle's Configuration Set Migration
-- needs sandbox configurations complete and published first, so a sandbox
-- never published and not destroyed (deleted) holds work that would not move.
-- R017: COMMITTED 36 (published), ACTIVE 4, DESTROYED 2.
s10_sbx AS (
    SELECT s.sandbox_id,
           MAX(UPPER(TO_CHAR(s.sandbox_state)))                            AS sandbox_state,
           MAX(s.publish_date)                                             AS publish_date
    FROM   adf_sb_sandboxes s
    GROUP  BY s.sandbox_id
),
s10_sbx_sum AS (
    SELECT COUNT(*)                                                        AS n_rows,
           NVL(SUM(CASE WHEN x.publish_date IS NULL
                         AND NVL(x.sandbox_state, '-') <> 'DESTROYED'
                        THEN 1 ELSE 0 END), 0)                             AS n_unpublished,
           NVL(SUM(CASE WHEN x.publish_date IS NOT NULL
                         AND NVL(x.sandbox_state, '-') <> 'DESTROYED'
                        THEN 1 ELSE 0 END), 0)                             AS n_published
    FROM   s10_sbx x
),
-- s10_text: the measured rows as the report prints them (F10.2 rows 11 / 12,
-- F10.3 rows 1-4). A source that returns no rows to the report user gives a
-- blank, never 0.
s10_text AS (
    SELECT CASE WHEN c.n_req > 0 AND l.n_hours > 0
                THEN TO_CHAR(l.peak_runs, 'FM999,999,990') || ' runs in peak hour ('
                     || l.peak_hod || ':00 UTC'
                     || CASE WHEN c.cover_days > 0
                             THEN ', about '
                                  || CASE WHEN l.peak_runs / c.cover_days >= 10
                                          THEN TO_CHAR(ROUND(l.peak_runs / c.cover_days),
                                                       'FM999,999,990')
                                          ELSE TO_CHAR(ROUND(l.peak_runs / c.cover_days, 1),
                                                       'FM999,990.0')
                                     END
                                  || ' a day'
                        END
                     || '; ' || c.span_text || ')'
                WHEN c.n_req > 0
                THEN 'Scheduled process volume unavailable (no runs in the last 90 days)'
           END                                                             AS peak_text,
           CASE WHEN c.n_req > 0 AND l.n_hours > 0
                THEN TO_CHAR(l.offpeak_runs, 'FM999,999,990')
                     || ' runs in quietest active hour (' || l.offpeak_hod || ':00 UTC'
                     || CASE WHEN c.cover_days > 0
                             THEN ', about '
                                  || CASE WHEN l.offpeak_runs / c.cover_days >= 10
                                          THEN TO_CHAR(ROUND(l.offpeak_runs / c.cover_days),
                                                       'FM999,999,990')
                                          ELSE TO_CHAR(ROUND(l.offpeak_runs / c.cover_days, 1),
                                                       'FM999,990.0')
                                     END
                                  || ' a day'
                        END
                     || '; ' || c.span_text || ')'
                WHEN c.n_req > 0
                THEN 'Scheduled process volume unavailable (no runs in the last 90 days)'
           END                                                             AS offpeak_text,
           CASE WHEN ls.n_rows > 0
                THEN NVL(ls.lang_list, 'No language is marked base or installed')
           END                                                             AS lang_text,
           CASE WHEN oc.n_opt > 0
                THEN CASE WHEN ts.tz_code IS NOT NULL
                          THEN NVL(tn.tz_name, ts.tz_code)
                               || CASE WHEN tn.tz_name IS NOT NULL
                                       THEN ' (' || ts.tz_code || ')' END
                               || ', site level'
                          ELSE 'Not set at site level'
                     END
           END                                                             AS tz_text,
           CASE WHEN x.n_rows > 0
                THEN TO_CHAR(x.n_unpublished, 'FM999,999,990') || ' not yet published ('
                     || TO_CHAR(x.n_published, 'FM999,999,990') || ' published)'
           END                                                             AS sbx_text,
           CASE WHEN s.n_req > 0
                THEN TO_CHAR(s.min_sub, 'YYYY-MM-DD') || ' to '
                     || TO_CHAR(s.max_sub, 'YYYY-MM-DD') || ': '
                     || TO_CHAR(s.n_req, 'FM999,999,990') || ' requests, '
                     || TO_CHAR(s.n_runs, 'FM999,999,990') || ' runs'
           END                                                             AS hist_text
    FROM        s10_cover      c
    CROSS JOIN  s10_load       l
    CROSS JOIN  s10_span       s
    CROSS JOIN  s10_lang_sum   ls
    CROSS JOIN  s10_tz_opt_cnt oc
    CROSS JOIN  s10_tz_site    ts
    LEFT JOIN   s10_tz_name    tn ON tn.tz_code = ts.tz_code
    CROSS JOIN  s10_sbx_sum    x
),
-- ---- END OF SECTION 10 BLOCK -----------------------------------------------------
-- ==== A scheduled-process load ======================================================
-- a_time: the clock behind PROCESSSTART. DUMP gives the stored type (Typ=180
-- TIMESTAMP, 181 TIMESTAMP WITH TIME ZONE, 231 WITH LOCAL TIME ZONE). When ESS
-- writes on the database clock, the latest submission on a busy pod is a few
-- minutes before SYSDATE, and the SYSTIMESTAMP offset names that clock.
a_time AS (
    SELECT REGEXP_SUBSTR(DUMP(s.max_ps), '^Typ=[0-9]+')                    AS ps_type,
           REGEXP_SUBSTR(DUMP(s.max_sub), '^Typ=[0-9]+')                   AS sub_type,
           TO_CHAR(s.max_sub, 'YYYY-MM-DD HH24:MI:SS')                     AS max_sub_text,
           TO_CHAR(s.max_ps, 'YYYY-MM-DD HH24:MI:SS')                      AS max_ps_text,
           TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS')                       AS sysdate_text,
           TO_CHAR(SYSTIMESTAMP, 'TZH:TZM')                                AS sys_offset,
           TO_CHAR(DBTIMEZONE)                                             AS db_tz,
           TO_CHAR(SESSIONTIMEZONE)                                        AS session_tz,
           ROUND((SYSDATE - CAST(s.max_sub AS DATE)) * 1440)               AS min_since_sub,
           ROUND((SYSDATE - CAST(s.max_ps AS DATE)) * 1440)                AS min_since_ps
    FROM   s10_span s
),
-- a_req_hour: the EBS rule, for comparison only: every request by the hour of
-- NVL(PROCESSSTART, SUBMISSION) (EBS: NVL(ACTUAL_START_DATE, REQUEST_DATE))
a_req_hour AS (
    SELECT TO_CHAR(NVL(e.processstart, e.submission), 'HH24')              AS hod,
           COUNT(*)                                                        AS n_req
    FROM   s10_ess e
    CROSS  JOIN s10_win w
    WHERE  NVL(e.processstart, e.submission) >= w.start_date
    GROUP  BY TO_CHAR(NVL(e.processstart, e.submission), 'HH24')
),
a_req_load AS (
    SELECT MAX(r.n_req)                                                    AS peak_req,
           MIN(r.n_req)                                                    AS offpeak_req,
           MAX(r.hod) KEEP (DENSE_RANK LAST ORDER BY r.n_req)              AS peak_hod,
           MAX(r.hod) KEEP (DENSE_RANK LAST ORDER BY r.n_req DESC)         AS offpeak_hod,
           NVL(SUM(r.n_req), 0)                                            AS n_req_win
    FROM   a_req_hour r
),
-- a_hours: the 24 hours of the day, so an hour with no run still prints
a_hours AS (
    SELECT LPAD(TO_CHAR(ROWNUM - 1), 2, '0')                               AS hod
    FROM   dual
    CONNECT BY ROWNUM <= 24
),
a_hour_rows AS (
    SELECT h.hod,
           NVL(r.n_runs, 0)                                                AS n_runs,
           NVL(q.n_req, 0)                                                 AS n_req,
           CASE WHEN h.hod = l.peak_hod    THEN '   <- peak (F10.2)'
                WHEN h.hod = l.offpeak_hod THEN '   <- off-peak (F10.2)'
           END                                                             AS mark
    FROM        a_hours      h
    LEFT JOIN   s10_run_hour r ON r.hod = h.hod
    LEFT JOIN   a_req_hour   q ON q.hod = h.hod
    CROSS JOIN  s10_load     l
),
-- a_never: requests in the window that never started (the EBS rule would add
-- them at their submission hour), by request type and state
a_never AS (
    SELECT e.requesttype,
           e.req_state,
           COUNT(*)                                                        AS n
    FROM   s10_ess e
    CROSS  JOIN s10_win w
    WHERE  e.processstart IS NULL
    AND    e.submission >= w.start_date
    GROUP  BY e.requesttype, e.req_state
),
a_never_cnt AS (
    SELECT COUNT(*)                                                        AS n_kinds,
           NVL(SUM(v.n), 0)                                                AS n
    FROM   a_never v
),
-- a_state_name: ESS state names, lookup BEN_ESS_REQ_STATE (R035)
a_state_name AS (
    SELECT TO_CHAR(lv.lookup_code)                                         AS lookup_code,
           MAX(TO_CHAR(lv.meaning)) KEEP (DENSE_RANK FIRST ORDER BY
               CASE WHEN lv.language = USERENV('LANG') THEN 0 ELSE 1 END)  AS meaning
    FROM   fnd_lookup_values lv
    WHERE  lv.lookup_type = 'BEN_ESS_REQ_STATE'
    AND    lv.language IN (USERENV('LANG'), 'US')
    GROUP  BY TO_CHAR(lv.lookup_code)
),
a_never_rows AS (
    SELECT v.requesttype,
           v.req_state,
           v.n,
           sn.meaning,
           ROW_NUMBER() OVER (ORDER BY v.n DESC, v.requesttype, v.req_state) AS rn
    FROM        a_never      v
    LEFT JOIN   a_state_name sn ON sn.lookup_code = TO_CHAR(v.req_state)
),
-- ==== B languages ===================================================================
b_rows AS (
    SELECT COUNT(*)                                                        AS n_rows
    FROM   fnd_languages_b b
),
b_keys AS (
    SELECT COUNT(*)                                                        AS n_keys
    FROM   s10_lang
),
b_tl AS (
    SELECT COUNT(*)                                                        AS n_rows
    FROM   fnd_languages_tl t
    WHERE  t.language IN (USERENV('LANG'), 'US')
),
b_named AS (
    SELECT COUNT(*)                                                        AS n_named
    FROM   s10_lang_name
),
b_flag AS (
    SELECT NVL(a.installed_flag, '-')                                      AS installed_flag,
           NVL(a.activation_status, '-')                                   AS activation_status,
           a.counted,
           COUNT(*)                                                        AS n
    FROM   s10_lang_all a
    GROUP  BY NVL(a.installed_flag, '-'), NVL(a.activation_status, '-'), a.counted
),
b_flag_rows AS (
    SELECT f.installed_flag, f.activation_status, f.counted, f.n,
           ROW_NUMBER() OVER (ORDER BY f.counted DESC, f.installed_flag,
                                       f.activation_status)                AS rn
    FROM   b_flag f
),
b_inst_rows AS (
    SELECT a.language_code, a.nls_language, a.lang_name, a.installed_flag,
           a.activation_status,
           ROW_NUMBER() OVER (ORDER BY CASE WHEN a.installed_flag = 'B' THEN 0 ELSE 1 END,
                                       a.lang_name)                        AS rn
    FROM   s10_lang_all a
    WHERE  a.counted = 'Y'
),
b_session AS (
    SELECT TO_CHAR(USERENV('LANG'))                                        AS sess_lang,
           TO_CHAR(SYS_CONTEXT('USERENV', 'LANGUAGE'))                     AS sess_language,
           TO_CHAR(SYS_CONTEXT('USERENV', 'NLS_TERRITORY'))                AS sess_territory
    FROM   dual
),
-- ==== C default user time zone =====================================================
c_opt AS (
    SELECT o.application_id,
           o.profile_option_id,
           o.enterprise_id,
           TO_CHAR(o.ora_seed_set1) || TO_CHAR(o.ora_seed_set2)            AS seed_sets,
           TO_CHAR(o.hierarchy_name)                                       AS hierarchy_name
    FROM   fnd_profile_options_b o
    WHERE  o.profile_option_name = 'FND_TIMEZONE'
),
c_opt_sum AS (
    SELECT COUNT(*)                                                        AS n_rows,
           LISTAGG(o.application_id || ' / ' || o.profile_option_id || ' / '
                   || o.enterprise_id || ' / ' || NVL(o.seed_sets, '-') || ' / '
                   || NVL(o.hierarchy_name, '-'), '; ')
               WITHIN GROUP (ORDER BY o.application_id, o.profile_option_id,
                                      o.enterprise_id)                     AS opt_list
    FROM   c_opt o
),
-- c_val: every value of the option. A user-level row shows "(user)" instead
-- of its level value.
c_val AS (
    SELECT TO_CHAR(v.level_name)                                           AS level_name,
           CASE WHEN UPPER(TO_CHAR(v.level_name)) = 'USER' THEN '(user)'
                ELSE TO_CHAR(v.level_value)
           END                                                             AS level_value_shown,
           v.enterprise_id,
           TO_CHAR(v.profile_option_value)                                 AS opt_value,
           TO_CHAR(v.ora_seed_set1) || TO_CHAR(v.ora_seed_set2)            AS seed_sets,
           v.last_update_date,
           CASE WHEN UPPER(TO_CHAR(v.level_name)) = 'SITE' THEN 'Y' ELSE 'N' END
                                                                           AS counted
    FROM   fnd_profile_option_values v
    JOIN   s10_tz_opt o ON  o.application_id    = v.application_id
                        AND o.profile_option_id = v.profile_option_id
),
c_val_cnt AS (
    SELECT COUNT(*)                                                        AS n_rows,
           NVL(SUM(CASE WHEN c.counted = 'Y' THEN 1 ELSE 0 END), 0)        AS n_site
    FROM   c_val c
),
c_val_rows AS (
    SELECT c.level_name, c.level_value_shown, c.enterprise_id, c.opt_value, c.seed_sets,
           c.last_update_date, c.counted,
           ROW_NUMBER() OVER (ORDER BY c.counted DESC, c.level_name, c.level_value_shown,
                                       c.enterprise_id)                    AS rn
    FROM   c_val c
),
c_level AS (
    SELECT TO_CHAR(v.level_name)                                           AS level_name,
           COUNT(*)                                                        AS n
    FROM   fnd_profile_option_values v
    GROUP  BY TO_CHAR(v.level_name)
),
c_level_rows AS (
    SELECT l.level_name, l.n,
           ROW_NUMBER() OVER (ORDER BY l.n DESC, l.level_name)             AS rn
    FROM   c_level l
),
-- ==== D sandboxes ===================================================================
d_rows AS (
    SELECT COUNT(*)                                                        AS n_rows
    FROM   adf_sb_sandboxes s
),
d_keys AS (
    SELECT COUNT(*)                                                        AS n_keys
    FROM   s10_sbx
),
-- d_flag: "counted" copies the s10_sbx_sum predicate: never published and not
-- destroyed
d_flag AS (
    SELECT NVL(UPPER(TO_CHAR(s.sandbox_state)), '-')                       AS sandbox_state,
           NVL(UPPER(TO_CHAR(s.publish_flag)), '-')                        AS publish_flag,
           CASE WHEN s.publish_date IS NULL THEN 'N' ELSE 'Y' END          AS has_publish_date,
           NVL(UPPER(TO_CHAR(s.private_flag)), '-')                        AS private_flag,
           CASE WHEN s.publish_date IS NULL
                 AND NVL(UPPER(TO_CHAR(s.sandbox_state)), '-') <> 'DESTROYED'
                THEN 'Y' ELSE 'N'
           END                                                             AS counted,
           COUNT(*)                                                        AS n
    FROM   adf_sb_sandboxes s
    GROUP  BY NVL(UPPER(TO_CHAR(s.sandbox_state)), '-'),
              NVL(UPPER(TO_CHAR(s.publish_flag)), '-'),
              CASE WHEN s.publish_date IS NULL THEN 'N' ELSE 'Y' END,
              NVL(UPPER(TO_CHAR(s.private_flag)), '-'),
              CASE WHEN s.publish_date IS NULL
                    AND NVL(UPPER(TO_CHAR(s.sandbox_state)), '-') <> 'DESTROYED'
                   THEN 'Y' ELSE 'N'
              END
),
d_flag_rows AS (
    SELECT f.sandbox_state, f.publish_flag, f.has_publish_date, f.private_flag, f.counted, f.n,
           ROW_NUMBER() OVER (ORDER BY f.counted DESC, f.n DESC, f.sandbox_state) AS rn
    FROM   d_flag f
),
d_list AS (
    SELECT TO_CHAR(s.name)                                                 AS sbx_name,
           NVL(UPPER(TO_CHAR(s.sandbox_state)), '-')                       AS sandbox_state,
           TO_CHAR(s.created_by)                                           AS created_by,
           s.creation_date,
           s.last_update_date,
           ROW_NUMBER() OVER (ORDER BY s.last_update_date DESC, s.sandbox_id) AS rn
    FROM   adf_sb_sandboxes s
    WHERE  s.publish_date IS NULL
    AND    NVL(UPPER(TO_CHAR(s.sandbox_state)), '-') <> 'DESTROYED'
),
grid AS (
    -- A ---------------------------------------------------------------------------
    SELECT 100                                                      AS ord,
           CAST('A scheduled-process load' AS VARCHAR2(400))        AS section,
           CAST('A0 summary (V10_1 v1.0, Section 10 block v1.0): requests / runs /'
                || ' submitted from .. to / first .. last run / window start /'
                || ' runs in the window / hours with a run / history covers the'
                || ' 90 days / days covered'
                AS VARCHAR2(1000))                                  AS item,
           CAST(s.n_req || ' / ' || s.n_runs || ' / '
                || NVL(TO_CHAR(s.min_sub, 'YYYY-MM-DD'), '-') || ' .. '
                || NVL(TO_CHAR(s.max_sub, 'YYYY-MM-DD'), '-') || ' / '
                || NVL(TO_CHAR(s.min_ps, 'YYYY-MM-DD HH24:MI'), '-') || ' .. '
                || NVL(TO_CHAR(s.max_ps, 'YYYY-MM-DD HH24:MI'), '-') || ' / '
                || TO_CHAR(w.start_date, 'YYYY-MM-DD HH24:MI') || ' / '
                || l.n_runs_win || ' / ' || l.n_hours || ' / '
                || NVL(c.full_window, '-') || ' / '
                || NVL(TO_CHAR(ROUND(c.cover_days, 1), 'FM999,990.0'), '-')
                || '   (R035: 29,661 / 29,473 / 2026-09-21 .. 2026-10-06)'
                AS VARCHAR2(4000))                                  AS value_text
    FROM        s10_span  s
    CROSS JOIN  s10_win   w
    CROSS JOIN  s10_load  l
    CROSS JOIN  s10_cover c
    UNION ALL
    SELECT 110, TO_CHAR('A scheduled-process load'),
           TO_CHAR('A1 F10.2 row 11 (peak) as printed'),
           TO_CHAR(NVL(t.peak_text, '(blank: ESS returned no rows)'))
    FROM   s10_text t
    UNION ALL
    SELECT 111, TO_CHAR('A scheduled-process load'),
           TO_CHAR('A1 F10.2 row 12 (off-peak) as printed'),
           TO_CHAR(NVL(t.offpeak_text, '(blank: ESS returned no rows)'))
    FROM   s10_text t
    UNION ALL
    SELECT 120, TO_CHAR('A scheduled-process load'),
           TO_CHAR('A2 clock: PROCESSSTART type / SUBMISSION type / latest submission /'
                   || ' latest run / SYSDATE / SYSTIMESTAMP offset / DBTIMEZONE /'
                   || ' SESSIONTIMEZONE / minutes since the latest submission / since'
                   || ' the latest run'),
           TO_CHAR(NVL(a.ps_type, '-') || ' / ' || NVL(a.sub_type, '-') || ' / '
                   || NVL(a.max_sub_text, '-') || ' / ' || NVL(a.max_ps_text, '-') || ' / '
                   || a.sysdate_text || ' / ' || a.sys_offset || ' / ' || a.db_tz || ' / '
                   || a.session_tz || ' / ' || NVL(TO_CHAR(a.min_since_sub), '-') || ' / '
                   || NVL(TO_CHAR(a.min_since_ps), '-'))
    FROM   a_time a
    UNION ALL
    SELECT 121, TO_CHAR('A scheduled-process load'),
           TO_CHAR('A2 verdict: does the UTC label on the F10.2 hours hold?'),
           TO_CHAR(CASE WHEN a.min_since_sub BETWEEN -2 AND 25 AND a.sys_offset = '+00:00'
                        THEN 'OK: ESS times follow the database clock, which is UTC (+00:00)'
                        WHEN a.min_since_sub BETWEEN -2 AND 25
                        THEN 'CHECK: ESS follows the database clock, but that clock is '
                             || a.sys_offset || ', not UTC: the hour label must change'
                        WHEN a.min_since_sub IS NULL
                        THEN 'CHECK: no ESS request to compare'
                        ELSE 'CHECK: the latest submission is ' || a.min_since_sub
                             || ' minutes before SYSDATE: a quiet pod, or ESS writes'
                             || ' another clock'
                   END)
    FROM   a_time a
    UNION ALL
    SELECT 130 + TO_NUMBER(h.hod), TO_CHAR('A scheduled-process load'),
           TO_CHAR('A3 hour ' || h.hod || ':00 - runs (F10.2 rule) | requests by'
                   || ' NVL(PROCESSSTART, SUBMISSION) (EBS rule)'),
           TO_CHAR(h.n_runs || ' | ' || h.n_req || h.mark)
    FROM   a_hour_rows h
    UNION ALL
    SELECT 160, TO_CHAR('A scheduled-process load'),
           TO_CHAR('A4 pick, F10.2 rule (runs) vs EBS rule (requests): peak hour (count)'
                   || ' / off-peak hour (count) / total in the window'),
           TO_CHAR('runs: ' || NVL(l.peak_hod, '-') || ' ('
                   || NVL(TO_CHAR(l.peak_runs), '-') || ') / '
                   || NVL(l.offpeak_hod, '-') || ' ('
                   || NVL(TO_CHAR(l.offpeak_runs), '-') || ') / ' || l.n_runs_win
                   || '  |  requests: ' || NVL(q.peak_hod, '-') || ' ('
                   || NVL(TO_CHAR(q.peak_req), '-') || ') / '
                   || NVL(q.offpeak_hod, '-') || ' ('
                   || NVL(TO_CHAR(q.offpeak_req), '-') || ') / ' || q.n_req_win
                   || '  |  '
                   || CASE WHEN NVL(l.peak_hod, '-') = NVL(q.peak_hod, '-')
                            AND NVL(l.offpeak_hod, '-') = NVL(q.offpeak_hod, '-')
                           THEN 'same hours under both rules'
                           ELSE 'the two rules pick different hours'
                      END)
    FROM        s10_load   l
    CROSS JOIN  a_req_load q
    UNION ALL
    SELECT 170, TO_CHAR('A scheduled-process load'),
           TO_CHAR('A5 requests in the window that never started (the EBS rule adds them):'
                   || ' kinds / requests. R035: REQUESTTYPE 2 = schedule parents'),
           TO_CHAR(c.n_kinds || ' / ' || c.n || ' (up to 20 kinds listed)')
    FROM   a_never_cnt c
    UNION ALL
    SELECT 170 + v.rn, TO_CHAR('A scheduled-process load'),
           TO_CHAR('A5 REQUESTTYPE ' || NVL(TO_CHAR(v.requesttype), '-') || ' / STATE '
                   || NVL(TO_CHAR(v.req_state), '-') || ' (' || NVL(v.meaning, '-') || ')'),
           TO_CHAR(v.n || ' requests')
    FROM   a_never_rows v
    WHERE  v.rn <= 20
    -- B ---------------------------------------------------------------------------
    UNION ALL
    SELECT 200, TO_CHAR('B languages'),
           TO_CHAR('B0 grain: FND_LANGUAGES_B rows / language codes / FND_LANGUAGES_TL'
                   || ' rows in the session language or US / codes with a name'),
           TO_CHAR(r.n_rows || ' / ' || k.n_keys || ' / ' || tl.n_rows || ' / ' || nm.n_named
                   || CASE WHEN r.n_rows = k.n_keys THEN '   OK one row per code'
                           ELSE '   CHECK: more rows than codes'
                      END)
    FROM        b_rows  r
    CROSS JOIN  b_keys  k
    CROSS JOIN  b_tl    tl
    CROSS JOIN  b_named nm
    UNION ALL
    SELECT 210 + f.rn, TO_CHAR('B languages'),
           TO_CHAR('B1 INSTALLED_FLAG=' || f.installed_flag || ' ACTIVATION_STATUS='
                   || f.activation_status || ' counted=' || f.counted),
           TO_CHAR(f.n || ' languages')
    FROM   b_flag_rows f
    WHERE  f.rn <= 15
    UNION ALL
    SELECT 230 + i.rn, TO_CHAR('B languages'),
           TO_CHAR('B2 counted: ' || i.language_code),
           TO_CHAR(NVL(i.nls_language, '-') || ' | ' || NVL(i.lang_name, '-') || ' | flag '
                   || NVL(i.installed_flag, '-') || ' | ' || NVL(i.activation_status, '-'))
    FROM   b_inst_rows i
    WHERE  i.rn <= 25
    UNION ALL
    SELECT 260, TO_CHAR('B languages'),
           TO_CHAR('B3 session: USERENV LANG / SYS_CONTEXT LANGUAGE (the session language'
                   || ' and territory, then the DATABASE character set) / NLS_TERRITORY'),
           TO_CHAR(NVL(x.sess_lang, '-') || ' / ' || NVL(x.sess_language, '-') || ' / '
                   || NVL(x.sess_territory, '-'))
    FROM   b_session x
    UNION ALL
    SELECT 261, TO_CHAR('B languages'),
           TO_CHAR('B4 F10.3 row 1 (Installed Languages) as printed'),
           TO_CHAR(NVL(t.lang_text, '(blank: FND_LANGUAGES_B returned no rows)'))
    FROM   s10_text t
    -- C ---------------------------------------------------------------------------
    UNION ALL
    SELECT 300, TO_CHAR('C default user time zone'),
           TO_CHAR('C0 FND_PROFILE_OPTIONS_B rows named FND_TIMEZONE: application id /'
                   || ' option id / ENTERPRISE_ID / seed sets 1 2 / hierarchy'),
           TO_CHAR(o.n_rows || ' row(s): ' || NVL(o.opt_list, '-'))
    FROM   c_opt_sum o
    UNION ALL
    SELECT 310 + v.rn, TO_CHAR('C default user time zone'),
           TO_CHAR('C1 value: level / level value / ENTERPRISE_ID / seed sets / counted'
                   || ' (site)'),
           TO_CHAR(v.level_name || ' / ' || NVL(v.level_value_shown, '-') || ' / '
                   || v.enterprise_id || ' / ' || NVL(v.seed_sets, '-') || ' / '
                   || v.counted || ' : ' || NVL(v.opt_value, '(null)') || ' (updated '
                   || NVL(TO_CHAR(v.last_update_date, 'YYYY-MM-DD'), '-') || ')')
    FROM   c_val_rows v
    WHERE  v.rn <= 15
    UNION ALL
    SELECT 330, TO_CHAR('C default user time zone'),
           TO_CHAR('C2 values of the option / at site level / F10.3 row 2 as printed'),
           TO_CHAR(c.n_rows || ' / ' || c.n_site || ' / '
                   || NVL(t.tz_text, '(blank: the option is not visible)')
                   || CASE WHEN c.n_site = 1 THEN '   OK one site value'
                           WHEN c.n_site = 0 THEN '   (no site value)'
                           ELSE '   CHECK: ' || c.n_site || ' site rows'
                      END)
    FROM        c_val_cnt c
    CROSS JOIN  s10_text  t
    UNION ALL
    SELECT 340 + l.rn, TO_CHAR('C default user time zone'),
           TO_CHAR('C3 LEVEL_NAME stored in FND_PROFILE_OPTION_VALUES (all options)'),
           TO_CHAR(l.level_name || ': ' || l.n || ' values')
    FROM   c_level_rows l
    WHERE  l.rn <= 10
    -- D ---------------------------------------------------------------------------
    UNION ALL
    SELECT 400, TO_CHAR('D sandboxes'),
           TO_CHAR('D0 ADF_SB_SANDBOXES rows / sandboxes / F10.3 row 3 as printed'
                   || '   (R017: 42 rows; COMMITTED 36, ACTIVE 4, DESTROYED 2)'),
           TO_CHAR(r.n_rows || ' / ' || k.n_keys || ' / '
                   || NVL(t.sbx_text, '(blank: ADF_SB_SANDBOXES returned no rows)'))
    FROM        d_rows   r
    CROSS JOIN  d_keys   k
    CROSS JOIN  s10_text t
    UNION ALL
    SELECT 410 + f.rn, TO_CHAR('D sandboxes'),
           TO_CHAR('D1 SANDBOX_STATE=' || f.sandbox_state || ' PUBLISH_FLAG='
                   || f.publish_flag || ' publish date=' || f.has_publish_date
                   || ' PRIVATE_FLAG=' || f.private_flag || ' counted=' || f.counted),
           TO_CHAR(f.n || ' sandboxes')
    FROM   d_flag_rows f
    WHERE  f.rn <= 15
    UNION ALL
    SELECT 430 + d.rn, TO_CHAR('D sandboxes'),
           TO_CHAR('D2 not yet published: ' || NVL(d.sbx_name, '(no name)')),
           TO_CHAR(d.sandbox_state || ' | created by ' || NVL(d.created_by, '-') || ' on '
                   || NVL(TO_CHAR(d.creation_date, 'YYYY-MM-DD'), '-') || ' | last updated '
                   || NVL(TO_CHAR(d.last_update_date, 'YYYY-MM-DD'), '-'))
    FROM   d_list d
    WHERE  d.rn <= 20
    -- E ---------------------------------------------------------------------------
    UNION ALL
    SELECT 500, TO_CHAR('E history retained'),
           TO_CHAR('E0 F10.3 row 4 (Scheduled Process History Retained) as printed'),
           TO_CHAR(NVL(t.hist_text, '(blank: ESS returned no rows)'))
    FROM   s10_text t
)
SELECT  g.ord         AS ord,
        g.section     AS section,
        g.item        AS item,
        g.value_text  AS value_text
FROM    grid g
ORDER BY g.ord
