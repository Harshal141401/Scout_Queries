-- ============================================================================
--  V9_1  CODE VALUES - every value the Section 9 rules use (run first)
--  Version   : 1.2 (2026-10-06)        Run log: 06_Run_Results/RUN_LOG.md
--              v1.2: carries the Section 9 block v1.1 (byte-identical with
--              F9.1 v1.1): Users counts login names. A0 prints accounts that
--              can sign in and login names side by side; the A5 verdict checks
--              that F9.1 counts each login name once. Notes quote R038.
--              Optional to run: R038 fixes every value (A0 290 / 115 / 251 /
--              114).
--              v1.1 ran as R038, v1.0 as R037.
--  For: F9.1
--  Binds: none used (the five standard binds are accepted for BIP parity).
--  Source    : Oracle Fusion Cloud (BIP data model, data source ApplicationDB_FSCM)
--  Window    : SNAPSHOT (as of the run day).
--  Reads     : PER_USERS, PER_ROLES_DN. Every column was printed on the pod by
--              R006 (V3_1) and R016 (V5_0), so no V9_0 column check is needed.
--
--  BLOCKS
--    A  user accounts: rows, accounts that can sign in, login names and the
--       F9.1 Users count (A0); every ACTIVE_FLAG x SUSPENDED x date state x
--       person combination with "counted Y/N" = can sign in (A1); accounts
--       that can sign in, with / without a person, HR-terminated (A2); user
--       names held by more than one account (A3); for those names, the
--       pattern of counted / deleted / suspended / person accounts and case
--       variants, a verdict that F9.1 counts each login name once, and every
--       login name held by 2+ accounts that can sign in (A5); accounts that
--       can sign in without a person, all listed with SUSPENDED, creator and
--       creation date (A4)
--    B  roles: rows vs keys and the F9.1 Roles count (B0); every ACTIVE_FLAG x
--       type flags x code class combination with "counted Y/N" (B1); counted
--       roles by code class (B2); roles with no type flag, listed (B3)
--  Expected (R038): A0 290 / 115 / 251 / 114; A2 57 / 58 / 0; A3 37 / 76;
--  A5 verdict 1 / 1 / 114 OK; A4 58 / 43 / 15; B0 511 / 511 / 511 / 511;
--  B2 440 / 22 / 49; B3 12 (all ORA_..._DISCRETIONARY).
--  Decide from the printed values, not from the Oracle doc: a column that
--  exists may never be written (R024 / R026).
--
--  OUTPUT  ord | section | item | value_text   (one grid, paste it back whole)
--  Pure SELECT. Nothing is written.
-- ============================================================================
WITH
-- ---- PARAMS / WINDOW / SCOPE: copied unchanged from F1 (shared block v3.1).
--      Section 9 is pod-wide and reads none of it; it is kept for parity with
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
-- ---- SECTION 9 BLOCK v1.1 (2026-10-06): user accounts and roles -------------
--      Byte-identical in F9.1 and V9_1, so the check prints exactly what the
--      report counts. Change both or none. Every column read here was printed
--      on the pod by the column checks R006 (V3_1) and R016 (V5_0).
-- s9_user: one row per PER_USERS row. EBS counts the FND_USER rows whose
-- start / end dates contain today. The Fusion equivalent of an account that
-- can sign in today:
--   ACTIVE_FLAG not 'N'  (Oracle doc: 'N' only when the account was deleted
--                         from the identity store)
--   SUSPENDED   not 'Y'  (a suspended account shows as Inactive in the
--                         Security Console and cannot sign in)
--   START_DATE / END_DATE contain today (blank = open, as EBS reads END_DATE)
-- Service and integration accounts (no PERSON_ID) count, as EBS counts
-- SYSADMIN and its other non-person users. Flags are read through
-- UPPER(TO_CHAR(..)) because the column check does not print their type.
s9_user AS (
    SELECT u.user_id,
           TO_CHAR(u.username)                                             AS user_name,
           NVL(UPPER(TO_CHAR(u.active_flag)), '-')                         AS active_flag,
           NVL(UPPER(TO_CHAR(u.suspended)), '-')                           AS suspended,
           NVL(UPPER(TO_CHAR(u.hr_terminated)), '-')                       AS hr_terminated,
           CASE WHEN u.person_id IS NULL THEN 'N' ELSE 'Y' END             AS has_person,
           CASE WHEN TRUNC(u.start_date) > TRUNC(SYSDATE) THEN 'future'
                WHEN TRUNC(u.end_date)   < TRUNC(SYSDATE) THEN 'ended'
                ELSE 'current'
           END                                                             AS date_state,
           CASE WHEN NVL(UPPER(TO_CHAR(u.active_flag)), 'Y') <> 'N'
                 AND NVL(UPPER(TO_CHAR(u.suspended)), 'N')   <> 'Y'
                 AND NVL(TRUNC(u.start_date), TRUNC(SYSDATE)) <= TRUNC(SYSDATE)
                 AND NVL(TRUNC(u.end_date),   TRUNC(SYSDATE)) >= TRUNC(SYSDATE)
                THEN 'Y' ELSE 'N'
           END                                                             AS counted
    FROM   per_users u
),
-- s9_user_key: one row per LOGIN NAME (block v1.1, after R038). USER_ID is
-- unique, but 37 user names are held by 76 accounts (R037 / R038): 34 are an
-- account re-created beside its deleted predecessor, and one Oracle
-- application identity is held by two accounts that can both sign in, which
-- v1.0 counted twice. A login name (USERNAME, compared upper-cased) counts
-- once if any of its accounts can sign in. EBS FND_USER.USER_NAME is unique,
-- so EBS's count is a count of login names too. A blank user name stays one
-- key per account.
s9_user_key AS (
    SELECT NVL(UPPER(su.user_name), '#' || TO_CHAR(su.user_id))           AS login_key,
           MAX(su.counted)                                                 AS counted
    FROM   s9_user su
    GROUP  BY NVL(UPPER(su.user_name), '#' || TO_CHAR(su.user_id))
),
s9_user_cnt AS (
    SELECT COUNT(*)                                                        AS n_keys,
           NVL(SUM(CASE WHEN k.counted = 'Y' THEN 1 ELSE 0 END), 0)        AS n_counted
    FROM   s9_user_key k
),
-- s9_role: one row per PER_ROLES_DN row. EBS counts every responsibility whose
-- dates contain today, seeded or custom. Fusion assigns roles instead of
-- responsibilities; PER_ROLES_DN carries no start / end date, so a role counts
-- unless ACTIVE_FLAG is 'N'. Every role type and both Oracle (ORA_) and client
-- roles count, as EBS counts seeded and custom responsibilities alike. The type
-- flags and the code class are carried for V9_1 only.
s9_role AS (
    SELECT r.role_id,
           TO_CHAR(r.role_common_name)                                     AS role_code,
           NVL(UPPER(TO_CHAR(r.active_flag)), '-')                         AS active_flag,
           NVL(UPPER(TO_CHAR(r.job_role)), '-')                            AS job_flag,
           NVL(UPPER(TO_CHAR(r.abstract_role)), '-')                       AS abstract_flag,
           NVL(UPPER(TO_CHAR(r.duty_role)), '-')                           AS duty_flag,
           NVL(UPPER(TO_CHAR(r.data_role)), '-')                           AS data_flag,
           NVL(UPPER(TO_CHAR(r.external_role)), '-')                       AS external_flag,
           CASE WHEN UPPER(TO_CHAR(r.role_common_name)) LIKE 'ORA\_%' ESCAPE '\'
                THEN 'ORA_'
                WHEN UPPER(TO_CHAR(r.role_common_name)) LIKE '%\_CUSTOM' ESCAPE '\'
                THEN '_CUSTOM'
                ELSE 'other'
           END                                                             AS code_class,
           CASE WHEN NVL(UPPER(TO_CHAR(r.active_flag)), 'Y') <> 'N'
                THEN 'Y' ELSE 'N'
           END                                                             AS counted
    FROM   per_roles_dn r
),
s9_role_key AS (
    SELECT sr.role_id, MAX(sr.counted) AS counted
    FROM   s9_role sr
    GROUP  BY sr.role_id
),
s9_role_cnt AS (
    SELECT COUNT(*)                                                        AS n_keys,
           NVL(SUM(CASE WHEN k.counted = 'Y' THEN 1 ELSE 0 END), 0)        AS n_counted
    FROM   s9_role_key k
),
-- ---- END OF SECTION 9 BLOCK ---------------------------------------------------
-- ---- A user accounts -----------------------------------------------------------
a_tot AS (
    SELECT COUNT(*)                                                        AS n_rows,
           NVL(SUM(CASE WHEN su.counted = 'Y' THEN 1 ELSE 0 END), 0)       AS n_rows_counted
    FROM   s9_user su
),
a_combo AS (
    SELECT su.active_flag, su.suspended, su.date_state, su.has_person, su.counted,
           COUNT(*)                                                        AS n
    FROM   s9_user su
    GROUP  BY su.active_flag, su.suspended, su.date_state, su.has_person, su.counted
),
a_combo_rows AS (
    SELECT c.active_flag, c.suspended, c.date_state, c.has_person, c.counted, c.n,
           ROW_NUMBER() OVER (ORDER BY c.counted DESC, c.n DESC, c.active_flag,
                                       c.suspended, c.date_state, c.has_person) AS rn
    FROM   a_combo c
),
a_split AS (
    SELECT NVL(SUM(CASE WHEN su.has_person = 'Y' THEN 1 ELSE 0 END), 0)    AS n_person,
           NVL(SUM(CASE WHEN su.has_person = 'N' THEN 1 ELSE 0 END), 0)    AS n_no_person,
           NVL(SUM(CASE WHEN su.hr_terminated = 'Y' THEN 1 ELSE 0 END), 0) AS n_hr_term
    FROM   s9_user su
    WHERE  su.counted = 'Y'
),
-- a_dup_grp: one row per user name (compared upper-cased) held by more than
-- one account, with what F9.1 makes of its accounts. name_min <> name_max
-- means the accounts differ only in letter case.
a_dup_grp AS (
    SELECT UPPER(su.user_name)                                             AS uname,
           COUNT(*)                                                        AS n_acc,
           NVL(SUM(CASE WHEN su.counted = 'Y' THEN 1 ELSE 0 END), 0)       AS n_counted,
           NVL(SUM(CASE WHEN su.active_flag = 'N' THEN 1 ELSE 0 END), 0)   AS n_deleted,
           NVL(SUM(CASE WHEN su.active_flag <> 'N' AND su.suspended = 'Y'
                        THEN 1 ELSE 0 END), 0)                             AS n_susp,
           NVL(SUM(CASE WHEN su.has_person = 'Y' THEN 1 ELSE 0 END), 0)    AS n_person,
           MIN(su.user_name)                                               AS name_min,
           MAX(su.user_name)                                               AS name_max
    FROM   s9_user su
    GROUP  BY UPPER(su.user_name)
    HAVING COUNT(*) > 1
),
a_dup AS (
    SELECT COUNT(*) AS n_names, NVL(SUM(g.n_acc), 0) AS n_accounts
    FROM   a_dup_grp g
),
a_dup_key AS (
    SELECT g.uname, g.n_acc,
           CAST('counted=' || CASE WHEN g.n_counted >= 2 THEN '2+'
                                   ELSE TO_CHAR(g.n_counted) END
                || ' deleted=' || g.n_deleted || ' suspended=' || g.n_susp
                || ' with-person=' || g.n_person
                || ' case-variants=' || CASE WHEN g.name_min <> g.name_max
                                             THEN 'Y' ELSE 'N' END
                || CASE WHEN g.uname IS NULL THEN ' (blank user name)' END
                AS VARCHAR2(400))                                          AS dup_pattern
    FROM   a_dup_grp g
),
a_dup_pat AS (
    SELECT k.dup_pattern, COUNT(*) AS n_names, NVL(SUM(k.n_acc), 0) AS n_accounts
    FROM   a_dup_key k
    GROUP  BY k.dup_pattern
),
a_dup_pat_rows AS (
    SELECT p.dup_pattern, p.n_names, p.n_accounts,
           ROW_NUMBER() OVER (ORDER BY p.n_names DESC, p.dup_pattern)          AS rn
    FROM   a_dup_pat p
),
a_dup_risk AS (
    SELECT COUNT(*)                                                        AS n_names_multi,
           NVL(SUM(g.n_counted - 1), 0)                                    AS n_extra
    FROM   a_dup_grp g
    WHERE  g.n_counted >= 2
),
a_dup_multi AS (
    SELECT g.name_min, g.n_acc, g.n_counted, g.n_person,
           ROW_NUMBER() OVER (ORDER BY g.uname)                            AS rn
    FROM   a_dup_grp g
    WHERE  g.n_counted >= 2
),
-- a_user_x: the PER_USERS columns printed here besides the block's (creator,
-- creation date), one row per USER_ID (R037 A0: USER_ID is unique)
a_user_x AS (
    SELECT u.user_id,
           TO_CHAR(u.created_by)                                           AS created_by,
           u.creation_date                                                 AS creation_date
    FROM   per_users u
),
a_noperson AS (
    SELECT su.user_name, su.suspended, x.created_by, x.creation_date,
           ROW_NUMBER() OVER (ORDER BY UPPER(su.user_name), su.user_id)    AS rn
    FROM   s9_user su
    LEFT   JOIN a_user_x x ON x.user_id = su.user_id
    WHERE  su.counted = 'Y'
    AND    su.has_person = 'N'
),
a_noperson_sum AS (
    SELECT COUNT(*)                                                        AS n_all,
           NVL(SUM(CASE WHEN np.suspended = '-' THEN 1 ELSE 0 END), 0)     AS n_susp_blank,
           NVL(SUM(CASE WHEN np.suspended <> '-' THEN 1 ELSE 0 END), 0)    AS n_susp_set
    FROM   a_noperson np
),
-- ---- B roles -------------------------------------------------------------------
b_tot AS (
    SELECT COUNT(*)                                                        AS n_rows
    FROM   s9_role sr
),
b_codes AS (
    SELECT COUNT(*) AS n_codes
    FROM   ( SELECT UPPER(sr.role_code) AS c FROM s9_role sr GROUP BY UPPER(sr.role_code) ) x
),
b_combo AS (
    SELECT sr.active_flag, sr.job_flag, sr.abstract_flag, sr.duty_flag, sr.data_flag,
           sr.external_flag, sr.code_class, sr.counted,
           COUNT(*)                                                        AS n
    FROM   s9_role sr
    GROUP  BY sr.active_flag, sr.job_flag, sr.abstract_flag, sr.duty_flag, sr.data_flag,
              sr.external_flag, sr.code_class, sr.counted
),
b_combo_rows AS (
    SELECT c.active_flag, c.job_flag, c.abstract_flag, c.duty_flag, c.data_flag,
           c.external_flag, c.code_class, c.counted, c.n,
           ROW_NUMBER() OVER (ORDER BY c.counted DESC, c.n DESC, c.code_class,
                                       c.active_flag, c.job_flag, c.abstract_flag,
                                       c.duty_flag, c.data_flag, c.external_flag) AS rn
    FROM   b_combo c
),
b_class AS (
    SELECT NVL(SUM(CASE WHEN sr.code_class = 'ORA_'    THEN 1 ELSE 0 END), 0) AS n_ora,
           NVL(SUM(CASE WHEN sr.code_class = '_CUSTOM' THEN 1 ELSE 0 END), 0) AS n_custom_copy,
           NVL(SUM(CASE WHEN sr.code_class = 'other'   THEN 1 ELSE 0 END), 0) AS n_other
    FROM   s9_role sr
    WHERE  sr.counted = 'Y'
),
-- b_untyped: roles with none of the job / abstract / duty / data flags set
b_untyped AS (
    SELECT sr.role_code, sr.active_flag, sr.counted,
           ROW_NUMBER() OVER (ORDER BY sr.role_code)                       AS rn
    FROM   s9_role sr
    WHERE  sr.job_flag      = '-'
    AND    sr.abstract_flag = '-'
    AND    sr.duty_flag     = '-'
    AND    sr.data_flag     = '-'
),
b_untyped_cnt AS (
    SELECT COUNT(*) AS n
    FROM   b_untyped ut
),
grid AS (
    -- A ------------------------------------------------------------------------
    SELECT 100                                                      AS ord,
           CAST('A user accounts' AS VARCHAR2(400))                 AS section,
           CAST('A0 summary (V9_1 v1.2, Section 9 block v1.1): PER_USERS rows / accounts'
                || ' that can sign in / login names / F9.1 Users (login names that can'
                || ' sign in)'
                AS VARCHAR2(400))                                   AS item,
           CAST(t.n_rows || ' / ' || t.n_rows_counted || ' / ' || k.n_keys || ' / '
                || CASE WHEN k.n_keys > 0 THEN TO_CHAR(k.n_counted)
                        ELSE 'blank (PER_USERS returns no rows)' END
                || ' (R038: 290 / 115 / 251 / 114)'
                AS VARCHAR2(4000))                                  AS value_text
    FROM   a_tot t
    CROSS  JOIN s9_user_cnt k
    UNION ALL
    SELECT 100 + a.rn, TO_CHAR('A user accounts'),
           TO_CHAR('A1 active_flag=' || a.active_flag || ' suspended=' || a.suspended
                   || ' dates=' || a.date_state || ' person=' || a.has_person),
           TO_CHAR(a.n || ' accounts | counted ' || a.counted)
    FROM   a_combo_rows a
    WHERE  a.rn <= 40
    UNION ALL
    SELECT 150, TO_CHAR('A user accounts'),
           TO_CHAR('A2 accounts that can sign in: with a person / without a person'
                   || ' (application identities, service, integration) / HR_TERMINATED = Y'),
           TO_CHAR(s.n_person || ' / ' || s.n_no_person || ' / ' || s.n_hr_term
                   || ' (R038: 57 / 58 / 0)')
    FROM   a_split s
    UNION ALL
    SELECT 160, TO_CHAR('A user accounts'),
           TO_CHAR('A3 user names held by more than one account: names / accounts'),
           TO_CHAR(d.n_names || ' / ' || d.n_accounts || ' (R037 / R038: 37 / 76)')
    FROM   a_dup d
    UNION ALL
    SELECT 160 + pr.rn, TO_CHAR('A user accounts'),
           TO_CHAR('A5 shared name pattern: ' || pr.dup_pattern),
           TO_CHAR(pr.n_names || ' names / ' || pr.n_accounts || ' accounts')
    FROM   a_dup_pat_rows pr
    WHERE  pr.rn <= 19
    UNION ALL
    SELECT 180, TO_CHAR('A user accounts'),
           TO_CHAR('A5 verdict: login names held by 2+ accounts that can sign in /'
                   || ' extra accounts / accounts that can sign in minus extra vs F9.1'
                   || ' Users'),
           TO_CHAR(r.n_names_multi || ' / ' || r.n_extra || ' / '
                   || (t.n_rows_counted - r.n_extra) || ' vs ' || k.n_counted
                   || CASE WHEN t.n_rows_counted - r.n_extra = k.n_counted
                           THEN ' - OK: F9.1 Users counts each login name once'
                           ELSE ' - CHECK: F9.1 Users and the name groups disagree'
                      END
                   || ' (R038: 1 / 1 / 114 vs 114)')
    FROM   a_dup_risk r
    CROSS  JOIN a_tot t
    CROSS  JOIN s9_user_cnt k
    UNION ALL
    SELECT 180 + m.rn, TO_CHAR('A user accounts'),
           TO_CHAR('A5 login name held by 2+ accounts that can sign in #' || m.rn),
           TO_CHAR(NVL(m.name_min, '(blank user name)') || ' | ' || m.n_counted
                   || ' counted of ' || m.n_acc || ' accounts | with a person '
                   || m.n_person)
    FROM   a_dup_multi m
    WHERE  m.rn <= 19
    UNION ALL
    SELECT 200, TO_CHAR('A user accounts'),
           TO_CHAR('A4 accounts that can sign in without a person: all / SUSPENDED'
                   || ' blank / SUSPENDED set'),
           TO_CHAR(ns.n_all || ' / ' || ns.n_susp_blank || ' / ' || ns.n_susp_set
                   || ' (R038: 58 / 43 / 15)')
    FROM   a_noperson_sum ns
    UNION ALL
    SELECT 200 + np.rn, TO_CHAR('A user accounts'),
           TO_CHAR('A4 counted, no person #' || np.rn),
           TO_CHAR(np.user_name || ' | suspended ' || np.suspended || ' | created '
                   || NVL(TO_CHAR(np.creation_date, 'YYYY-MM-DD'), '-') || ' by '
                   || NVL(np.created_by, '-'))
    FROM   a_noperson np
    WHERE  np.rn <= 80
    -- B ------------------------------------------------------------------------
    UNION ALL
    SELECT 300, TO_CHAR('B roles'),
           TO_CHAR('B0 summary: PER_ROLES_DN rows / roles (ROLE_ID) / role codes / F9.1'
                   || ' Roles (counted roles)'),
           TO_CHAR(t.n_rows || ' / ' || k.n_keys || ' / ' || c.n_codes || ' / '
                   || CASE WHEN k.n_keys > 0 THEN TO_CHAR(k.n_counted)
                           ELSE 'blank (PER_ROLES_DN returns no rows)' END
                   || ' (R038: 511 / 511 / 511 / 511)')
    FROM   b_tot t
    CROSS  JOIN s9_role_cnt k
    CROSS  JOIN b_codes c
    UNION ALL
    SELECT 300 + b.rn, TO_CHAR('B roles'),
           TO_CHAR('B1 active_flag=' || b.active_flag || ' job=' || b.job_flag
                   || ' abstract=' || b.abstract_flag || ' duty=' || b.duty_flag
                   || ' data=' || b.data_flag || ' external=' || b.external_flag
                   || ' code=' || b.code_class),
           TO_CHAR(b.n || ' roles | counted ' || b.counted)
    FROM   b_combo_rows b
    WHERE  b.rn <= 40
    UNION ALL
    SELECT 350, TO_CHAR('B roles'),
           TO_CHAR('B2 counted roles by code: ORA_ (Oracle) / _CUSTOM (copies) / other'
                   || ' (client)'),
           TO_CHAR(c.n_ora || ' / ' || c.n_custom_copy || ' / ' || c.n_other
                   || ' (R038: 440 / 22 / 49)')
    FROM   b_class c
    UNION ALL
    SELECT 360, TO_CHAR('B roles'),
           TO_CHAR('B3 roles with no type flag (job / abstract / duty / data all blank)'),
           TO_CHAR(uc.n || ' (R038: 12, all ORA_..._DISCRETIONARY)')
    FROM   b_untyped_cnt uc
    UNION ALL
    SELECT 360 + ut.rn, TO_CHAR('B roles'),
           TO_CHAR('B3 no type flag #' || ut.rn),
           TO_CHAR(ut.role_code || ' | active ' || ut.active_flag || ' | counted '
                   || ut.counted)
    FROM   b_untyped ut
    WHERE  ut.rn <= 30
)
SELECT  g.ord         AS ord,
        g.section     AS section,
        g.item        AS item,
        g.value_text  AS value_text
FROM    grid g
ORDER BY g.ord