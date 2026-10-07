-- ============================================================================
--  F10.3  Section 10.3 Fusion pod posture (Fusion only, not in the EBS report)
--  Version   : 1.1 (2026-10-07). Not yet run on a pod.
--              v1.1 (2026-10-07): comment-only. No ampersand anywhere in the
--              text: BIP reads one, even inside a comment, as a lexical
--              parameter and asks for a value before running (R039).
--              Logic and output unchanged; v1.0 never ran.
--              RUN AFTER V10_0 and V10_1 (same Section 10 block). Log every
--              run in 06_Run_Results/RUN_LOG.md.
--  Source    : Oracle Fusion Cloud (BIP data model, data source ApplicationDB_FSCM)
--  Why       : user, 2026-10-06: add Fusion-specific rows, "the information
--              should be useful". Each row is something the target pod must
--              match, or finish, before a Fusion -> Fusion migration:
--              * Oracle requires the source and target to be on the same release
--                and patches for Configuration Set Migration and for setup data
--                export / import (F10.1 rows 1 and 10);
--              * Configuration Set Migration needs sandbox configurations
--                complete and published (Oracle, "Migrate Your Configurations").
--  Mirrors   : no EBS collector. The rows follow the plan's "pod and release
--              posture" (01_Plan lines 209 / 223 / 251; backlog C10 / E-M1).
--              Ledger base currencies are already in 2.1 (F2.1 Currency column)
--              and are not repeated here.
--  Window    : SNAPSHOT (as of the run day); row 4 describes the retained ESS
--              history. The discovery dates are accepted and ignored.
--  Scope     : pod-wide. The binds are accepted for BIP parity and do not
--              change the result.
--  Reads     : the Section 10 block: FND_LANGUAGES_B / _TL, FND_PROFILE_OPTIONS_B,
--              FND_PROFILE_OPTION_VALUES, FND_TIMEZONES_TL, ADF_SB_SANDBOXES
--              (V10_0 checks the columns), ESS_REQUEST_HISTORY (R034 / R035).
--
--  OUTPUT  Parameter | Value      (4 rows)
--    1 Installed Languages        base and installed languages (FND_LANGUAGES_B
--                                 INSTALLED_FLAG B / I), named from
--                                 FND_LANGUAGES_TL. The target pod needs the same
--                                 languages for translated setup data to move.
--    2 Default User Time Zone     site value of profile FND_TIMEZONE, named from
--                                 FND_TIMEZONES_TL. Users start from it; the
--                                 target pod should match.
--    3 Sandboxes Not Yet Published
--                                 ADF_SB_SANDBOXES never published and not
--                                 destroyed, with the published count. R017:
--                                 4 not yet published, 36 published.
--    4 Scheduled Process History Retained
--                                 first and last ESS submission, requests and
--                                 runs. It bounds every run count in Sections 5,
--                                 8 and 10 (R035: from 2026-09-21).
--    A source that returns no rows to the report user gives a blank, never 0.
-- ============================================================================
WITH
-- ---- PARAMS / WINDOW / SCOPE: copied unchanged from F1 (shared block v3.1).
--      Section 10 is pod-wide and reads none of it; it is kept for parity with
--      every other query.
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
grid AS (
    SELECT 1                                                        AS seq,
           CAST('Installed Languages' AS VARCHAR2(100))             AS param_name,
           CAST(t.lang_text AS VARCHAR2(4000))                      AS param_value
    FROM   s10_text t
    UNION ALL
    SELECT 2, TO_CHAR('Default User Time Zone'), TO_CHAR(t.tz_text)
    FROM   s10_text t
    UNION ALL
    SELECT 3, TO_CHAR('Sandboxes Not Yet Published'), TO_CHAR(t.sbx_text)
    FROM   s10_text t
    UNION ALL
    SELECT 4, TO_CHAR('Scheduled Process History Retained'), TO_CHAR(t.hist_text)
    FROM   s10_text t
)
SELECT
    g.param_name                                              AS "Parameter",
    g.param_value                                             AS "Value"
FROM        grid g
ORDER BY    g.seq
