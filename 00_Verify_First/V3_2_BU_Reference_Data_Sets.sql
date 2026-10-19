-- ============================================================================
--  V3_2  BU REFERENCE DATA SETS - can F3.1 rows 2-4 be narrowed to one BU?
--  Version   : 1.0 (2026-10-16). Not yet run on a pod.
--              Run log: 06_Run_Results/RUN_LOG.md
--  Run with the SAME :p_bu_id as the report being checked (ledger blank).
--
--  WHY  Manager feedback (2026-10-16): with a BU selected, the F3.1 "Setup
--  Area By Module" counts did not drop. In Fusion, AR payment terms, AR
--  transaction types and AR transaction sources are not owned by a BU: each
--  row belongs to a reference data SET (SET_ID), and a BU sees the sets
--  assigned to it, plus the common set. Narrowing rows 2-4 to a BU therefore
--  needs the BU's set assignments (FND_SETID_ASSIGNMENTS), which no query has
--  read yet. This check reads them and shows what rows 2-4 would print for
--  the BU, before F3.1 is changed.
--  Not covered: AP payment terms (row 1; AP_TERMS_B has no proven SET_ID),
--  GL journal sources / categories (rows 5-6, global), item templates (8)
--  and cost books (11) - not owned by a BU or a set.
--
--  OUTPUT  ord | section | item | value
--    A 100      reference groups assigned to this BU (0 = no assignment
--               found: wrong BU id, or the table is not visible)
--      101+     reference group -> set code
--    B 201+     AR payment terms (RA_TERMS_B) per set: assigned to this BU
--               Y/N, the common set Y/N, rows
--    C 301+     AR transaction types (RA_CUST_TRX_TYPES_ALL), same
--    D 401+     AR transaction sources (RA_BATCH_SOURCES_ALL), same
--    E 501-503  what F3.1 rows 2-4 would print for this BU: rows in a set
--               assigned to it (any reference group) or in the common set,
--               out of all rows
--  Columns: SET_ID on the three AR tables and FND_SETID_SETS_VL are proved
--  (V3_1, R006). NOT yet proved: FND_SETID_ASSIGNMENTS.SET_ID /
--  DETERMINANT_TYPE / DETERMINANT_VALUE / REFERENCE_GROUP_NAME - an
--  ORA-00904 here names the one that differs; send it.
--  Pure SELECT, one statement, every aggregate in its own CTE, no DISTINCT.
-- ============================================================================
WITH
params AS (
    SELECT :p_ledger_id     AS p_ledger_id,
           :p_bu_id         AS p_bu_id,
           :p_custom_prefix AS p_custom_prefix,
           :p_from_date     AS p_from_date,
           :p_to_date       AS p_to_date
    FROM   dual
),
set_names AS (
    SELECT s.set_id, MAX(TO_CHAR(s.set_code)) AS set_code
    FROM   fnd_setid_sets_vl s
    GROUP  BY s.set_id
),
-- the BU's set assignments, one row per reference group
bu_sets AS (
    SELECT a.set_id,
           TO_CHAR(a.reference_group_name) AS ref_group
    FROM   fnd_setid_assignments a
    CROSS  JOIN params p
    WHERE  a.determinant_type  = 'BU'
    AND    a.determinant_value = TO_NUMBER(p.p_bu_id)
),
bu_set_cnt AS (
    SELECT COUNT(*) AS n FROM bu_sets
),
bu_set_ids AS (
    SELECT b.set_id FROM bu_sets b GROUP BY b.set_id
),
bu_assign AS (
    SELECT b.ref_group,
           NVL(sn.set_code, TO_CHAR(b.set_id))                         AS set_code,
           ROW_NUMBER() OVER (ORDER BY b.ref_group, b.set_id)          AS rn
    FROM        bu_sets   b
    LEFT JOIN   set_names sn ON sn.set_id = b.set_id
),
-- the three set-owned AR setups, one row per setup row
obj AS (
    SELECT 'B' AS sec, 'AR payment terms' AS obj, t.set_id FROM ra_terms_b t
    UNION ALL
    SELECT 'C', 'AR transaction types', t.set_id FROM ra_cust_trx_types_all t
    UNION ALL
    SELECT 'D', 'AR transaction sources', s.set_id FROM ra_batch_sources_all s
),
obj_grp AS (
    SELECT sec, obj, set_id, COUNT(*) AS n
    FROM   obj
    GROUP  BY sec, obj, set_id
),
obj_det AS (
    SELECT g.sec, g.obj, g.set_id, g.n,
           NVL(sn.set_code, TO_CHAR(g.set_id))                         AS set_code,
           CASE WHEN bs.set_id IS NOT NULL THEN 'Y' ELSE 'N' END       AS bu_set,
           CASE WHEN g.set_id = 0 OR UPPER(sn.set_code) = 'COMMON'
                THEN 'Y' ELSE 'N' END                                  AS common_set,
           ROW_NUMBER() OVER (PARTITION BY g.sec
                              ORDER BY g.n DESC, g.set_id)             AS rn
    FROM        obj_grp    g
    LEFT JOIN   set_names  sn ON sn.set_id = g.set_id
    LEFT JOIN   bu_set_ids bs ON bs.set_id = g.set_id
),
obj_bu AS (
    SELECT sec, obj,
           SUM(n)                                                       AS n_all,
           SUM(CASE WHEN bu_set = 'Y' OR common_set = 'Y' THEN n ELSE 0 END) AS n_bu
    FROM   obj_det
    GROUP  BY sec, obj
),
grid AS (
    SELECT 100 AS ord, CAST('A BU SET ASSIGNMENTS' AS VARCHAR2(30)) AS section,
           CAST('reference groups assigned to this BU (0 = none found)' AS VARCHAR2(400)) AS item,
           CAST(TO_CHAR(c.n) AS VARCHAR2(400)) AS value
    FROM   bu_set_cnt c
    UNION ALL
    SELECT 100 + a.rn, 'A BU SET ASSIGNMENTS',
           TO_CHAR('reference group ' || a.ref_group),
           TO_CHAR('set ' || a.set_code)
    FROM   bu_assign a
    UNION ALL
    SELECT CASE d.sec WHEN 'B' THEN 200 WHEN 'C' THEN 300 ELSE 400 END + d.rn,
           CASE d.sec WHEN 'B' THEN 'B AR PAYMENT TERMS'
                      WHEN 'C' THEN 'C AR TRANSACTION TYPES'
                      ELSE 'D AR TRANSACTION SOURCES' END,
           TO_CHAR('set ' || d.set_code || ' | assigned to this BU ' || d.bu_set
                   || ' | common set ' || d.common_set),
           TO_CHAR(d.n)
    FROM   obj_det d
    UNION ALL
    SELECT CASE o.sec WHEN 'B' THEN 501 WHEN 'C' THEN 502 ELSE 503 END,
           'E F3.1 FOR THIS BU',
           TO_CHAR(o.obj || ': rows in a set assigned to this BU or the common set'),
           TO_CHAR(TO_CHAR(o.n_bu) || ' of ' || TO_CHAR(o.n_all))
    FROM   obj_bu o
)
SELECT  g.ord      AS ord,
        g.section  AS section,
        g.item     AS item,
        g.value    AS value
FROM    grid g
ORDER BY g.ord
