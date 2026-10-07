-- ============================================================================
--  V10_2b  READ TEST - can the report user read the database NLS settings?
--  Version   : 1.0 (2026-10-07)        Run log: 06_Run_Results/RUN_LOG.md
--  Source    : Oracle Fusion Cloud (BIP data model, data source ApplicationDB_FSCM)
--  For: F10.2 row 8 (Database Character Set) and row 9 (NLS Language)
--
--  WHY: EBS reads NLS_DATABASE_PARAMETERS. Oracle grants it to PUBLIC by
--  default, but Fusion SaaS may not. Only a read settles it.
--
--  RESULT
--    an error (ORA-00942 / ORA-01031) -> not readable. Send the error. F10.2
--        v1.1 then takes the character set from SYS_CONTEXT('USERENV',
--        'LANGUAGE') (printed by V10_1 B3), and row 9 says not readable.
--    rows -> readable (about 20 parameters). Expected on a Fusion pod:
--        NLS_CHARACTERSET AL32UTF8.
--  No binds. Pure SELECT. Nothing is written.
-- ============================================================================
SELECT  p.parameter  AS parameter_name,
        p.value      AS parameter_value
FROM    nls_database_parameters p
ORDER BY p.parameter
