-- ============================================================================
--  V10_2f  READ TEST - can the report user read the database catalog views the
--          EBS rows use? (expected: no, Oracle runs the database in SaaS)
--  Version   : 1.0 (2026-10-07)        Run log: 06_Run_Results/RUN_LOG.md
--  Source    : Oracle Fusion Cloud (BIP data model, data source ApplicationDB_FSCM)
--  For: the rows F10.1 / F10.2 v1.0 fill with "Oracle-managed (SaaS)":
--       F10.2 rows 1 / 2 (DBA_DATA_FILES, DBA_TEMP_FILES, DBA_SEGMENTS),
--       4 (V$PARAMETER, GV$INSTANCE), 5 (V$DATABASE, V$DATAGUARD_CONFIG),
--       6 (DBA_FEATURE_USAGE_STATISTICS; V$OPTION is V10_2e), 7
--       (DBA_TABLESPACES), 10 (V$RMAN_BACKUP_JOB_DETAILS) and the EBS source
--       of F10.1 row 7 (V$DATABASE.PLATFORM_NAME).
--
--  WHY ONE QUERY FOR ALL TEN: they all need the same catalog privilege
--  (SELECT_CATALOG_ROLE or similar), which the Fusion report user is not
--  expected to hold. Each view is read once, ROWNUM <= 1 where it can be
--  large, so the test stays light.
--
--  RESULT
--    an error (ORA-00942 / ORA-01031) -> at least one is not readable. Send
--        the error. With V10_0 (its candidate block lists a SYS view only if
--        the report user can read it) this proves the fixed texts. If V10_0
--        lists any of these views as readable, that view gets its own test.
--    one row -> all ten are readable. Send the row: F10.1 / F10.2 v1.1 then
--        measure those rows as EBS does.
--  No binds. Pure SELECT. Nothing is written.
-- ============================================================================
WITH
t_database AS (
    SELECT TO_CHAR(d.platform_name)                    AS platform_name,
           TO_CHAR(d.database_role)                    AS database_role
    FROM   v$database d
),
t_parameter AS (
    SELECT MAX(UPPER(TO_CHAR(p.value)))                AS cluster_database
    FROM   v$parameter p
    WHERE  p.name = 'cluster_database'
),
t_nodes AS (
    SELECT COUNT(*)                                    AS node_count
    FROM   gv$instance i
),
t_dataguard AS (
    SELECT COUNT(*)                                    AS n
    FROM   v$dataguard_config c
    WHERE  ROWNUM <= 1
),
t_rman AS (
    SELECT COUNT(*)                                    AS n
    FROM   v$rman_backup_job_details b
    WHERE  ROWNUM <= 1
),
t_data_files AS (
    SELECT COUNT(*)                                    AS n
    FROM   dba_data_files f
    WHERE  ROWNUM <= 1
),
t_temp_files AS (
    SELECT COUNT(*)                                    AS n
    FROM   dba_temp_files f
    WHERE  ROWNUM <= 1
),
t_segments AS (
    SELECT COUNT(*)                                    AS n
    FROM   dba_segments s
    WHERE  ROWNUM <= 1
),
t_tablespaces AS (
    SELECT COUNT(*)                                    AS n
    FROM   dba_tablespaces s
    WHERE  ROWNUM <= 1
),
t_features AS (
    SELECT COUNT(*)                                    AS n
    FROM   dba_feature_usage_statistics u
    WHERE  ROWNUM <= 1
)
SELECT  d.platform_name                                AS platform_name,
        d.database_role                                AS database_role,
        p.cluster_database                             AS cluster_database,
        nd.node_count                                  AS node_count,
        dg.n                                           AS dataguard_rows,
        rm.n                                           AS rman_rows,
        df.n                                           AS data_file_rows,
        tf.n                                           AS temp_file_rows,
        sg.n                                           AS segment_rows,
        tb.n                                           AS tablespace_rows,
        fu.n                                           AS feature_rows
FROM        t_database    d
CROSS JOIN  t_parameter   p
CROSS JOIN  t_nodes       nd
CROSS JOIN  t_dataguard   dg
CROSS JOIN  t_rman        rm
CROSS JOIN  t_data_files  df
CROSS JOIN  t_temp_files  tf
CROSS JOIN  t_segments    sg
CROSS JOIN  t_tablespaces tb
CROSS JOIN  t_features    fu
