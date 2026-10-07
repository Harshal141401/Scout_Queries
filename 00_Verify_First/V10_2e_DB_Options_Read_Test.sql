-- ============================================================================
--  V10_2e  READ TEST - can the report user read the installed database options?
--  Version   : 1.0 (2026-10-07)        Run log: 06_Run_Results/RUN_LOG.md
--  Source    : Oracle Fusion Cloud (BIP data model, data source ApplicationDB_FSCM)
--  For: F10.2 row 6 (Available DB options / detected pack usage)
--
--  WHY: EBS lists the options V$OPTION marks TRUE among Partitioning, Real
--  Application Clusters, Spatial, Advanced Analytics, Data Mining, OLAP,
--  Oracle Database Vault, Real Application Testing and Advanced Compression.
--  F10.2 v1.0 prints "Oracle-managed (SaaS)" in row 6. If V$OPTION is
--  readable, v1.1 lists the options as EBS does (the pack-usage half needs
--  DBA_FEATURE_USAGE_STATISTICS, tested by V10_2f).
--
--  RESULT
--    an error (ORA-00942 / ORA-01031) -> not readable: row 6 stays as it is.
--        Send the error.
--    rows -> readable. Send the XML export.
--  All options. No binds. Pure SELECT. Nothing is written.
-- ============================================================================
SELECT  o.parameter  AS option_name,
        o.value      AS option_value
FROM    v$option o
ORDER BY o.parameter
