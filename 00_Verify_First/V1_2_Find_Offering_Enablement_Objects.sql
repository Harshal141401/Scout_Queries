-- ============================================================================
--  V1_2  FIND the offering / feature enablement objects this report user can see
--  Version   : 1.0 (2026-10-01)        Run log: 06_Run_Results/RUN_LOG.md
--
--  WHY THIS EXISTS
--    "Live modules" in the functional sense = the offerings and functional
--    areas enabled in Setup and Maintenance. F1 cannot see that; it infers
--    activity from data. In June the guessed tables (ASK_FA_OFFERINGS_VL etc.)
--    were not granted on the dev pod. Instead of guessing names again, this
--    lists every table or view visible to the BIP user whose name looks like
--    offering / feature / functional-area / provisioning storage, with its
--    columns, so the right object (if any is granted) can be picked.
--
--  Metadata only (ALL_OBJECTS, ALL_TAB_COLUMNS). It cannot fail on a missing
--  object. Zero rows in section 2 = nothing of that kind is granted.
--
--  OUTPUT  ord | object_name | col_count | status_like_columns | all_columns
--    ord 1  how many ASK_ / ASM_ objects are visible at all (0 = not granted)
--    ord 2  one row per matching table / view
--  No binds. Pure SELECT. Nothing is written.
-- ============================================================================
WITH
obj_hits AS (
    SELECT  o.owner, o.object_name, o.object_type
    FROM    all_objects o
    WHERE   o.object_type IN ('TABLE', 'VIEW')
    AND     (    o.object_name LIKE '%OFFERING%'
              OR REGEXP_LIKE(o.object_name,
                   '^AS[KM]_.*(OFFER|FEATURE|FUNC|PROVISION|ENABLE|DEPLOY|OPT)') )
    GROUP   BY o.owner, o.object_name, o.object_type
),
prefix_objs AS (
    SELECT  SUBSTR(o.object_name, 1, 4) AS pfx, o.object_name
    FROM    all_objects o
    WHERE   o.object_type IN ('TABLE', 'VIEW')
    AND     REGEXP_LIKE(o.object_name, '^AS[KM]_')
    GROUP   BY SUBSTR(o.object_name, 1, 4), o.object_name
),
prefix_cnt AS (
    SELECT  SUM(CASE WHEN pfx = 'ASK_' THEN 1 ELSE 0 END) AS n_ask,
            SUM(CASE WHEN pfx = 'ASM_' THEN 1 ELSE 0 END) AS n_asm,
            COUNT(*)                                      AS n_all
    FROM    prefix_objs
),
col_hits AS (
    SELECT  c.owner, c.table_name, c.column_name
    FROM        all_tab_columns c
    JOIN        obj_hits        h ON h.owner = c.owner AND h.object_name = c.table_name
    GROUP   BY  c.owner, c.table_name, c.column_name
),
obj_cols AS (
    SELECT  owner, table_name,
            COUNT(*)                                                         AS col_cnt,
            LISTAGG(CASE WHEN REGEXP_LIKE(column_name,
                               '(ENABLE|STATUS|ACTIVE|OPT|PROVISION|SELECTED|IMPLEMENT|DEPLOY)')
                         THEN column_name END, ' ' ON OVERFLOW TRUNCATE)
                WITHIN GROUP (ORDER BY column_name)                          AS status_cols,
            LISTAGG(column_name, ' ' ON OVERFLOW TRUNCATE)
                WITHIN GROUP (ORDER BY column_name)                          AS all_cols
    FROM    col_hits
    GROUP   BY owner, table_name
)
SELECT  1                                                       AS ord,
        'Visible ASK_ / ASM_ tables+views: ASK_ ' || TO_CHAR(NVL(p.n_ask, 0))
          || ', ASM_ ' || TO_CHAR(NVL(p.n_asm, 0))              AS object_name,
        TO_CHAR(NVL(p.n_all, 0))                                AS col_count,
        '-'                                                     AS status_like_columns,
        '-'                                                     AS all_columns
FROM    prefix_cnt p
UNION ALL
SELECT  2,
        h.owner || '.' || h.object_name || ' (' || h.object_type || ')',
        TO_CHAR(NVL(oc.col_cnt, 0)),
        NVL(oc.status_cols, '-'),
        NVL(oc.all_cols, '(no columns visible)')
FROM        obj_hits h
LEFT JOIN   obj_cols oc ON oc.owner = h.owner AND oc.table_name = h.object_name
ORDER BY    1, 2
