-- ============================================================
-- Sub-question 5: Where should Olist focus delivery improvement?
--
-- Approach: Combine the category-sensitivity finding (q2) with
-- the distance-as-mechanism finding (q3) to compute, for each
-- (product category, customer state) combination:
--
--   - Order volume (size of the prize)
--   - Late delivery rate (how often things go wrong)
--   - Score penalty when late (how much one bad delivery costs)
--   - Estimated review score gain if late deliveries became on-time
--
-- The final ranking surfaces high-volume, high-late-rate, high-
-- penalty combinations: the category-state pairs where Olist gets
-- the most review-score improvement per delivery problem fixed.
--
-- Restricted to the top 10 product categories by volume (from q2)
-- and Brazilian states with at least 500 orders to keep estimates
-- stable.
-- ============================================================

WITH order_state AS (
    SELECT
        o.order_id,
        o.customer_id,
        oi.seller_id,
        oi.product_id,
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
),

order_enriched AS (
    -- Attach category (English) and customer state to each order
    SELECT
        os.order_id,
        os.delivery_state,
        t.product_category_name_english AS category,
        c.customer_state
    FROM order_state os
    JOIN products p ON os.product_id = p.product_id
    JOIN product_category_name_translation t 
        ON p.product_category_name = t.product_category_name
    JOIN customers c ON os.customer_id = c.customer_id
    WHERE t.product_category_name_english IS NOT NULL
),

top_categories AS (
    SELECT category
    FROM order_enriched
    GROUP BY category
    ORDER BY COUNT(*) DESC
    LIMIT 10
),

stable_states AS (
    SELECT customer_state
    FROM order_enriched
    GROUP BY customer_state
    HAVING COUNT(*) >= 500
),

with_reviews AS (
    SELECT
        oe.category,
        oe.customer_state,
        oe.delivery_state,
        r.review_score
    FROM order_enriched oe
    JOIN order_reviews r ON oe.order_id = r.order_id
    WHERE oe.category IN (SELECT category FROM top_categories)
      AND oe.customer_state IN (SELECT customer_state FROM stable_states)
),

aggregated AS (
    SELECT
        category,
        customer_state,
        COUNT(*) AS n_orders,
        SUM(CASE WHEN delivery_state = 'Late' THEN 1 ELSE 0 END) AS n_late,
        100.0 * SUM(CASE WHEN delivery_state = 'Late' THEN 1 ELSE 0 END) 
            / COUNT(*) AS pct_late,
        AVG(CASE WHEN delivery_state = 'On time or early' 
                 THEN review_score END) AS avg_score_ontime,
        AVG(CASE WHEN delivery_state = 'Late' 
                 THEN review_score END) AS avg_score_late,
        AVG(review_score) AS avg_score_current
    FROM with_reviews
    GROUP BY category, customer_state
    HAVING SUM(CASE WHEN delivery_state = 'Late' THEN 1 ELSE 0 END) >= 20
       AND SUM(CASE WHEN delivery_state = 'On time or early' THEN 1 ELSE 0 END) >= 20
)

SELECT
    category,
    customer_state,
    n_orders,
    ROUND(pct_late, 1) AS pct_late,
    ROUND(avg_score_ontime, 2) AS avg_score_ontime,
    ROUND(avg_score_late, 2) AS avg_score_late,
    ROUND(avg_score_current, 2) AS avg_score_current,
    -- The headline metric: estimated average review score IF every
    -- currently-late delivery in this segment became on-time. This
    -- assumes late deliveries would adopt the on-time score for
    -- their category-state cell, which is a strong assumption but
    -- the right first-order estimate.
    ROUND(avg_score_ontime, 2) AS avg_score_potential,
    ROUND(avg_score_ontime - avg_score_current, 2) AS score_uplift_potential,
    -- Intervention priority: uplift weighted by volume. A small
    -- uplift across many orders is more valuable than a big uplift
    -- across a handful. Volume-weighted uplift = total review-score
    -- "points" recoverable across the segment.
    ROUND((avg_score_ontime - avg_score_current) * n_orders, 0) AS total_review_points_recoverable
FROM aggregated
ORDER BY total_review_points_recoverable DESC
LIMIT 20;