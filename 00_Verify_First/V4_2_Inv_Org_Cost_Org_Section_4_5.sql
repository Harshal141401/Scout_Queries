-- ============================================================================
--  V4_2  INVENTORY ORG -> COST ORG list (verifies F4.5 on THIS pod)
--  Version   : 1.0 (2026-10-13). Not yet run on a pod.
--              Run log: 06_Run_Results/RUN_LOG.md
--  Run AFTER V4_0 reads ALL OK.
--
--  WHY  F4.5 counts inventory orgs by costing method, but first maps each
--  inventory org to its cost organization through CST_COST_INV_ORGS (current
--  row by FROM_DATE / TO_DATE, MIN(COST_ORG_ID) if more than one). This lists
--  that mapping row by row so the F4.5 counts can be checked by eye.
--
--  OUTPUT  one row per inventory org x current cost org assignment
--          (an inventory org with no current cost org prints once, cost org
--          columns empty). Whole pod - no binds; filter on Ledger ID to
--          match an F4.5 run with :p_ledger_id.
--    Used by F4.5 = 'Y'  the cost org F4.5 picks (MIN of the current ones)
--                 = 'N'  another current assignment F4.5 ignores
--    Current Assignments > 1 flags an inventory org F4.5 resolves by MIN.
--  Pure SELECT, one statement, every aggregate in its own CTE, no DISTINCT.
-- ============================================================================
WITH
-- same population as F4.5 inv_org_scope (no ledger filter here)
inv_orgs AS (
    SELECT iod.organization_id,
           MAX(iod.organization_code) AS org_code,
           MAX(iod.organization_name) AS org_name,
           MAX(iod.set_of_books_id)   AS ledger_id
    FROM   inv_organization_definitions_v iod
    GROUP  BY iod.organization_id
),
-- current cost org assignments, same date rule as F4.5 org_cost_org
cur_assign AS (
    SELECT ci.inv_org_id, ci.cost_org_id,
           MIN(ci.from_date) AS from_date,
           MAX(ci.to_date)   AS to_date
    FROM   cst_cost_inv_orgs ci
    WHERE  TRUNC(SYSDATE) BETWEEN NVL(TRUNC(ci.from_date), TRUNC(SYSDATE))
                              AND NVL(TRUNC(ci.to_date),   TRUNC(SYSDATE))
    GROUP  BY ci.inv_org_id, ci.cost_org_id
),
assign_cnt AS (
    SELECT inv_org_id,
           COUNT(*)         AS n_assign,
           MIN(cost_org_id) AS f45_cost_org_id
    FROM   cur_assign
    GROUP  BY inv_org_id
),
-- cost organizations are HR organizations; current name in session language
cost_org_names AS (
    SELECT ou.organization_id, MAX(ou.name) AS cost_org_name
    FROM   hr_organization_units_f_tl ou
    WHERE  ou.language = USERENV('LANG')
    AND    TRUNC(SYSDATE) BETWEEN TRUNC(ou.effective_start_date)
                              AND TRUNC(ou.effective_end_date)
    GROUP  BY ou.organization_id
),
-- primary-ledger cost book, same rule as F4.5 primary_book
primary_book AS (
    SELECT cob.cost_org_id, MIN(cob.cost_book_id) AS cost_book_id
    FROM   cst_cost_org_books cob
    WHERE  cob.primary_book_flag = 'Y'
    AND    NVL(cob.inactive_date, SYSDATE + 1) > SYSDATE
    GROUP  BY cob.cost_org_id
),
ledger_names AS (
    SELECT gl.ledger_id, MAX(gl.name) AS ledger_name
    FROM   gl_ledgers gl
    GROUP  BY gl.ledger_id
)
SELECT
    io.ledger_id                                              AS "Ledger ID",
    ln.ledger_name                                            AS "Ledger",
    io.organization_id                                        AS "Inv Org ID",
    io.org_code                                               AS "Inv Org Code",
    io.org_name                                               AS "Inv Org Name",
    ca.cost_org_id                                            AS "Cost Org ID",
    NVL(cn.cost_org_name,
        CASE WHEN ca.cost_org_id IS NULL THEN 'No cost organization' END)
                                                              AS "Cost Org Name",
    ca.from_date                                              AS "Assigned From",
    ca.to_date                                                AS "Assigned To",
    pb.cost_book_id                                           AS "Primary Cost Book ID",
    NVL(ac.n_assign, 0)                                       AS "Current Assignments",
    CASE WHEN ca.cost_org_id IS NULL                 THEN NULL
         WHEN ca.cost_org_id = ac.f45_cost_org_id    THEN 'Y'
         ELSE 'N'
    END                                                       AS "Used by F4.5"
FROM        inv_orgs       io
LEFT JOIN   cur_assign     ca ON ca.inv_org_id      = io.organization_id
LEFT JOIN   assign_cnt     ac ON ac.inv_org_id      = io.organization_id
LEFT JOIN   cost_org_names cn ON cn.organization_id = ca.cost_org_id
LEFT JOIN   primary_book   pb ON pb.cost_org_id     = ca.cost_org_id
LEFT JOIN   ledger_names   ln ON ln.ledger_id       = io.ledger_id
ORDER BY    io.ledger_id, io.org_code, ca.cost_org_id
