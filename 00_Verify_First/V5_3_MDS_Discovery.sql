-- ============================================================================
--  V5_3  MDS DISCOVERY - what the metadata repository (MDS) shows this user
--  Version   : 1.0 (2026-10-05)        Run log: 06_Run_Results/RUN_LOG.md
--  Source    : Oracle Fusion Cloud (BIP data model, data source ApplicationDB_FSCM)
--  For: F5.1 row 20 (custom scheduled processes) and a possible page-
--       customization row. Every column read here was printed by V5_0 (R016).
--
--  WHY: V5_0 (R016) found ESS request history not visible, but the MDS views
--  readable (MDS_PATHS, MDS_PARTITIONS, MDS_TRANSACTIONS ...). Fusion keeps
--  ESS job definitions and page customizations as MDS documents. If they show
--  here:
--    - custom ESS job definitions (path /oracle/apps/ess/custom/...) can be
--      counted from MDS - INCLUDING jobs never run, which request history can
--      never show;
--    - customization documents (path .../mdssys/cust/<layer>/...) give the
--      Fusion counterpart of EBS form personalizations, by layer.
--  This query only LOOKS: nothing is reported from it until the values are
--  understood.
--
--  TIP VERSION: MDS keeps every version of a document. A row whose
--  PATH_HIGH_CN is NULL is taken as the current version (assumption - block D
--  shows how the rows split, so it can be confirmed).
--
--  OUTPUT  ord | section | item | value_text   (one grid, paste it back whole)
--    A 101-120  partitions: documents in total / current / under
--               /oracle/apps/ess/ / under /oracle/apps/ess/custom/ /
--               customization documents
--    B 201-230  custom ESS job definitions (current): totals, root element
--               names (a job definition should be 'job'), 10 sample paths
--    C 301-330  customization documents (current) by layer, by creator type
--               (user account or not, via MDS_TRANSACTIONS), 5 sample site paths
--    D 401-420  PATH_TYPE x PATH_OPERATION x current, to confirm the tip rule
--  It scans MDS_PATHS once for the counts and twice more for samples; on a
--  large repository it can take a few minutes. No binds. Pure SELECT.
-- ============================================================================
WITH
-- user accounts - copied from F3.2 / F5.1
user_accts AS (
    SELECT  UPPER(pu.username) AS uname
    FROM    per_users pu
    WHERE   pu.username IS NOT NULL
    GROUP   BY UPPER(pu.username)
),
part_names AS (
    SELECT mpt.partition_id, MAX(TO_CHAR(mpt.partition_name)) AS partition_name
    FROM   mds_partitions mpt
    GROUP  BY mpt.partition_id
),
-- one pass: every MDS_PATHS row reduced to a few flags
path_flags AS (
    SELECT mp.path_partition_id                                           AS partition_id,
           CASE WHEN mp.path_high_cn IS NULL THEN 'Y' ELSE 'N' END        AS is_tip,
           TO_CHAR(NVL(TO_CHAR(mp.path_type), '(null)'))                   AS path_type,
           TO_CHAR(NVL(TO_CHAR(mp.path_operation), '(null)'))              AS path_op,
           CASE WHEN mp.path_fullname LIKE '/oracle/apps/ess/%'
                THEN 'Y' ELSE 'N' END                                     AS is_ess,
           CASE WHEN mp.path_fullname LIKE '/oracle/apps/ess/custom/%'
                THEN 'Y' ELSE 'N' END                                     AS is_ess_custom,
           CASE WHEN INSTR(mp.path_fullname, '/mdssys/cust/') > 0
                THEN TO_CHAR(NVL(REGEXP_SUBSTR(mp.path_fullname,
                                 '/mdssys/cust/([^/]+)/', 1, 1, NULL, 1), '(none)'))
           END                                                            AS cust_layer,
           CASE WHEN mp.path_fullname LIKE '/oracle/apps/ess/custom/%'
                THEN TO_CHAR(NVL(TO_CHAR(mp.path_doc_elem_name), '(null)'))
           END                                                            AS ess_elem
    FROM   mds_paths mp
),
path_agg AS (
    SELECT f.partition_id, f.is_tip, f.path_type, f.path_op, f.is_ess, f.is_ess_custom,
           f.cust_layer, f.ess_elem, COUNT(*) AS n
    FROM   path_flags f
    GROUP  BY f.partition_id, f.is_tip, f.path_type, f.path_op, f.is_ess, f.is_ess_custom,
              f.cust_layer, f.ess_elem
),
-- ---- A partitions -------------------------------------------------------------
part_sum AS (
    SELECT a.partition_id,
           SUM(a.n)                                                              AS n_rows,
           SUM(CASE WHEN a.is_tip = 'Y' THEN a.n ELSE 0 END)                     AS n_tip,
           SUM(CASE WHEN a.is_tip = 'Y' AND a.is_ess = 'Y' THEN a.n ELSE 0 END)  AS n_ess,
           SUM(CASE WHEN a.is_tip = 'Y' AND a.is_ess_custom = 'Y'
                    THEN a.n ELSE 0 END)                                         AS n_ess_custom,
           SUM(CASE WHEN a.is_tip = 'Y' AND a.cust_layer IS NOT NULL
                    THEN a.n ELSE 0 END)                                         AS n_cust
    FROM   path_agg a
    GROUP  BY a.partition_id
),
part_rows AS (
    SELECT ps.partition_id, ps.n_rows, ps.n_tip, ps.n_ess, ps.n_ess_custom, ps.n_cust,
           NVL(pn.partition_name, TO_CHAR(ps.partition_id))                      AS pname,
           ROW_NUMBER() OVER (ORDER BY ps.n_ess_custom DESC, ps.n_cust DESC,
                                       ps.n_rows DESC, ps.partition_id)          AS rn
    FROM        part_sum   ps
    LEFT JOIN   part_names pn ON pn.partition_id = ps.partition_id
),
all_sum AS (
    SELECT NVL(SUM(ps.n_rows), 0)        AS n_rows,
           NVL(SUM(ps.n_tip), 0)         AS n_tip,
           NVL(SUM(ps.n_ess), 0)         AS n_ess,
           NVL(SUM(ps.n_ess_custom), 0)  AS n_ess_custom,
           NVL(SUM(ps.n_cust), 0)        AS n_cust,
           COUNT(*)                      AS n_parts
    FROM   part_sum ps
),
-- ---- B custom ESS job definitions -------------------------------------------
ess_elems AS (
    SELECT a.ess_elem,
           SUM(CASE WHEN a.is_tip = 'Y' THEN a.n ELSE 0 END) AS n_tip,
           SUM(a.n)                                           AS n_all
    FROM   path_agg a
    WHERE  a.is_ess_custom = 'Y'
    GROUP  BY a.ess_elem
),
ess_elem_rows AS (
    SELECT e.ess_elem, e.n_tip, e.n_all, ROW_NUMBER() OVER (ORDER BY e.n_tip DESC, e.ess_elem) AS rn
    FROM   ess_elems e
),
ess_samples AS (
    SELECT TO_CHAR(mp.path_fullname)                                   AS path_fullname,
           TO_CHAR(NVL(TO_CHAR(mp.path_doc_elem_name), '(null)'))       AS elem,
           ROW_NUMBER() OVER (ORDER BY mp.path_fullname)                AS rn
    FROM   mds_paths mp
    WHERE  mp.path_fullname LIKE '/oracle/apps/ess/custom/%'
    AND    mp.path_high_cn IS NULL
),
-- ---- C customization documents ---------------------------------------------
cust_layers AS (
    SELECT a.cust_layer, SUM(a.n) AS n_tip
    FROM   path_agg a
    WHERE  a.cust_layer IS NOT NULL
    AND    a.is_tip = 'Y'
    GROUP  BY a.cust_layer
),
cust_layer_rows AS (
    SELECT c.cust_layer, c.n_tip, ROW_NUMBER() OVER (ORDER BY c.n_tip DESC, c.cust_layer) AS rn
    FROM   cust_layers c
),
-- who created the current version of each customization document
cust_creators AS (
    SELECT TO_CHAR(NVL(REGEXP_SUBSTR(mp.path_fullname, '/mdssys/cust/([^/]+)/', 1, 1, NULL, 1),
                       '(none)'))                                                AS cust_layer,
           CASE WHEN ua.uname IS NOT NULL THEN 'user account'
                WHEN mt.txn_creator IS NULL THEN 'no transaction row'
                ELSE 'not a user account' END                                    AS creator_type,
           COUNT(*)                                                              AS n
    FROM        mds_paths        mp
    LEFT JOIN   mds_transactions mt ON  mt.txn_cn           = mp.path_low_cn
                                    AND mt.txn_partition_id = mp.path_partition_id
    LEFT JOIN   user_accts       ua ON  ua.uname = UPPER(mt.txn_creator)
    WHERE  INSTR(mp.path_fullname, '/mdssys/cust/') > 0
    AND    mp.path_high_cn IS NULL
    GROUP  BY TO_CHAR(NVL(REGEXP_SUBSTR(mp.path_fullname, '/mdssys/cust/([^/]+)/', 1, 1, NULL, 1),
                          '(none)')),
              CASE WHEN ua.uname IS NOT NULL THEN 'user account'
                   WHEN mt.txn_creator IS NULL THEN 'no transaction row'
                   ELSE 'not a user account' END
),
cust_creator_rows AS (
    SELECT c.cust_layer, c.creator_type, c.n,
           ROW_NUMBER() OVER (ORDER BY c.n DESC, c.cust_layer, c.creator_type) AS rn
    FROM   cust_creators c
),
site_samples AS (
    SELECT TO_CHAR(mp.path_fullname)                    AS path_fullname,
           ROW_NUMBER() OVER (ORDER BY mp.path_fullname) AS rn
    FROM   mds_paths mp
    WHERE  INSTR(mp.path_fullname, '/mdssys/cust/site/') > 0
    AND    mp.path_high_cn IS NULL
),
-- ---- D type x operation x current -----------------------------------------------
type_ops AS (
    SELECT a.path_type, a.path_op, a.is_tip, SUM(a.n) AS n
    FROM   path_agg a
    GROUP  BY a.path_type, a.path_op, a.is_tip
),
type_op_rows AS (
    SELECT x.path_type, x.path_op, x.is_tip, x.n,
           ROW_NUMBER() OVER (ORDER BY x.n DESC, x.path_type, x.path_op, x.is_tip) AS rn
    FROM   type_ops x
),
grid AS (
    -- A ------------------------------------------------------------------------
    SELECT 101                                             AS ord,
           CAST('A MDS totals' AS VARCHAR2(400))           AS section,
           CAST('A0 rows / current (PATH_HIGH_CN null) / partitions' AS VARCHAR2(400)) AS item,
           CAST(TO_CHAR(s.n_rows || ' / ' || s.n_tip || ' / ' || s.n_parts)
                AS VARCHAR2(4000))                         AS value_text
    FROM   all_sum s
    UNION ALL
    SELECT 102, TO_CHAR('A MDS totals'),
           TO_CHAR('A1 current docs under /oracle/apps/ess/ / under /oracle/apps/ess/custom/'),
           TO_CHAR(s.n_ess || ' / ' || s.n_ess_custom)
    FROM   all_sum s
    UNION ALL
    SELECT 103, TO_CHAR('A MDS totals'),
           TO_CHAR('A2 current customization documents (.../mdssys/cust/...)'),
           TO_CHAR(s.n_cust)
    FROM   all_sum s
    UNION ALL
    SELECT 103 + pr.rn, TO_CHAR('A partitions'), TO_CHAR('A ' || pr.pname),
           TO_CHAR('rows ' || pr.n_rows || ', current ' || pr.n_tip || ', ESS ' || pr.n_ess
                   || ', ESS custom ' || pr.n_ess_custom || ', customization docs ' || pr.n_cust)
    FROM   part_rows pr
    WHERE  pr.rn <= 15
    -- B ------------------------------------------------------------------------
    UNION ALL
    SELECT 200 + er.rn, TO_CHAR('B custom ESS job definitions'),
           TO_CHAR('B root element ' || er.ess_elem),
           TO_CHAR(er.n_tip || ' current documents (' || er.n_all || ' rows incl. old versions)')
    FROM   ess_elem_rows er
    WHERE  er.rn <= 10
    UNION ALL
    SELECT 210 + es.rn, TO_CHAR('B custom ESS sample paths'), TO_CHAR('B ' || es.elem),
           TO_CHAR(es.path_fullname)
    FROM   ess_samples es
    WHERE  es.rn <= 10
    -- C ------------------------------------------------------------------------
    UNION ALL
    SELECT 300 + cl.rn, TO_CHAR('C customization docs by layer'),
           TO_CHAR('C layer ' || cl.cust_layer),
           TO_CHAR(cl.n_tip || ' current documents')
    FROM   cust_layer_rows cl
    WHERE  cl.rn <= 10
    UNION ALL
    SELECT 310 + cc.rn, TO_CHAR('C customization docs by creator'),
           TO_CHAR('C layer ' || cc.cust_layer || ', ' || cc.creator_type),
           TO_CHAR(cc.n || ' current documents')
    FROM   cust_creator_rows cc
    WHERE  cc.rn <= 15
    UNION ALL
    SELECT 325 + ss.rn, TO_CHAR('C site-layer sample paths'), TO_CHAR('C sample'),
           TO_CHAR(ss.path_fullname)
    FROM   site_samples ss
    WHERE  ss.rn <= 5
    -- D ------------------------------------------------------------------------
    UNION ALL
    SELECT 400 + tr.rn, TO_CHAR('D type x operation'),
           TO_CHAR('D PATH_TYPE=' || tr.path_type || ' PATH_OPERATION=' || tr.path_op
                   || ' current=' || tr.is_tip),
           TO_CHAR(tr.n || ' rows')
    FROM   type_op_rows tr
    WHERE  tr.rn <= 20
)
SELECT  g.ord         AS ord,
        g.section     AS section,
        g.item        AS item,
        g.value_text  AS value_text
FROM    grid g
ORDER BY g.ord
