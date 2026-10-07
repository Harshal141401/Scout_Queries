-- ============================================================================
--  F3.1 WB  Payment Terms workbook - sheet "AR Payment Terms"
--  Workbook  : Fusion_Discovery_3_1_Payment_Terms.xlsx
--  Version   : 1.0 (2026-10-05). Not yet run on a pod.
--              RUN V3_1 FIRST. Log every run in 06_Run_Results/RUN_LOG.md.
--  Mirrors   : EBS agent _PAYMENT_TERMS_DETAIL_SQL, AR half (2026-09-23)
--
--  GRAIN   one row per (term, installment); a term with no lines gets one row.
--  RECONCILES  distinct terms on this sheet = F3.1 row 2 "AR Payment Terms"
--              (both read every row of RA_TERMS_B).
--
--  COLUMNS  same as the AP sheet (EBS keeps both sheets the same shape), plus
--    REFERENCE_SET after DESCRIPTION: Fusion AR terms belong to a reference
--    data SET (RA_TERMS_B.SET_ID), so the same term name can exist in two sets.
--    TYPE prints '-' (AR has no TYPE column, EBS parity).
--    STATUS  Active = today inside the date range (AR has no ENABLED_FLAG).
--    DOCUMENTS_USING  AR transactions pointing at the term
--    MASTER_DEFAULTS  customer site uses + CURRENT customer profiles
--    Usage columns are term-level and repeat per installment - never sum.
--
--  FUSION PORT (verified on the Oracle pages 2026-10-05; V3_1 re-checks)
--    RA_TERMS_B carries NAME and DESCRIPTION itself (plus SET_ID), so no
--    _TL join is needed for the name.
--    RA_TERMS_LINES: PK TERM_ID + SEQUENCE_NUM.
--    RA_TERMS_LINES_DISCOUNTS: PK TERMS_LINES_DISCOUNT_ID - several discount
--    tiers per installment are possible, so they are collapsed to ONE row per
--    (term, installment): the largest DISCOUNT_PERCENT, with DISCOUNT_DAYS
--    taken from that SAME tier (KEEP DENSE_RANK FIRST) - EBS rule unchanged.
--    HZ_CUSTOMER_PROFILES_F is DATE-EFFECTIVE (PK includes
--    EFFECTIVE_START_DATE / EFFECTIVE_END_DATE): only the row current today
--    is counted, otherwise every historical version of a profile would count.
--    HZ_CUST_SITE_USES_ALL.PAYMENT_TERM_ID as in EBS.
--    Reference set code: FND_SETID_SETS_VL (one row per set); if the set has
--    no row in the session language the SET_ID itself is printed.
--
--  SCOPE   pod-wide (terms carry no BU or ledger - EBS parity).
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
set_names AS (
    SELECT  s.set_id, MAX(s.set_code) AS set_code
    FROM    fnd_setid_sets_vl s
    GROUP   BY s.set_id
),
-- one discount row per (term, installment): largest percent, its own days
ar_disc AS (
    SELECT  d.term_id,
            d.sequence_num,
            MAX(d.discount_percent)                                AS discount_percent,
            MAX(d.discount_days) KEEP (DENSE_RANK FIRST
                ORDER BY d.discount_percent DESC NULLS LAST)        AS discount_days
    FROM    ra_terms_lines_discounts d
    GROUP   BY d.term_id, d.sequence_num
),
-- documents referencing the term: AR transactions
ar_doc_use AS (
    SELECT  ct.term_id, COUNT(*) AS docs
    FROM    ra_customer_trx_all ct
    WHERE   ct.term_id IS NOT NULL
    GROUP   BY ct.term_id
),
-- master records defaulting to the term: site uses + current profiles
ar_master_use AS (
    SELECT  term_id, SUM(n) AS defaults_cnt
    FROM  ( SELECT su.payment_term_id AS term_id, COUNT(*) AS n
            FROM   hz_cust_site_uses_all su
            WHERE  su.payment_term_id IS NOT NULL
            GROUP  BY su.payment_term_id
            UNION ALL
            SELECT cp.standard_terms, COUNT(*)
            FROM   hz_customer_profiles_f cp
            WHERE  cp.standard_terms IS NOT NULL
            AND    TRUNC(SYSDATE) BETWEEN cp.effective_start_date
                                      AND cp.effective_end_date
            GROUP  BY cp.standard_terms )
    GROUP   BY term_id
)
SELECT
    b.name                                                    AS "TERM_NAME",
    b.description                                             AS "DESCRIPTION",
    NVL(sn.set_code, TO_CHAR(b.set_id))                       AS "REFERENCE_SET",
    '-'                                                       AS "TYPE",
    CASE WHEN b.start_date_active <= TRUNC(SYSDATE)
          AND NVL(b.end_date_active, TRUNC(SYSDATE)) >= TRUNC(SYSDATE)
         THEN 'Active' ELSE 'Inactive'
    END                                                       AS "STATUS",
    NVL(du.docs, 0)                                           AS "DOCUMENTS_USING",
    NVL(mu.defaults_cnt, 0)                                   AS "MASTER_DEFAULTS",
    TO_CHAR(b.start_date_active, 'YYYY-MM-DD')                AS "START_DATE_ACTIVE",
    TO_CHAR(b.end_date_active,   'YYYY-MM-DD')                AS "END_DATE_ACTIVE",
    b.due_cutoff_day                                          AS "DUE_CUTOFF_DAY",
    ln.sequence_num                                           AS "INSTALLMENT",
    ln.due_days                                               AS "DUE_DAYS",
    ln.due_day_of_month                                       AS "DUE_DAY_OF_MONTH",
    ln.due_months_forward                                     AS "DUE_MONTHS_FORWARD",
    ad.discount_percent                                       AS "DISCOUNT_PERCENT",
    ad.discount_days                                          AS "DISCOUNT_DAYS"
FROM        ra_terms_b     b
LEFT JOIN   set_names      sn ON sn.set_id      = b.set_id
LEFT JOIN   ra_terms_lines ln ON ln.term_id     = b.term_id
LEFT JOIN   ar_disc        ad ON ad.term_id     = ln.term_id
                             AND ad.sequence_num = ln.sequence_num
LEFT JOIN   ar_doc_use     du ON du.term_id     = b.term_id
LEFT JOIN   ar_master_use  mu ON mu.term_id     = b.term_id
ORDER BY    b.name, b.term_id, ln.sequence_num
