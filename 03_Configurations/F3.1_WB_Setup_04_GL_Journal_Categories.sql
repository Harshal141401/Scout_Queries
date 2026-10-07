-- ============================================================================
--  F3.1 WB  Setup Inventory workbook - sheet "GL Journal Categories"
--  Version   : 1.0 (2026-10-05). Not yet run on a pod.
--              RUN V3_1 FIRST. Log every run in 06_Run_Results/RUN_LOG.md.
--  Mirrors   : EBS agent _setup_inventory_sql['gl_journal_categories']
--  RECONCILES  row count = F3.1 row 6 "Journal Categories": distinct
--              JE_CATEGORY_NAME in GL_JE_CATEGORIES_TL with LANGUAGE IN
--              (session language, 'US') - the same population.
--
--  COLUMNS  JE_CATEGORY_NAME, USER_NAME, DESCRIPTION, CONSOLIDATION,
--           MANUAL_ENTRY_DISALLOWED, JOURNALS_POSTED
--    EBS had REVERSAL_OPTION: Fusion GL_JE_CATEGORIES_B has NO
--    REVERSAL_OPTION_CODE (verified on the Oracle page 2026-10-05), so that
--    column is dropped, not faked. CONSOLIDATION = CONSOLIDATION_FLAG (EBS
--    parity; Oracle marks it "not currently used"). MANUAL_ENTRY_DISALLOWED =
--    DISALLOW_MJE_FLAG, the Fusion category setting that matters to a
--    migration (manual journals blocked for the category).
--    JOURNALS_POSTED  GL_JE_HEADERS rows with this category; ledger-scoped
--                     when :p_ledger_id is set (EBS rule).
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
cat_names AS (
    SELECT  c.je_category_name,
            MAX(c.user_je_category_name) KEEP (DENSE_RANK FIRST ORDER BY
                CASE WHEN c.language = USERENV('LANG') THEN 0 ELSE 1 END)  AS user_name,
            MAX(c.description) KEEP (DENSE_RANK FIRST ORDER BY
                CASE WHEN c.language = USERENV('LANG') THEN 0 ELSE 1 END)  AS cat_desc
    FROM    gl_je_categories_tl c
    WHERE   c.language IN (USERENV('LANG'), 'US')
    GROUP   BY c.je_category_name
),
cat_flags AS (
    SELECT  b.je_category_name,
            MAX(b.consolidation_flag)  AS consolidation,
            MAX(b.disallow_mje_flag)   AS mje_disallowed
    FROM    gl_je_categories_b b
    GROUP   BY b.je_category_name
),
cat_use AS (
    SELECT  h.je_category, COUNT(*) AS journals
    FROM        gl_je_headers h
    CROSS JOIN  params p
    WHERE       ( p.p_ledger_id IS NULL
                  OR h.ledger_id = TO_NUMBER(p.p_ledger_id) )
    GROUP   BY  h.je_category
)
SELECT
    n.je_category_name                                        AS "JE_CATEGORY_NAME",
    n.user_name                                               AS "USER_NAME",
    n.cat_desc                                                AS "DESCRIPTION",
    f.consolidation                                           AS "CONSOLIDATION",
    f.mje_disallowed                                          AS "MANUAL_ENTRY_DISALLOWED",
    NVL(u.journals, 0)                                        AS "JOURNALS_POSTED"
FROM        cat_names n
LEFT JOIN   cat_flags f ON f.je_category_name = n.je_category_name
LEFT JOIN   cat_use   u ON u.je_category      = n.je_category_name
ORDER BY    NVL(u.journals, 0) DESC, n.je_category_name
