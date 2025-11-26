/*
================================================================================
NHS WINTER PRESSURE ANALYTICS - GEOGRAPHIC DATA MAPPING
================================================================================
Author: Data Analyst Portfolio Project
Purpose: Map external weather data cities to NHS England regions
         This enables enrichment of hospital data with weather context
         for predictive analytics and correlation analysis.

Database: NHS_WinterPressure (SQL Server)
================================================================================
*/

-- ============================================================================
-- SECTION 1: GEOGRAPHIC MAPPING DEFINITION
-- ============================================================================
-- Define the mapping between weather data cities and NHS regions
-- Note: Some regions require proxy cities due to data availability

WITH CityRegionMap AS (
    SELECT 'Birmingham' AS city, 'Midlands' AS region_name UNION ALL
    SELECT 'Bristol', 'South West' UNION ALL
    SELECT 'Leeds', 'North East and Yorkshire' UNION ALL
    SELECT 'Liverpool', 'North West' UNION ALL
    SELECT 'London', 'London' UNION ALL
    SELECT 'Manchester', 'North West' UNION ALL
    SELECT 'Norwich', 'East of England' UNION ALL
    SELECT 'Edinburgh', 'Other' -- Scotland: Not in NHS England data
)
SELECT 
    m.region_name,
    w.city,
    COUNT(*) AS weather_records
FROM [weather_data_2025-11-21] w
JOIN CityRegionMap m ON w.city = m.city
GROUP BY m.region_name, w.city
ORDER BY m.region_name;


-- ============================================================================
-- SECTION 2: REGIONAL COVERAGE ANALYSIS
-- ============================================================================
-- Identify which NHS regions have direct vs proxy weather coverage

SELECT 
    o.region_name,
    COUNT(DISTINCT o.trust_code) AS trust_count,
    CASE 
        WHEN o.region_name = 'South East' THEN 'Missing - Using London as proxy'
        WHEN o.region_name = 'Midlands' THEN 'Covered - Birmingham'
        WHEN o.region_name = 'South West' THEN 'Covered - Bristol'
        WHEN o.region_name = 'North East and Yorkshire' THEN 'Covered - Leeds'
        WHEN o.region_name = 'North West' THEN 'Covered - Liverpool/Manchester'
        WHEN o.region_name = 'London' THEN 'Covered - London'
        WHEN o.region_name = 'East of England' THEN 'Covered - Norwich'
        ELSE 'Unknown Coverage'
    END AS weather_coverage_status
FROM DimOrganisation o
GROUP BY o.region_name
ORDER BY trust_count DESC;


-- ============================================================================
-- SECTION 3: COMPLETE REGION-CITY MAPPING TABLE
-- ============================================================================
-- Reusable CTE for joining weather data to NHS regional data
-- Note: South East region uses London as a geographic proxy

/*
Use this CTE in any query requiring weather enrichment:
*/

SELECT 'Midlands' AS region_name, 'Birmingham' AS city UNION ALL
SELECT 'South West', 'Bristol' UNION ALL
SELECT 'North East and Yorkshire', 'Leeds' UNION ALL
SELECT 'North West', 'Liverpool' UNION ALL
SELECT 'London', 'London' UNION ALL
SELECT 'South East', 'London' UNION ALL  -- PROXY: No South East city in weather data
SELECT 'East of England', 'Norwich';


-- ============================================================================
-- SECTION 4: VALIDATE MAPPING COMPLETENESS
-- ============================================================================
-- Ensure all NHS regions can be linked to weather data

WITH RegionCityMap AS (
    SELECT 'Midlands' AS region_name, 'Birmingham' AS city UNION ALL
    SELECT 'South West', 'Bristol' UNION ALL
    SELECT 'North East and Yorkshire', 'Leeds' UNION ALL
    SELECT 'North West', 'Liverpool' UNION ALL
    SELECT 'London', 'London' UNION ALL
    SELECT 'South East', 'London' UNION ALL
    SELECT 'East of England', 'Norwich'
)
SELECT 
    o.region_name AS nhs_region,
    rcm.city AS mapped_city,
    CASE WHEN rcm.city IS NULL THEN 'NO MAPPING' ELSE 'MAPPED' END AS status
FROM (SELECT DISTINCT region_name FROM DimOrganisation) o
LEFT JOIN RegionCityMap rcm ON o.region_name = rcm.region_name
ORDER BY status DESC, nhs_region;


/*
================================================================================
END OF GEOGRAPHIC MAPPING
================================================================================
Key Notes for Implementation:
1. South East region uses London weather data as proxy
2. Scotland (Edinburgh) data excluded from NHS England analysis
3. North West region has multiple cities - Liverpool used as primary
4. This mapping is critical for weather-based demand forecasting
================================================================================
*/

