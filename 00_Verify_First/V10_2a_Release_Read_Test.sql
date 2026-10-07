-- ============================================================================
--  V10_2a  READ TEST - can the report user read the Fusion release record?
--  Version   : 1.0 (2026-10-07)        Run log: 06_Run_Results/RUN_LOG.md
--  Source    : Oracle Fusion Cloud (BIP data model, data source ApplicationDB_FSCM)
--  For: F10.1 row 1 (Fusion Release) and row 9 (Last Full Patching Cycle)
--
--  WHY: EBS reads FND_PRODUCT_GROUPS.RELEASE_NAME. AD_PRODUCT_GROUPS is not in
--  Oracle's Fusion Tables and Views reference; a Fusion blog (2022) reads
--  RELEASE_NAME and LAST_UPDATE_DATE from it. Only a read settles it.
--
--  RESULT
--    an error (ORA-00942 / ORA-01031) -> not readable. F10.1 v1.1 then prints
--        "see Settings and Actions > About This Application" in row 1 and
--        drops the row 9 proxy. Send the error text back.
--    rows -> readable. Send the XML export: it shows the RELEASE_NAME format
--        and LAST_UPDATE_DATE, to compare with the date this pod last took a
--        quarterly update (C85). An XML export leaves out NULL columns, so its
--        headings are not the full column list (R034); V10_0 lists the columns.
--    no row -> readable but empty (send that back too).
--  At most 10 rows, all columns. No binds. Pure SELECT. Nothing is written.
-- ============================================================================
SELECT  *
FROM    ad_product_groups
WHERE   ROWNUM <= 10
