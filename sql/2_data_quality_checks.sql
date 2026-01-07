-- Purpose: Run data quality checks on airbnb_listings_raw

-- 0) Quick row count
SELECT COUNT(*) AS total_rows
FROM airbnb_listings_raw;

-- 1) Check primary identifier quality
-- 1.1 Missing IDs
SELECT COUNT(*) AS missing_id
FROM airbnb_listings_raw
WHERE id IS NULL;

-- 1.2 Duplicate IDs (should be 0 for a well-formed listings table)
SELECT id, COUNT(*) AS cnt
FROM airbnb_listings_raw
GROUP BY id
HAVING COUNT(*) > 1
ORDER BY cnt DESC;

-- 2) Key field completeness (fields typically required for analysis)
SELECT
  SUM(CASE WHEN host_id IS NULL THEN 1 ELSE 0 END) AS null_host_id,
  SUM(CASE WHEN neighbourhood_cleansed IS NULL OR TRIM(neighbourhood_cleansed) = '' THEN 1 ELSE 0 END) AS null_neighbourhood_cleansed,
  SUM(CASE WHEN room_type IS NULL OR TRIM(room_type) = '' THEN 1 ELSE 0 END) AS null_room_type,
  SUM(CASE WHEN property_type IS NULL OR TRIM(property_type) = '' THEN 1 ELSE 0 END) AS null_property_type,
  SUM(CASE WHEN latitude IS NULL OR longitude IS NULL THEN 1 ELSE 0 END) AS null_geo
FROM airbnb_listings_raw;

-- 3) Geographic validity checks
-- 3.1 Latitude/Longitude out of range
SELECT COUNT(*) AS out_of_range_geo
FROM airbnb_listings_raw
WHERE latitude IS NOT NULL
  AND (latitude < -90 OR latitude > 90)
   OR longitude IS NOT NULL
  AND (longitude < -180 OR longitude > 180);

-- 3.2 Missing geo for non-empty neighbourhood (suspicious)
SELECT COUNT(*) AS neighbourhood_but_no_geo
FROM airbnb_listings_raw
WHERE (neighbourhood_cleansed IS NOT NULL AND TRIM(neighbourhood_cleansed) <> '')
  AND (latitude IS NULL OR longitude IS NULL);

-- 4) Price format & validity checks (RAW price is TEXT)
-- Common formats: "$123.00", "123", "123.00", sometimes empty or null
-- 4.1 Missing/blank price
SELECT COUNT(*) AS missing_price
FROM airbnb_listings_raw
WHERE price IS NULL OR TRIM(price) = '';

-- 4.2 Non-numeric price after removing $, commas
-- This flags rows that cannot be safely converted to numeric in the cleaning step.
SELECT COUNT(*) AS invalid_price_format
FROM airbnb_listings_raw
WHERE price IS NOT NULL
  AND TRIM(price) <> ''
  AND REGEXP_REPLACE(price, '[$,]', '', 'g') !~ '^[0-9]+(\.[0-9]+)?$';

-- 4.3 Suspicious price outliers (requires conversion)
-- We create a safe numeric expression only where conversion is valid.
WITH priced AS (
  SELECT
    id,
    NULLIF(REGEXP_REPLACE(price, '[$,]', '', 'g'), '')::NUMERIC AS price_num
  FROM airbnb_listings_raw
  WHERE price IS NOT NULL
    AND TRIM(price) <> ''
    AND REGEXP_REPLACE(price, '[$,]', '', 'g') ~ '^[0-9]+(\.[0-9]+)?$'
)
SELECT
  COUNT(*) AS extreme_price_count
FROM priced
WHERE price_num <= 0 OR price_num > 2000;

-- 5) Nights & availability sanity checks
-- 5.1 Minimum nights greater than maximum nights (if both present)
SELECT COUNT(*) AS min_gt_max_nights
FROM airbnb_listings_raw
WHERE minimum_nights IS NOT NULL
  AND maximum_nights IS NOT NULL
  AND minimum_nights > maximum_nights;

