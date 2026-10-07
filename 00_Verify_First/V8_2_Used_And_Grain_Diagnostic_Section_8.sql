-- ============================================================================
--  V8_2  DIAGNOSTIC - can "Used (6 mth)" be measured, and at which grain?
--  Version   : 1.0 (2026-10-06)        Run log: 06_Run_Results/RUN_LOG.md
--  For: the Section 8 v1.1 decisions after V8_1 (R032). F8.1 / F8.2a / F8.2b /
--       F8.2c / F8.2_WB v1.0 are ON HOLD until this answers.
--  Binds: none used (the five standard binds are accepted for BIP parity).
--  Columns: every column read here is in R031's lists (V8_0 block A, or its
--  candidate block C): GL_FRC_REPORTS_B; GL_FRC_USER_ACCESS_REPORTS incl.
--  LAST_ACCESSED_BIP_ESS_REQ_ID, FAVORITE_FLAG, USER_ACCESS_REPORT_ID; and
--  GL_FRC_REPORTS_TL (REPORT_ID, LANGUAGE, REPORT_DISPLAY_NAME). Text columns
--  are wrapped in TO_CHAR in case one is national-character (ORA-12704).
--
--  WHY (R032):
--    - LAST_ACCESSED_DATE is overwritten by bulk events: 3,288 items were last
--      accessed in 2026-01 and 1,221 in 2026-07, and 1,293 of 1,374 Oracle BI
--      Publisher reports look "used" in 6 months. v1.0's Used would be false.
--    - Dashboard rows look like dashboard PAGES (.../_portal/<dash>/page 1),
--      which would also change F5.1 card 3.
--    - Client folders named 'Data Model' hold BIP-type items: are BI Publisher
--      data models counted as reports?
--    - The 6 financial reports live under '/Shared Folders/...' (v1.1 rule).
--
--  BLOCKS  population = the PROPOSED v1.1 rule: the shared catalog, with
--          '/Shared Folders/' read as '/shared/'; BIP, Analysis, Dashboard, FR
--    A  days ranked by how many items were last accessed that day (top 15):
--       type mix, how many have last access = last modified, how many
--       distinct minutes, the biggest one-minute burst. A system event shows
--       as many items in few minutes.
--    B  last access vs last modified, per type x custom. A deploy or a save
--       writes both dates; a run only moves the access date.
--    C  candidate "Used (6 mth)" rules, per type x custom:
--         r1 = last access in the window (the v1.0 rule)
--         r2 = r1, not on a day with >= 100 items accessed
--         r3 = r1, last access later than last modified (to the minute)
--         r4 = r2 and r3
--         r5 = r1, not in a minute with >= 20 items accessed
--         masked = r1 on a >= 100-item day (an earlier real use there is
--                  overwritten and cannot be seen)
--    D  dashboard grain: Dashboard rows vs distinct parent folders
--       (dashboards), rows under /_portal/, page names, biggest dashboards
--    E  BI Publisher items by file extension (.xdo report, .xdm data model)
--    F  the 6 financial reports under the v1.1 rule
--    G  the per-user access log: empty dates, ESS request ids (runs launched
--       from the Financial Reporting Center), latest accesses
--    H  report display names in GL_FRC_REPORTS_TL: coverage and samples
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
-- logwin: the same 6-month operational window as the Section 8 catalog block
logwin AS (
    SELECT ADD_MONTHS(TRUNC(SYSDATE), -6) AS start_date,
           TRUNC(SYSDATE) + 1             AS end_date_excl
    FROM   dual
),
-- ---- population under the PROPOSED v1.1 path rule (R032: the 6 financial
--      reports are stored as '/Shared Folders/...'). R032 B0: no duplicate
--      type + path, so one index row = one item.
v_items AS (
    SELECT UPPER(r.report_type_code)                                       AS type_code,
           TO_CHAR(r.report_path)                                          AS raw_path,
           TO_CHAR(REGEXP_REPLACE(r.report_path, '^/shared folders/', '/shared/',
                                  1, 1, 'i'))                              AS norm_path,
           r.report_id                                                     AS report_id,
           r.last_accessed_date                                            AS acc,
           r.last_modified_date                                            AS md
    FROM   gl_frc_reports_b r
    WHERE  (   LOWER(r.report_path) LIKE '/shared/%'
            OR LOWER(r.report_path) LIKE '/shared folders/%' )
    AND    UPPER(r.report_type_code) IN ('BIP', 'ANALYSIS', 'DASHBOARD', 'FR')
),
v_flag AS (
    SELECT v.type_code, v.raw_path, v.norm_path, v.report_id, v.acc, v.md,
           CASE WHEN LOWER(v.norm_path) LIKE '/shared/custom/%'
                THEN 'Y' ELSE 'N' END                                      AS is_custom,
           TO_CHAR(REGEXP_SUBSTR(v.norm_path, '[^/]+$'))                   AS item_name
    FROM   v_items v
),
v_tot AS (
    SELECT COUNT(*) AS n_items FROM v_flag
),
-- ==== A bulk-access days ========================================================
a_day AS (
    SELECT TRUNC(f.acc)                                                 AS acc_day,
           COUNT(*)                                                     AS n,
           SUM(CASE WHEN f.is_custom = 'Y'         THEN 1 ELSE 0 END)   AS n_custom,
           SUM(CASE WHEN f.type_code = 'BIP'       THEN 1 ELSE 0 END)   AS n_bip,
           SUM(CASE WHEN f.type_code = 'ANALYSIS'  THEN 1 ELSE 0 END)   AS n_ana,
           SUM(CASE WHEN f.type_code = 'DASHBOARD' THEN 1 ELSE 0 END)   AS n_dash,
           SUM(CASE WHEN f.type_code = 'FR'        THEN 1 ELSE 0 END)   AS n_fr,
           SUM(CASE WHEN f.acc = f.md              THEN 1 ELSE 0 END)   AS n_eq
    FROM   v_flag f
    WHERE  f.acc IS NOT NULL
    GROUP  BY TRUNC(f.acc)
),
a_min AS (
    SELECT TRUNC(f.acc, 'MI') AS acc_min,
           COUNT(*)           AS n
    FROM   v_flag f
    WHERE  f.acc IS NOT NULL
    GROUP  BY TRUNC(f.acc, 'MI')
),
a_day_min AS (
    SELECT TRUNC(m.acc_min)  AS acc_day,
           COUNT(*)          AS n_minutes,
           MAX(m.n)          AS max_per_min,
           MIN(m.acc_min)    AS first_min,
           MAX(m.acc_min)    AS last_min
    FROM   a_min m
    GROUP  BY TRUNC(m.acc_min)
),
a_day_rows AS (
    SELECT d.acc_day, d.n, d.n_custom, d.n_bip, d.n_ana, d.n_dash, d.n_fr, d.n_eq,
           dm.n_minutes, dm.max_per_min, dm.first_min, dm.last_min,
           ROW_NUMBER() OVER (ORDER BY d.n DESC, d.acc_day) AS rn
    FROM   a_day     d
    JOIN   a_day_min dm ON dm.acc_day = d.acc_day
),
a_sum AS (
    SELECT COUNT(*)                                                    AS n_days,
           NVL(SUM(CASE WHEN d.n >=  50 THEN 1 ELSE 0 END), 0)         AS n_d50,
           NVL(SUM(CASE WHEN d.n >= 100 THEN 1 ELSE 0 END), 0)         AS n_d100,
           NVL(SUM(CASE WHEN d.n >= 500 THEN 1 ELSE 0 END), 0)         AS n_d500,
           NVL(SUM(CASE WHEN d.n >= 100 THEN d.n ELSE 0 END), 0)       AS n_items_d100
    FROM   a_day d
),
-- ==== B last access vs last modified ============================================
b_cmp AS (
    SELECT f.type_code, f.is_custom,
           COUNT(*)                                                         AS n,
           SUM(CASE WHEN f.acc = f.md THEN 1 ELSE 0 END)                    AS n_eq,
           SUM(CASE WHEN f.acc <> f.md
                     AND TRUNC(f.acc, 'MI') = TRUNC(f.md, 'MI')
                    THEN 1 ELSE 0 END)                                      AS n_same_min,
           SUM(CASE WHEN TRUNC(f.acc, 'MI') > TRUNC(f.md, 'MI')
                    THEN 1 ELSE 0 END)                                      AS n_later,
           SUM(CASE WHEN TRUNC(f.acc, 'MI') < TRUNC(f.md, 'MI')
                    THEN 1 ELSE 0 END)                                      AS n_earlier,
           SUM(CASE WHEN f.acc IS NULL OR f.md IS NULL THEN 1 ELSE 0 END)   AS n_null
    FROM   v_flag f
    GROUP  BY f.type_code, f.is_custom
),
b_rows AS (
    SELECT b.type_code, b.is_custom, b.n, b.n_eq, b.n_same_min, b.n_later,
           b.n_earlier, b.n_null,
           ROW_NUMBER() OVER (ORDER BY b.type_code, b.is_custom) AS rn
    FROM   b_cmp b
),
-- ==== C candidate Used rules ======================================================
c_rules AS (
    SELECT f.type_code, f.is_custom,
           COUNT(*)                                                         AS n,
           NVL(SUM(CASE WHEN f.acc >= w.start_date AND f.acc < w.end_date_excl
                        THEN 1 ELSE 0 END), 0)                              AS r1,
           NVL(SUM(CASE WHEN f.acc >= w.start_date AND f.acc < w.end_date_excl
                         AND d.n < 100
                        THEN 1 ELSE 0 END), 0)                              AS r2,
           NVL(SUM(CASE WHEN f.acc >= w.start_date AND f.acc < w.end_date_excl
                         AND TRUNC(f.acc, 'MI') > TRUNC(f.md, 'MI')
                        THEN 1 ELSE 0 END), 0)                              AS r3,
           NVL(SUM(CASE WHEN f.acc >= w.start_date AND f.acc < w.end_date_excl
                         AND d.n < 100
                         AND TRUNC(f.acc, 'MI') > TRUNC(f.md, 'MI')
                        THEN 1 ELSE 0 END), 0)                              AS r4,
           NVL(SUM(CASE WHEN f.acc >= w.start_date AND f.acc < w.end_date_excl
                         AND m.n < 20
                        THEN 1 ELSE 0 END), 0)                              AS r5,
           NVL(SUM(CASE WHEN f.acc >= w.start_date AND f.acc < w.end_date_excl
                         AND d.n >= 100
                        THEN 1 ELSE 0 END), 0)                              AS n_masked
    FROM   v_flag f
    LEFT   JOIN a_day d ON d.acc_day = TRUNC(f.acc)
    LEFT   JOIN a_min m ON m.acc_min = TRUNC(f.acc, 'MI')
    CROSS  JOIN logwin w
    GROUP  BY f.type_code, f.is_custom
),
c_rows AS (
    SELECT c.type_code, c.is_custom, c.n, c.r1, c.r2, c.r3, c.r4, c.r5, c.n_masked,
           ROW_NUMBER() OVER (ORDER BY c.type_code, c.is_custom) AS rn
    FROM   c_rules c
),
-- ==== D dashboard grain ===========================================================
d_dash AS (
    SELECT f.is_custom,
           TO_CHAR(REGEXP_REPLACE(f.norm_path, '/[^/]*$', ''))                    AS dash_path,
           COUNT(*)                                                               AS n_pages,
           MAX(f.acc)                                                             AS acc,
           SUM(CASE WHEN INSTR(LOWER(f.norm_path), '/_portal/') > 0
                    THEN 1 ELSE 0 END)                                            AS n_portal
    FROM   v_flag f
    WHERE  f.type_code = 'DASHBOARD'
    GROUP  BY f.is_custom, TO_CHAR(REGEXP_REPLACE(f.norm_path, '/[^/]*$', ''))
),
d_sum AS (
    SELECT d.is_custom,
           COUNT(*)                                                         AS n_dash,
           NVL(SUM(d.n_pages), 0)                                           AS n_rows,
           MAX(d.n_pages)                                                   AS max_pages,
           NVL(SUM(CASE WHEN d.n_pages = 1 THEN 1 ELSE 0 END), 0)           AS n_single,
           NVL(SUM(d.n_portal), 0)                                          AS n_rows_portal,
           NVL(SUM(CASE WHEN d.acc >= w.start_date AND d.acc < w.end_date_excl
                        THEN 1 ELSE 0 END), 0)                              AS n_used_6m
    FROM   d_dash d
    CROSS  JOIN logwin w
    GROUP  BY d.is_custom
),
d_sum_rows AS (
    SELECT s.is_custom, s.n_dash, s.n_rows, s.max_pages, s.n_single, s.n_rows_portal,
           s.n_used_6m,
           ROW_NUMBER() OVER (ORDER BY s.is_custom) AS rn
    FROM   d_sum s
),
d_ana_portal AS (
    SELECT COUNT(*) AS n
    FROM   v_flag f
    WHERE  f.type_code = 'ANALYSIS'
    AND    INSTR(LOWER(f.norm_path), '/_portal/') > 0
),
d_names AS (
    SELECT f.item_name, COUNT(*) AS n
    FROM   v_flag f
    WHERE  f.type_code = 'DASHBOARD'
    GROUP  BY f.item_name
),
d_name_rows AS (
    SELECT dn.item_name, dn.n, ROW_NUMBER() OVER (ORDER BY dn.n DESC, dn.item_name) AS rn
    FROM   d_names dn
),
d_big AS (
    SELECT d.is_custom, d.dash_path, d.n_pages,
           ROW_NUMBER() OVER (ORDER BY d.n_pages DESC, d.dash_path) AS rn
    FROM   d_dash d
),
-- ==== E BI Publisher file types =====================================================
e_ext AS (
    SELECT f.is_custom,
           NVL(LOWER(TO_CHAR(REGEXP_SUBSTR(f.item_name, '[.][^.]*$'))), '(none)') AS ext,
           COUNT(*)                                                          AS n
    FROM   v_flag f
    WHERE  f.type_code = 'BIP'
    GROUP  BY f.is_custom,
              NVL(LOWER(TO_CHAR(REGEXP_SUBSTR(f.item_name, '[.][^.]*$'))), '(none)')
),
e_ext_rows AS (
    SELECT e.is_custom, e.ext, e.n,
           ROW_NUMBER() OVER (ORDER BY e.is_custom, e.n DESC, e.ext) AS rn
    FROM   e_ext e
),
e_odd AS (
    SELECT f.is_custom, f.norm_path,
           ROW_NUMBER() OVER (ORDER BY f.is_custom DESC, f.norm_path) AS k
    FROM   v_flag f
    WHERE  f.type_code = 'BIP'
    AND    LOWER(f.item_name) NOT LIKE '%.xdo'
),
-- ==== F financial reports under the v1.1 rule =======================================
f_fr AS (
    SELECT f.raw_path, f.norm_path, f.is_custom, f.acc,
           TO_CHAR(r.author_display_name)                                    AS author,
           CASE WHEN f.acc >= w.start_date AND f.acc < w.end_date_excl
                THEN 'Y' ELSE 'N' END                                        AS used_6m,
           ROW_NUMBER() OVER (ORDER BY f.norm_path)                          AS rn
    FROM   v_flag f
    JOIN   gl_frc_reports_b r ON r.report_id = f.report_id
    CROSS  JOIN logwin w
    WHERE  f.type_code = 'FR'
),
-- ==== G per-user access log (Financial Reporting Center) =============================
g_acc AS (
    SELECT COUNT(*)                                                               AS n_rows,
           NVL(SUM(CASE WHEN u.last_accessed_date IS NULL THEN 1 ELSE 0 END), 0)  AS n_null,
           NVL(SUM(CASE WHEN u.last_accessed_bip_ess_req_id IS NOT NULL
                        THEN 1 ELSE 0 END), 0)                                    AS n_req,
           NVL(SUM(CASE WHEN u.last_accessed_bip_ess_req_id IS NOT NULL
                         AND u.last_accessed_date >= w.start_date
                         AND u.last_accessed_date <  w.end_date_excl
                        THEN 1 ELSE 0 END), 0)                                    AS n_req_6m,
           NVL(SUM(CASE WHEN TO_CHAR(u.favorite_flag) = 'Y' THEN 1 ELSE 0 END), 0) AS n_fav,
           NVL(SUM(CASE WHEN u.last_accessed_date >= w.start_date
                         AND u.last_accessed_date <  w.end_date_excl
                        THEN 1 ELSE 0 END), 0)                                    AS n_6m
    FROM   gl_frc_user_access_reports u
    CROSS  JOIN logwin w
),
g_year AS (
    SELECT NVL(TO_CHAR(u.last_accessed_date, 'YYYY'), '(empty)') AS yr,
           COUNT(*)                                              AS n
    FROM   gl_frc_user_access_reports u
    GROUP  BY NVL(TO_CHAR(u.last_accessed_date, 'YYYY'), '(empty)')
),
g_year_rows AS (
    SELECT y.yr, y.n, ROW_NUMBER() OVER (ORDER BY y.yr) AS rn
    FROM   g_year y
),
g_latest AS (
    SELECT TO_CHAR(u.user_name)                                         AS user_name,
           TO_CHAR(r.report_path)                                       AS report_path,
           TO_CHAR(r.report_type_code)                                  AS type_code,
           u.last_accessed_date                                         AS acc,
           CASE WHEN u.last_accessed_bip_ess_req_id IS NOT NULL
                THEN 'Y' ELSE 'N' END                                   AS has_req,
           ROW_NUMBER() OVER (ORDER BY u.last_accessed_date DESC,
                                       u.user_access_report_id)         AS rn
    FROM   gl_frc_user_access_reports u
    LEFT   JOIN gl_frc_reports_b r ON r.report_id = u.report_id
    WHERE  u.last_accessed_date IS NOT NULL
),
-- ==== H display names (GL_FRC_REPORTS_TL), one per report: session language, else US
h_tl AS (
    SELECT COUNT(*) AS n_rows FROM gl_frc_reports_tl t
),
h_lang AS (
    SELECT TO_CHAR(t.language) AS lang, COUNT(*) AS n
    FROM   gl_frc_reports_tl t
    GROUP  BY TO_CHAR(t.language)
),
h_lang_rows AS (
    SELECT l.lang, l.n, ROW_NUMBER() OVER (ORDER BY l.n DESC, l.lang) AS rn
    FROM   h_lang l
),
h_pick AS (
    SELECT t.report_id,
           MAX(TO_CHAR(t.report_display_name)) KEEP (DENSE_RANK FIRST ORDER BY
               CASE WHEN t.language = USERENV('LANG') THEN 0 ELSE 1 END)   AS disp
    FROM   gl_frc_reports_tl t
    WHERE  t.language IN (USERENV('LANG'), 'US')
    GROUP  BY t.report_id
),
h_cov AS (
    SELECT f.type_code,
           COUNT(*)                                                           AS n,
           SUM(CASE WHEN p.report_id IS NOT NULL THEN 1 ELSE 0 END)           AS n_tl,
           SUM(CASE WHEN p.disp IS NOT NULL AND p.disp <> f.item_name
                    THEN 1 ELSE 0 END)                                        AS n_diff
    FROM   v_flag f
    LEFT   JOIN h_pick p ON p.report_id = f.report_id
    GROUP  BY f.type_code
),
h_cov_rows AS (
    SELECT c.type_code, c.n, c.n_tl, c.n_diff,
           ROW_NUMBER() OVER (ORDER BY c.type_code) AS rn
    FROM   h_cov c
),
h_samples AS (
    SELECT f.type_code, f.item_name, p.disp, f.norm_path,
           ROW_NUMBER() OVER (PARTITION BY f.type_code ORDER BY f.norm_path) AS rn
    FROM   v_flag f
    JOIN   h_pick p ON p.report_id = f.report_id
    WHERE  p.disp <> f.item_name
),
h_sample_rows AS (
    SELECT s.type_code, s.item_name, s.disp, s.norm_path,
           ROW_NUMBER() OVER (ORDER BY s.type_code, s.rn) AS k
    FROM   h_samples s
    WHERE  s.rn <= 2
),
grid AS (
    -- A ------------------------------------------------------------------------
    SELECT 100                                                      AS ord,
           CAST('A bulk-access days' AS VARCHAR2(400))              AS section,
           CAST('A0 summary (V8_2 v1.0): days with an access / with >= 50 / >= 100 /'
                || ' >= 500 items; items on >= 100-item days'
                AS VARCHAR2(400))                                   AS item,
           CAST(s.n_days || ' / ' || s.n_d50 || ' / ' || s.n_d100 || ' / ' || s.n_d500
                || '; ' || s.n_items_d100 || ' of ' || t.n_items || ' items'
                AS VARCHAR2(4000))                                  AS value_text
    FROM   a_sum s
    CROSS  JOIN v_tot t
    UNION ALL
    SELECT 100 + d.rn, TO_CHAR('A bulk-access days'),
           TO_CHAR('A1 ' || TO_CHAR(d.acc_day, 'YYYY-MM-DD')),
           TO_CHAR(d.n || ' items (custom ' || d.n_custom || '; BIP ' || d.n_bip
                   || ', analyses ' || d.n_ana || ', dashboards ' || d.n_dash || ', FR ' || d.n_fr
                   || ') | access = modified ' || d.n_eq || ' | ' || d.n_minutes
                   || ' distinct minutes, max ' || d.max_per_min || ' in one minute, '
                   || TO_CHAR(d.first_min, 'HH24:MI') || '-' || TO_CHAR(d.last_min, 'HH24:MI'))
    FROM   a_day_rows d
    WHERE  d.rn <= 15
    -- B ------------------------------------------------------------------------
    UNION ALL
    SELECT 200 + b.rn, TO_CHAR('B last access vs last modified'),
           TO_CHAR('B1 type=' || b.type_code || ' custom=' || b.is_custom),
           TO_CHAR(b.n || ' items | equal ' || b.n_eq || ' | same minute ' || b.n_same_min
                   || ' | access later ' || b.n_later || ' | access earlier ' || b.n_earlier
                   || ' | a date missing ' || b.n_null)
    FROM   b_rows b
    WHERE  b.rn <= 9
    -- C ------------------------------------------------------------------------
    UNION ALL
    SELECT 300, TO_CHAR('C candidate Used rules'), TO_CHAR('C0 window and rules'),
           TO_CHAR(TO_CHAR(w.start_date, 'YYYY-MM-DD') || ' .. '
                   || TO_CHAR(w.end_date_excl - 1, 'YYYY-MM-DD')
                   || ' | r1 last access in window (v1.0) | r2 r1, not on a >= 100-item day'
                   || ' | r3 r1, access later than modified | r4 r2 and r3'
                   || ' | r5 r1, not in a >= 20-item minute | masked r1 on a >= 100-item day')
    FROM   logwin w
    UNION ALL
    SELECT 300 + c.rn, TO_CHAR('C candidate Used rules'),
           TO_CHAR('C1 type=' || c.type_code || ' custom=' || c.is_custom),
           TO_CHAR(c.n || ' items | r1 ' || c.r1 || ' | r2 ' || c.r2 || ' | r3 ' || c.r3
                   || ' | r4 ' || c.r4 || ' | r5 ' || c.r5 || ' | masked ' || c.n_masked)
    FROM   c_rows c
    WHERE  c.rn <= 9
    -- D ------------------------------------------------------------------------
    UNION ALL
    SELECT 400 + s.rn, TO_CHAR('D dashboard grain'),
           TO_CHAR('D1 custom=' || s.is_custom || ': rows / dashboards (parent folders) /'
                   || ' rows under /_portal/ / most pages / one-page dashboards /'
                   || ' dashboards with a page accessed in 6 mth'),
           TO_CHAR(s.n_rows || ' / ' || s.n_dash || ' / ' || s.n_rows_portal || ' / '
                   || s.max_pages || ' / ' || s.n_single || ' / ' || s.n_used_6m)
    FROM   d_sum_rows s
    WHERE  s.rn <= 2
    UNION ALL
    SELECT 405, TO_CHAR('D dashboard grain'),
           TO_CHAR('D2 Analysis rows under /_portal/ (expected 0)'),
           TO_CHAR(a.n || ' rows')
    FROM   d_ana_portal a
    UNION ALL
    SELECT 405 + n.rn, TO_CHAR('D dashboard grain'),
           TO_CHAR('D3 Dashboard row name: ' || n.item_name),
           TO_CHAR(n.n || ' rows')
    FROM   d_name_rows n
    WHERE  n.rn <= 6
    UNION ALL
    SELECT 412 + g.rn, TO_CHAR('D dashboard grain'),
           TO_CHAR('D4 most pages, custom=' || g.is_custom),
           TO_CHAR(g.dash_path || ' | ' || g.n_pages || ' rows')
    FROM   d_big g
    WHERE  g.rn <= 5
    -- E ------------------------------------------------------------------------
    UNION ALL
    SELECT 500 + e.rn, TO_CHAR('E BI Publisher file types'),
           TO_CHAR('E1 custom=' || e.is_custom || ' extension=' || e.ext),
           TO_CHAR(e.n || ' BIP items')
    FROM   e_ext_rows e
    WHERE  e.rn <= 9
    UNION ALL
    SELECT 510 + o.k, TO_CHAR('E BI Publisher file types'),
           TO_CHAR('E2 sample not ending .xdo, custom=' || o.is_custom),
           TO_CHAR(o.norm_path)
    FROM   e_odd o
    WHERE  o.k <= 6
    -- F ------------------------------------------------------------------------
    UNION ALL
    SELECT 600 + f.rn, TO_CHAR('F financial reports (v1.1 rule)'),
           TO_CHAR('F1 custom=' || f.is_custom || ' used 6 mth=' || f.used_6m),
           TO_CHAR(f.raw_path || ' -> ' || f.norm_path || ' | last access '
                   || NVL(TO_CHAR(f.acc, 'YYYY-MM-DD HH24:MI'), '-')
                   || ' | author ' || NVL(f.author, '-'))
    FROM   f_fr f
    WHERE  f.rn <= 20
    -- G ------------------------------------------------------------------------
    UNION ALL
    SELECT 700, TO_CHAR('G user access log'),
           TO_CHAR('G0 rows / access date empty / ESS request id filled (in 6 mth) /'
                   || ' favourites / accesses in 6 mth'),
           TO_CHAR(g.n_rows || ' / ' || g.n_null || ' / ' || g.n_req || ' (' || g.n_req_6m
                   || ') / ' || g.n_fav || ' / ' || g.n_6m)
    FROM   g_acc g
    UNION ALL
    SELECT 700 + y.rn, TO_CHAR('G user access log'),
           TO_CHAR('G1 access year ' || y.yr),
           TO_CHAR(y.n || ' rows')
    FROM   g_year_rows y
    WHERE  y.rn <= 8
    UNION ALL
    SELECT 710 + l.rn, TO_CHAR('G user access log'),
           TO_CHAR('G2 latest access ' || l.rn),
           TO_CHAR(TO_CHAR(l.acc, 'YYYY-MM-DD HH24:MI') || ' | ' || l.user_name || ' | '
                   || NVL(l.type_code, '-') || ' | '
                   || NVL(l.report_path, '(report not in the index)')
                   || ' | ESS request id ' || l.has_req)
    FROM   g_latest l
    WHERE  l.rn <= 12
    -- H ------------------------------------------------------------------------
    UNION ALL
    SELECT 800, TO_CHAR('H display names'), TO_CHAR('H0 GL_FRC_REPORTS_TL rows'),
           TO_CHAR(h.n_rows || ' rows')
    FROM   h_tl h
    UNION ALL
    SELECT 800 + l.rn, TO_CHAR('H display names'),
           TO_CHAR('H1 LANGUAGE=' || l.lang),
           TO_CHAR(l.n || ' rows')
    FROM   h_lang_rows l
    WHERE  l.rn <= 5
    UNION ALL
    SELECT 810 + c.rn, TO_CHAR('H display names'),
           TO_CHAR('H2 type=' || c.type_code || ': items / with a name row / name differs'
                   || ' from the path name'),
           TO_CHAR(c.n || ' / ' || c.n_tl || ' / ' || c.n_diff)
    FROM   h_cov_rows c
    WHERE  c.rn <= 4
    UNION ALL
    SELECT 820 + s.k, TO_CHAR('H display names'),
           TO_CHAR('H3 sample type=' || s.type_code),
           TO_CHAR(s.item_name || ' -> ' || s.disp || ' | ' || s.norm_path)
    FROM   h_sample_rows s
    WHERE  s.k <= 8
)
SELECT  g.ord         AS ord,
        g.section     AS section,
        g.item        AS item,
        g.value_text  AS value_text
FROM    grid g
ORDER BY g.ord
