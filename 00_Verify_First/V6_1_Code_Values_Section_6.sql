-- ============================================================================
--  V6_1  CODE VALUES + GRAIN - the stored values Section 6 filters on (run after V6_0)
--  Version   : 1.0 (2026-10-05)        Run log: 06_Run_Results/RUN_LOG.md
--  For: F6.1_Data_Volume_Trends, F6.2_Master_Data
--  Binds: none used (the five standard binds are accepted for BIP parity).
--
--  WHY: F6.1 / F6.2 filter on stored values (STATUS 'A', COMPLETE_FLAG 'Y',
--  ACCOUNT_CLASSIFICATION 'INTERNAL', TYPE_LOOKUP_CODE 'STANDARD', GL STATUS
--  'P', ENABLED_FLAG / TEMPLATE_ITEM_FLAG 'Y', SUBMITTED_FLAG 'Y'). A value that
--  is not stored makes a row read 0, and a 0 would be reported as real. Each is
--  printed with a verdict. The grain block shows whether a table holds more
--  than one row per business key (why F6.2 groups on the key).
--
--  OUTPUT  ord | section | item | value_text   (one grid, paste it back whole)
--    A 101-130  HZ STATUS values: customer parties, accounts, account sites
--    B 201-210  RA_CUSTOMER_TRX_ALL.COMPLETE_FLAG values; verdict
--    C 301-312  EGP_SYSTEM_ITEMS_B ENABLED_FLAG x TEMPLATE_ITEM_FLAG
--    D 401-410  CE_BANK_ACCOUNTS.ACCOUNT_CLASSIFICATION values; verdict
--    E 501-530  PO_HEADERS_ALL.TYPE_LOOKUP_CODE, GL_JE_HEADERS.STATUS,
--               DOO_HEADERS_ALL.SUBMITTED_FLAG values; verdicts
--    F 601-606  grain: rows vs keys for supplier sites, customer sites, items,
--               sales orders (DOO header rows vs orders)
--  Pure SELECT. Nothing is written.
-- ============================================================================
WITH
-- ---- A TCA status values ---------------------------------------------------------
party_status AS (
    SELECT NVL(TO_CHAR(hp.status), '(null)') AS val, COUNT(*) AS n
    FROM   hz_parties hp
    WHERE  hp.party_id IN ( SELECT hca.party_id FROM hz_cust_accounts hca )
    GROUP  BY NVL(TO_CHAR(hp.status), '(null)')
),
acct_status AS (
    SELECT NVL(TO_CHAR(hca.status), '(null)') AS val, COUNT(*) AS n
    FROM   hz_cust_accounts hca
    GROUP  BY NVL(TO_CHAR(hca.status), '(null)')
),
site_status AS (
    SELECT NVL(TO_CHAR(cs.status), '(null)') AS val, COUNT(*) AS n
    FROM   hz_cust_acct_sites_all cs
    GROUP  BY NVL(TO_CHAR(cs.status), '(null)')
),
status_rows AS (
    SELECT 100 AS base, 'customer parties' AS what, x.val, x.n,
           ROW_NUMBER() OVER (ORDER BY x.n DESC, x.val) AS rn
    FROM   party_status x
    UNION ALL
    SELECT 110, 'customer accounts', x.val, x.n,
           ROW_NUMBER() OVER (ORDER BY x.n DESC, x.val)
    FROM   acct_status x
    UNION ALL
    SELECT 120, 'customer account sites', x.val, x.n,
           ROW_NUMBER() OVER (ORDER BY x.n DESC, x.val)
    FROM   site_status x
),
-- ---- B AR complete flag ---------------------------------------------------------------
ar_flag AS (
    SELECT NVL(TO_CHAR(ct.complete_flag), '(null)') AS val, COUNT(*) AS n
    FROM   ra_customer_trx_all ct
    GROUP  BY NVL(TO_CHAR(ct.complete_flag), '(null)')
),
ar_flag_rows AS (
    SELECT x.val, x.n, ROW_NUMBER() OVER (ORDER BY x.n DESC, x.val) AS rn FROM ar_flag x
),
ar_flag_chk AS (
    SELECT NVL(SUM(CASE WHEN x.val = 'Y' THEN x.n END), 0) AS n_y, NVL(SUM(x.n), 0) AS n_all
    FROM   ar_flag x
),
-- ---- C item flags ------------------------------------------------------------------
item_flags AS (
    SELECT NVL(TO_CHAR(i.enabled_flag), '(null)')       AS enabled_val,
           NVL(TO_CHAR(i.template_item_flag), '(null)') AS template_val,
           COUNT(*)                                     AS n
    FROM   egp_system_items_b i
    GROUP  BY NVL(TO_CHAR(i.enabled_flag), '(null)'), NVL(TO_CHAR(i.template_item_flag), '(null)')
),
item_flag_rows AS (
    SELECT x.enabled_val, x.template_val, x.n,
           ROW_NUMBER() OVER (ORDER BY x.n DESC, x.enabled_val, x.template_val) AS rn
    FROM   item_flags x
),
-- ---- D bank account classification --------------------------------------------
bank_class AS (
    SELECT NVL(TO_CHAR(ba.account_classification), '(null)') AS val, COUNT(*) AS n
    FROM   ce_bank_accounts ba
    GROUP  BY NVL(TO_CHAR(ba.account_classification), '(null)')
),
bank_class_rows AS (
    SELECT x.val, x.n, ROW_NUMBER() OVER (ORDER BY x.n DESC, x.val) AS rn FROM bank_class x
),
bank_class_chk AS (
    SELECT NVL(SUM(CASE WHEN x.val = 'INTERNAL' THEN x.n END), 0) AS n_internal
    FROM   bank_class x
),
-- ---- E PO type, GL status, DOO submitted flag ----------------------------------
po_types AS (
    SELECT NVL(TO_CHAR(ph.type_lookup_code), '(null)') AS val, COUNT(*) AS n
    FROM   po_headers_all ph
    GROUP  BY NVL(TO_CHAR(ph.type_lookup_code), '(null)')
),
gl_status AS (
    SELECT NVL(TO_CHAR(jh.status), '(null)') AS val, COUNT(*) AS n
    FROM   gl_je_headers jh
    GROUP  BY NVL(TO_CHAR(jh.status), '(null)')
),
doo_flag AS (
    SELECT NVL(TO_CHAR(dh.submitted_flag), '(null)') AS val, COUNT(*) AS n
    FROM   doo_headers_all dh
    GROUP  BY NVL(TO_CHAR(dh.submitted_flag), '(null)')
),
code_rows AS (
    SELECT 500 AS base, 'PO_HEADERS_ALL.TYPE_LOOKUP_CODE' AS what, x.val, x.n,
           ROW_NUMBER() OVER (ORDER BY x.n DESC, x.val) AS rn
    FROM   po_types x
    UNION ALL
    SELECT 510, 'GL_JE_HEADERS.STATUS', x.val, x.n,
           ROW_NUMBER() OVER (ORDER BY x.n DESC, x.val)
    FROM   gl_status x
    UNION ALL
    SELECT 520, 'DOO_HEADERS_ALL.SUBMITTED_FLAG', x.val, x.n,
           ROW_NUMBER() OVER (ORDER BY x.n DESC, x.val)
    FROM   doo_flag x
),
code_chk AS (
    SELECT NVL(SUM(CASE WHEN c.base = 500 AND c.val = 'STANDARD' THEN c.n END), 0) AS n_standard,
           NVL(SUM(CASE WHEN c.base = 510 AND c.val = 'P'        THEN c.n END), 0) AS n_posted,
           NVL(SUM(CASE WHEN c.base = 520 AND c.val = 'Y'        THEN c.n END), 0) AS n_submitted
    FROM   code_rows c
),
-- ---- F grain ---------------------------------------------------------------------------
site_grain AS (
    SELECT COUNT(*) AS n_rows FROM poz_supplier_sites_all_m ss
),
site_keys AS (
    SELECT COUNT(*) AS n_keys
    FROM  ( SELECT ss.vendor_site_id FROM poz_supplier_sites_all_m ss GROUP BY ss.vendor_site_id )
),
csite_grain AS (
    SELECT COUNT(*) AS n_rows FROM hz_cust_acct_sites_all cs
),
csite_keys AS (
    SELECT COUNT(*) AS n_keys
    FROM  ( SELECT cs.cust_acct_site_id FROM hz_cust_acct_sites_all cs GROUP BY cs.cust_acct_site_id )
),
item_grain AS (
    SELECT COUNT(*) AS n_rows FROM egp_system_items_b i
),
item_keys AS (
    SELECT COUNT(*) AS n_keys
    FROM  ( SELECT i.inventory_item_id FROM egp_system_items_b i GROUP BY i.inventory_item_id )
),
doo_grain AS (
    SELECT COUNT(*) AS n_rows FROM doo_headers_all dh
),
doo_keys AS (
    SELECT COUNT(*) AS n_keys
    FROM  ( SELECT dh.order_number, dh.source_order_system
            FROM   doo_headers_all dh
            GROUP  BY dh.order_number, dh.source_order_system )
),
grid AS (
    -- A ------------------------------------------------------------------------
    SELECT sr.base + sr.rn                                           AS ord,
           CAST('A TCA STATUS - ' || sr.what AS VARCHAR2(400))       AS section,
           CAST('A STATUS=' || sr.val AS VARCHAR2(400))              AS item,
           CAST(TO_CHAR(sr.n) || ' rows' AS VARCHAR2(4000))          AS value_text
    FROM   status_rows sr
    WHERE  sr.rn <= 9
    -- B ------------------------------------------------------------------------
    UNION ALL
    SELECT 200, TO_CHAR('B AR complete flag'), TO_CHAR('B0 verdict'),
           TO_CHAR(CASE WHEN ac.n_y > 0 OR ac.n_all = 0
                        THEN 'OK: ' || ac.n_y || ' of ' || ac.n_all || ' transactions have COMPLETE_FLAG = Y'
                        ELSE '*** no COMPLETE_FLAG = Y: F6.1 Receivables chart would read 0 - send this back ***'
                   END)
    FROM   ar_flag_chk ac
    UNION ALL
    SELECT 200 + afr.rn, TO_CHAR('B AR complete flag'), TO_CHAR('B COMPLETE_FLAG=' || afr.val),
           TO_CHAR(afr.n || ' rows')
    FROM   ar_flag_rows afr
    WHERE  afr.rn <= 9
    -- C ------------------------------------------------------------------------
    UNION ALL
    SELECT 300 + ifr.rn, TO_CHAR('C item flags'),
           TO_CHAR('C ENABLED_FLAG=' || ifr.enabled_val || ' TEMPLATE_ITEM_FLAG=' || ifr.template_val),
           TO_CHAR(ifr.n || ' item-org rows')
    FROM   item_flag_rows ifr
    WHERE  ifr.rn <= 12
    -- D ------------------------------------------------------------------------
    UNION ALL
    SELECT 400, TO_CHAR('D bank classification'), TO_CHAR('D0 verdict'),
           TO_CHAR(CASE WHEN bcc.n_internal > 0
                        THEN 'OK: ' || bcc.n_internal || ' INTERNAL accounts'
                        ELSE '*** no INTERNAL accounts: F6.2 row 7 would read 0 - send this back ***'
                   END)
    FROM   bank_class_chk bcc
    UNION ALL
    SELECT 400 + bcr.rn, TO_CHAR('D bank classification'),
           TO_CHAR('D ACCOUNT_CLASSIFICATION=' || bcr.val), TO_CHAR(bcr.n || ' accounts')
    FROM   bank_class_rows bcr
    WHERE  bcr.rn <= 9
    -- E ------------------------------------------------------------------------
    UNION ALL
    SELECT 500, TO_CHAR('E code verdicts'), TO_CHAR('E0 STANDARD POs / posted journals / submitted orders'),
           TO_CHAR(CASE WHEN cc.n_standard > 0 AND cc.n_posted > 0 AND cc.n_submitted > 0
                        THEN 'OK: ' || cc.n_standard || ' / ' || cc.n_posted || ' / ' || cc.n_submitted
                        ELSE 'CHECK: ' || cc.n_standard || ' / ' || cc.n_posted || ' / ' || cc.n_submitted
                             || ' - a 0 here zeroes a chart; send this back'
                   END)
    FROM   code_chk cc
    UNION ALL
    SELECT cr.base + cr.rn, TO_CHAR('E ' || cr.what), TO_CHAR('E ' || cr.val), TO_CHAR(cr.n || ' rows')
    FROM   code_rows cr
    WHERE  cr.rn <= 9
    -- F ------------------------------------------------------------------------
    UNION ALL
    SELECT 601, TO_CHAR('F grain'), TO_CHAR('F1 supplier sites: rows / distinct VENDOR_SITE_ID'),
           TO_CHAR(sg.n_rows || ' / ' || sk.n_keys)
    FROM   site_grain sg CROSS JOIN site_keys sk
    UNION ALL
    SELECT 602, TO_CHAR('F grain'), TO_CHAR('F2 customer account sites: rows / distinct CUST_ACCT_SITE_ID'),
           TO_CHAR(cg.n_rows || ' / ' || ck.n_keys)
    FROM   csite_grain cg CROSS JOIN csite_keys ck
    UNION ALL
    SELECT 603, TO_CHAR('F grain'), TO_CHAR('F3 items: item-org rows / distinct INVENTORY_ITEM_ID'),
           TO_CHAR(ig.n_rows || ' / ' || ik.n_keys)
    FROM   item_grain ig CROSS JOIN item_keys ik
    UNION ALL
    SELECT 604, TO_CHAR('F grain'), TO_CHAR('F4 sales orders: DOO header rows / orders'),
           TO_CHAR(dg.n_rows || ' / ' || dk.n_keys)
    FROM   doo_grain dg CROSS JOIN doo_keys dk
)
SELECT  g.ord         AS ord,
        g.section     AS section,
        g.item        AS item,
        g.value_text  AS value_text
FROM    grid g
ORDER BY g.ord
