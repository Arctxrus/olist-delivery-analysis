-- ============================================================
-- Sub-question 1: How much does delivery delay move review scores?
--
-- Approach: For every delivered order, compute the gap between
-- estimated and actual delivery date. Bucket orders by delay
-- severity, then join review scores and average per bucket.
--
-- Hypothesis: The relationship is non-linear. Early and on-time
-- deliveries cluster around a similar score; late deliveries
-- collapse review scores sharply, with severity scaling.
-- ============================================================

WITH order_delays AS (
    SELECT
        o.order_id,
        CAST(julianday(o.order_delivered_customer_date) 
             - julianday(o.order_estimated_delivery_date) AS INTEGER) AS delay_days
    FROM orders o
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
),

bucketed AS (
    SELECT
        order_id,
        delay_days,
        CASE
            WHEN delay_days <= -15 THEN '1. Very early (15+ days)'
            WHEN delay_days BETWEEN -14 AND -1 THEN '2. Early (1-14 days)'
            WHEN delay_days = 0 THEN '3. On time'
            WHEN delay_days BETWEEN 1 AND 7 THEN '4. Slightly late (1-7 days)'
            WHEN delay_days BETWEEN 8 AND 30 THEN '5. Late (8-30 days)'
            WHEN delay_days > 30 THEN '6. Very late (30+ days)'
        END AS delay_bucket
    FROM order_delays
)

SELECT
    b.delay_bucket,
    COUNT(*) AS n_orders,
    ROUND(AVG(r.review_score), 2) AS avg_review_score,
    ROUND(100.0 * SUM(CASE WHEN r.review_score = 1 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_one_star,
    ROUND(100.0 * SUM(CASE WHEN r.review_score = 5 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_five_star
FROM bucketed b
JOIN order_reviews r ON b.order_id = r.order_id
GROUP BY b.delay_bucket
ORDER BY b.delay_bucket;