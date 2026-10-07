-- ============================================================================
--  V5_5  DETAIL CHECK - settles the open points R017 left on F5.1
--  Version   : 1.0 (2026-10-05)        Run log: 06_Run_Results/RUN_LOG.md
--  Source    : Oracle Fusion Cloud (BIP data model, data source ApplicationDB_FSCM)
--  For: F5.1 rows 30 (custom roles), 40 (approval rules), 10-14 (BI catalog)
--       and 61 (AADs). Every column read here was printed by V5_0 (R016).
--
--  WHY (from R017)
--    R  71 role codes do not start ORA_. 28 start CUSTOM_ and 17 YEU_ (client
--       prefixes), but others start with Oracle product codes - INV_, POR_,
--       PO_, WIE_, CST_, EGI_, ASM_, AI_ - and may be Oracle roles without
--       the ORA_ prefix. This lists all of them with flags, creation date and
--       creator type, next to the date range of the ORA_ roles.
--    A  36 active, published approval rules, but only 11 created by a user
--       account. This lists every non-sandbox rule and who created it.
--    U  /users/svc holds 283 catalog items. BIP data models of THIS discovery
--       run are named __svc__temp_... (see the export headers), so svc is
--       most likely the report user itself. User folders are not counted in
--       F5.1 rows 10-14; this shows which user folders exist.
--    X  XLA_PRODUCT_RULES_B returned no rows (F5.1 row 61 is now blank). This
--       lists the accounting-definition objects this user can see (metadata
--       only - it cannot fail on them).
--  Creator identities are printed only when they are NOT a user account
--  (system / seed identities); user accounts print as 'user account'.
--
--  OUTPUT  ord | section | item | value_text   (one grid, paste it back whole)
--    R 2001-2004 summary, 2011-2120 one row per non-ORA_ role code
--    A 3001-3010 creators of active rules, 3011-3070 one row per rule
--    U 4001-4011 catalog items under /users/, by user folder
--    X 5001-5020 visible XLA objects about accounting definitions / methods
--  No binds. Pure SELECT. Nothing is written.
-- ============================================================================
WITH
user_accts AS (
    SELECT  UPPER(pu.username) AS uname
    FROM    per_users pu
    WHERE   pu.username IS NOT NULL
    GROUP   BY UPPER(pu.username)
),
-- ==== R roles ===================================================================
role_rows AS (
    SELECT r.role_common_name                                           AS role_code,
           CASE WHEN SUBSTR(r.role_common_name, 1, 4) = 'ORA_' THEN 'ORA_'
                ELSE 'non-ORA_' END                                     AS code_class,
           CASE WHEN ua.uname IS NOT NULL THEN 'user account'
                ELSE 'not a user account: ' || NVL(TO_CHAR(r.created_by), '(null)')
           END                                                          AS creator,
           CASE WHEN ua.uname IS NOT NULL THEN 'user' ELSE 'non-user' END AS creator_type,
           r.creation_date, r.last_update_date,
           TO_CHAR('job=' || NVL(TO_CHAR(r.job_role), '-') || ' abstract=' || NVL(TO_CHAR(r.abstract_role), '-')
                   || ' duty=' || NVL(TO_CHAR(r.duty_role), '-') || ' data=' || NVL(TO_CHAR(r.data_role), '-')
                   || ' active=' || NVL(TO_CHAR(r.active_flag), '-'))   AS flags
    FROM        per_roles_dn r
    LEFT JOIN   user_accts   ua ON ua.uname = UPPER(r.created_by)
    WHERE       r.role_common_name IS NOT NULL
),
role_class_sum AS (
    SELECT rr.code_class, rr.creator_type, COUNT(*) AS n,
           MIN(rr.creation_date) AS first_created, MAX(rr.creation_date) AS last_created
    FROM   role_rows rr
    GROUP  BY rr.code_class, rr.creator_type
),
role_class_rows AS (
    SELECT s.code_class, s.creator_type, s.n, s.first_created, s.last_created,
           ROW_NUMBER() OVER (ORDER BY s.code_class, s.creator_type) AS rn
    FROM   role_class_sum s
),
role_list AS (
    SELECT rr.role_code, rr.flags, rr.creator, rr.creation_date, rr.last_update_date,
           ROW_NUMBER() OVER (ORDER BY rr.role_code) AS rn
    FROM   role_rows rr
    WHERE  rr.code_class = 'non-ORA_'
),
-- ==== A procurement approval rules ===========================================
amx_rows AS (
    SELECT ar.rule_id, ar.display_rule_name, ar.rule_name, ar.task_id,
           TO_CHAR(ar.active_flag)                                       AS active_flag,
           ar.creation_date,
           CASE WHEN ua.uname IS NOT NULL THEN 'user account'
                ELSE 'not a user account: ' || NVL(TO_CHAR(ar.created_by), '(null)')
           END                                                           AS creator,
           CASE WHEN ub.uname IS NOT NULL THEN 'user account'
                ELSE 'not a user account: ' || NVL(TO_CHAR(ar.last_updated_by), '(null)')
           END                                                           AS updater
    FROM        por_amx_rules ar
    LEFT JOIN   user_accts    ua ON ua.uname = UPPER(ar.created_by)
    LEFT JOIN   user_accts    ub ON ub.uname = UPPER(ar.last_updated_by)
    WHERE       NVL(ar.sandbox_flag, 'N') <> 'Y'
),
amx_creators AS (
    SELECT a.creator, COUNT(*) AS n
    FROM   amx_rows a
    WHERE  a.active_flag = 'Y'
    GROUP  BY a.creator
),
amx_creator_rows AS (
    SELECT c.creator, c.n, ROW_NUMBER() OVER (ORDER BY c.n DESC, c.creator) AS rn
    FROM   amx_creators c
),
amx_list AS (
    SELECT a.display_rule_name, a.rule_name, a.task_id, a.active_flag, a.creation_date,
           a.creator, a.updater,
           ROW_NUMBER() OVER (ORDER BY a.active_flag DESC, a.task_id, a.display_rule_name, a.rule_id) AS rn
    FROM   amx_rows a
),
-- ==== U BI catalog user folders ==============================================
user_folders AS (
    SELECT TO_CHAR(LOWER(REGEXP_SUBSTR(r.report_path, '^/users/[^/]*'))) AS fld,
           COUNT(*)                                                     AS n,
           SUM(CASE WHEN UPPER(r.report_type_code) = 'BIP' THEN 1 ELSE 0 END)       AS n_bip,
           SUM(CASE WHEN UPPER(r.report_type_code) = 'ANALYSIS' THEN 1 ELSE 0 END)  AS n_analysis,
           SUM(CASE WHEN UPPER(r.report_type_code) = 'DASHBOARD' THEN 1 ELSE 0 END) AS n_dashboard
    FROM   gl_frc_reports_b r
    WHERE  LOWER(r.report_path) LIKE '/users/%'
    GROUP  BY TO_CHAR(LOWER(REGEXP_SUBSTR(r.report_path, '^/users/[^/]*')))
),
user_folder_rows AS (
    SELECT u.fld, u.n, u.n_bip, u.n_analysis, u.n_dashboard,
           ROW_NUMBER() OVER (ORDER BY u.n DESC, u.fld) AS rn
    FROM   user_folders u
),
user_folder_tot AS (
    SELECT NVL(SUM(u.n), 0) AS n, COUNT(*) AS n_folders FROM user_folders u
),
-- ==== X accounting-definition objects (metadata only) =======================
xla_objs AS (
    SELECT o.object_name,
           LISTAGG(o.owner || '.' || o.object_type, ', ')
               WITHIN GROUP (ORDER BY o.owner, o.object_type)  AS visible_as
    FROM   all_objects o
    WHERE  o.object_type IN ('TABLE', 'VIEW', 'SYNONYM')
    AND    REGEXP_LIKE(o.object_name, '^XLA_.*(PRODUCT_RULE|ACCTG_METHOD|PROD_ACCT|AAD|JE_RULE_SET|SLAM)')
    GROUP  BY o.object_name
),
xla_cols AS (
    SELECT c.table_name, COUNT(*) AS n_cols
    FROM  ( SELECT tc.table_name, tc.column_name
            FROM   all_tab_columns tc
            WHERE  tc.table_name IN ( SELECT x.object_name FROM xla_objs x )
            GROUP  BY tc.table_name, tc.column_name ) c
    GROUP  BY c.table_name
),
xla_rows AS (
    SELECT x.object_name, x.visible_as, NVL(c.n_cols, 0) AS n_cols,
           ROW_NUMBER() OVER (ORDER BY x.object_name) AS rn
    FROM        xla_objs x
    LEFT JOIN   xla_cols c ON c.table_name = x.object_name
),
grid AS (
    -- R ------------------------------------------------------------------------
    SELECT 2000 + rc.rn                                                   AS ord,
           CAST('R roles summary' AS VARCHAR2(400))                       AS section,
           CAST('R ' || rc.code_class || ' codes, creator ' || rc.creator_type
                AS VARCHAR2(400))                                         AS item,
           CAST(TO_CHAR(rc.n || ' roles, created '
                || NVL(TO_CHAR(rc.first_created, 'YYYY-MM-DD'), '-') || ' to '
                || NVL(TO_CHAR(rc.last_created, 'YYYY-MM-DD'), '-')) AS VARCHAR2(4000)) AS value_text
    FROM   role_class_rows rc
    WHERE  rc.rn <= 4
    UNION ALL
    SELECT 2010 + rl.rn, TO_CHAR('R non-ORA_ roles'), TO_CHAR('R ' || SUBSTR(rl.role_code, 1, 200)),
           TO_CHAR(rl.flags || ' | created ' || NVL(TO_CHAR(rl.creation_date, 'YYYY-MM-DD'), '-')
                   || ' by ' || rl.creator
                   || ' | last updated ' || NVL(TO_CHAR(rl.last_update_date, 'YYYY-MM-DD'), '-'))
    FROM   role_list rl
    WHERE  rl.rn <= 110
    -- A ------------------------------------------------------------------------
    UNION ALL
    SELECT 3000 + acr.rn, TO_CHAR('A active rules by creator'), TO_CHAR('A ' || acr.creator),
           TO_CHAR(acr.n || ' active rules')
    FROM   amx_creator_rows acr
    WHERE  acr.rn <= 10
    UNION ALL
    SELECT 3010 + al.rn, TO_CHAR('A approval rules (not sandbox)'),
           TO_CHAR('A ' || SUBSTR(NVL(al.display_rule_name, al.rule_name), 1, 150)),
           TO_CHAR('active=' || al.active_flag || ' | task ' || al.task_id
                   || ' | created ' || NVL(TO_CHAR(al.creation_date, 'YYYY-MM-DD'), '-')
                   || ' by ' || al.creator || ' | last updated by ' || al.updater)
    FROM   amx_list al
    WHERE  al.rn <= 60
    -- U ------------------------------------------------------------------------
    UNION ALL
    SELECT 4001, TO_CHAR('U catalog user folders'), TO_CHAR('U0 items under /users/, folders'),
           TO_CHAR(uft.n || ' items in ' || uft.n_folders || ' user folders')
    FROM   user_folder_tot uft
    UNION ALL
    SELECT 4001 + ufr.rn, TO_CHAR('U catalog user folders'), TO_CHAR('U ' || NVL(ufr.fld, '(none)')),
           TO_CHAR(ufr.n || ' items: BIP ' || ufr.n_bip || ', Analysis ' || ufr.n_analysis
                   || ', Dashboard ' || ufr.n_dashboard)
    FROM   user_folder_rows ufr
    WHERE  ufr.rn <= 10
    -- X ------------------------------------------------------------------------
    UNION ALL
    SELECT 5000 + xr.rn, TO_CHAR('X XLA objects (metadata)'), TO_CHAR('X ' || xr.object_name),
           TO_CHAR(xr.visible_as || ' | ' || xr.n_cols || ' columns visible')
    FROM   xla_rows xr
    WHERE  xr.rn <= 20
)
SELECT  g.ord         AS ord,
        g.section     AS section,
        g.item        AS item,
        g.value_text  AS value_text
FROM    grid g
ORDER BY g.ord
