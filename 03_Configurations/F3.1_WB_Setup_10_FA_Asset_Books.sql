-- ============================================================================
--  F3.1 WB  Setup Inventory workbook - sheet "FA Asset Books"
--  Version   : 1.0 (2026-10-05). Not yet run on a pod.
--              RUN V3_1 FIRST. Log every run in 06_Run_Results/RUN_LOG.md.
--  Mirrors   : EBS agent _asset_books_sql (the same rows feed the 3.1 FA count
--              and the class/status breakdown)
--  RECONCILES  row count = F3.1 row 12 "Configured asset books"
--              = F3.1b Total / Configured. Same filter: UPPER(BOOK_CLASS) IN
--              ('CORPORATE','TAX'), disabled books included,
--              SET_OF_BOOKS_ID = :p_ledger_id when bound.
--
--  COLUMNS  BOOK_NAME, BOOK_CLASS, STATUS, SOURCE_CORPORATE_BOOK, LEDGER,
--           DISABLE_DATE, GL_POSTING_ALLOWED (EBS order)
--    STATUS  Disabled when DATE_INEFFECTIVE <= today, else Not disabled.
--    LEDGER  EBS printed LEDGER_ID; printed here by NAME (GL_LEDGERS.NAME,
--            verified by V0_1) so source and target pods can be compared.
--    All FA_BOOK_CONTROLS columns verified on the Oracle page 2026-10-05.
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
ledger_names AS (
    SELECT  gl.ledger_id, MAX(gl.name) AS ledger_name
    FROM    gl_ledgers gl
    GROUP   BY gl.ledger_id
)
SELECT
    fbc.book_type_code                                        AS "BOOK_NAME",
    fbc.book_class                                            AS "BOOK_CLASS",
    CASE WHEN fbc.date_ineffective <= SYSDATE
         THEN 'Disabled' ELSE 'Not disabled'
    END                                                       AS "STATUS",
    fbc.distribution_source_book                              AS "SOURCE_CORPORATE_BOOK",
    NVL(ln.ledger_name, TO_CHAR(fbc.set_of_books_id))         AS "LEDGER",
    TO_CHAR(fbc.date_ineffective, 'YYYY-MM-DD')               AS "DISABLE_DATE",
    fbc.gl_posting_allowed_flag                               AS "GL_POSTING_ALLOWED"
FROM        fa_book_controls fbc
CROSS JOIN  params           p
LEFT JOIN   ledger_names     ln ON ln.ledger_id = fbc.set_of_books_id
WHERE       UPPER(fbc.book_class) IN ('CORPORATE', 'TAX')
AND         ( p.p_ledger_id IS NULL
              OR fbc.set_of_books_id = TO_NUMBER(p.p_ledger_id) )
ORDER BY    fbc.book_class, fbc.book_type_code
