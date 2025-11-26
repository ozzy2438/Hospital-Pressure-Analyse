/*
================================================================================
NHS WINTER PRESSURE ANALYTICS - FEATURE ENGINEERING
================================================================================
Author: Data Analyst Portfolio Project
Purpose: Create analysis-ready features including:
         - Calculated occupancy rates
         - Pressure threshold flags
         - Window functions (moving averages, lag values)
         - What-if simulation features
         
This demonstrates advanced SQL analytics for machine learning preparation.

Database: NHS_WinterPressure (SQL Server)
================================================================================
*/

-- ============================================================================
-- SECTION 1: PIVOT METRICS (Long to Wide Format)
-- ============================================================================
-- Transform fact table from long format to wide format for analysis

WITH DailyPivot AS (
    SELECT
        f.date,
        f.org_key,
        d_org.trust_code,
        d_org.region_name,
        
        -- General & Acute Bed Metrics
        MAX(CASE WHEN metric_name = 'beds_open' THEN metric_value END) AS ga_beds_open,
        MAX(CASE WHEN metric_name = 'beds_occupied' THEN metric_value END) AS ga_beds_occupied,
        
        -- Critical Care Metrics
        MAX(CASE WHEN metric_name = 'cc_adult_beds_open' THEN metric_value END) AS cc_beds_open,
        MAX(CASE WHEN metric_name = 'cc_adult_beds_occupied' THEN metric_value END) AS cc_beds_occupied,
        
        -- Flu Metrics
        MAX(CASE WHEN metric_name = 'flu_beds_occupied' THEN metric_value END) AS flu_beds_occupied
    FROM FactNhsDailyPressure f
    JOIN DimOrganisation d_org ON f.org_key = d_org.org_key
    GROUP BY f.date, f.org_key, d_org.trust_code, d_org.region_name
)
SELECT TOP 100 * FROM DailyPivot ORDER BY date DESC, trust_code;


-- ============================================================================
-- SECTION 2: FEATURE ENGINEERING WITH WINDOW FUNCTIONS
-- ============================================================================
-- Create analytical features including rates, flags, and temporal features

WITH 
-- Step 1: Base Pivot - Convert Long to Wide Format for Ratio Calculations
DailyPivot AS (
    SELECT
        f.date,
        f.org_key,
        d_org.trust_code,
        d_org.region_name,
        
        -- G&A Bed Metrics
        MAX(CASE WHEN metric_name = 'beds_open' THEN metric_value END) AS ga_beds_open,
        MAX(CASE WHEN metric_name = 'beds_occupied' THEN metric_value END) AS ga_beds_occupied,
        
        -- Critical Care Metrics
        MAX(CASE WHEN metric_name = 'cc_adult_beds_open' THEN metric_value END) AS cc_beds_open,
        MAX(CASE WHEN metric_name = 'cc_adult_beds_occupied' THEN metric_value END) AS cc_beds_occupied,
        
        -- Flu Metrics
        MAX(CASE WHEN metric_name = 'flu_beds_occupied' THEN metric_value END) AS flu_beds_occupied
    FROM FactNhsDailyPressure f
    JOIN DimOrganisation d_org ON f.org_key = d_org.org_key
    GROUP BY f.date, f.org_key, d_org.trust_code, d_org.region_name
),

