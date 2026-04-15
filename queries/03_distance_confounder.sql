-- ============================================================
-- Sub-question 3: Is distance a confounder in the delay-vs-score
-- relationship?
-- ============================================================

WITH geo_dedup AS (
    SELECT
        geolocation_zip_code_prefix AS zip_prefix,
        AVG(geolocation_lat) AS lat,
        AVG(geolocation_lng) AS lng
    FROM geolocation
    GROUP BY geolocation_zip_code_prefix
),

order_zip_pairs AS (
    -- Resolve each delivered order to a (seller_zip, customer_zip) pair
    -- via a single straight-line join chain. No coordinates yet,
    -- just zip prefixes — kept lightweight to avoid blow-up.
    SELECT
        o.order_id,
        s.seller_zip_code_prefix    AS seller_zip,
        c.customer_zip_code_prefix  AS customer_zip,
        CASE
            WHEN CAST(julianday(o.order_delivered_customer_date)
                    - julianday(o.order_estimated_delivery_date) AS INTEGER) > 0
            THEN 'Late'
            ELSE 'On time or early'
        END AS delivery_state
    FROM orders o
    JOIN customers c   ON o.customer_id = c.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id AND oi.order_item_id = 1
    JOIN sellers s     ON oi.seller_id = s.seller_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
),

with_coords AS (
    SELECT
        p.order_id,
        p.delivery_state,
        sg.lat AS seller_lat,
        sg.lng AS seller_lng,
        cg.lat AS customer_lat,
        cg.lng AS customer_lng
    FROM order_zip_pairs p
    JOIN geo_dedup sg ON p.seller_zip   = sg.zip_prefix
    JOIN geo_dedup cg ON p.customer_zip = cg.zip_prefix
),

distances AS (
    SELECT
        order_id,
        delivery_state,
        -- Haversine, with the inner sqrt argument clipped to [0,1]
        -- defensively to avoid domain errors on near-identical points.
        6371 * 2 * ASIN(
            CASE
                WHEN (
                    POWER(SIN((customer_lat - seller_lat) * 3.14159265 / 180 / 2), 2)
                    + COS(seller_lat   * 3.14159265 / 180)
                    * COS(customer_lat * 3.14159265 / 180)
                    * POWER(SIN((customer_lng - seller_lng) * 3.14159265 / 180 / 2), 2)
                ) > 1 THEN 1
                ELSE SQRT(
                    POWER(SIN((customer_lat - seller_lat) * 3.14159265 / 180 / 2), 2)
                    + COS(seller_lat   * 3.14159265 / 180)
                    * COS(customer_lat * 3.14159265 / 180)
                    * POWER(SIN((customer_lng - seller_lng) * 3.14159265 / 180 / 2), 2)
                )
            END
        ) AS distance_km
    FROM with_coords
),

bucketed AS (
    SELECT
        order_id,
        delivery_state,
        CASE
            WHEN distance_km < 50   THEN '1. Local (<50 km)'
            WHEN distance_km < 200  THEN '2. Regional (50-200 km)'
            WHEN distance_km < 500  THEN '3. Inter-state (200-500 km)'
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