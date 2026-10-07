-- ============================================================================
--  F3.1 WB  Setup Inventory workbook - sheet "CE Bank Accounts"
--  Version   : 1.0 (2026-10-05). Not yet run on a pod.
--              RUN V3_1 FIRST. Log every run in 06_Run_Results/RUN_LOG.md.
--  Mirrors   : EBS agent _setup_inventory_sql['ce_bank_accounts']
--  RECONCILES  row count = F3.1 row 10 "Active internal bank accounts" - the
--              same filters (INTERNAL, not end-dated) and the same scope test
--              (scope_flag / bu_scope copied from F3.1 unchanged).
--
--  COLUMNS  BANK_ACCOUNT_NAME, DESCRIPTION, CURRENCY, ACCOUNT_NUM_MASKED,
--           END_DATE, BANK_ACCOUNT_ID (EBS order)
--    ACCOUNT NUMBERS ARE NEVER READ IN CLEAR. EBS masked BANK_ACCOUNT_NUM to
--    its last 4 characters in SQL; Fusion CE_BANK_ACCOUNTS carries Oracle's
--    own MASKED_ACCOUNT_NUM ("Masked number of the bank account", verified
--    2026-10-05), so the raw BANK_ACCOUNT_NUM column is not selected at all.
--
--  SCOPE  blank ledger and BU = every active internal account (whole pod).
--         Bound = accounts with a use (CE_BANK_ACCT_USES_ALL.ORG_ID = "the
--         business unit") by an in-scope BU; EXISTS keeps a shared account
--         counted once.
-- ============================================================================
WITH
params AS (
    SELECT :p_ledger_id     AS p_ledger_id,
           :p_bu_id         AS p_bu_id,
           :p_custom_prefix AS p_custom_prefix,
           :p_from_date     AS p_from_date,
           :p_to_date       AS p_to_date
    FROM   dual
),
-- 0 = unbound (whole pod), 1 = a ledger and/or BU was given
scope_flag AS (
    SELECT CASE WHEN p.p_ledger_id IS NULL AND p.p_bu_id IS NULL
                THEN 0 ELSE 1 END                          AS is_bound
    FROM   params p
),
-- same BU rule as the F0 / F1 shared block (PRIMARY_LEDGER_ID is a string)
bu_scope AS (
    SELECT bu.bu_id
    FROM   fun_all_business_units_v bu
    CROSS  JOIN params p
    WHERE  bu.primary_ledger_id IS NOT NULL
    AND    NVL(UPPER(bu.status), 'A') NOT IN ('I', 'INACTIVE')
    AND    (p.p_ledger_id IS NULL OR bu.primary_ledger_id = TRIM(p.p_ledger_id))
    AND    (p.p_bu_id     IS NULL OR bu.bu_id = TO_NUMBER(p.p_bu_id))
    GROUP  BY bu.bu_id
)
SELECT
    ba.bank_account_name                                      AS "BANK_ACCOUNT_NAME",
    ba.description                                            AS "DESCRIPTION",
    ba.currency_code                                          AS "CURRENCY",
    ba.masked_account_num                                     AS "ACCOUNT_NUM_MASKED",
    TO_CHAR(ba.end_date, 'YYYY-MM-DD')                        AS "END_DATE",
    ba.bank_account_id                                        AS "BANK_ACCOUNT_ID"
FROM        ce_bank_accounts ba
CROSS JOIN  scope_flag       f
WHERE       ba.account_classification = 'INTERNAL'
AND         NVL(ba.end_date, SYSDATE + 1) > SYSDATE
AND         ( f.is_bound = 0
              OR EXISTS ( SELECT 1
                          FROM   ce_bank_acct_uses_all u
                          JOIN   bu_scope b ON b.bu_id = u.org_id
                          WHERE  u.bank_account_id = ba.bank_account_id ) )
ORDER BY    ba.bank_account_name, ba.bank_account_id