-- Step 2: External Data Preparation
ExternalData AS (
    SELECT
        f.date,
        d_org.region_name,
        -- Weather (Daily, City-Level linked to Region)
        AVG(w.temp_mean) AS region_temp_mean,
        AVG(w.rain_sum) AS region_rain_sum,
        
        -- Google Trends (Weekly -> Daily expansion)
        MAX(dt.trend_ae_wait) AS trend_ae_wait,
        MAX(dt.trend_cold_flu) AS trend_cold_flu
    FROM FactNhsDailyPressure f
    JOIN DimOrganisation d_org ON f.org_key = d_org.org_key
    -- Region-City Mapping
    LEFT JOIN (
        SELECT 'Midlands' AS region_name, 'Birmingham' AS city UNION ALL
        SELECT 'South West', 'Bristol' UNION ALL
        SELECT 'North East and Yorkshire', 'Leeds' UNION ALL
        SELECT 'North West', 'Liverpool' UNION ALL
        SELECT 'London', 'London' UNION ALL
        SELECT 'South East', 'London' UNION ALL
        SELECT 'East of England', 'Norwich'
    ) rcm ON d_org.region_name = rcm.region_name
    -- Weather Join
    LEFT JOIN [weather_data_2025-11-21] w ON f.date = w.date AND rcm.city = w.city
    -- Trends Join (Simplified for CTE)
    LEFT JOIN (
        SELECT 
            d.date,
            gt.search_volume AS trend_ae_wait,
            gt2.search_volume AS trend_cold_flu
        FROM DimDate d
        LEFT JOIN [google_trends_2025-11-21] gt 
            ON d.date >= gt.date 
            AND d.date < DATEADD(day, 7, gt.date) 
            AND gt.keyword = 'A&E wait times'
        LEFT JOIN [google_trends_2025-11-21] gt2 
            ON d.date >= gt2.date 
            AND d.date < DATEADD(day, 7, gt2.date) 
            AND gt2.keyword = 'cold and flu'
    ) dt ON f.date = dt.date
    GROUP BY f.date, d_org.region_name
)

-- Step 3: Feature Calculation with Window Functions
SELECT TOP 1000
    base.date,
    base.trust_code,
    base.region_name,
    
    -- A. Calculated Occupancy Rates
    base.ga_beds_occupied,
    base.ga_beds_open,
    CASE 
        WHEN base.ga_beds_open > 0 
        THEN CAST(base.ga_beds_occupied AS FLOAT) / base.ga_beds_open 
        ELSE 0 
    END AS ga_occupancy_rate,
    
    -- B. High Pressure Event Flag (>85% Occupancy is industry threshold)
    CASE 
        WHEN (CASE WHEN base.ga_beds_open > 0 
                   THEN CAST(base.ga_beds_occupied AS FLOAT) / base.ga_beds_open 
                   ELSE 0 END) > 0.85 
        THEN 1 
        ELSE 0 
    END AS is_high_pressure_event,
    
    -- C. Window Functions for Temporal Features
    
    -- 7-Day Moving Average of Occupancy Rate
    AVG(CASE WHEN base.ga_beds_open > 0 
             THEN CAST(base.ga_beds_occupied AS FLOAT) / base.ga_beds_open 
             ELSE 0 END) 
        OVER (
            PARTITION BY base.trust_code 
            ORDER BY base.date 
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) AS ga_occupancy_7day_avg,
        
    -- Previous Day Occupancy (Lag Feature for ML)
    LAG(base.ga_beds_occupied, 1) 
        OVER (
            PARTITION BY base.trust_code 
            ORDER BY base.date
        ) AS ga_occupied_lag_1,
    
    -- D. External Context Features
    ext.region_temp_mean,
    ext.trend_cold_flu,
    
    -- E. What-If Simulation Feature
    -- Scenario: If Google Trend 'cold and flu' increases by 20%, assume 5% increase in Flu Beds
    base.flu_beds_occupied AS current_flu_beds,
    base.flu_beds_occupied * 1.05 AS simulated_flu_beds_spike
    
FROM DailyPivot base
LEFT JOIN ExternalData ext 
    ON base.date = ext.date 
    AND base.region_name = ext.region_name
ORDER BY base.trust_code, base.date;


/*
================================================================================
END OF FEATURE ENGINEERING
================================================================================
Key Features Created:
1. ga_occupancy_rate: Real-time bed utilization percentage
2. is_high_pressure_event: Binary flag for >85% occupancy
3. ga_occupancy_7day_avg: Smoothed trend indicator (rolling average)
4. ga_occupied_lag_1: Previous day value for time-series analysis
5. simulated_flu_beds_spike: What-if scenario modeling

SQL Techniques Demonstrated:
- Conditional aggregation (PIVOT pattern)
- CASE expressions for calculated fields
- Window functions: AVG() OVER, LAG()
- Multi-CTE query architecture
================================================================================
*/