-- 5.2 Negative or impossible availability values
SELECT COUNT(*) AS invalid_availability
FROM airbnb_listings_raw
WHERE (availability_30  IS NOT NULL AND (availability_30  < 0 OR availability_30  > 30))
   OR (availability_60  IS NOT NULL AND (availability_60  < 0 OR availability_60  > 60))
   OR (availability_90  IS NOT NULL AND (availability_90  < 0 OR availability_90  > 90))
   OR (availability_365 IS NOT NULL AND (availability_365 < 0 OR availability_365 > 365));

-- 6) Category consistency checks
-- 6.1 Unexpected room_type values (quick scan)
SELECT room_type, COUNT(*) AS cnt
FROM airbnb_listings_raw
GROUP BY room_type
ORDER BY cnt DESC;

-- 6.2 Property type scan (top values)
SELECT property_type, COUNT(*) AS cnt
FROM airbnb_listings_raw
GROUP BY property_type
ORDER BY cnt DESC
LIMIT 25;

-- 7) Host rate fields (stored as TEXT, often like "90%")
-- 7.1 Invalid response rate format
SELECT COUNT(*) AS invalid_host_response_rate
FROM airbnb_listings_raw
WHERE host_response_rate IS NOT NULL
  AND TRIM(host_response_rate) <> ''
  AND host_response_rate !~ '^[0-9]{1,3}%$';

-- 7.2 Invalid acceptance rate format
SELECT COUNT(*) AS invalid_host_acceptance_rate
FROM airbnb_listings_raw
WHERE host_acceptance_rate IS NOT NULL
  AND TRIM(host_acceptance_rate) <> ''
  AND host_acceptance_rate !~ '^[0-9]{1,3}%$';

-- 7.3 Rates > 100% (should not happen)
WITH rates AS (
  SELECT
    id,
    CASE
      WHEN host_response_rate ~ '^[0-9]{1,3}%$'
      THEN REPLACE(host_response_rate, '%', '')::INT
      ELSE NULL
    END AS response_rate_num,
    CASE
      WHEN host_acceptance_rate ~ '^[0-9]{1,3}%$'
      THEN REPLACE(host_acceptance_rate, '%', '')::INT
      ELSE NULL
    END AS acceptance_rate_num
  FROM airbnb_listings_raw
)
SELECT
  SUM(CASE WHEN response_rate_num   IS NOT NULL AND response_rate_num   > 100 THEN 1 ELSE 0 END) AS response_rate_gt_100,
  SUM(CASE WHEN acceptance_rate_num IS NOT NULL AND acceptance_rate_num > 100 THEN 1 ELSE 0 END) AS acceptance_rate_gt_100
FROM rates;

-- 8) Review score ranges (usually 0-5 or 0-100 depending on dataset; we check for negatives and absurd values)
SELECT COUNT(*) AS invalid_review_scores
FROM airbnb_listings_raw
WHERE (review_scores_rating IS NOT NULL AND (review_scores_rating < 0 OR review_scores_rating > 100))
   OR (review_scores_accuracy IS NOT NULL AND (review_scores_accuracy < 0 OR review_scores_accuracy > 10))
   OR (review_scores_cleanliness IS NOT NULL AND (review_scores_cleanliness < 0 OR review_scores_cleanliness > 10))
   OR (review_scores_checkin IS NOT NULL AND (review_scores_checkin < 0 OR review_scores_checkin > 10))
   OR (review_scores_communication IS NOT NULL AND (review_scores_communication < 0 OR review_scores_communication > 10))
   OR (review_scores_location IS NOT NULL AND (review_scores_location < 0 OR review_scores_location > 10))
   OR (review_scores_value IS NOT NULL AND (review_scores_value < 0 OR review_scores_value > 10));

-- 9) Final: a compact “issue summary” style output (useful for README)
SELECT
  (SELECT COUNT(*) FROM airbnb_listings_raw) AS total_rows,
  (SELECT COUNT(*) FROM airbnb_listings_raw WHERE id IS NULL) AS missing_id,
  (SELECT COUNT(*) FROM airbnb_listings_raw WHERE price IS NULL OR TRIM(price) = '') AS missing_price,
  (SELECT COUNT(*) FROM airbnb_listings_raw WHERE latitude IS NULL OR longitude IS NULL) AS missing_geo;
