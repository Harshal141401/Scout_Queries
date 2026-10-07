-- ============================================================================
--  V5_2b  READ TEST - can this report user read ESS request properties?
--  Version   : 1.0 (2026-10-05)        Run log: 06_Run_Results/RUN_LOG.md
--  Source    : Oracle Fusion Cloud (BIP data model, data source ApplicationDB_FSCM)
--
--  WHY: same finding as V5_2a, for ESS_REQUEST_PROPERTY (FUSION synonym for
--  FUSION_ORA_ESS.REQUEST_PROPERTY_VIEW, no columns visible in R016). F5.2
--  reads it only for the BIP report behind each job (property 'reportID').
--
--  RESULT
--    an error  -> NOT readable: F5.2 drops its BIP_REPORT column. Send the
--                 error text back.
--    one row   -> readable; the headings are the column list.
--    no row    -> readable but empty.
--  Run it after V5_2a. One row at most. No binds. Pure SELECT.
-- ============================================================================
SELECT  *
FROM    ess_request_property
WHERE   ROWNUM <= 1
