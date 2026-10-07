-- ============================================================================
--  F8.2_WB  Section 8.2 workbook WB9: every BI catalog report used in the
--           trailing 3 months (every type, seeded and custom)
--  Version   : 1.0 (2026-10-05). Not yet run on a pod.
--              RUN V8_0 AND V8_1 FIRST (V8_1 prints every value this query
--              classifies on). Log every run in 06_Run_Results/RUN_LOG.md.
--  Source    : Oracle Fusion Cloud (BIP data model, data source ApplicationDB_FSCM)
--  Mirrors   : EBS agent _REPORTS_RUN_SQL (tools.py 5143), the workbook
--              EBS_Discovery_9_1_Reports_Run_Last_3_Months.xlsx (report
--              30-Sep-2026, Vision: 20 rows - EBS numbers, not targets)
--  File      : Fusion_Discovery_8_2_Reports_Used_Last_3_Months.xlsx, sheet 1
--  Window    : OPERATIONAL, as in EBS: ADD_MONTHS(TRUNC(SYSDATE), -3) up to now
--              (win3). The discovery-window dates are accepted and ignored.
--  Scope     : pod-wide; the shared catalog (/shared/...), the Section 8
--              catalog block population.
--
--  OUTPUT  Product Area | Report | Report Type | Custom | Last Used |
--          Last Modified | Created By | ESS Job | Catalog Path
--    One row per catalog report whose last access falls in the window, most
--    recent first. EBS lists every concurrent program that RAN (with a run
--    count); the catalog holds only the LAST access, so a report used 50
--    times and one used once look the same here. The About sheet says so.
--    Not in this sheet: scheduled processes (ESS jobs) that ran. They need
--    ESS request history (R016: not visible; V5_2a decides). If V5_2a
--    passes, they become sheet 2.
--  Reconciliation: rows <= F8.1's Used (6 mth) summed over the BI Publisher
--    total, OTBI and financial-report rows (3 months sit inside 6); rows with
--    Custom = Y <= F8.2c Used (6 mth).
-- ============================================================================
WITH
-- ---- PARAMS / WINDOW / SCOPE: copied unchanged from F1 (shared block v3.1).
--      Section 8 reads only led_scope (F8.1 account groups); the rest is kept
--      for parity with every other query. The discovery window (win) is NOT
--      used: Section 8 measures operational time (logwin below).
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
-- ---- SECTION 8 CATALOG BLOCK v1.0 (2026-10-05) -------------------------------
--      Byte-identical in F8.1, F8.2a, F8.2b, F8.2c, F8.2_WB and V8_1, so every
--      Section 8 number comes from one population. Change all six or none.
-- logwin: the EBS agent's _logwin_cte, the trailing 6 months of OPERATIONAL
-- time measured from the run day (ADD_MONTHS(TRUNC(SYSDATE), -6) up to the
-- end of today). Not the discovery window: report use is operational
-- history, not a business date (WINDOW_AND_PARAMETERS.md section 2).
logwin AS (
    SELECT ADD_MONTHS(TRUNC(SYSDATE), -6) AS start_date,
           TRUNC(SYSDATE) + 1             AS end_date_excl
    FROM   dual
),
-- s8_items: one row per item of the SHARED BI catalog (/shared/...) of the
-- four report types, read from GL_FRC_REPORTS_B, "the list of reports
-- available in BI catalog" (Oracle doc 25D). Grain = type + path, the F5.1
-- grain, so the custom counts tie to the 5.1 cards (R017: BIP 196, OTBI
-- 35 + 339). Left out: personal folders (/users/...; V8_1 block K counts
-- them), the index's '... dummy' placeholder rows, and account groups
-- (type AG; F8.1 counts them from GL_ACCOUNT_GROUPS).
-- LAST_ACCESSED_DATE is "when report was last accessed in business
-- intelligence catalog" (doc): a last-use date, NOT a run count. The index
-- is refreshed by Fusion, not live (R017: latest row 2026-09-24).
s8_items AS (
    SELECT UPPER(r.report_type_code)                              AS type_code,
           TO_CHAR(r.report_path)                                 AS report_path,
           MIN(r.report_id)                                       AS report_id,
           COUNT(*)                                               AS index_rows,
           MAX(r.last_accessed_date)                              AS last_accessed,
           MAX(r.last_modified_date)                              AS last_modified,
           MAX(TO_CHAR(r.author_display_name))                    AS author,
           MAX(CASE WHEN r.bip_report_job_definition IS NOT NULL
                    THEN 'Y' ELSE 'N' END)                        AS has_ess_job
    FROM   gl_frc_reports_b r
    WHERE  LOWER(r.report_path) LIKE '/shared/%'
    AND    UPPER(r.report_type_code) IN ('BIP', 'ANALYSIS', 'DASHBOARD', 'FR')
    GROUP  BY UPPER(r.report_type_code), r.report_path
),
-- s8_path: report name (last path segment, as stored), custom flag (the
-- Section 5 marker: under /shared/Custom/, compared lower-cased, as F5.1) and
-- the folder path below /shared/ or below /shared/Custom/.
s8_path AS (
    SELECT i.type_code, i.report_path, i.report_id, i.index_rows,
           i.last_accessed, i.last_modified, i.author, i.has_ess_job,
           TO_CHAR(REGEXP_SUBSTR(i.report_path, '[^/]+$'))                AS report_name,
           CASE WHEN LOWER(i.report_path) LIKE '/shared/custom/%'
                THEN 'Y' ELSE 'N' END                                    AS is_custom,
           TO_CHAR(REGEXP_REPLACE(REGEXP_REPLACE(i.report_path, '/[^/]*$', '') || '/',
                                  '^/shared/(custom/)?', '', 1, 1, 'i')) AS rel_folder
    FROM   s8_items i
),
-- s8_area: product area = the first two folder levels of rel_folder, e.g.
-- "Financials / Payables": the BI catalog's own family / product folders, so
-- no module name is typed in this SQL. A custom report filed like Oracle's
-- tree (/shared/Custom/Financials/Payables/...) lands in the same area as
-- the seeded reports; one filed elsewhere shows under its own folder names.
s8_area AS (
    SELECT p.type_code, p.report_path, p.report_id, p.index_rows,
           p.last_accessed, p.last_modified, p.author, p.has_ess_job,
           p.report_name, p.is_custom, p.rel_folder,
           CAST(CASE p.type_code WHEN 'BIP'       THEN 'BI Publisher report'
                                 WHEN 'ANALYSIS'  THEN 'OTBI analysis'
                                 WHEN 'DASHBOARD' THEN 'OTBI dashboard'
                                 WHEN 'FR'        THEN 'Financial report (FR Web Studio)'
                END AS VARCHAR2(100))                                     AS type_label,
           TO_CHAR(CASE WHEN REGEXP_SUBSTR(p.rel_folder, '[^/]+', 1, 1) IS NULL
                        THEN '(top)' || p.is_custom
                        ELSE LOWER(REGEXP_SUBSTR(p.rel_folder, '[^/]+', 1, 1)) || '/'
                             || LOWER(NVL(REGEXP_SUBSTR(p.rel_folder, '[^/]+', 1, 2), '-'))
                   END)                                                   AS area_key,
           TO_CHAR(CASE WHEN REGEXP_SUBSTR(p.rel_folder, '[^/]+', 1, 1) IS NULL
                        THEN CASE p.is_custom WHEN 'Y' THEN '(top of /shared/Custom)'
                                              ELSE '(top of /shared)' END
                        WHEN REGEXP_SUBSTR(p.rel_folder, '[^/]+', 1, 2) IS NULL
                        THEN REGEXP_SUBSTR(p.rel_folder, '[^/]+', 1, 1)
                        ELSE REGEXP_SUBSTR(p.rel_folder, '[^/]+', 1, 1) || ' / '
                             || REGEXP_SUBSTR(p.rel_folder, '[^/]+', 1, 2)
                   END)                                                   AS area_label
    FROM   s8_path p
),
-- ---- END OF SECTION 8 CATALOG BLOCK -----------------------------------------
win3 AS (
    SELECT ADD_MONTHS(TRUNC(SYSDATE), -3) AS start_date,
           SYSDATE                        AS end_date
    FROM   dual
)
SELECT
    a.area_label                                              AS "Product Area",
    a.report_name                                             AS "Report",
    a.type_label                                              AS "Report Type",
    a.is_custom                                               AS "Custom",
    TO_CHAR(a.last_accessed, 'YYYY-MM-DD HH24:MI')            AS "Last Used",
    TO_CHAR(a.last_modified, 'YYYY-MM-DD')                    AS "Last Modified",
    a.author                                                  AS "Created By",
    a.has_ess_job                                             AS "ESS Job",
    a.report_path                                             AS "Catalog Path"
FROM        s8_area a
CROSS JOIN  win3    w
WHERE       a.last_accessed >= w.start_date
AND         a.last_accessed <= w.end_date
ORDER BY    a.last_accessed DESC, a.report_path
