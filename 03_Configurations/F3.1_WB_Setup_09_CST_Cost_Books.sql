-- ============================================================================
--  F3.1 WB  Setup Inventory workbook - sheet "CST Cost Books"
--  Version   : 1.0 (2026-10-05). Not yet run on a pod.
--              RUN V3_1 FIRST. Log every run in 06_Run_Results/RUN_LOG.md.
--  RECONCILES  row count = F3.1 row 11 "Cost Books" (every row of
--              CST_COST_BOOKS_B, pod-wide).
--
--  ADDED FOR FUSION. The EBS workbook had no Cost Types sheet even though its
--  report says "every other row above is expanded name-by-name". This sheet
--  makes that sentence true for Fusion. Cost books are the Fusion counterpart
--  of EBS cost types (see F3.1 header).
--  COLUMNS  COST_BOOK_CODE, PERIODIC_AVERAGE, COST_BOOK_ID
--    CST_COST_BOOKS_B: PK COST_BOOK_ID, COST_BOOK_CODE, PERIODIC_AVERAGE_FLAG
--    (verified on the Oracle page 2026-10-05). The table has no status or
--    end-date column, so every book is listed.
-- ============================================================================
WITH
params AS (
    SELECT :p_ledger_id     AS p_ledger_id,
           :p_bu_id         AS p_bu_id,
           :p_custom_prefix AS p_custom_prefix,
           :p_from_date     AS p_from_date,
           :p_to_date       AS p_to_date
    FROM   dual
)
SELECT
    cb.cost_book_code                                         AS "COST_BOOK_CODE",
    cb.periodic_average_flag                                  AS "PERIODIC_AVERAGE",
    cb.cost_book_id                                           AS "COST_BOOK_ID"
FROM        cst_cost_books_b cb
ORDER BY    cb.cost_book_code, cb.cost_book_id
