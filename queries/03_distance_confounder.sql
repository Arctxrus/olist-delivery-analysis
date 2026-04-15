-- ============================================================
-- Sub-question 3: Is distance a confounder in the delay-vs-score
-- relationship? Are long-distance sellers being punished for
-- geography rather than performance?
--
-- Approach:
--   1. Get one representative lat/long per zip code prefix from
--      the geolocation table (it has many duplicates per prefix).
--   2. For each delivered order, look up seller and customer
--      coordinates and compute great-circle distance using the
--      Haversine formula.
--   3. Bucket orders by distance and re-examine the delay-vs-score
--      relationship within each distance band.
--
-- Hypothesis: Distance influences review scores primarily THROUGH
-- delay (long distance -> more late deliveries -> worse reviews),
-- not directly. If we control for delay state and the score still
-- varies by distance, that means customers are punishing sellers
-- for geography itself, which would be unfair.
-- ============================================================

WITH geo_dedup AS (
    -- The geolocation table has many rows per zip prefix.
    -- We average the coordinates to get one representative point.
    SELECT
        geolocation_zip_code_prefix AS zip_prefix,
        AVG(geolocation_lat) AS lat,
        AVG(geolocation_lng) AS lng
    FROM geolocation
    GROUP BY geolocation_zip_code_prefix
),

order_geo AS (
    -- Join orders to seller and customer coordinates.
    -- Each order has one customer; for orders with multiple sellers
    -- we take the first item's seller, same simplification as query 2.
    SELECT
        o.order_id,
        s_geo.lat AS seller_lat,
        s_geo.lng AS seller_lng,
        c_geo.lat AS customer_lat,
        c_geo.lng AS customer_lng,
        CASE
            WHEN CAST(julianday(o.order_delivered_customer_date)
                    - julianday(o.order_estimated_delivery_date) AS INTEGER) > 0
            THEN 'Late'
            ELSE 'On time or early'
        END AS delivery_state
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id AND oi.order_item_id = 1
    JOIN sellers s ON oi.seller_id = s.seller_id
    JOIN geo_dedup s_geo ON s.seller_zip_code_prefix = s_geo.zip_prefix
    JOIN geo_dedup c_geo ON c.customer_zip_code_prefix = c_geo.zip_prefix
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
),

distances AS (
    -- Haversine formula for great-circle distance in km.
    -- 6371 = Earth's radius in km.
    SELECT
        order_id,
        delivery_state,
        6371 * 2 * ASIN(SQRT(
            POWER(SIN((customer_lat - seller_lat) * 3.14159265 / 180 / 2), 2)
            + COS(seller_lat * 3.14159265 / 180)
            * COS(customer_lat * 3.14159265 / 180)
            * POWER(SIN((customer_lng - seller_lng) * 3.14159265 / 180 / 2), 2)
        )) AS distance_km
    FROM order_geo
),

bucketed AS (
    SELECT
        order_id,
        delivery_state,
        distance_km,
        CASE
            WHEN distance_km < 50 THEN '1. Local (<50 km)'
            WHEN distance_km < 200 THEN '2. Regional (50-200 km)'
            WHEN distance_km < 500 THEN '3. Inter-state (200-500 km)'
            WHEN distance_km < 1500 THEN '4. Long-haul (500-1500 km)'
            ELSE '5. Cross-country (1500+ km)'
        END AS distance_bucket
    FROM distances
)

SELECT
    b.distance_bucket,
    COUNT(*) AS n_orders,
    ROUND(100.0 * SUM(CASE WHEN b.delivery_state = 'Late' THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_late,
    ROUND(AVG(CASE WHEN b.delivery_state = 'On time or early' THEN r.review_score END), 2) AS avg_score_ontime,
    ROUND(AVG(CASE WHEN b.delivery_state = 'Late' THEN r.review_score END), 2) AS avg_score_late,
    ROUND(AVG(r.review_score), 2) AS avg_score_overall
FROM bucketed b
JOIN order_reviews r ON b.order_id = r.order_id
GROUP BY b.distance_bucket
ORDER BY b.distance_bucket;