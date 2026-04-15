-- ============================================================
-- Sub-question 2: Does the delivery-delay penalty vary by category?
--
-- Approach: Reuse the bucketed delay logic from query 1, then
-- join through order_items to products to category translation
-- to get an English category name. Compute average review score
-- per (category, delay bucket).
--
-- To keep the analysis stable, we restrict to:
--   - The top 10 product categories by order volume
--   - Two delay states: "on-time-or-early" and "late"
--   This collapses the 6-bucket view into a clear 2x10 comparison
--   showing which categories are most/least forgiving of lateness.
--
-- Hypothesis: Time-sensitive categories (electronics, gifts) get
-- punished more harshly than mundane categories (furniture, bath).
-- ============================================================

WITH order_delays AS (
    SELECT
        o.order_id,
        CASE
            WHEN CAST(julianday(o.order_delivered_customer_date)
                    - julianday(o.order_estimated_delivery_date) AS INTEGER) > 0
            THEN 'Late'
            ELSE 'On time or early'
        END AS delivery_state
    FROM orders o
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
),

order_categories AS (
    SELECT
        oi.order_id,
        t.product_category_name_english AS category
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    JOIN product_category_name_translation t 
        ON p.product_category_name = t.product_category_name
    WHERE oi.order_item_id = 1
      AND t.product_category_name_english IS NOT NULL
),

top_categories AS (
    SELECT category
    FROM order_categories
    GROUP BY category
    ORDER BY COUNT(*) DESC
    LIMIT 10
),

joined AS (
    SELECT
        oc.category,
        od.delivery_state,
        r.review_score
    FROM order_delays od
    JOIN order_categories oc ON od.order_id = oc.order_id
    JOIN order_reviews r ON od.order_id = r.order_id
    WHERE oc.category IN (SELECT category FROM top_categories)
)

SELECT
    category,
    ROUND(AVG(CASE WHEN delivery_state = 'On time or early' THEN review_score END), 2) AS avg_score_ontime,
    ROUND(AVG(CASE WHEN delivery_state = 'Late' THEN review_score END), 2) AS avg_score_late,
    ROUND(
        AVG(CASE WHEN delivery_state = 'On time or early' THEN review_score END)
        - AVG(CASE WHEN delivery_state = 'Late' THEN review_score END), 
    2) AS score_drop_when_late,
    SUM(CASE WHEN delivery_state = 'On time or early' THEN 1 ELSE 0 END) AS n_ontime,
    SUM(CASE WHEN delivery_state = 'Late' THEN 1 ELSE 0 END) AS n_late
FROM joined
GROUP BY category
ORDER BY score_drop_when_late DESC;