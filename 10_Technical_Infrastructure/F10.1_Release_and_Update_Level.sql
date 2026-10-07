-- ============================================================================
--  F10.1  Section 10.1 Fusion release and update level
--  Version   : 1.1 (2026-10-07). Not yet run on a pod.
--              v1.1 (2026-10-07): comment-only. No ampersand anywhere in the
--              text: BIP reads one, even inside a comment, as a lexical
--              parameter and asks for a value before running (R039).
--              Logic and output unchanged; v1.0 never ran.
--              RUN AFTER V10_0 and the read tests V10_2a (AD_PRODUCT_GROUPS),
--              V10_2c (PRODUCT_COMPONENT_VERSION) and V10_2d
--              (DBMS_UTILITY.PORT_STRING). One object the report user cannot
--              read fails the whole data set: if a read test fails, send its
--              error first (v1.1 then replaces that source with a fixed text).
--              Log every run in 06_Run_Results/RUN_LOG.md.
--  Source    : Oracle Fusion Cloud (BIP data model, data source ApplicationDB_FSCM)
--  Mirrors   : EBS agent ebs_discover_tech_infrastructure (tools.py 5920-6155),
--              table 10.1 "EBS release and patch level" (report 30-Sep-2026,
--              Vision: 12.2.14 | C.16 | C.16 | 19c (19.24) | Linux x86 64-bit |
--              June 2025 (proxy) - EBS, not targets)
--  Window    : SNAPSHOT (as of the run day). The dates are accepted and ignored.
--  Scope     : pod-wide, as EBS is instance-wide. The binds are accepted for BIP
--              parity and do not change the result.
--  Reads     : AD_PRODUCT_GROUPS (not in Oracle's Fusion table docs; a 2022
--              Fusion blog reads RELEASE_NAME and LAST_UPDATE_DATE from it;
--              V10_2a proves it), PRODUCT_COMPONENT_VERSION (granted to PUBLIC
--              by default; V10_2c), DBMS_UTILITY.PORT_STRING (PUBLIC by default;
--              V10_2d), and the shared-block tables.
--
--  OUTPUT  Parameter | Value      (10 rows, the EBS rows in EBS order)
--    1 Fusion Release             EBS: "EBS Release", FND_PRODUCT_GROUPS
--                                 .RELEASE_NAME. Fusion: AD_PRODUCT_GROUPS
--                                 .RELEASE_NAME (the latest row).
--    2 AD Patch Level             EBS: AD_TRACKABLE_ENTITIES (ad). No AD
--                                 utilities in Fusion SaaS: fixed text.
--    3 TXK Codelevel              EBS: AD_TRACKABLE_ENTITIES (txk). Fixed text.
--    4 Technology Stack           fixed text, as EBS (not in SQL)
--    5 Database Version           PRODUCT_COMPONENT_VERSION: the product name
--                                 as stored plus the first two parts of
--                                 VERSION_FULL, as EBS prints "19c (19.24)"
--    6 Application Tier OS        fixed text, as EBS
--    7 Database Tier OS           EBS: V$DATABASE.PLATFORM_NAME (a catalog
--                                 privilege; V10_2f). Fusion: the database port
--                                 string, platform family only, as EBS claims
--                                 no exact distribution.
--    8 Outstanding Critical Patches
--                                 fixed text, as EBS
--    9 Last Full Patching Cycle   EBS: latest AD_ADOP_SESSION_PATCHES.END_DATE,
--                                 a proxy. Fusion: the month AD_PRODUCT_GROUPS
--                                 was last updated, a proxy (check it against
--                                 the quarterly update calendar: C85).
--   10 Recommended Pre-Migration Update
--                                 EBS: "Recommended Fusion Pre-Migration Patch".
--                                 Fixed text (user, 2026-10-06): release parity.
--                                 Oracle requires the source and target to be on
--                                 the same release with the same standard and
--                                 one-off patches for Configuration Set
--                                 Migration, and on the same revision for setup
--                                 data export / import.
--    "Oracle-managed (SaaS)" means Oracle runs that tier and the customer
--    cannot see it. A source that returns no rows to the report user gives a
--    blank, never 0.
--  Manual cross-check of row 1: Settings and Actions > About This Application.
-- ============================================================================
WITH
-- ---- PARAMS / WINDOW / SCOPE: copied unchanged from F1 (shared block v3.1).
--      Section 10 is pod-wide and reads none of it; it is kept for parity with
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
-- ---- F10.1 sources -----------------------------------------------------------------
-- s10_rel: the Fusion release record. EBS reads FND_PRODUCT_GROUPS.RELEASE_NAME;
-- Fusion keeps it in AD_PRODUCT_GROUPS (V10_2a prints every filled column). If
-- there is more than one row, the most recently updated one wins.
s10_rel AS (
    SELECT COUNT(*)                                                        AS n_rows,
           MAX(TO_CHAR(g.release_name)) KEEP (DENSE_RANK LAST ORDER BY
               g.last_update_date NULLS FIRST)                             AS release_name,
           MAX(g.last_update_date)                                         AS last_update
    FROM   ad_product_groups g
),
-- s10_dbv: the database version. EBS tries V$INSTANCE first (a catalog
-- privilege) and falls back to PRODUCT_COMPONENT_VERSION, which is granted to
-- PUBLIC and carries the same numbers. PRODUCT already holds the marketing
-- name with its letter (e.g. "Oracle Database 19c Enterprise Edition"), so no
-- letter is derived; VERSION_FULL (18c and later) holds the release update.
s10_dbv AS (
    SELECT COUNT(*)                                                        AS n_rows,
           MAX(TRIM(TO_CHAR(v.product)))                                   AS product,
           MAX(TO_CHAR(v.version))                                         AS version,
           MAX(TO_CHAR(v.version_full))                                    AS version_full
    FROM   product_component_version v
    WHERE  UPPER(v.product) LIKE 'ORACLE DATABASE%'
),
-- s10_port: the database tier's platform family. DBMS_UTILITY.PORT_STRING is
-- granted to PUBLIC and names the operating system of the database port
-- (e.g. x86_64/Linux); like EBS, no exact distribution is claimed.
s10_port AS (
    SELECT TO_CHAR(dbms_utility.port_string)                               AS port_string
    FROM   dual
),
grid AS (
    SELECT 1                                                        AS seq,
           CAST('Fusion Release' AS VARCHAR2(100))                  AS param_name,
           CAST(CASE WHEN r.n_rows > 0 AND r.release_name IS NOT NULL
                     THEN 'Oracle Fusion Cloud Applications ' || r.release_name
                     WHEN r.n_rows > 0
                     THEN 'Release not recorded; see Settings and Actions > About This'
                          || ' Application'
                END AS VARCHAR2(4000))                              AS param_value
    FROM   s10_rel r
    UNION ALL
    SELECT 2, TO_CHAR('AD Patch Level'),
           TO_CHAR('Not applicable in Fusion SaaS: Oracle applies the quarterly updates and'
                   || ' maintenance patches; there is no customer-run AD patching')
    FROM   dual
    UNION ALL
    SELECT 3, TO_CHAR('TXK Codelevel'),
           TO_CHAR('Not applicable in Fusion SaaS: Oracle manages the technology stack;'
                   || ' there is no TXK code level')
    FROM   dual
    UNION ALL
    SELECT 4, TO_CHAR('Technology Stack'),
           TO_CHAR('Oracle-managed (SaaS): not visible to customers')
    FROM   dual
    UNION ALL
    SELECT 5, TO_CHAR('Database Version'),
           TO_CHAR(CASE WHEN d.n_rows > 0
                        THEN d.product || ' ('
                             || NVL(REGEXP_SUBSTR(NVL(d.version_full, d.version),
                                                  '^[0-9]+\.[0-9]+'),
                                    NVL(d.version_full, d.version))
                             || ')'
                   END)
    FROM   s10_dbv d
    UNION ALL
    SELECT 6, TO_CHAR('Application Tier OS'),
           TO_CHAR('Oracle-managed (SaaS): not visible to customers')
    FROM   dual
    UNION ALL
    SELECT 7, TO_CHAR('Database Tier OS'),
           TO_CHAR(CASE WHEN p.port_string IS NOT NULL
                        THEN p.port_string || ' (database port string: platform family'
                             || ' only; the exact operating system version is not'
                             || ' available from SQL)'
                   END)
    FROM   s10_port p
    UNION ALL
    SELECT 8, TO_CHAR('Outstanding Critical Patches'),
           TO_CHAR('Oracle-managed (SaaS): Oracle applies critical patches; not'
                   || ' determinable from SQL')
    FROM   dual
    UNION ALL
    SELECT 9, TO_CHAR('Last Full Patching Cycle'),
           TO_CHAR(CASE WHEN r.last_update IS NOT NULL
                        THEN TO_CHAR(r.last_update, 'fmMonth YYYY')
                             || ' (release record last updated - proxy)'
                        WHEN r.n_rows > 0
                        THEN 'Patching history not available from SQL'
                   END)
    FROM   s10_rel r
    UNION ALL
    SELECT 10, TO_CHAR('Recommended Pre-Migration Update'),
           TO_CHAR('Bring the source and target pods to the same quarterly update and'
                   || ' patch level before migrating setup, configurations or data')
    FROM   dual
)
SELECT
    g.param_name                                              AS "Parameter",
    g.param_value                                             AS "Value"
FROM        grid g
ORDER BY    g.seq
