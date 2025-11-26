/*
================================================================================
NHS WINTER PRESSURE ANALYTICS - DIMENSIONAL LINKING & MASTER JOIN
================================================================================
Author: Data Analyst Portfolio Project
Purpose: Create enriched dataset by joining NHS hospital data with:
         - Weather data (daily, city-level)
         - Google Trends data (weekly, expanded to daily)
         
This demonstrates advanced SQL joins, CTEs, and temporal data handling.

Database: NHS_WinterPressure (SQL Server)
================================================================================
*/

-- ============================================================================
-- SECTION 1: GOOGLE TRENDS DATA TRANSFORMATION
-- ============================================================================
-- Google Trends data is weekly. We need to expand it to daily for joins.

-- 1.1 Pivot Weekly Trends Data (Long to Wide format)
WITH GoogleTrendsPivot AS (
    SELECT 
        date AS week_start_date,
        MAX(CASE WHEN keyword = 'A&E wait times' THEN search_volume END) AS trend_ae_wait,
        MAX(CASE WHEN keyword = 'cold and flu' THEN search_volume END) AS trend_cold_flu,
        MAX(CASE WHEN keyword = 'emergency room' THEN search_volume END) AS trend_emergency,
        MAX(CASE WHEN keyword = 'fever' THEN search_volume END) AS trend_fever,
        MAX(CASE WHEN keyword = 'flu symptoms' THEN search_volume END) AS trend_flu_symptoms
    FROM [google_trends_2025-11-21]
    GROUP BY date
)
SELECT * FROM GoogleTrendsPivot ORDER BY week_start_date;


-- 1.2 Expand Weekly Trends to Daily Granularity
-- Each weekly trend value is applied to the following 7 days
WITH GoogleTrendsPivot AS (
    SELECT 
        date AS week_start_date,
        MAX(CASE WHEN keyword = 'A&E wait times' THEN search_volume END) AS trend_ae_wait,
        MAX(CASE WHEN keyword = 'cold and flu' THEN search_volume END) AS trend_cold_flu,
        MAX(CASE WHEN keyword = 'emergency room' THEN search_volume END) AS trend_emergency,
        MAX(CASE WHEN keyword = 'fever' THEN search_volume END) AS trend_fever,
        MAX(CASE WHEN keyword = 'flu symptoms' THEN search_volume END) AS trend_flu_symptoms
    FROM [google_trends_2025-11-21]
    GROUP BY date
),
DailyTrends AS (
    SELECT 
        d.date,
        gt.trend_ae_wait,
        gt.trend_cold_flu,
        gt.trend_emergency,
        gt.trend_fever,
        gt.trend_flu_symptoms
    FROM DimDate d
    JOIN GoogleTrendsPivot gt 
      ON d.date >= gt.week_start_date 
      AND d.date < DATEADD(day, 7, gt.week_start_date)
)
SELECT TOP 20 * FROM DailyTrends ORDER BY date;


-- ============================================================================
-- SECTION 2: MASTER ENRICHED DATASET JOIN
-- ============================================================================
-- Combines NHS hospital metrics with weather and Google Trends data

WITH 
-- A. Pivot Google Trends (Weekly Data)
GoogleTrendsPivot AS (
    SELECT 
        date AS week_start_date,
        MAX(CASE WHEN keyword = 'A&E wait times' THEN search_volume END) AS trend_ae_wait,
        MAX(CASE WHEN keyword = 'cold and flu' THEN search_volume END) AS trend_cold_flu,
        MAX(CASE WHEN keyword = 'emergency room' THEN search_volume END) AS trend_emergency,
        MAX(CASE WHEN keyword = 'fever' THEN search_volume END) AS trend_fever,
        MAX(CASE WHEN keyword = 'flu symptoms' THEN search_volume END) AS trend_flu_symptoms
    FROM [google_trends_2025-11-21]
    GROUP BY date
),

-- B. Expand Trends to Daily (Join Logic Helper)
-- Assuming trend date is Sunday, valid for next 6 days
DailyTrends AS (
    SELECT 
        d.date,
        gt.trend_ae_wait,
        gt.trend_cold_flu,
        gt.trend_emergency,
        gt.trend_fever,
        gt.trend_flu_symptoms
    FROM DimDate d
    JOIN GoogleTrendsPivot gt 
      ON d.date >= gt.week_start_date 
      AND d.date < DATEADD(day, 7, gt.week_start_date)
),

-- C. Geographic Mapping (Weather City to NHS Region)
RegionCityMap AS (
    SELECT 'Midlands' AS region_name, 'Birmingham' AS city UNION ALL
    SELECT 'South West', 'Bristol' UNION ALL
    SELECT 'North East and Yorkshire', 'Leeds' UNION ALL
    SELECT 'North West', 'Liverpool' UNION ALL
    SELECT 'London', 'London' UNION ALL
    SELECT 'South East', 'London' UNION ALL -- PROXY
    SELECT 'East of England', 'Norwich'
)

-- D. Main Join: NHS Data + Weather + Trends
SELECT TOP 1000
    f.date,
    d_org.trust_code,
    d_org.trust_name,
    d_org.region_name,
    f.metric_name,
    f.metric_value,
    
    -- Weather Context (Daily, City-Level linked via Region)
    w.temp_mean,
    w.rain_sum,
    w.wind_speed_max,
    
    -- Google Trends (Weekly propagated to Daily)
    dt.trend_ae_wait,
    dt.trend_cold_flu,
    dt.trend_fever

FROM FactNhsDailyPressure f
LEFT JOIN DimOrganisation d_org ON f.org_key = d_org.org_key
LEFT JOIN RegionCityMap rcm ON d_org.region_name = rcm.region_name
LEFT JOIN [weather_data_2025-11-21] w ON f.date = w.date AND rcm.city = w.city
LEFT JOIN DailyTrends dt ON f.date = dt.date
ORDER BY f.date DESC, d_org.trust_code;


/*
================================================================================
END OF DIMENSIONAL LINKING
================================================================================
Key Techniques Demonstrated:
1. CTE chaining for complex transformations
2. PIVOT pattern using conditional aggregation
3. Date range joins for weekly-to-daily expansion
4. Multi-source LEFT JOINs with geographic mapping
5. Handling surrogate keys vs. natural keys in star schema
================================================================================
*/

