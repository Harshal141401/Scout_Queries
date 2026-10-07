-- ============================================================================
--  F4.3  Section 4.3 Record-to-report (R2R)
--  Version   : 1.1 (2026-10-05). Not yet run on a pod. v1.1: GL_LEDGERS.NAME is
--              wrapped in TO_CHAR so the UNION ALL with the typed 'Instance-wide'
--              label cannot raise ORA-12704 if the column is NVARCHAR2 (see
--              R009 / R010 on F4.1). Logic unchanged.
--              RUN V4_0 AND V4_1 FIRST. Log every run in 06_Run_Results/RUN_LOG.md.
--  Source    : Oracle Fusion Cloud (BIP data model, data source ApplicationDB_FSCM)
--  Mirrors   : EBS agent ebs_discover_business_processes, R2R block + _frequency
--              (report 30-Sep-2026, Vision: GL journals 1,704 / 8 sources /
--              Daily; bank statements 2,609 instance-wide - EBS numbers)
--
--  OUTPUT  Activity | Ledger | Frequency | Volume | Sources
--    GL journals  one row per ledger in scope that has posted journals in the
--                 window (STATUS 'P', by CREATION_DATE)
--                 Volume  = journal headers
--                 Sources = distinct JE_SOURCE feeding them (Payables,
--                           Receivables, Manual, ...), NOT a table name
--    Bank statements / reconciliation  CE_STATEMENT_HEADERS created in the
--                 window, INSTANCE-WIDE (EBS functional sign-off: a bank
--                 account can serve several BUs and ledgers, so tying a
--                 statement to one ledger double-counts). Sources '-'.
--    Frequency  derived, never typed: distinct active days / window days
--               >= 1/2 Daily, >= 1/7 Weekly, >= 1/30 Monthly, > 0 Quarterly,
--               0 Ad-hoc  (the EBS _frequency rule unchanged)
--  RECONCILES  F4.3_WB_GL_Journal_Sources: SUM(JOURNAL_COUNT) = the GL journals
--              Volume (summed over ledgers) - same population.
--
--  PARAMETERS  the five standard binds, all optional - same meaning as F1:
--    :p_ledger_id / :p_bu_id narrow the scope; :p_from_date / :p_to_date
--    ('YYYY-MM-DD') set the window, blank = the last 90 days up to today.
--    Run every Section 4 query with the SAME values as F1, or the numbers
--    stop being comparable (see 06_Run_Results/RUN_LOG.md).
--  SCOPE (identical to F1, which is the EBS 1.1 / 4.x rule with BU for OU)
--    ledger-scoped    GL (led_scope), FA (book -> SET_OF_BOOKS_ID)
--    business units   requisitions, POs, AP, payments, orders, AR, receipts,
--                     projects (bu_scope: active BUs whose primary ledger is
--                     in scope, narrowed by :p_bu_id)
--    inventory orgs   receipts, deliveries, items, costing (inv_org_scope)
--  Columns used here (GL_JE_HEADERS STATUS / CREATION_DATE / JE_SOURCE /
--  LEDGER_ID, CE_STATEMENT_HEADERS.CREATION_DATE) are already pod-proven
--  (R006 / the F1 run); V4_0 re-checks them.
-- ============================================================================
WITH
-- ---- PARAMS / WINDOW / SCOPE: copied unchanged from F1 (shared block v3.1),
--      so Section 4 measures the same population and window as Section 1.
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
-- ---- posted journals in scope and window ----------------------------------
jrnl AS (
    SELECT h.ledger_id, h.je_source, TRUNC(h.creation_date) AS jrnl_day
    FROM   gl_je_headers h
    JOIN   led_scope l ON l.ledger_id = h.ledger_id
    CROSS  JOIN win w
    WHERE  h.status = 'P'
    AND    h.creation_date >= w.start_date
    AND    h.creation_date <  w.end_date_excl
),
jrnl_vol AS (
    SELECT ledger_id, COUNT(*) AS volume FROM jrnl GROUP BY ledger_id
),
jrnl_days AS (
    SELECT ledger_id, COUNT(*) AS active_days
    FROM  ( SELECT ledger_id, jrnl_day FROM jrnl GROUP BY ledger_id, jrnl_day )
    GROUP BY ledger_id
),
jrnl_src AS (
    SELECT ledger_id, COUNT(*) AS sources
    FROM  ( SELECT ledger_id, je_source FROM jrnl GROUP BY ledger_id, je_source )
    GROUP BY ledger_id
),
win_len AS (
    SELECT w.end_date_excl - w.start_date AS days FROM win w
),
-- ---- bank statements, instance-wide -------------------------------------------
bank AS (
    SELECT TRUNC(cs.creation_date) AS stmt_day
    FROM   ce_statement_headers cs
    CROSS  JOIN win w
    WHERE  cs.creation_date >= w.start_date
    AND    cs.creation_date <  w.end_date_excl
),
bank_vol AS (
    SELECT COUNT(*) AS volume FROM bank
),
bank_days AS (
    SELECT COUNT(*) AS active_days
    FROM  ( SELECT stmt_day FROM bank GROUP BY stmt_day )
),
r2r_rows AS (
    SELECT  1                                  AS grp,
            v.volume                           AS sort_vol,
            'GL journals'                      AS activity,
            TO_CHAR(gl.name)                   AS ledger,
            CASE WHEN NVL(d.active_days, 0) <= 0      THEN 'Ad-hoc'
                 WHEN d.active_days * 2  >= wl.days    THEN 'Daily'
                 WHEN d.active_days * 7  >= wl.days    THEN 'Weekly'
                 WHEN d.active_days * 30 >= wl.days    THEN 'Monthly'
                 ELSE 'Quarterly' END                  AS frequency,
            v.volume                           AS volume,
            TO_CHAR(NVL(s.sources, 0))         AS sources
    FROM        jrnl_vol  v
    JOIN        gl_ledgers gl ON gl.ledger_id = v.ledger_id
    LEFT JOIN   jrnl_days d   ON d.ledger_id  = v.ledger_id
    LEFT JOIN   jrnl_src  s   ON s.ledger_id  = v.ledger_id
    CROSS JOIN  win_len   wl
    UNION ALL
    SELECT  2, 0,
            'Bank statements / reconciliation',
            'Instance-wide (all ledgers)',
            CASE WHEN NVL(bd.active_days, 0) <= 0      THEN 'Ad-hoc'
                 WHEN bd.active_days * 2  >= wl.days    THEN 'Daily'
                 WHEN bd.active_days * 7  >= wl.days    THEN 'Weekly'
                 WHEN bd.active_days * 30 >= wl.days    THEN 'Monthly'
                 ELSE 'Quarterly' END,
            bv.volume,
            '-'
    FROM        bank_vol  bv
    CROSS JOIN  bank_days bd
    CROSS JOIN  win_len   wl
)
SELECT
    r.activity                                                AS "Activity",
    r.ledger                                                  AS "Ledger",
    r.frequency                                               AS "Frequency",
    r.volume                                                  AS "Volume",
    r.sources                                                 AS "Sources"
FROM        r2r_rows r
ORDER BY    r.grp, r.sort_vol DESC, r.ledger
