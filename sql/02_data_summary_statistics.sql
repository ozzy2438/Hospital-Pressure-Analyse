/*
================================================================================
NHS WINTER PRESSURE ANALYTICS - DATA SUMMARY STATISTICS
================================================================================
Author: Data Analyst Portfolio Project
Purpose: Comprehensive summary statistics for all tables
         Understanding data volume, date ranges, and unique identifiers
         is critical for planning analytical queries.

Database: NHS_WinterPressure (SQL Server)
================================================================================
*/

-- ============================================================================
-- SECTION 1: FACT TABLES SUMMARY
-- ============================================================================
-- Understanding the scope and coverage of each fact table

SELECT 
    'FactNhsDailyPressure' AS table_name,
    COUNT(*) AS total_records,
    COUNT(DISTINCT date) AS distinct_dates,
    MIN(date) AS min_date,
    MAX(date) AS max_date,
    COUNT(DISTINCT trust_code) AS distinct_trusts,
    COUNT(DISTINCT region_name) AS distinct_regions,
    COUNT(DISTINCT metric_name) AS distinct_metrics
FROM FactNhsDailyPressure

UNION ALL

SELECT 
    'Fact_GA_Beds' AS table_name,
    COUNT(*) AS total_records,
    COUNT(DISTINCT date) AS distinct_dates,
    MIN(date) AS min_date,
    MAX(date) AS max_date,
    COUNT(DISTINCT trust_code) AS distinct_trusts,
    COUNT(DISTINCT region_name) AS distinct_regions,
    4 AS distinct_metrics  -- beds_open, beds_unavailable_non_covid, beds_occupied, occupancy_rate
FROM Fact_GA_Beds

UNION ALL

SELECT 
    'Fact_Flu_Beds' AS table_name,
    COUNT(*) AS total_records,
    COUNT(DISTINCT date) AS distinct_dates,
    MIN(date) AS min_date,
    MAX(date) AS max_date,
    COUNT(DISTINCT trust_code) AS distinct_trusts,
    COUNT(DISTINCT region_name) AS distinct_regions,
    2 AS distinct_metrics  -- flu_beds_occupied, flu_cc_beds_occupied
FROM Fact_Flu_Beds

UNION ALL

SELECT 
    'Fact_CC_Adult' AS table_name,
    COUNT(*) AS total_records,
    COUNT(DISTINCT date) AS distinct_dates,
    MIN(date) AS min_date,
    MAX(date) AS max_date,
    COUNT(DISTINCT trust_code) AS distinct_trusts,
    COUNT(DISTINCT region_name) AS distinct_regions,
    2 AS distinct_metrics  -- cc_adult_beds_open, cc_adult_beds_occupied
FROM Fact_CC_Adult;


-- ============================================================================
-- SECTION 2: EXTERNAL DATA SUMMARY
-- ============================================================================
-- Weather and Google Trends data coverage analysis

SELECT 
    'weather_data_2025-11-21' AS table_name,
    COUNT(*) AS total_records,
    COUNT(DISTINCT date) AS distinct_dates,
    MIN(date) AS min_date,
    MAX(date) AS max_date,
    COUNT(DISTINCT city) AS distinct_cities,
    0 AS distinct_keywords
FROM [weather_data_2025-11-21]

UNION ALL

SELECT 
    'google_trends_2025-11-21' AS table_name,
    COUNT(*) AS total_records,
    COUNT(DISTINCT date) AS distinct_dates,
    MIN(date) AS min_date,
    MAX(date) AS max_date,
    0 AS distinct_cities,
    COUNT(DISTINCT keyword) AS distinct_keywords
FROM [google_trends_2025-11-21];


-- ============================================================================
-- SECTION 3: DATE RANGE ALIGNMENT CHECK
-- ============================================================================
-- Critical for ensuring temporal data can be joined correctly

SELECT 'NHS Data' AS source, 
       MIN(date) AS start_date, 
       MAX(date) AS end_date, 
       COUNT(DISTINCT date) AS days 
FROM FactNhsDailyPressure

UNION ALL

SELECT 'Weather Data', 
       MIN(date), 
       MAX(date), 
       COUNT(DISTINCT date) 
FROM [weather_data_2025-11-21]

UNION ALL

SELECT 'Google Trends', 
       MIN(date), 
       MAX(date), 
       COUNT(DISTINCT date) 
FROM [google_trends_2025-11-21];


-- ============================================================================
-- SECTION 4: METRIC NAMES ENUMERATION
-- ============================================================================
-- List all unique metrics available in the FactNhsDailyPressure table

SELECT DISTINCT metric_name 
FROM FactNhsDailyPressure 
ORDER BY metric_name;


-- ============================================================================
-- SECTION 5: GEOGRAPHIC COVERAGE
-- ============================================================================
-- Understand the regional breakdown of the data

-- 5.1 NHS Regions in the Dataset
SELECT DISTINCT region_name 
FROM DimOrganisation 
ORDER BY region_name;

-- 5.2 Weather Cities Available
SELECT DISTINCT city 
FROM [weather_data_2025-11-21]
ORDER BY city;

-- 5.3 Regional Trust Count
SELECT 
    o.region_name,
    COUNT(DISTINCT o.trust_code) AS trust_count
FROM DimOrganisation o
GROUP BY o.region_name
ORDER BY trust_count DESC;


/*
================================================================================
END OF DATA SUMMARY STATISTICS
================================================================================
Key Insights:
- Multiple fact tables with overlapping date ranges
- External data (Weather, Trends) can be joined for enriched analysis
- 7 NHS regions with varying trust counts
- 8 UK cities for weather data coverage
================================================================================
*/

