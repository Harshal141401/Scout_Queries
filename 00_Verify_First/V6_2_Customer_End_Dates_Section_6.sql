-- ============================================================================
--  V6_2  END DATES on customer accounts and account sites (run with F6.2)
--  Version   : 1.0 (2026-10-05)        Run log: 06_Run_Results/RUN_LOG.md
--  For: F6.2_Master_Data rows 4 (Customer accounts) and 5 (Customer sites)
--  Binds: none.
--
--  WHY: R021 (V6_1 block A) found STATUS = 'A' on every customer party (284),
--  account (285) and account site (1,096), so F6.2 rows 3-5 will read
--  Active = Total. The EBS rule reads STATUS only. Fusion account sites also
--  carry START_DATE / END_DATE, and accounts carry ACCOUNT_TERMINATION_DATE
--  (all three seen in R020). If a row was end-dated before today but still
--  says STATUS 'A', the status rule counts it as active and F6.2 must also
--  test the date. This check counts those rows. A far-future end date (such
--  as 31-12-4712, "open") falls in the "future" bucket.
--
--  OUTPUT  ord | section | item | value_text   (one grid, paste it back whole)
--    A 100-105  HZ_CUST_ACCT_SITES_ALL: END_DATE empty / future / past,
--               past with STATUS A, START_DATE future; verdict A0
--    B 200-204  HZ_CUST_ACCOUNTS: ACCOUNT_TERMINATION_DATE empty / future /
--               past, past with STATUS A; verdict B0
--  Pure SELECT. Nothing is written.
-- ============================================================================
WITH
site_dates AS (
    SELECT COUNT(*)                                                          AS n_all,
           NVL(SUM(CASE WHEN cs.end_date IS NULL     THEN 1 ELSE 0 END), 0)  AS n_end_null,
           NVL(SUM(CASE WHEN cs.end_date >  SYSDATE  THEN 1 ELSE 0 END), 0)  AS n_end_future,
           NVL(SUM(CASE WHEN cs.end_date <= SYSDATE  THEN 1 ELSE 0 END), 0)  AS n_end_past,
           NVL(SUM(CASE WHEN cs.end_date <= SYSDATE AND cs.status = 'A'
                        THEN 1 ELSE 0 END), 0)                               AS n_past_status_a,
           NVL(SUM(CASE WHEN cs.start_date > SYSDATE THEN 1 ELSE 0 END), 0)  AS n_start_future
    FROM   hz_cust_acct_sites_all cs
),
acct_dates AS (
    SELECT COUNT(*)                                                          AS n_all,
           NVL(SUM(CASE WHEN hca.account_termination_date IS NULL
                        THEN 1 ELSE 0 END), 0)                               AS n_term_null,
           NVL(SUM(CASE WHEN hca.account_termination_date >  SYSDATE
                        THEN 1 ELSE 0 END), 0)                               AS n_term_future,
           NVL(SUM(CASE WHEN hca.account_termination_date <= SYSDATE
                        THEN 1 ELSE 0 END), 0)                               AS n_term_past,
           NVL(SUM(CASE WHEN hca.account_termination_date <= SYSDATE AND hca.status = 'A'
                        THEN 1 ELSE 0 END), 0)                               AS n_past_status_a
    FROM   hz_cust_accounts hca
),
grid AS (
    -- A ------------------------------------------------------------------------
    SELECT 100                                                       AS ord,
           CAST('A account sites (HZ_CUST_ACCT_SITES_ALL)' AS VARCHAR2(400)) AS section,
           CAST('A0 verdict' AS VARCHAR2(400))                       AS item,
           CAST(CASE WHEN sd.n_past_status_a = 0
                     THEN 'OK: no site end-dated before today still says STATUS A; F6.2 row 5 status rule stands'
                     ELSE '*** ' || sd.n_past_status_a || ' sites end-dated before today still say STATUS A:'
                          || ' F6.2 row 5 must also test END_DATE - send this back ***'
                END AS VARCHAR2(4000))                               AS value_text
    FROM   site_dates sd
    UNION ALL
    SELECT 101, TO_CHAR('A account sites (HZ_CUST_ACCT_SITES_ALL)'), TO_CHAR('A1 END_DATE empty'),
           TO_CHAR(sd.n_end_null || ' of ' || sd.n_all || ' sites')
    FROM   site_dates sd
    UNION ALL
    SELECT 102, TO_CHAR('A account sites (HZ_CUST_ACCT_SITES_ALL)'), TO_CHAR('A2 END_DATE after today'),
           TO_CHAR(sd.n_end_future || ' of ' || sd.n_all || ' sites')
    FROM   site_dates sd
    UNION ALL
    SELECT 103, TO_CHAR('A account sites (HZ_CUST_ACCT_SITES_ALL)'), TO_CHAR('A3 END_DATE today or earlier'),
           TO_CHAR(sd.n_end_past || ' of ' || sd.n_all || ' sites')
    FROM   site_dates sd
    UNION ALL
    SELECT 104, TO_CHAR('A account sites (HZ_CUST_ACCT_SITES_ALL)'), TO_CHAR('A4 of A3, STATUS = A'),
           TO_CHAR(sd.n_past_status_a || ' sites')
    FROM   site_dates sd
    UNION ALL
    SELECT 105, TO_CHAR('A account sites (HZ_CUST_ACCT_SITES_ALL)'), TO_CHAR('A5 START_DATE after today'),
           TO_CHAR(sd.n_start_future || ' of ' || sd.n_all || ' sites')
    FROM   site_dates sd
    -- B ------------------------------------------------------------------------
    UNION ALL
    SELECT 200, TO_CHAR('B customer accounts (HZ_CUST_ACCOUNTS)'), TO_CHAR('B0 verdict'),
           TO_CHAR(CASE WHEN ad.n_past_status_a = 0
                        THEN 'OK: no account terminated before today still says STATUS A; F6.2 row 4 status rule stands'
                        ELSE '*** ' || ad.n_past_status_a || ' accounts terminated before today still say STATUS A:'
                             || ' F6.2 row 4 must also test ACCOUNT_TERMINATION_DATE - send this back ***'
                   END)
    FROM   acct_dates ad
    UNION ALL
    SELECT 201, TO_CHAR('B customer accounts (HZ_CUST_ACCOUNTS)'), TO_CHAR('B1 ACCOUNT_TERMINATION_DATE empty'),
           TO_CHAR(ad.n_term_null || ' of ' || ad.n_all || ' accounts')
    FROM   acct_dates ad
    UNION ALL
    SELECT 202, TO_CHAR('B customer accounts (HZ_CUST_ACCOUNTS)'), TO_CHAR('B2 ACCOUNT_TERMINATION_DATE after today'),
           TO_CHAR(ad.n_term_future || ' of ' || ad.n_all || ' accounts')
    FROM   acct_dates ad
    UNION ALL
    SELECT 203, TO_CHAR('B customer accounts (HZ_CUST_ACCOUNTS)'), TO_CHAR('B3 ACCOUNT_TERMINATION_DATE today or earlier'),
           TO_CHAR(ad.n_term_past || ' of ' || ad.n_all || ' accounts')
    FROM   acct_dates ad
    UNION ALL
    SELECT 204, TO_CHAR('B customer accounts (HZ_CUST_ACCOUNTS)'), TO_CHAR('B4 of B3, STATUS = A'),
           TO_CHAR(ad.n_past_status_a || ' accounts')
    FROM   acct_dates ad
)
SELECT  g.ord         AS ord,
        g.section     AS section,
        g.item        AS item,
        g.value_text  AS value_text
FROM    grid g
ORDER BY g.ord
