-- ============================================================================
--  F3.1 WB  Payment Terms workbook - sheet "AP Payment Terms"
--  Workbook  : Fusion_Discovery_3_1_Payment_Terms.xlsx
--              (EBS: EBS_Discovery_3_1_Payment_Terms.xlsx, sheets AP + AR)
--  Version   : 1.0 (2026-10-05). Not yet run on a pod.
--              RUN V3_1 FIRST. Log every run in 06_Run_Results/RUN_LOG.md.
--  Mirrors   : EBS agent _PAYMENT_TERMS_DETAIL_SQL, AP half (2026-09-23)
--
--  GRAIN   one row per (term, installment). A term with no lines still gets
--          one row. Several installments = several rows for one term.
--  RECONCILES  distinct terms on this sheet = F3.1 row 1 "AP Payment Terms"
--              (both read every row of AP_TERMS_B). The row count is higher
--              when terms have more than one installment - that is the grain,
--              not a mismatch (EBS sheet: 41 terms -> more rows).
--
--  COLUMNS (EBS order) TERM_NAME, DESCRIPTION, TYPE, STATUS, DOCUMENTS_USING,
--    MASTER_DEFAULTS, START/END_DATE_ACTIVE, DUE_CUTOFF_DAY, INSTALLMENT,
--    DUE_DAYS, DUE_DAY_OF_MONTH, DUE_MONTHS_FORWARD, DISCOUNT_PERCENT,
--    DISCOUNT_DAYS
--    STATUS           Active = ENABLED_FLAG Y and today inside the date range
--    DOCUMENTS_USING  AP invoices + purchase orders pointing at the term
--    MASTER_DEFAULTS  supplier sites defaulting to the term
--    Both usage columns are TERM-level: they repeat on every installment row
--    of the same term - never sum them down the sheet.
--
--  FUSION PORT (columns verified on the Oracle Fusion Tables and Views pages
--  2026-10-05; V3_1 re-checks them on the pod)
--    EBS read AP_TERMS_TL (no _B on Vision). Fusion has AP_TERMS_B (PK
--    TERM_ID, ENABLED_FLAG, TYPE, dates) - the row population. Name and
--    description come from AP_TERMS_TL with ONE language picked per term
--    (session language first, then 'US'), so a term translated into two
--    languages cannot become two rows.
--    AP_TERMS_LINES: PK TERM_ID + SEQUENCE_NUM; AP keeps the discount on the
--    line (DISCOUNT_PERCENT / DISCOUNT_DAYS), same as EBS.
--    Supplier sites: EBS AP_SUPPLIER_SITES_ALL -> Fusion
--    POZ_SUPPLIER_SITES_ALL_M (PK VENDOR_SITE_ID, TERMS_ID).
--    Usage is pre-aggregated in CTEs (one pass per source table), never a
--    scalar subquery per output row.
--
--  SCOPE   pod-wide, no binds used (terms carry no BU or ledger - EBS parity).
--          The five standard binds are accepted for BIP parity.
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
-- one name / description per term: session language first, then 'US'
ap_term_lang AS (
    SELECT  t.term_id,
            MAX(t.name) KEEP (DENSE_RANK FIRST ORDER BY
                CASE WHEN t.language = USERENV('LANG') THEN 0 ELSE 1 END)  AS term_name,
            MAX(t.description) KEEP (DENSE_RANK FIRST ORDER BY
                CASE WHEN t.language = USERENV('LANG') THEN 0 ELSE 1 END)  AS term_desc
    FROM    ap_terms_tl t
    WHERE   t.language IN (USERENV('LANG'), 'US')
    GROUP   BY t.term_id
),
-- documents referencing the term: AP invoices + purchase orders
ap_doc_use AS (
    SELECT  terms_id, SUM(n) AS docs
    FROM  ( SELECT ai.terms_id, COUNT(*) AS n
            FROM   ap_invoices_all ai
            WHERE  ai.terms_id IS NOT NULL
            GROUP  BY ai.terms_id
            UNION ALL
            SELECT ph.terms_id, COUNT(*)
            FROM   po_headers_all ph
            WHERE  ph.terms_id IS NOT NULL
            GROUP  BY ph.terms_id )
    GROUP   BY terms_id
),
-- master records defaulting to the term: supplier sites
ap_master_use AS (
    SELECT  ss.terms_id, COUNT(*) AS defaults_cnt
    FROM    poz_supplier_sites_all_m ss
    WHERE   ss.terms_id IS NOT NULL
    GROUP   BY ss.terms_id
)
SELECT
    l.term_name                                               AS "TERM_NAME",
    l.term_desc                                               AS "DESCRIPTION",
    NVL(b.type, '-')                                          AS "TYPE",
    CASE WHEN NVL(b.enabled_flag, 'Y') = 'Y'
          AND NVL(b.start_date_active, TRUNC(SYSDATE)) <= TRUNC(SYSDATE)
          AND NVL(b.end_date_active,   TRUNC(SYSDATE)) >= TRUNC(SYSDATE)
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
    ln.discount_percent                                       AS "DISCOUNT_PERCENT",
    ln.discount_days                                          AS "DISCOUNT_DAYS"
FROM        ap_terms_b     b
LEFT JOIN   ap_term_lang   l  ON l.term_id   = b.term_id
LEFT JOIN   ap_terms_lines ln ON ln.term_id  = b.term_id
LEFT JOIN   ap_doc_use     du ON du.terms_id = b.term_id
LEFT JOIN   ap_master_use  mu ON mu.terms_id = b.term_id
ORDER BY    l.term_name, b.term_id, ln.sequence_num
