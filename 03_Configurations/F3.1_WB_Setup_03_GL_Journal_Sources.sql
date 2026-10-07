-- ============================================================================
--  F3.1 WB  Setup Inventory workbook - sheet "GL Journal Sources"
--  Version   : 1.0 (2026-10-05). Not yet run on a pod.
--              RUN V3_1 FIRST. Log every run in 06_Run_Results/RUN_LOG.md.
--  Mirrors   : EBS agent _setup_inventory_sql['gl_journal_sources']
--  RECONCILES  row count = F3.1 row 5 "Journal Sources": the SAME population -
--              distinct JE_SOURCE_NAME in GL_JE_SOURCES_TL with LANGUAGE IN
--              (session language, 'US'), one row per source.
--
--  COLUMNS  JE_SOURCE_NAME, USER_NAME, DESCRIPTION, APPROVAL_REQUIRED,
--           IMPORT_USING_KEY, JOURNALS_POSTED (EBS order and meaning)
--    USER_NAME / DESCRIPTION  one language per source (session first, then
--                             'US') so a translated source stays one row.
--    APPROVAL_REQUIRED / IMPORT_USING_KEY  in Fusion these live on
--                             GL_JE_SOURCES_B (JOURNAL_APPROVAL_FLAG,
--                             IMPORT_USING_KEY_FLAG; PK JE_SOURCE_NAME) - EBS
--                             read them from the _TL table.
--    JOURNALS_POSTED  GL_JE_HEADERS rows with this source (EBS rule - every
--                     header, not only posted ones; the name is kept for
--                     parity). Ledger-scoped when :p_ledger_id is set, whole
--                     pod when blank. Pre-aggregated once, LEFT JOINed.
--  Answers "defined vs used": many seeded sources are defined, few are used.
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
src_names AS (
    SELECT  s.je_source_name,
            MAX(s.user_je_source_name) KEEP (DENSE_RANK FIRST ORDER BY
                CASE WHEN s.language = USERENV('LANG') THEN 0 ELSE 1 END)  AS user_name,
            MAX(s.description) KEEP (DENSE_RANK FIRST ORDER BY
                CASE WHEN s.language = USERENV('LANG') THEN 0 ELSE 1 END)  AS src_desc
    FROM    gl_je_sources_tl s
    WHERE   s.language IN (USERENV('LANG'), 'US')
    GROUP   BY s.je_source_name
),
src_flags AS (
    SELECT  b.je_source_name,
            MAX(b.journal_approval_flag)  AS approval_required,
            MAX(b.import_using_key_flag)  AS import_using_key
    FROM    gl_je_sources_b b
    GROUP   BY b.je_source_name
),
src_use AS (
    SELECT  h.je_source, COUNT(*) AS journals
    FROM        gl_je_headers h
    CROSS JOIN  params p
    WHERE       ( p.p_ledger_id IS NULL
                  OR h.ledger_id = TO_NUMBER(p.p_ledger_id) )
    GROUP   BY  h.je_source
)
SELECT
    n.je_source_name                                          AS "JE_SOURCE_NAME",
    n.user_name                                               AS "USER_NAME",
    n.src_desc                                                AS "DESCRIPTION",
    f.approval_required                                       AS "APPROVAL_REQUIRED",
    f.import_using_key                                        AS "IMPORT_USING_KEY",
    NVL(u.journals, 0)                                        AS "JOURNALS_POSTED"
FROM        src_names n
LEFT JOIN   src_flags f ON f.je_source_name = n.je_source_name
LEFT JOIN   src_use   u ON u.je_source      = n.je_source_name
ORDER BY    NVL(u.journals, 0) DESC, n.je_source_name
