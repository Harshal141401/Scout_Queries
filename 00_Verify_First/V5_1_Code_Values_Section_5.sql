-- ============================================================================
--  V5_1  CODE VALUES - the stored values Section 5 classifies on (run after V5_0)
--  Version   : 1.2 (2026-10-05)        Run log: 06_Run_Results/RUN_LOG.md
--              v1.2 after V5_0 (R016): the ESS blocks A-H are MOVED to V5_4
--              (ESS_REQUEST_HISTORY is a synonym whose columns this user cannot
--              see, and reading it could fail this whole grid). New blocks P
--              (Alerts Composer) and Q (sandboxes) check F5.1 v1.2 rows 70 / 80;
--              block K adds the role-type flags. Every object read here had its
--              columns printed by R016.
--              v1.1: follows F5.1 v1.1 (Fusion customization inventory).
--  For: F5.1_Extensions_Summary (all rows except 20)
--  Binds: none used (the five standard binds are accepted for BIP parity).
--
--  WHY: every "custom" rule in F5.1 rests on a stored value. A wrong
--  assumption makes a row read 0, and a 0 would be reported as "no
--  customizations". Each assumption is printed with its verdict:
--    BI      customer content sits under /shared/Custom/; type codes  block J
--    Roles   predefined codes start ORA_; copies end _CUSTOM          block K
--    Rules   ACTIVE_FLAG / SANDBOX_FLAG values                        block L
--    "created by a user account" agrees with Oracle's own
--            seeded / user-defined markers                           blocks M, N, P
--    Alerts  ENABLED = 'Y' and DELETED_FLAG = 'Y' mean what F5.1 assumes  block P
--    Sandbox which of the three sandbox tables holds the published ones  block Q
--
--  OUTPUT  ord | section | item | value_text   (one grid, paste it back whole)
--    J 1001-1030  BI catalog index: size, freshness, top folders, type codes
--    K 1101-1140  roles: ORA_ / _CUSTOM split, prefixes of non-ORA_ codes,
--                 custom roles by type flags (job / abstract / duty / data)
--    L 1201-1210  procurement approval rules by flag values
--    M 1301-1306  flexfield segments, lookup types, value sets
--    N 1401-1430  Subledger Accounting: Oracle's type code x created-by-user
--    P 1501-1520  Alerts Composer: ENABLED x DELETED_FLAG x created-by-user
--    Q 1601-1630  sandboxes: ADF_SB_SANDBOXES_B vs ADF_SB_SANDBOXES vs
--                 MDS_SANDBOXES
--  Pure SELECT. Nothing is written.
-- ============================================================================
WITH
-- ---- PARAMS / WINDOW / SCOPE: copied unchanged from F1 (shared block v3.1).
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
-- user accounts - copied from F3.2 / F5.1
user_accts AS (
    SELECT  UPPER(pu.username) AS uname
    FROM    per_users pu
    WHERE   pu.username IS NOT NULL
    GROUP   BY UPPER(pu.username)
),
-- ==== J BI catalog index =====================================================
bi_tot AS (
    SELECT COUNT(*)                AS n_rows,
           MAX(r.last_update_date) AS last_upd,
           MAX(r.creation_date)    AS last_created
    FROM   gl_frc_reports_b r
),
-- top two folder levels, lower-cased: /shared/custom, /shared/financials ...
bi_folders AS (
    SELECT TO_CHAR(LOWER(REGEXP_SUBSTR(r.report_path, '^/[^/]*/[^/]*'))) AS fld,
           COUNT(*)                                                     AS n
    FROM   gl_frc_reports_b r
    GROUP  BY TO_CHAR(LOWER(REGEXP_SUBSTR(r.report_path, '^/[^/]*/[^/]*')))
),
bi_folder_rows AS (
    SELECT f.fld, f.n, ROW_NUMBER() OVER (ORDER BY f.n DESC, f.fld) AS rn FROM bi_folders f
),
bi_types AS (
    SELECT TO_CHAR(r.report_type_code) AS type_code,
           COUNT(*)                    AS n,
           SUM(CASE WHEN LOWER(r.report_path) LIKE '/shared/custom/%'
                    THEN 1 ELSE 0 END) AS n_custom
    FROM   gl_frc_reports_b r
    GROUP  BY TO_CHAR(r.report_type_code)
),
bi_type_rows AS (
    SELECT t.type_code, t.n, t.n_custom,
           ROW_NUMBER() OVER (ORDER BY t.n DESC, t.type_code) AS rn
    FROM   bi_types t
),
-- ==== K roles ==================================================================
role_codes AS (
    SELECT r.role_common_name AS role_code
    FROM   per_roles_dn r
    WHERE  r.role_common_name IS NOT NULL
    GROUP  BY r.role_common_name
),
role_split AS (
    SELECT COUNT(*)                                                         AS n_all,
           NVL(SUM(CASE WHEN SUBSTR(rc.role_code, 1, 4) = 'ORA_'
                        THEN 1 ELSE 0 END), 0)                              AS n_ora,
           NVL(SUM(CASE WHEN SUBSTR(rc.role_code, 1, 4) = 'ORA_'
                         AND SUBSTR(rc.role_code, -7) = '_CUSTOM'
                        THEN 1 ELSE 0 END), 0)                              AS n_ora_custom,
           NVL(SUM(CASE WHEN SUBSTR(rc.role_code, 1, 4) <> 'ORA_'
                        THEN 1 ELSE 0 END), 0)                              AS n_non_ora
    FROM   role_codes rc
),
-- first word of the non-ORA_ codes: Oracle infrastructure roles (if any) show here
role_pfx AS (
    SELECT TO_CHAR(NVL(REGEXP_SUBSTR(rc.role_code, '^[^_]+'), '(none)')) AS pf,
           COUNT(*)                                                       AS n
    FROM   role_codes rc
    WHERE  SUBSTR(rc.role_code, 1, 4) <> 'ORA_'
    GROUP  BY TO_CHAR(NVL(REGEXP_SUBSTR(rc.role_code, '^[^_]+'), '(none)'))
),
role_pfx_rows AS (
    SELECT x.pf, x.n, ROW_NUMBER() OVER (ORDER BY x.n DESC, x.pf) AS rn FROM role_pfx x
),
-- custom roles (F5.1 row 30 rule) by the role-type flags PER_ROLES_DN carries
role_types AS (
    SELECT TO_CHAR('job=' || NVL(TO_CHAR(r.job_role), '-') || ' abstract=' || NVL(TO_CHAR(r.abstract_role), '-')
                   || ' duty=' || NVL(TO_CHAR(r.duty_role), '-') || ' data=' || NVL(TO_CHAR(r.data_role), '-')
                   || ' active=' || NVL(TO_CHAR(r.active_flag), '-'))  AS pattern,
           COUNT(*)                                            AS n
    FROM   per_roles_dn r
    WHERE  r.role_common_name IS NOT NULL
    AND    (   SUBSTR(r.role_common_name, 1, 4) <> 'ORA_'
            OR SUBSTR(r.role_common_name, -7)   = '_CUSTOM' )
    GROUP  BY TO_CHAR('job=' || NVL(TO_CHAR(r.job_role), '-') || ' abstract=' || NVL(TO_CHAR(r.abstract_role), '-')
                      || ' duty=' || NVL(TO_CHAR(r.duty_role), '-') || ' data=' || NVL(TO_CHAR(r.data_role), '-')
                      || ' active=' || NVL(TO_CHAR(r.active_flag), '-'))
),
role_type_rows AS (
    SELECT x.pattern, x.n, ROW_NUMBER() OVER (ORDER BY x.n DESC, x.pattern) AS rn
    FROM   role_types x
),
-- ==== L procurement approval rules ===========================================
amx_flags AS (
    SELECT TO_CHAR(NVL(ar.active_flag, '(null)'))  AS active_flag,
           TO_CHAR(NVL(ar.sandbox_flag, '(null)')) AS sandbox_flag,
           COUNT(*)                                AS n,
           SUM(CASE WHEN ua.uname IS NOT NULL THEN 1 ELSE 0 END) AS n_user
    FROM        por_amx_rules ar
    LEFT JOIN   user_accts    ua ON ua.uname = UPPER(ar.created_by)
    GROUP   BY  TO_CHAR(NVL(ar.active_flag, '(null)')), TO_CHAR(NVL(ar.sandbox_flag, '(null)'))
),
amx_rows AS (
    SELECT a.active_flag, a.sandbox_flag, a.n, a.n_user,
           ROW_NUMBER() OVER (ORDER BY a.n DESC, a.active_flag, a.sandbox_flag) AS rn
    FROM   amx_flags a
),
-- ==== M application extensions ===============================================
seg_keyed AS (
    SELECT  s.application_id,
            s.descriptive_flexfield_code,
            s.context_code,
            s.segment_code,
            MAX(s.enabled_flag)     AS enabled_flag,
            MAX(s.last_updated_by)  AS last_updated_by
    FROM    fnd_df_segments_b s
    WHERE   s.context_code <> 'Context Data Element'
    AND     s.descriptive_flexfield_code NOT LIKE '$SRS$.%'
    AND     UPPER(s.descriptive_flexfield_code) NOT LIKE '%INTERFACE%'
    GROUP   BY s.application_id, s.descriptive_flexfield_code,
               s.context_code, s.segment_code
),
seg_cnt AS (
    SELECT COUNT(*) AS n_custom
    FROM   seg_keyed  k
    JOIN   user_accts ua ON ua.uname = UPPER(k.last_updated_by)
    WHERE  k.enabled_flag = 'Y'
),
lkp_keyed AS (
    SELECT lt.lookup_type, lt.view_application_id,
           SUM(CASE WHEN ua.uname IS NULL THEN 1 ELSE 0 END) AS n_non_user_rows
    FROM        fnd_lookup_types lt
    LEFT JOIN   user_accts       ua ON ua.uname = UPPER(lt.created_by)
    GROUP   BY  lt.lookup_type, lt.view_application_id
),
lkp_cnt AS (
    SELECT COUNT(*)                                                    AS n_all,
           NVL(SUM(CASE WHEN k.n_non_user_rows = 0 THEN 1 ELSE 0 END), 0) AS n_custom
    FROM   lkp_keyed k
),
vs_keyed AS (
    SELECT vs.value_set_code,
           SUM(CASE WHEN ua.uname IS NULL THEN 1 ELSE 0 END)            AS n_non_user_rows,
           SUM(CASE WHEN vs.seed_data_source IS NOT NULL THEN 1 ELSE 0 END) AS n_seed_src
    FROM        fnd_vs_value_sets vs
    LEFT JOIN   user_accts        ua ON ua.uname = UPPER(vs.created_by)
    GROUP   BY  vs.value_set_code
),
vs_cnt AS (
    SELECT COUNT(*)                                                    AS n_all,
           NVL(SUM(CASE WHEN k.n_non_user_rows = 0 THEN 1 ELSE 0 END), 0) AS n_custom,
           NVL(SUM(CASE WHEN k.n_non_user_rows = 0 AND k.n_seed_src > 0
                        THEN 1 ELSE 0 END), 0)                          AS n_custom_seeded
    FROM   vs_keyed k
),
-- ==== N Subledger Accounting: Oracle's type code x created-by-user ==========
am_keyed AS (
    SELECT am.accounting_method_type_code, am.accounting_method_code,
           SUM(CASE WHEN ua.uname IS NULL THEN 1 ELSE 0 END) AS n_non_user_rows
    FROM        xla_acctg_methods_b am
    LEFT JOIN   user_accts          ua ON ua.uname = UPPER(am.created_by)
    GROUP   BY  am.accounting_method_type_code, am.accounting_method_code
),
am_types AS (
    SELECT TO_CHAR(NVL(k.accounting_method_type_code, '(null)'))       AS type_code,
           COUNT(*)                                                    AS n,
           NVL(SUM(CASE WHEN k.n_non_user_rows = 0 THEN 1 ELSE 0 END), 0) AS n_user
    FROM   am_keyed k
    GROUP  BY TO_CHAR(NVL(k.accounting_method_type_code, '(null)'))
),
am_type_rows AS (
    SELECT t.type_code, t.n, t.n_user,
           ROW_NUMBER() OVER (ORDER BY t.type_code) AS rn
    FROM   am_types t
),
aad_keyed AS (
    SELECT pr.application_id, pr.product_rule_type_code, pr.product_rule_code,
           SUM(CASE WHEN ua.uname IS NULL THEN 1 ELSE 0 END) AS n_non_user_rows
    FROM        xla_product_rules_b pr
    LEFT JOIN   user_accts          ua ON ua.uname = UPPER(pr.created_by)
    GROUP   BY  pr.application_id, pr.product_rule_type_code, pr.product_rule_code
),
aad_types AS (
    SELECT TO_CHAR(NVL(k.product_rule_type_code, '(null)'))            AS type_code,
           COUNT(*)                                                    AS n,
           NVL(SUM(CASE WHEN k.n_non_user_rows = 0 THEN 1 ELSE 0 END), 0) AS n_user
    FROM   aad_keyed k
    GROUP  BY TO_CHAR(NVL(k.product_rule_type_code, '(null)'))
),
aad_type_rows AS (
    SELECT t.type_code, t.n, t.n_user,
           ROW_NUMBER() OVER (ORDER BY t.type_code) AS rn
    FROM   aad_types t
),
-- ==== P Alerts Composer =======================================================
alert_flags AS (
    SELECT NVL(TO_CHAR(al.enabled), '(null)')      AS enabled_val,
           NVL(TO_CHAR(al.deleted_flag), '(null)') AS deleted_val,
           CASE WHEN ua.uname IS NOT NULL THEN 'user' ELSE 'non-user' END AS creator,
           COUNT(*)                                AS n,
           SUM(CASE WHEN al.seed_data_source IS NOT NULL THEN 1 ELSE 0 END) AS n_seed_src
    FROM        hrc_alerts_b al
    LEFT JOIN   user_accts   ua ON ua.uname = UPPER(al.created_by)
    GROUP   BY  NVL(TO_CHAR(al.enabled), '(null)'), NVL(TO_CHAR(al.deleted_flag), '(null)'),
                CASE WHEN ua.uname IS NOT NULL THEN 'user' ELSE 'non-user' END
),
alert_flag_rows AS (
    SELECT f.enabled_val, f.deleted_val, f.creator, f.n, f.n_seed_src,
           ROW_NUMBER() OVER (ORDER BY f.n DESC, f.enabled_val, f.deleted_val, f.creator) AS rn
    FROM   alert_flags f
),
alert_chk AS (
    SELECT NVL(SUM(f.n), 0)                                                      AS n_all,
           NVL(SUM(CASE WHEN f.enabled_val = 'Y' THEN f.n END), 0)               AS n_enabled_y,
           NVL(SUM(CASE WHEN f.enabled_val = 'Y' AND f.deleted_val <> 'Y'
                         AND f.creator = 'user' THEN f.n END), 0)                AS n_row70,
           NVL(SUM(CASE WHEN f.creator = 'user' THEN f.n_seed_src END), 0)       AS n_user_seeded
    FROM   alert_flags f
),
alert_types AS (
    SELECT NVL(TO_CHAR(al.alert_type), '(null)') AS alert_type, COUNT(*) AS n
    FROM   hrc_alerts_b al
    JOIN   user_accts   ua ON ua.uname = UPPER(al.created_by)
    GROUP  BY NVL(TO_CHAR(al.alert_type), '(null)')
),
alert_type_rows AS (
    SELECT x.alert_type, x.n, ROW_NUMBER() OVER (ORDER BY x.n DESC, x.alert_type) AS rn
    FROM   alert_types x
),
-- ==== Q sandboxes: three candidate tables ===================================
sb_b AS (
    SELECT COUNT(*)                                                       AS n_all,
           NVL(SUM(CASE WHEN sb.published_on IS NOT NULL THEN 1 ELSE 0 END), 0) AS n_published,
           MAX(sb.published_on)                                           AS last_published
    FROM   adf_sb_sandboxes_b sb
),
sb_b_status AS (
    SELECT NVL(TO_CHAR(sb.sandbox_status), '(null)') AS status_val,
           COUNT(*)                                  AS n,
           SUM(CASE WHEN sb.published_on IS NOT NULL THEN 1 ELSE 0 END) AS n_published
    FROM   adf_sb_sandboxes_b sb
    GROUP  BY NVL(TO_CHAR(sb.sandbox_status), '(null)')
),
sb_b_status_rows AS (
    SELECT x.status_val, x.n, x.n_published,
           ROW_NUMBER() OVER (ORDER BY x.n DESC, x.status_val) AS rn
    FROM   sb_b_status x
),
sb_old AS (
    SELECT COUNT(*)                                                         AS n_all,
           NVL(SUM(CASE WHEN so.publish_date IS NOT NULL THEN 1 ELSE 0 END), 0) AS n_published
    FROM   adf_sb_sandboxes so
),
sb_old_flags AS (
    SELECT NVL(TO_CHAR(so.publish_flag), '(null)')  AS publish_flag,
           NVL(TO_CHAR(so.sandbox_state), '(null)') AS state_val,
           COUNT(*)                                 AS n
    FROM   adf_sb_sandboxes so
    GROUP  BY NVL(TO_CHAR(so.publish_flag), '(null)'), NVL(TO_CHAR(so.sandbox_state), '(null)')
),
sb_old_flag_rows AS (
    SELECT x.publish_flag, x.state_val, x.n,
           ROW_NUMBER() OVER (ORDER BY x.n DESC, x.publish_flag, x.state_val) AS rn
    FROM   sb_old_flags x
),
sb_mds AS (
    SELECT COUNT(*)              AS n_all,
           MAX(ms.sb_created_on) AS last_created
    FROM   mds_sandboxes ms
),
grid AS (
    -- J ------------------------------------------------------------------------
    SELECT 1001                                        AS ord,
           CAST('J BI catalog index' AS VARCHAR2(400)) AS section,
           CAST('J1 rows in GL_FRC_REPORTS_B' AS VARCHAR2(400)) AS item,
           CAST(TO_CHAR(bt.n_rows) AS VARCHAR2(4000))  AS value_text
    FROM   bi_tot bt
    UNION ALL
    SELECT 1002, TO_CHAR('J BI catalog index'),
           TO_CHAR('J2 latest row created / updated (how current the index is)'),
           TO_CHAR(NVL(TO_CHAR(bt.last_created, 'YYYY-MM-DD'), '-') || ' / '
                   || NVL(TO_CHAR(bt.last_upd, 'YYYY-MM-DD'), '-'))
    FROM   bi_tot bt
    UNION ALL
    SELECT 1010 + bf.rn, TO_CHAR('J BI catalog folders'), TO_CHAR('J ' || NVL(bf.fld, '(no path)')),
           TO_CHAR(bf.n || ' items')
    FROM   bi_folder_rows bf
    WHERE  bf.rn <= 10
    UNION ALL
    SELECT 1020 + bty.rn, TO_CHAR('J BI catalog types'), TO_CHAR('J type ' || NVL(bty.type_code, '(null)')),
           TO_CHAR(bty.n || ' items, ' || bty.n_custom || ' under /shared/Custom/')
    FROM   bi_type_rows bty
    WHERE  bty.rn <= 10
    -- K ------------------------------------------------------------------------
    UNION ALL
    SELECT 1101, TO_CHAR('K roles'), TO_CHAR('K1 role codes in PER_ROLES_DN'),
           TO_CHAR(rs.n_all)
    FROM   role_split rs
    UNION ALL
    SELECT 1102, TO_CHAR('K roles'), TO_CHAR('K2 starting ORA_ (predefined)'),
           TO_CHAR(rs.n_ora)
    FROM   role_split rs
    UNION ALL
    SELECT 1103, TO_CHAR('K roles'), TO_CHAR('K3 starting ORA_ and ending _CUSTOM (copies)'),
           TO_CHAR(rs.n_ora_custom)
    FROM   role_split rs
    UNION ALL
    SELECT 1104, TO_CHAR('K roles'), TO_CHAR('K4 not starting ORA_'),
           TO_CHAR(rs.n_non_ora)
    FROM   role_split rs
    UNION ALL
    SELECT 1105, TO_CHAR('K roles'), TO_CHAR('K5 custom roles = K3 + K4 = F5.1 row 30'),
           TO_CHAR(rs.n_ora_custom + rs.n_non_ora)
    FROM   role_split rs
    UNION ALL
    SELECT 1110 + rp.rn, TO_CHAR('K non-ORA_ role code prefixes'), TO_CHAR('K ' || rp.pf || '_*'),
           TO_CHAR(rp.n || ' roles (an Oracle infrastructure prefix here must be excluded)')
    FROM   role_pfx_rows rp
    WHERE  rp.rn <= 10
    -- L ------------------------------------------------------------------------
    UNION ALL
    SELECT 1200 + axr.rn, TO_CHAR('L approval rules'),
           TO_CHAR('L ACTIVE_FLAG=' || axr.active_flag || ' SANDBOX_FLAG=' || axr.sandbox_flag),
           TO_CHAR(axr.n || ' rules, ' || axr.n_user || ' created by a user account')
    FROM   amx_rows axr
    WHERE  axr.rn <= 10
    -- M ------------------------------------------------------------------------
    UNION ALL
    SELECT 1301, TO_CHAR('M application extensions'),
           TO_CHAR('M1 DFF segments counted = F5.1 row 50 = SUM(F3.2 Enabled Segments)'),
           TO_CHAR(sg.n_custom)
    FROM   seg_cnt sg
    UNION ALL
    SELECT 1302, TO_CHAR('M application extensions'), TO_CHAR('M2 lookup types (all)'),
           TO_CHAR(lk.n_all)
    FROM   lkp_cnt lk
    UNION ALL
    SELECT 1303, TO_CHAR('M application extensions'),
           TO_CHAR('M3 lookup types created by a user account = F5.1 row 51'),
           TO_CHAR(lk.n_custom)
    FROM   lkp_cnt lk
    UNION ALL
    SELECT 1304, TO_CHAR('M application extensions'), TO_CHAR('M4 value sets (all codes)'),
           TO_CHAR(vc.n_all)
    FROM   vs_cnt vc
    UNION ALL
    SELECT 1305, TO_CHAR('M application extensions'),
           TO_CHAR('M5 value sets created by a user account = F5.1 row 52'),
           TO_CHAR(vc.n_custom)
    FROM   vs_cnt vc
    UNION ALL
    SELECT 1306, TO_CHAR('M application extensions'),
           TO_CHAR('M6 verdict: of M5, value sets that carry a SEED_DATA_SOURCE'),
           TO_CHAR(CASE WHEN vc.n_custom_seeded = 0
                        THEN 'OK: 0 - the user-account rule agrees with Oracle''s seed marker'
                        ELSE 'CHECK: ' || vc.n_custom_seeded || ' user-created value sets are'
                             || ' marked as seed data - send this grid back'
                   END)
    FROM   vs_cnt vc
    -- N ------------------------------------------------------------------------
    UNION ALL
    SELECT 1400 + mt.rn, TO_CHAR('N accounting methods'),
           TO_CHAR('N ACCOUNTING_METHOD_TYPE_CODE=' || mt.type_code),
           TO_CHAR(mt.n || ' methods, ' || mt.n_user || ' created by a user account'
                   || ' (one type code should hold all the user rows)')
    FROM   am_type_rows mt
    WHERE  mt.rn <= 10
    UNION ALL
    SELECT 1420 + adt.rn, TO_CHAR('N accounting definitions'),
           TO_CHAR('N PRODUCT_RULE_TYPE_CODE=' || adt.type_code),
           TO_CHAR(adt.n || ' AADs, ' || adt.n_user || ' created by a user account'
                   || ' (one type code should hold all the user rows)')
    FROM   aad_type_rows adt
    WHERE  adt.rn <= 10
    -- K (role types) ---------------------------------------------------------
    UNION ALL
    SELECT 1130 + rtr.rn, TO_CHAR('K custom roles by type flags'), TO_CHAR('K ' || rtr.pattern),
           TO_CHAR(rtr.n || ' custom roles')
    FROM   role_type_rows rtr
    WHERE  rtr.rn <= 10
    -- P ------------------------------------------------------------------------
    UNION ALL
    SELECT 1501, TO_CHAR('P Alerts Composer'), TO_CHAR('P1 alerts in HRC_ALERTS_B'),
           TO_CHAR(ac.n_all)
    FROM   alert_chk ac
    UNION ALL
    SELECT 1502, TO_CHAR('P Alerts Composer'), TO_CHAR('P2 verdict: ENABLED holds the value Y'),
           TO_CHAR(CASE WHEN ac.n_enabled_y > 0 OR ac.n_all = 0
                        THEN 'OK: ' || ac.n_enabled_y || ' alerts have ENABLED = Y'
                        ELSE '*** no ENABLED = Y: F5.1 row 70 would read 0. See P rows'
                             || ' below and send this grid back. ***'
                   END)
    FROM   alert_chk ac
    UNION ALL
    SELECT 1503, TO_CHAR('P Alerts Composer'),
           TO_CHAR('P3 enabled, not deleted, created by a user account = F5.1 row 70'),
           TO_CHAR(ac.n_row70)
    FROM   alert_chk ac
    UNION ALL
    SELECT 1504, TO_CHAR('P Alerts Composer'),
           TO_CHAR('P4 verdict: user-created alerts that carry a SEED_DATA_SOURCE'),
           TO_CHAR(CASE WHEN ac.n_user_seeded = 0
                        THEN 'OK: 0 - the user-account rule agrees with Oracle''s seed marker'
                        ELSE 'CHECK: ' || ac.n_user_seeded || ' user-created alerts are marked'
                             || ' as seed data - send this grid back'
                   END)
    FROM   alert_chk ac
    UNION ALL
    SELECT 1504 + afr.rn, TO_CHAR('P Alerts Composer flags'),
           TO_CHAR('P ENABLED=' || afr.enabled_val || ' DELETED_FLAG=' || afr.deleted_val
                   || ' creator=' || afr.creator),
           TO_CHAR(afr.n || ' alerts, ' || afr.n_seed_src || ' with SEED_DATA_SOURCE')
    FROM   alert_flag_rows afr
    WHERE  afr.rn <= 10
    UNION ALL
    SELECT 1515 + atr.rn, TO_CHAR('P Alerts Composer types (user-created)'),
           TO_CHAR('P ALERT_TYPE=' || atr.alert_type),
           TO_CHAR(atr.n || ' alerts')
    FROM   alert_type_rows atr
    WHERE  atr.rn <= 5
    -- Q ------------------------------------------------------------------------
    UNION ALL
    SELECT 1601, TO_CHAR('Q sandboxes'),
           TO_CHAR('Q1 ADF_SB_SANDBOXES_B: all / published (PUBLISHED_ON set) = F5.1 row 80'),
           TO_CHAR(sbb.n_all || ' / ' || sbb.n_published || ', last published '
                   || NVL(TO_CHAR(sbb.last_published, 'YYYY-MM-DD'), '-'))
    FROM   sb_b sbb
    UNION ALL
    SELECT 1602, TO_CHAR('Q sandboxes'),
           TO_CHAR('Q2 ADF_SB_SANDBOXES: all / published (PUBLISH_DATE set)'),
           TO_CHAR(sbo.n_all || ' / ' || sbo.n_published)
    FROM   sb_old sbo
    UNION ALL
    SELECT 1603, TO_CHAR('Q sandboxes'), TO_CHAR('Q3 MDS_SANDBOXES: all, last created'),
           TO_CHAR(sbm.n_all || ', last created '
                   || NVL(TO_CHAR(sbm.last_created, 'YYYY-MM-DD'), '-'))
    FROM   sb_mds sbm
    UNION ALL
    SELECT 1603 + ssr.rn, TO_CHAR('Q ADF_SB_SANDBOXES_B status'),
           TO_CHAR('Q SANDBOX_STATUS=' || ssr.status_val),
           TO_CHAR(ssr.n || ' sandboxes, ' || ssr.n_published || ' with PUBLISHED_ON')
    FROM   sb_b_status_rows ssr
    WHERE  ssr.rn <= 10
    UNION ALL
    SELECT 1615 + sor.rn, TO_CHAR('Q ADF_SB_SANDBOXES flags'),
           TO_CHAR('Q PUBLISH_FLAG=' || sor.publish_flag || ' SANDBOX_STATE=' || sor.state_val),
           TO_CHAR(sor.n || ' sandboxes')
    FROM   sb_old_flag_rows sor
    WHERE  sor.rn <= 10
)
SELECT  g.ord         AS ord,
        g.section     AS section,
        g.item        AS item,
        g.value_text  AS value_text
FROM    grid g
ORDER BY g.ord
