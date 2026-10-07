-- ============================================================================
--  F5.2b Section 5.2 caption: how far back ESS request history goes
--  Version   : 1.0 (2026-10-05). Not yet run on a pod.
--              RUN V5_0 FIRST. Log every run in 06_Run_Results/RUN_LOG.md.
--  Source    : Oracle Fusion Cloud (BIP data model, data source ApplicationDB_FSCM)
--  Mirrors   : EBS agent ebs_discover_cemli request_history block (agent
--              2026-09-23; report 30-Sep-2026, Vision: 2019-07-30 to 2026-09-30,
--              41,095 requests - EBS numbers, not targets)
--  Window    : uses the shared win block only to say whether the period is
--              inside retained history. Same dates as F5.2.
--  Scope     : pod-wide. :p_ledger_id / :p_bu_id / :p_custom_prefix accepted,
--              not used (parameter parity).
--
--  WHY THIS EXISTS (EBS reasoning, unchanged)
--    A 0 in F5.2 "Executions (period)" means nothing if request history does
--    not reach back to the period: Fusion purges old ESS requests, as EBS
--    purges FND_CONCURRENT_REQUESTS. This one row says how far back any
--    execution figure in 5.2 can see. Print it beside the 5.2 table.
--
--  OUTPUT  one row
--    REQUESTS_RETAINED  requests that started (PROCESSSTART populated), all jobs
--    FIRST_REQUEST / LAST_REQUEST   earliest / latest start in retained history
--    PERIOD_START / PERIOD_END      the period F5.2 used
--    PERIOD_COVERAGE    Full    - history starts on or before the period start
--                       Partial - history starts inside the period
--                       None    - the period lies outside retained history
--                       Unknown - no request has started at all
--    (EBS reported overlap yes / no; Full / Partial is the same test, split.)
-- ============================================================================
WITH
-- ---- PARAMS / WINDOW / SCOPE: copied unchanged from F1 (shared block v3.1).
--      Only params and win are read; the rest is kept for parity.
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
-- ---- retained history: every request that started --------------------------
hist AS (
    SELECT COUNT(*)              AS requests,
           MIN(erh.processstart) AS first_start,
           MAX(erh.processstart) AS last_start
    FROM   ess_request_history erh
    WHERE  erh.processstart IS NOT NULL
)
SELECT
    h.requests                                                AS "REQUESTS_RETAINED",
    TO_CHAR(h.first_start, 'YYYY-MM-DD')                      AS "FIRST_REQUEST",
    TO_CHAR(h.last_start,  'YYYY-MM-DD')                      AS "LAST_REQUEST",
    TO_CHAR(w.start_date, 'YYYY-MM-DD')                       AS "PERIOD_START",
    TO_CHAR(w.end_date_excl - 1, 'YYYY-MM-DD')                AS "PERIOD_END",
    CASE WHEN h.requests = 0
         THEN 'Unknown: no request has started in retained history'
         WHEN h.last_start < w.start_date OR h.first_start >= w.end_date_excl
         THEN 'None: the period lies outside retained history, so a 0 in the period means no history, not idle'
         WHEN h.first_start <= w.start_date
         THEN 'Full: retained history starts on or before the period start'
         ELSE 'Partial: retained history starts inside the period, on ' || TO_CHAR(h.first_start, 'YYYY-MM-DD')
    END                                                       AS "PERIOD_COVERAGE"
FROM        hist h
CROSS JOIN  win  w
