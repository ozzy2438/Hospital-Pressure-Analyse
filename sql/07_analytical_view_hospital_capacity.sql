/*
================================================================================
NHS WINTER PRESSURE ANALYTICS - ANALYTICAL VIEW: HOSPITAL CAPACITY
================================================================================
Author: Data Analyst Portfolio Project
Purpose: Create the primary analytical view combining all data sources
         with calculated features for dashboard and reporting use.

This view serves as the foundation for:
- Power BI dashboards
- Executive reporting
- Machine learning feature stores

Database: NHS_WinterPressure (SQL Server)
================================================================================
*/

CREATE OR ALTER VIEW Analytics_HospitalCapacity AS
WITH 
-- ============================================================================
-- STEP 1: BASE PIVOT - Daily Metrics per Trust
-- ============================================================================
DailyPivot AS (
    SELECT
        f.date,
        f.org_key,
        d_org.trust_code,
        d_org.trust_name,
        d_org.region_name,
        
        -- Pivot Metrics from Long to Wide format
        MAX(CASE WHEN metric_name = 'beds_open' THEN metric_value END) AS ga_beds_open,
        MAX(CASE WHEN metric_name = 'beds_occupied' THEN metric_value END) AS ga_beds_occupied,
        MAX(CASE WHEN metric_name = 'cc_adult_beds_open' THEN metric_value END) AS cc_beds_open,
        MAX(CASE WHEN metric_name = 'cc_adult_beds_occupied' THEN metric_value END) AS cc_beds_occupied,
        MAX(CASE WHEN metric_name = 'flu_beds_occupied' THEN metric_value END) AS flu_beds_occupied
    FROM FactNhsDailyPressure f
    JOIN DimOrganisation d_org ON f.org_key = d_org.org_key
    GROUP BY f.date, f.org_key, d_org.trust_code, d_org.trust_name, d_org.region_name
),

-- ============================================================================
-- STEP 2: EXTERNAL DATA - Weather & Trends (Aggregated by Region)
-- ============================================================================
ExternalData AS (
    SELECT
        f.date,
        d_org.region_name,
        AVG(w.temp_mean) AS region_temp_mean,
        AVG(w.rain_sum) AS region_rain_sum,
        MAX(dt.trend_ae_wait) AS trend_ae_wait,
        MAX(dt.trend_cold_flu) AS trend_cold_flu
    FROM FactNhsDailyPressure f
    JOIN DimOrganisation d_org ON f.org_key = d_org.org_key
    -- Geographic Proxy Mapping
    LEFT JOIN (
        SELECT 'Midlands' AS region_name, 'Birmingham' AS city UNION ALL
        SELECT 'South West', 'Bristol' UNION ALL
        SELECT 'North East and Yorkshire', 'Leeds' UNION ALL
        SELECT 'North West', 'Liverpool' UNION ALL
        SELECT 'London', 'London' UNION ALL
        SELECT 'South East', 'London' UNION ALL
        SELECT 'East of England', 'Norwich'
    ) rcm ON d_org.region_name = rcm.region_name
    -- Weather Join (Daily)
    LEFT JOIN [weather_data_2025-11-21] w 
        ON f.date = w.date AND rcm.city = w.city
    -- Google Trends Join (Weekly expanded to Daily)
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

-- ============================================================================
-- STEP 3: FINAL PROJECTION - Feature Engineering & Enrichment
-- ============================================================================
SELECT
    base.date,
    base.trust_code,
    base.trust_name,
    base.region_name,
    
    -- General & Acute Beds: Raw Metrics
    base.ga_beds_open,
    base.ga_beds_occupied,
    
    -- Calculated: G&A Occupancy Rate
    CASE 
        WHEN base.ga_beds_open > 0 
        THEN CAST(base.ga_beds_occupied AS FLOAT) / base.ga_beds_open 
        ELSE 0 
    END AS ga_occupancy_rate,
    
    -- Calculated: High Pressure Event Flag (Threshold: 85%)
    CASE 
        WHEN (CASE WHEN base.ga_beds_open > 0 
                   THEN CAST(base.ga_beds_occupied AS FLOAT) / base.ga_beds_open 
                   ELSE 0 END) > 0.85 
        THEN 1 
        ELSE 0 
    END AS is_high_pressure_event,
    
    -- Window Function: 7-Day Moving Average Occupancy
    AVG(CASE WHEN base.ga_beds_open > 0 
             THEN CAST(base.ga_beds_occupied AS FLOAT) / base.ga_beds_open 
             ELSE 0 END) 
        OVER (
            PARTITION BY base.trust_code 
            ORDER BY base.date 
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) AS ga_occupancy_7day_avg,
    
    -- Window Function: Previous Day Occupancy (Lag)
    LAG(base.ga_beds_occupied, 1) 
        OVER (
            PARTITION BY base.trust_code 
            ORDER BY base.date
        ) AS ga_occupied_lag_1,

    -- Critical Care Beds: Raw Metrics
    base.cc_beds_open,
    base.cc_beds_occupied,
    
    -- Calculated: Critical Care Occupancy Rate
    CASE 
        WHEN base.cc_beds_open > 0 
        THEN CAST(base.cc_beds_occupied AS FLOAT) / base.cc_beds_open 
        ELSE 0 
    END AS cc_occupancy_rate,

    -- Flu & Simulation Features
    base.flu_beds_occupied,
    base.flu_beds_occupied * 1.05 AS simulated_flu_beds_spike,

    -- External Context: Weather & Trends
    ext.region_temp_mean,
    ext.region_rain_sum,
    ext.trend_ae_wait,
    ext.trend_cold_flu

FROM DailyPivot base
LEFT JOIN ExternalData ext 
    ON base.date = ext.date 
    AND base.region_name = ext.region_name;

GO

-- ============================================================================
-- VERIFICATION QUERY
-- ============================================================================
-- Run after creating the view to verify output

SELECT TOP 10 * 
FROM Analytics_HospitalCapacity 
ORDER BY date DESC;


/*
================================================================================
END OF ANALYTICAL VIEW - HOSPITAL CAPACITY
================================================================================
View Columns:
- date, trust_code, trust_name, region_name: Dimension attributes
- ga_beds_open, ga_beds_occupied: G&A raw metrics
- ga_occupancy_rate: Calculated percentage
- is_high_pressure_event: Binary flag (1 if >85%)
- ga_occupancy_7day_avg: Rolling average for trend analysis
- ga_occupied_lag_1: Yesterday's value for comparison
- cc_beds_open, cc_beds_occupied, cc_occupancy_rate: Critical care metrics
- flu_beds_occupied, simulated_flu_beds_spike: Flu data with simulation
- region_temp_mean, region_rain_sum: Weather context
- trend_ae_wait, trend_cold_flu: Google Trends signals
================================================================================
*/

