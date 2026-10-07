-- ============================================================================
--  V5_2c  ESS COLUMN DISCOVERY - which columns ESS_REQUEST_HISTORY really has
--  Version   : 1.0 (2026-10-06)        Run log: 06_Run_Results/RUN_LOG.md
--  Source    : Oracle Fusion Cloud (BIP data model, data source ApplicationDB_FSCM)
--
--  WHY: V5_2a (R034) proved the view is readable: SELECT * returned a row.
--  But a BIP XML export leaves out every element whose value is NULL. Its one
--  row was a waiting schedule (STATE 1), so it showed 45 columns and NOT
--  PROCESSSTART / PROCESSEND, which F5.2, F5.2b, V5_4 and the Section 8 run
--  counts need. ALL_TAB_COLUMNS shows no column for this view (R016), so the
--  list has to come from the data itself.
--
--  WHAT IT RETURNS: the latest request of every STATE x JOBTYPE combination
--  (both columns proven by R034), all columns. A column that is filled for
--  any kind of request appears in at least one row of the export.
--
--  RESULT: send the XML export back. A column that never appears is either
--  missing or empty on every sampled row; V8_3 then proves it by name.
--  Cannot fail on a column name (SELECT *). The * stays in the outer query
--  (a LONG column, if the view has one, is not allowed in a subquery's
--  select list). No binds. Pure SELECT.
-- ============================================================================
SELECT  h.*
FROM    ess_request_history h
WHERE   h.requestid IN ( SELECT MAX(h2.requestid)
                         FROM   ess_request_history h2
                         GROUP  BY h2.state, h2.jobtype )
ORDER BY h.state, h.jobtype
