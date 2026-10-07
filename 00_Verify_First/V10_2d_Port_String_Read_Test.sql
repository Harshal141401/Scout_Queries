-- ============================================================================
--  V10_2d  READ TEST - can the report user call DBMS_UTILITY.PORT_STRING?
--  Version   : 1.0 (2026-10-07)        Run log: 06_Run_Results/RUN_LOG.md
--  Source    : Oracle Fusion Cloud (BIP data model, data source ApplicationDB_FSCM)
--  For: F10.1 row 7 (Database Tier OS)
--
--  WHY: EBS reads V$DATABASE.PLATFORM_NAME, which needs a catalog privilege
--  (V10_2f). DBMS_UTILITY is granted to PUBLIC by default, and PORT_STRING
--  "returns a string that identifies the operating system" of the database
--  port (Oracle 19c PL/SQL Packages reference), e.g. x86_64/Linux 2.4.xx. Like
--  EBS, the row claims the platform family only, not the exact distribution.
--
--  RESULT
--    an error (ORA-00904 / ORA-00942 / ORA-06550) -> not callable. Send the
--        error; F10.1 v1.1 then prints "Oracle-managed (SaaS)" in row 7.
--    one row -> callable. Send the value.
--  No binds. Pure SELECT (a function call). Nothing is written.
-- ============================================================================
SELECT  dbms_utility.port_string  AS port_string
FROM    dual
