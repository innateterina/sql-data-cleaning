-- Materialize a cleaned reporting table from airbnb_listings_raw

DROP TABLE IF EXISTS airbnb_listings_clean;

CREATE TABLE airbnb_listings_clean AS
WITH base AS (
    SELECT
        id,
        listing_url,
        host_id,

        NULLIF(TRIM(name), '') AS name,
        NULLIF(TRIM(property_type), '') AS property_type,
        NULLIF(TRIM(room_type), '') AS room_type,
        NULLIF(TRIM(neighbourhood_cleansed), '') AS neighbourhood_cleansed,
        NULLIF(TRIM(neighbourhood_group_cleansed), '') AS neighbourhood_group_cleansed,

        latitude,
        longitude,

        accommodates,
        bathrooms,
        bedrooms,
        beds,

        -- raw price and rates
        price AS price_raw,
        host_response_rate AS host_response_rate_raw,
        host_acceptance_rate AS host_acceptance_rate_raw,

        host_is_superhost,
        instant_bookable,

        minimum_nights,
        maximum_nights,

        has_availability,
        availability_30,
        availability_60,
        availability_90,
        availability_365,

        number_of_reviews,
        number_of_reviews_l30d,
        number_of_reviews_ltm,
        first_review,
        last_review,
        reviews_per_month,

        review_scores_rating,
        review_scores_cleanliness,
        review_scores_location,
        review_scores_value,

        last_scraped,
        calendar_last_scraped

    FROM airbnb_listings_raw
),
typed AS (
    SELECT
        *,
        CASE
            WHEN price_raw IS NULL OR TRIM(price_raw) = '' THEN NULL
            WHEN REGEXP_REPLACE(price_raw, '[$,]', '', 'g') ~ '^[0-9]+(\.[0-9]+)?$'
                THEN NULLIF(REGEXP_REPLACE(price_raw, '[$,]', '', 'g'), '')::NUMERIC
            ELSE NULL
        END AS price_usd,

        CASE
            WHEN host_response_rate_raw ~ '^[0-9]{1,3}%$'
                THEN REPLACE(host_response_rate_raw, '%', '')::NUMERIC
            ELSE NULL
        END AS host_response_rate_pct,

        CASE
            WHEN host_acceptance_rate_raw ~ '^[0-9]{1,3}%$'
                THEN REPLACE(host_acceptance_rate_raw, '%', '')::NUMERIC
            ELSE NULL
        END AS host_acceptance_rate_pct
    FROM base
),
flags AS (
    SELECT
        *,
        CASE WHEN id IS NULL THEN 1 ELSE 0 END AS flag_missing_id,
        CASE WHEN host_id IS NULL THEN 1 ELSE 0 END AS flag_missing_host_id,

        CASE WHEN price_usd IS NULL THEN 1 ELSE 0 END AS flag_missing_or_invalid_price,
        CASE WHEN price_usd IS NOT NULL AND (price_usd <= 0 OR price_usd > 2000) THEN 1 ELSE 0 END AS flag_extreme_price,

        CASE
            WHEN latitude IS NULL OR longitude IS NULL THEN 1
            WHEN latitude < -90 OR latitude > 90 THEN 1
            WHEN longitude < -180 OR longitude > 180 THEN 1
            ELSE 0
        END AS flag_invalid_geo,

        CASE
            WHEN minimum_nights IS NOT NULL AND maximum_nights IS NOT NULL AND minimum_nights > maximum_nights THEN 1
            ELSE 0
        END AS flag_invalid_nights,

        CASE
            WHEN (availability_30  IS NOT NULL AND (availability_30  < 0 OR availability_30  > 30))
              OR (availability_60  IS NOT NULL AND (availability_60  < 0 OR availability_60  > 60))
              OR (availability_90  IS NOT NULL AND (availability_90  < 0 OR availability_90  > 90))
              OR (availability_365 IS NOT NULL AND (availability_365 < 0 OR availability_365 > 365))
            THEN 1 ELSE 0
        END AS flag_invalid_availability
    FROM typed
),
final AS (
    SELECT
        -- keep clean fields
        id,
        listing_url,
        host_id,
        name,
        property_type,
        room_type,
        neighbourhood_group_cleansed,
        neighbourhood_cleansed,
        latitude,
        longitude,
        accommodates,
        bathrooms,
        bedrooms,
        beds,
        price_usd,
        host_response_rate_pct,
        host_acceptance_rate_pct,
        host_is_superhost,
        instant_bookable,
        minimum_nights,
        maximum_nights,
        availability_30,
        availability_60,
        availability_90,
        availability_365,
        number_of_reviews,
        number_of_reviews_l30d,
        number_of_reviews_ltm,
        first_review,
        last_review,
        reviews_per_month,
        review_scores_rating,
        review_scores_cleanliness,
        review_scores_location,
        review_scores_value,

        -- keep flags for transparency 
        flag_missing_id,
        flag_missing_host_id,
        flag_missing_or_invalid_price,
        flag_extreme_price,
        flag_invalid_geo,
        flag_invalid_nights,
        flag_invalid_availability,

        -- exclusion reason 
        CASE
            WHEN flag_missing_id = 1 THEN 'missing_id'
            WHEN flag_missing_host_id = 1 THEN 'missing_host_id'
            WHEN flag_missing_or_invalid_price = 1 THEN 'missing_or_invalid_price'
            WHEN flag_extreme_price = 1 THEN 'extreme_price'
            WHEN flag_invalid_geo = 1 THEN 'invalid_geo'
            WHEN flag_invalid_nights = 1 THEN 'invalid_nights'
            WHEN flag_invalid_availability = 1 THEN 'invalid_availability'
            ELSE NULL
        END AS exclusion_reason

    FROM flags
)
SELECT *
FROM final
WHERE exclusion_reason IS NULL;  -- keep only valid rows in clean table

-- Basic indexes for analysis
CREATE INDEX IF NOT EXISTS idx_airbnb_clean_id ON airbnb_listings_clean(id);
CREATE INDEX IF NOT EXISTS idx_airbnb_clean_neigh ON airbnb_listings_clean(neighbourhood_cleansed);
