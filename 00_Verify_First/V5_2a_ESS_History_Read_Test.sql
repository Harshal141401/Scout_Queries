-- ============================================================================
--  V5_2a  READ TEST - can this report user read ESS request history at all?
--  Version   : 1.0 (2026-10-05)        Run log: 06_Run_Results/RUN_LOG.md
--  Source    : Oracle Fusion Cloud (BIP data model, data source ApplicationDB_FSCM)
--
--  WHY: V5_0 (R016) found ESS_REQUEST_HISTORY to be a FUSION synonym for
--  FUSION_ORA_ESS.REQUEST_HISTORY_VIEW, and ALL_TAB_COLUMNS showed NO columns
--  for that view. Either the user has no SELECT on it, or the grant does not
--  show in the dictionary. Only an actual read settles it.
--
--  RESULT
--    an error (ORA-00942 / ORA-01031 / ORA-04063)  -> NOT readable. F5.2 and
--        F5.2b cannot run on this pod with this data source; F5.1 row 20 must
--        come from V5_3 (MDS) or from the Scheduled Processes UI / ESS REST API.
--        Send the error text back.
--    one row  -> readable. The column headings ARE the column list (send the
--        output back; F5.2 / V5_4 are then checked against it).
--    no row   -> readable but empty (send that back too).
--  One row at most, all columns. No binds. Pure SELECT. Nothing is written.
-- ============================================================================
SELECT  *
FROM    ess_request_history
WHERE   ROWNUM <= 1
