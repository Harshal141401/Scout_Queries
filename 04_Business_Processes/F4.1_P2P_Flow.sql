-- ============================================================================
--  F4.1  Section 4.1 Procure-to-pay (P2P) flow
--  Version   : 1.3 (2026-10-05). Row 2 (purchase orders) "not cancelled" now also
--              tests DOCUMENT_STATUS: R024 (V7_1 block B) showed CANCEL_FLAG is
--              never set on this pod's POs - all 260 STANDARD POs with
--              DOCUMENT_STATUS CANCELED have CANCEL_FLAG empty - so the v1.2
--              test removed nothing. R015's 850 may include cancelled POs.
--              Nothing else changed.
--              v1.2 (2026-10-05). v1.1 STILL raised ORA-12704 (R010): a second
--              NVARCHAR2 source (the lookup / payment-method name columns) fed
--              the labels. Every label is now forced to VARCHAR2: the name CTEs
--              return TO_CHAR(...), each sub-row label is wrapped in TO_CHAR(...)
--              and row 1 is CAST AS VARCHAR2(400), so the column is VARCHAR2
--              whatever the stored types are. Logic unchanged.
--              v1.0 failed on the pod with ORA-12704 (R009):
--              UNISTR returns NVARCHAR2 and was mixed with VARCHAR2 rows in a
--              UNION ALL. The middle dot is now TO_CHAR(UNISTR('\00B7')),
--              i.e. plain VARCHAR2. Logic unchanged.
--              RUN V4_0 AND V4_1 FIRST. Log every run in 06_Run_Results/RUN_LOG.md.
--  Source    : Oracle Fusion Cloud (BIP data model, data source ApplicationDB_FSCM)
--  Mirrors   : EBS agent ebs_discover_business_processes, P2P block (2026-09-23)
--              (report 30-Sep-2026, Vision: 138 / 336 / 369 / 958 / 369 -
--              EBS numbers, not targets)
-- ============================================================================
WITH
-- ---- PARAMS / WINDOW / SCOPE: copied unchanged from F1 (shared block v3.1),
--      so Section 4 measures the same population and window as Section 1.
params AS (
    SELECT :p_ledger_id     AS p_ledger_id,
           :p_bu_id         AS p_bu_id,
           :p_custom_prefix AS p_custom_prefix,
           :p_from_date     AS p_from_date,
           :p_to_date       AS p_to_date
    FROM   dual
),
-- ---- WINDOW: identical in F0 and F1 -------------------------------------
win AS (
    SELECT NVL(TO_DATE(p.p_from_date, 'YYYY-MM-DD'), TRUNC(SYSDATE) - 90) AS start_date,
           NVL(TO_DATE(p.p_to_date,   'YYYY-MM-DD'), TRUNC(SYSDATE)) + 1  AS end_date_excl
    FROM   params p
),
-- ---- SCOPE BLOCK: identical in F0 and F1 --------------------------------
led_scope AS (
    SELECT gl.ledger_id
    FROM   gl_ledgers gl
    CROSS  JOIN params p
    WHERE  gl.object_type_code = 'L'
    AND    NVL(gl.complete_flag, 'Y') = 'Y'
    AND    (p.p_ledger_id IS NULL OR gl.ledger_id = TO_NUMBER(p.p_ledger_id))
),
-- FUN_ALL_BUSINESS_UNITS_V.PRIMARY_LEDGER_ID is ORG_INFORMATION3 (a string),
-- so it is compared as a string. A BU whose classification STATUS is
-- inactive ('I' / 'INACTIVE') is excluded - the Fusion counterpart of the EBS
-- W3-Houston "disabled OU" rule. The view itself already drops BUs whose
-- effective dates have ended. V0_2 block A prints the STATUS values present.
bu_scope AS (
    SELECT bu.bu_id
    FROM   fun_all_business_units_v bu
    CROSS  JOIN params p
    WHERE  bu.primary_ledger_id IS NOT NULL
    AND    NVL(UPPER(bu.status), 'A') NOT IN ('I', 'INACTIVE')
    AND    (p.p_ledger_id IS NULL OR bu.primary_ledger_id = TRIM(p.p_ledger_id))
    AND    (p.p_bu_id     IS NULL OR bu.bu_id = TO_NUMBER(p.p_bu_id))
    GROUP  BY bu.bu_id
),
inv_org_scope AS (
    SELECT iod.organization_id
    FROM   inv_organization_definitions_v iod
    CROSS  JOIN params p
    WHERE  (p.p_ledger_id IS NULL OR iod.set_of_books_id = TO_NUMBER(p.p_ledger_id))
    GROUP  BY iod.organization_id
),
fa_book_scope AS (
    SELECT fbc.book_type_code
    FROM   fa_book_controls fbc
    CROSS  JOIN params p
    WHERE  (p.p_ledger_id IS NULL OR fbc.set_of_books_id = TO_NUMBER(p.p_ledger_id))
    GROUP  BY fbc.book_type_code
),
-- ---- 1 requisitions sourced to a PO ---------------------------------------
req_cnt AS (
    SELECT COUNT(*) AS cnt
    FROM   por_requisition_headers_all rh
    JOIN   bu_scope b ON b.bu_id = rh.req_bu_id
    CROSS  JOIN win w
    WHERE  rh.creation_date >= w.start_date
    AND    rh.creation_date <  w.end_date_excl
    AND    EXISTS ( SELECT 1
                    FROM   por_requisition_lines_all rl
                    WHERE  rl.requisition_header_id = rh.requisition_header_id
                    AND    rl.po_header_id IS NOT NULL )
),
-- ---- 2 purchase orders: STANDARD / BLANKET / PLANNED, not cancelled --------
po_cnt AS (
    SELECT COUNT(*) AS cnt
    FROM   po_headers_all ph
    CROSS  JOIN win w
    WHERE  ph.type_lookup_code IN ('STANDARD', 'BLANKET', 'PLANNED')
    AND    NVL(ph.cancel_flag, 'N') = 'N'
    -- Fusion records cancellation in DOCUMENT_STATUS; CANCEL_FLAG stays empty (R024)
    AND    REPLACE(UPPER(NVL(ph.document_status, 'OPEN')), '_', ' ')
               NOT IN ('CANCELED', 'CANCELLED')
    AND    ph.creation_date >= w.start_date
    AND    ph.creation_date <  w.end_date_excl
    AND    EXISTS ( SELECT 1
                    FROM   bu_scope b
                    WHERE  b.bu_id IN (ph.prc_bu_id, ph.req_bu_id, ph.billto_bu_id) )
),
-- ---- 3 receipts: one per receipt DOCUMENT (shipment header) ----------------
rcv_cnt AS (
    SELECT COUNT(*) AS cnt
    FROM  ( SELECT rt.shipment_header_id
            FROM   rcv_transactions rt
            JOIN   inv_org_scope ios ON ios.organization_id = rt.organization_id
            CROSS  JOIN win w
            WHERE  rt.transaction_type = 'RECEIVE'
            AND    rt.transaction_date >= w.start_date
            AND    rt.transaction_date <  w.end_date_excl
            AND    rt.shipment_header_id IS NOT NULL
            AND    rt.po_header_id       IS NOT NULL
            GROUP  BY rt.shipment_header_id )
),
-- ---- 4 AP invoices by type --------------------------------------------------
ap_by_type AS (
    SELECT NVL(ai.invoice_type_lookup_code, '(no type)') AS inv_type,
           COUNT(*)                                     AS cnt
    FROM   ap_invoices_all ai
    JOIN   bu_scope b ON b.bu_id = ai.org_id
    CROSS  JOIN win w
    WHERE  ai.cancelled_date IS NULL
    AND    ai.invoice_date >= w.start_date
    AND    ai.invoice_date <  w.end_date_excl
    GROUP  BY NVL(ai.invoice_type_lookup_code, '(no type)')
),
ap_total AS (
    SELECT NVL(SUM(cnt), 0) AS cnt FROM ap_by_type
),
inv_type_names AS (
    SELECT lv.lookup_code,
           TO_CHAR(MAX(lv.meaning) KEEP (DENSE_RANK FIRST ORDER BY
               CASE WHEN lv.language = USERENV('LANG') THEN 0 ELSE 1 END)) AS meaning
    FROM   fnd_lookup_values lv
    WHERE  lv.lookup_type = 'INVOICE TYPE'
    AND    lv.language IN (USERENV('LANG'), 'US')
    GROUP  BY lv.lookup_code
),
-- ---- 5 payments by method, voided excluded ----------------------------------
pay_by_method AS (
    SELECT ac.payment_method_code AS method_code,
           COUNT(*)               AS cnt
    FROM   ap_checks_all ac
    JOIN   bu_scope b ON b.bu_id = ac.org_id
    CROSS  JOIN win w
    WHERE  NVL(ac.status_lookup_code, 'X') <> 'VOIDED'
    AND    ac.check_date >= w.start_date
    AND    ac.check_date <  w.end_date_excl
    GROUP  BY ac.payment_method_code
),
pay_total AS (
    SELECT NVL(SUM(cnt), 0) AS cnt FROM pay_by_method
),
method_names AS (
    SELECT pm.payment_method_code,
           TO_CHAR(MAX(pm.payment_method_name) KEEP (DENSE_RANK FIRST ORDER BY
               CASE WHEN pm.language = USERENV('LANG') THEN 0 ELSE 1 END)) AS method_name
    FROM   iby_payment_methods_tl pm
    WHERE  pm.language IN (USERENV('LANG'), 'US')
    GROUP  BY pm.payment_method_code
),
-- ---- the report rows ---------------------------------------------------------
p2p_rows AS (
    SELECT 1 AS grp, 0 AS sub_cnt,
           CAST('Requisitions sourced to POs' AS VARCHAR2(400)) AS process_variant,
           c.cnt AS volume
    FROM   req_cnt c
    UNION ALL
    SELECT 2, 0, 'Total purchase orders', c.cnt FROM po_cnt c
    UNION ALL
    SELECT 3, 0, 'Total PO receipts', c.cnt FROM rcv_cnt c
    UNION ALL
    SELECT 4, 0, 'Total AP invoices', c.cnt FROM ap_total c
    UNION ALL
    SELECT 5, t.cnt,
           TO_CHAR(TO_CHAR(UNISTR('\00B7')) || ' ' || NVL(n.meaning, TO_CHAR(t.inv_type))),
           t.cnt
    FROM        ap_by_type     t
    LEFT JOIN   inv_type_names n ON n.lookup_code = t.inv_type
    UNION ALL
    SELECT 6, 0, 'Total payments', c.cnt FROM pay_total c
    UNION ALL
    SELECT 7, m.cnt,
           TO_CHAR(TO_CHAR(UNISTR('\00B7')) || ' '
                   || NVL(mn.method_name, NVL(TO_CHAR(m.method_code), '(no method)'))),
           m.cnt
    FROM        pay_by_method m
    LEFT JOIN   method_names  mn ON mn.payment_method_code = m.method_code
)
SELECT
    r.process_variant                                         AS "Process Variant",
    r.volume                                                  AS "Volume"
FROM        p2p_rows r
ORDER BY    r.grp, r.sub_cnt DESC, r.process_variant
