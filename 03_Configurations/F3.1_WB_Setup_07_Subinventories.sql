-- ============================================================================
--  F3.1 WB  Setup Inventory workbook - sheet "Subinventories"
--  Version   : 1.1 (2026-10-16). Not yet run on a pod. v1.1: when a ledger
--              or BU is given, only the subinventories of the inventory orgs
--              in scope (as F3.1 v1.1 row 9).
--              RUN V3_1 FIRST. Log every run in 06_Run_Results/RUN_LOG.md.
--  Mirrors   : EBS agent _setup_inventory_sql['inv_subinventories']
--  RECONCILES  row count = F3.1 row 9 "Subinventories" (unbound: every row of
--              INV_SECONDARY_INVENTORIES, disabled ones included - EBS parity;
--              bound: the orgs in scope, v1.1).
--
--  COLUMNS  SUBINVENTORY, DESCRIPTION, ORG_CODE, ORGANIZATION_ID, ASSET,
--           QTY_TRACKED, LOCATOR_TYPE, PICKING_ORDER, DISABLE_DATE (EBS order)
--    INV_SECONDARY_INVENTORIES: PK SECONDARY_INVENTORY_NAME + ORGANIZATION_ID;
--    DESCRIPTION, ASSET_INVENTORY, QUANTITY_TRACKED, LOCATOR_TYPE,
--    PICKING_ORDER, DISABLE_DATE all verified on the Oracle page 2026-10-05.
--    ORG_CODE: EBS read MTL_PARAMETERS; Fusion reads
--    INV_ORGANIZATION_DEFINITIONS_V.ORGANIZATION_CODE (already verified by
--    V0_1), grouped per organization so the lookup cannot add rows.
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
-- v1.1: inventory orgs in scope when bound - the shared-block rule (v3.3):
-- the org's ledger = :p_ledger_id, its business unit = :p_bu_id
inv_org_scope AS (
    SELECT iod.organization_id
    FROM   inv_organization_definitions_v iod
    CROSS  JOIN params p
    WHERE  (p.p_ledger_id IS NULL OR iod.set_of_books_id = TO_NUMBER(p.p_ledger_id))
    AND    (p.p_bu_id     IS NULL OR iod.business_unit_id = TO_NUMBER(p.p_bu_id))
    GROUP  BY iod.organization_id
),
org_codes AS (
    SELECT  iod.organization_id, MAX(iod.organization_code) AS org_code
    FROM    inv_organization_definitions_v iod
    GROUP   BY iod.organization_id
)
SELECT
    si.secondary_inventory_name                               AS "SUBINVENTORY",
    si.description                                            AS "DESCRIPTION",
    oc.org_code                                               AS "ORG_CODE",
    si.organization_id                                        AS "ORGANIZATION_ID",
    si.asset_inventory                                        AS "ASSET",
    si.quantity_tracked                                       AS "QTY_TRACKED",
    si.locator_type                                           AS "LOCATOR_TYPE",
    si.picking_order                                          AS "PICKING_ORDER",
    TO_CHAR(si.disable_date, 'YYYY-MM-DD')                    AS "DISABLE_DATE"
FROM        inv_secondary_inventories si
CROSS JOIN  params                    p
LEFT JOIN   org_codes                 oc ON oc.organization_id = si.organization_id
-- v1.1: unbound = every row; bound = the orgs in scope (F3.1 row 9 rule)
WHERE       ( p.p_ledger_id IS NULL AND p.p_bu_id IS NULL )
   OR       si.organization_id IN ( SELECT o.organization_id FROM inv_org_scope o )
ORDER BY    si.organization_id, si.secondary_inventory_name
