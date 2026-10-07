-- ============================================================================
--  F3.1b  Section 3.1 "Asset books by class and status"
--  Version   : 1.0 (2026-10-05). Not yet run on a pod.
--              RUN V3_0 FIRST. Log every run in 06_Run_Results/RUN_LOG.md.
--  Source    : Oracle Fusion Cloud (BIP data model, data source ApplicationDB_FSCM)
--  Mirrors   : EBS agent _asset_books_sql + utils/asset_books.asset_book_counts
--              (report 30-Sep-2026, Vision ledger 1: Corporate 4/4/0,
--              Tax 9/7/2, Total 13/11/2 - EBS numbers, not targets)
--
--  OUTPUT  Book Class | Configured | Not Disabled | Disabled
--    Rows: Corporate, Tax, Total. Both classes always print, zeros included
--    (EBS parity). Labels are INITCAP of the class code, not typed text.
--
--  RULES (identical to EBS; columns verified on the Oracle Fusion
--  FA_BOOK_CONTROLS page 2026-10-05, re-checked on the pod by V3_0)
--    population   FA_BOOK_CONTROLS, UPPER(BOOK_CLASS) IN ('CORPORATE','TAX')
--                 - reviewer rule: budget and other classes excluded
--    scope        SET_OF_BOOKS_ID = :p_ledger_id when bound; blank = every
--                 ledger. :p_bu_id is ignored (a book follows its ledger).
--    Disabled     DATE_INEFFECTIVE <= SYSDATE (measured at run time)
--    Not Disabled everything else, including a NULL DATE_INEFFECTIVE
--  RECONCILES  Total / Configured = F3.1 row 12 "Configured asset books"
--              (same population, same filter).
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
book_rows AS (
    SELECT  UPPER(fbc.book_class)                                     AS cls,
            CASE WHEN fbc.date_ineffective <= SYSDATE THEN 1 ELSE 0 END AS is_disabled
    FROM        fa_book_controls fbc
    CROSS JOIN  params p
    WHERE       UPPER(fbc.book_class) IN ('CORPORATE', 'TAX')
    AND         ( p.p_ledger_id IS NULL
                  OR fbc.set_of_books_id = TO_NUMBER(p.p_ledger_id) )
),
-- the two reported classes, in report order (the filter codes above)
book_classes AS (
    SELECT 1 AS seq, 'CORPORATE' AS cls FROM dual
    UNION ALL
    SELECT 2,        'TAX'              FROM dual
),
class_agg AS (
    SELECT  cls,
            COUNT(*)              AS configured,
            SUM(1 - is_disabled)  AS not_disabled,
            SUM(is_disabled)      AS disabled
    FROM    book_rows
    GROUP   BY cls
),
total_agg AS (
    SELECT  COUNT(*)                      AS configured,
            NVL(SUM(1 - is_disabled), 0)  AS not_disabled,
            NVL(SUM(is_disabled), 0)      AS disabled
    FROM    book_rows
),
book_table AS (
    SELECT  bc.seq                        AS seq,
            INITCAP(bc.cls)               AS book_class,
            NVL(ca.configured, 0)         AS configured,
            NVL(ca.not_disabled, 0)       AS not_disabled,
            NVL(ca.disabled, 0)           AS disabled
    FROM        book_classes bc
    LEFT JOIN   class_agg    ca ON ca.cls = bc.cls
    UNION ALL
    SELECT  3, 'Total', t.configured, t.not_disabled, t.disabled
    FROM    total_agg t
)
SELECT
    bt.book_class                                             AS "Book Class",
    bt.configured                                             AS "Configured",
    bt.not_disabled                                           AS "Not Disabled",
    bt.disabled                                               AS "Disabled"
FROM        book_table bt
ORDER BY    bt.seq
