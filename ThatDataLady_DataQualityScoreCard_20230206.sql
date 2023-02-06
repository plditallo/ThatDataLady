-- ***********************************************************************
-- ThatDataLady!: https://thatdatalady.wordpress.com/
-- Companion to blog post: MSSQL DQS, Oracle EDQ and The Data Quality Scorecard  dated: 2/16/2023
-- Topic of exploration: The Data Quality Scorecard
-- ***********************************************************************


-- PROFILING
-- Here is an example of SQL code that can be used as an approach to profile data and identify issues such as missing values, invalid values, and duplicates 
-- in a table of competitor pricing for tulip bulbs at a garden chain store.

-- This will give you a common table expression (CTE) of competitor prices with:
-- (1) missing_count: number of missing values
-- (2) invalid_count: number of invalid values. (example: price not between 0 and 100)
-- (3) duplicate_count: number of duplicate values.

--Note: Replace "tulip_pricing" with the name of the table you actually intend on profiling. Adjust the conditions for identifying invalid and duplicate values 
--      to match the specific requirements of your data, like if the price should be in a different range or if there is a different identifier of interest.


WITH missing_values AS (
  SELECT
    competitor_name,
    COUNT(*) AS missing_count
  FROM
    tulip_pricing
  GROUP BY
    competitor_name
  HAVING
    COUNT(*) = 0
), invalid_values AS (
  SELECT
    competitor_name,
    COUNT(*) AS invalid_count
  FROM
    tulip_pricing
  WHERE
    price NOT BETWEEN 0 AND 100
  GROUP BY
    competitor_name
), duplicate_values AS (
  SELECT
    competitor_name,
    COUNT(*) AS duplicate_count
  FROM
    tulip_pricing
  GROUP BY
    competitor_name,
    price
  HAVING
    COUNT(*) > 1
)
SELECT
  competitor_name,
  missing_count,
  invalid_count,
  duplicate_count
FROM
  missing_values
  JOIN invalid_values USING (competitor_name)
  JOIN duplicate_values USING (competitor_name);
  
  
 -- II. CLEANSING
 -- This sample SQL code can be used as an approach to correct identified issues in the data using built-in SQL functions such as REPLACE(), 
 -- SUBSTRING(), and UPPER() to standardize and cleanse data. Suppose a poorly maintained tulip bulb inventory for a retail garden store chain has following issues:
 -- (1) Some of the species names contain extra spaces before or after the name.
 -- (2) Some of the species names are in mixed case, while others are in all uppercase.
 -- (3) Some of the species names contain typos, like "Tulipa kaufmanniana" instead of "Tulipa kaufmanniana"
 
 -- This query will return a table with the same structure as the original table but with the species name standardized and typo corrected.
 
 WITH cleaned_data AS (
  SELECT 
    REPLACE(species, '  ', ' ') as species, -- remove extra spaces
    UPPER(SUBSTRING(species, 1, 1)) || SUBSTRING(species, 2) as species, -- standardize the case
    REPLACE(species, 'Tulipa kaufmanniana', 'Tulipa kaufmanniana') as species, -- correct the typo
    price,
    quantity
  FROM 
    tulip_inventory
)

SELECT
  species,
  price,
  quantity
FROM
  cleaned_data;

-- III. METRICS
-- This SQL code can be used as an approach to defining the metrics that measure the quality of the data of 
-- the poorly maintained inventory table of tulip varieties described in the last example.

-- This query will return a single row of the following metrics:

-- (1). total_missing: the total number of rows where species, price, or quantity is missing
-- (2). total_duplicates: the total number of duplicate rows based on species and price
-- (3). total_invalid: the total number of rows where price or quantity is less than 0
-- (4). total_outliers: the total number of rows where price or quantity is more than 3 standard deviations away from the mean

WITH missing_values AS (
  SELECT
    COUNT(*) AS total_missing
  FROM
    tulip_inventory
  WHERE
    species IS NULL OR price IS NULL OR quantity IS NULL
), duplicates AS (
  SELECT
    COUNT(*) AS total_duplicates
  FROM
    (SELECT 
      species,
      price,
      COUNT(*)
    FROM
      tulip_inventory
    GROUP BY
      species,
      price
    HAVING
      COUNT(*) > 1) AS duplicates
), invalid_values AS (
  SELECT
    COUNT(*) AS total_invalid
  FROM
    tulip_inventory
  WHERE
    price < 0 OR quantity < 0
), outliers AS (
  SELECT
    COUNT(*) AS total_outliers
  FROM
    tulip_inventory
  WHERE
    price > (SELECT AVG(price) + 3*STDDEV(price) FROM tulip_inventory) OR
    price < (SELECT AVG(price) - 3*STDDEV(price) FROM tulip_inventory) OR
    quantity > (SELECT AVG(quantity) + 3*STDDEV(quantity) FROM tulip_inventory) OR
    quantity < (SELECT AVG(quantity) - 3*STDDEV(quantity) FROM tulip_inventory)
)
SELECT
  total_missing,
  total_duplicates,
  total_invalid,
  total_outliers
FROM
  missing_values,
  duplicates,
  invalid_values,
  outliers;


-- IV. Scorecard 
-- This example of SQL code is an approach toward creating a scorecard that displays the results of the data quality metrics defined above.

-- This query will return a table with a single column metric and a single column value. The metric column contains the name of the metric 
-- and the value column contains the value of the metric. The query uses UNION ALL operator to combine multiple SELECT statements into a single result set.

-- Note: this is a bare-bones example of the types of measurements of interest. Scorecards generally track the quality of the data over time, rating each OF
--       metrics with a report card grading. 90-100% = A, 80-90% = B, 70-80% = C, and so on. This example does not track, or grade the state of the data. 

WITH missing_values AS (
  SELECT
    COUNT(*) AS total_missing
  FROM
    tulip_inventory
  WHERE
    species IS NULL OR price IS NULL OR quantity IS NULL
), duplicates AS (
  SELECT
    COUNT(*) AS total_duplicates
  FROM
    (SELECT 
      species,
      price,
      COUNT(*)
    FROM
      tulip_inventory
    GROUP BY
      species,
      price
    HAVING
      COUNT(*) > 1) AS duplicates
), invalid_values AS (
  SELECT
    COUNT(*) AS total_invalid
  FROM
    tulip_inventory
  WHERE
    price < 0 OR quantity < 0
), outliers AS (
  SELECT
    COUNT(*) AS total_outliers
  FROM
    tulip_inventory
  WHERE
    price > (SELECT AVG(price) + 3*STDDEV(price) FROM tulip_inventory) OR
    price < (SELECT AVG(price) - 3*STDDEV(price) FROM tulip_inventory) OR
    quantity > (SELECT AVG(quantity) + 3*STDDEV(quantity) FROM tulip_inventory) OR
    quantity < (SELECT AVG(quantity) - 3*STDDEV(quantity) FROM tulip_inventory)
)
SELECT 'Missing Values' as metric, total_missing as value
FROM missing_values
UNION ALL
SELECT 'Duplicates' as metric, total_duplicates as value
FROM duplicates
UNION ALL
SELECT 'Invalid Values' as metric, total_invalid as value
FROM invalid_values
UNION ALL
SELECT 'Outliers' as metric, total_outliers as value
FROM outliers;


