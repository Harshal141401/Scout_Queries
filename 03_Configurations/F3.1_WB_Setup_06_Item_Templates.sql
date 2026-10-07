-- ============================================================================
--  F3.1 WB  Setup Inventory workbook - sheet "Item Templates"
--  Version   : 1.0 (2026-10-05). Not yet run on a pod.
--              RUN V3_1 FIRST. Log every run in 06_Run_Results/RUN_LOG.md.
--  Mirrors   : EBS agent _setup_inventory_sql['inv_item_templates']
--  RECONCILES  row count = F3.1 row 8 "Item Templates": distinct
--              INVENTORY_ITEM_ID with TEMPLATE_ITEM_FLAG = 'Y' - the same
--              population, one row per template.
--
--  COLUMNS  TEMPLATE_ID, TEMPLATE_NAME, DESCRIPTION (EBS order)
--    Fusion has no item-template table: a template is an item row in
--    EGP_SYSTEM_ITEMS_B (PK INVENTORY_ITEM_ID + ORGANIZATION_ID) flagged
--    TEMPLATE_ITEM_FLAG = 'Y'. TEMPLATE_ID = its INVENTORY_ITEM_ID.
--    TEMPLATE_NAME and DESCRIPTION are on EGP_SYSTEM_ITEMS_TL (PK
--    INVENTORY_ITEM_ID + ORGANIZATION_ID + LANGUAGE; verified 2026-10-05).
--    One name per template: session language first, then 'US', then the
--    lowest organization - a template present in several orgs or languages
--    stays ONE row. If no TL name exists, ITEM_NUMBER from the _B row is shown.
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
tmpl AS (
    SELECT  i.inventory_item_id,
            MIN(i.item_number) AS item_number
    FROM    egp_system_items_b i
    WHERE   NVL(i.template_item_flag, 'N') = 'Y'
    GROUP   BY i.inventory_item_id
),
tmpl_names AS (
    SELECT  tl.inventory_item_id,
            MAX(tl.template_name) KEEP (DENSE_RANK FIRST ORDER BY
                CASE WHEN tl.language = USERENV('LANG') THEN 0 ELSE 1 END,
                tl.organization_id)                                        AS template_name,
            MAX(tl.description) KEEP (DENSE_RANK FIRST ORDER BY
                CASE WHEN tl.language = USERENV('LANG') THEN 0 ELSE 1 END,
                tl.organization_id)                                        AS tmpl_desc
    FROM    egp_system_items_tl tl
    WHERE   tl.language IN (USERENV('LANG'), 'US')
    AND     tl.inventory_item_id IN ( SELECT t.inventory_item_id FROM tmpl t )
    GROUP   BY tl.inventory_item_id
)
SELECT
    t.inventory_item_id                                       AS "TEMPLATE_ID",
    NVL(n.template_name, t.item_number)                       AS "TEMPLATE_NAME",
    n.tmpl_desc                                               AS "DESCRIPTION"
FROM        tmpl       t
LEFT JOIN   tmpl_names n ON n.inventory_item_id = t.inventory_item_id
ORDER BY    NVL(n.template_name, t.item_number), t.inventory_item_id
