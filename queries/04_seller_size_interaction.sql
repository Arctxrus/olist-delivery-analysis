-- ============================================================
-- Sub-question 4: Does seller size moderate the late-delivery penalty?
--
-- Approach:
--   1. Compute each seller's total order volume across the full
--      dataset and bucket sellers into size tiers (small / mid / large).
--   2. Bucket each delivered order by lateness state.
--   3. Cross-tab average review score by (seller size, lateness),
--      yielding a 3x2 grid that exposes the interaction effect.
--
-- Hypothesis: Late deliveries from small/unknown sellers are
-- punished more harshly than late deliveries from large/trusted
-- sellers. Customers extend more goodwill to sellers with implicit
-- "track record" signals (high volume = social proof on the platform).
-- The interaction effect, if present, would suggest Olist should
-- protect its small sellers from late-delivery penalties more
-- actively than its large ones.
-- ============================================================

WITH seller_volumes AS (
    -- Each seller's total order count across the dataset.
    -- Used as a proxy for size / market presence on Olist.
    SELECT
        seller_id,
        COUNT(DISTINCT order_id) AS n_orders
    FROM order_items
    GROUP BY seller_id
),

seller_size_tiers AS (
    -- Bucket sellers into rough tiers using NTILE-style logic.
    -- We use absolute thresholds rather than percentiles for clarity:
    -- a "large" seller on Olist is anyone with 200+ orders, which
    -- is a meaningful operational scale.
    SELECT
        seller_id,
        n_orders,
        CASE
            WHEN n_orders < 20 THEN '1. Small (<20 orders)'
            WHEN n_orders < 200 THEN '2. Mid (20-199 orders)'
            ELSE '3. Large (200+ orders)'
        END AS size_tier
    FROM seller_volumes
),

order_state AS (
    -- Same delay logic as previous queries; binary on-time/late split.
    SELECT
        o.order_id,
        oi.seller_id,
        CASE
            WHEN CAST(julianday(o.order_delivered_customer_date)
                    - julianday(o.order_estimated_delivery_date) AS INTEGER) > 0
            THEN 'Late'
            ELSE 'On time or early'
        END AS delivery_state
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id AND oi.order_item_id = 1
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
)

SELECT
    sst.size_tier,
    COUNT(DISTINCT sst.seller_id) AS n_sellers,
    SUM(CASE WHEN os.delivery_state = 'On time or early' THEN 1 ELSE 0 END) AS n_ontime,
    SUM(CASE WHEN os.delivery_state = 'Late' THEN 1 ELSE 0 END) AS n_late,
    ROUND(100.0 * SUM(CASE WHEN os.delivery_state = 'Late' THEN 1 ELSE 0 END) 
                / COUNT(*), 1) AS pct_late,
    ROUND(AVG(CASE WHEN os.delivery_state = 'On time or early' 
                   THEN r.review_score END), 2) AS avg_score_ontime,
    ROUND(AVG(CASE WHEN os.delivery_state = 'Late' 
                   THEN r.review_score END), 2) AS avg_score_late,
    ROUND(
        AVG(CASE WHEN os.delivery_state = 'On time or early' THEN r.review_score END)
        - AVG(CASE WHEN os.delivery_state = 'Late' THEN r.review_score END),
    2) AS score_drop_when_late
FROM seller_size_tiers sst
JOIN order_state os ON sst.seller_id = os.seller_id
JOIN order_reviews r ON os.order_id = r.order_id
GROUP BY sst.size_tier
ORDER BY sst.size_tier;