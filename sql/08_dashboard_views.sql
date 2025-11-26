/*
================================================================================
NHS WINTER PRESSURE ANALYTICS - DASHBOARD VIEWS FOR POWER BI
================================================================================
Author: Data Analyst Portfolio Project
Purpose: Create optimized views for business intelligence dashboards:
         - vw_HospitalCapacity: Granular trust-level data
         - vw_SeasonalPressure: Regional aggregated KPIs
         - vw_TrendCorrelation: External drivers analysis

These views are designed to connect directly to Power BI with
business-friendly column names.

Database: NHS_WinterPressure (SQL Server)
================================================================================
*/

-- ============================================================================
-- VIEW 1: vw_HospitalCapacity
-- Purpose: Detailed trust-level daily data for drill-down analysis
-- Best For: Tables, detailed charts, individual trust analysis
-- ============================================================================

CREATE OR ALTER VIEW vw_HospitalCapacity AS
SELECT
    date,
    trust_code,
    trust_name,
    region_name,
    
    -- General & Acute Beds (Business-Friendly Names)
    ga_beds_open AS Beds_Open_General_Acute,
    ga_beds_occupied AS Beds_Occupied_General_Acute,
    ga_occupancy_rate AS Occupancy_Rate_General_Acute,
    is_high_pressure_event AS Flag_High_Pressure_Event,
    ga_occupancy_7day_avg AS Occupancy_Rate_7Day_Avg,
    
    -- Critical Care Beds
    cc_beds_open AS Beds_Open_Critical_Care,
    cc_beds_occupied AS Beds_Occupied_Critical_Care,
    cc_occupancy_rate AS Occupancy_Rate_Critical_Care,
    
    -- Flu Metrics
    flu_beds_occupied AS Beds_Occupied_Flu,
    simulated_flu_beds_spike AS Simulated_Flu_Spike_5Pct,
    
    -- External Context (Weather & Trends)
    region_temp_mean AS Weather_Temp_Mean_C,
    region_rain_sum AS Weather_Rain_Sum_mm,
    trend_ae_wait AS Google_Trend_AE_Wait_Score,
    trend_cold_flu AS Google_Trend_Cold_Flu_Score
FROM Analytics_HospitalCapacity;

GO


-- ============================================================================
-- VIEW 2: vw_SeasonalPressure
-- Purpose: Regional aggregated view for executive dashboards
-- Best For: KPI cards, heatmaps, high-level regional comparisons
-- ============================================================================

CREATE OR ALTER VIEW vw_SeasonalPressure AS
SELECT
    date,
    region_name,
    
    -- Aggregated Capacity Metrics
    SUM(Beds_Open_General_Acute) AS Region_Beds_Open,
    SUM(Beds_Occupied_General_Acute) AS Region_Beds_Occupied,
    CASE 
        WHEN SUM(Beds_Open_General_Acute) > 0 
        THEN CAST(SUM(Beds_Occupied_General_Acute) AS FLOAT) / SUM(Beds_Open_General_Acute) 
        ELSE 0 
    END AS Region_Occupancy_Rate,
    
    -- Pressure Monitoring Metrics
    SUM(Flag_High_Pressure_Event) AS Count_Trusts_High_Pressure,
    COUNT(trust_code) AS Count_Trusts_Reporting,
    CAST(SUM(Flag_High_Pressure_Event) AS FLOAT) / COUNT(trust_code) AS Pct_Trusts_Under_Pressure,
    
    -- Environmental Context (Region Average)
    AVG(Weather_Temp_Mean_C) AS Region_Avg_Temp_C,
    MAX(Google_Trend_AE_Wait_Score) AS Region_AE_Wait_Trend
FROM vw_HospitalCapacity
GROUP BY date, region_name;

GO


-- ============================================================================
-- VIEW 3: vw_TrendCorrelation
-- Purpose: Analyze correlation between external factors and hospital demand
-- Best For: Scatter plots, dual-axis charts, correlation analysis
-- ============================================================================

CREATE OR ALTER VIEW vw_TrendCorrelation AS
SELECT
    date,
    region_name,
    
    -- Hospital Demand Signals
    SUM(Beds_Occupied_Flu) AS Total_Flu_Patients,
    SUM(Beds_Occupied_Critical_Care) AS Total_Critical_Care_Patients,
    SUM(Beds_Occupied_General_Acute) AS Total_GA_Patients,
    
    -- External Drivers
    AVG(Weather_Temp_Mean_C) AS Avg_Temp_C,
    AVG(Weather_Rain_Sum_mm) AS Avg_Rain_mm,
    MAX(Google_Trend_Cold_Flu_Score) AS Trend_Cold_Flu,
    MAX(Google_Trend_AE_Wait_Score) AS Trend_AE_Wait
FROM vw_HospitalCapacity
GROUP BY date, region_name;

GO


-- ============================================================================
-- VERIFICATION: Confirm All Views Exist
-- ============================================================================

SELECT TABLE_NAME 
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_TYPE = 'VIEW' 
  AND TABLE_NAME IN ('vw_HospitalCapacity', 'vw_SeasonalPressure', 'vw_TrendCorrelation')
ORDER BY TABLE_NAME;


-- ============================================================================
-- SAMPLE QUERIES FOR EACH VIEW
-- ============================================================================

-- Sample from vw_HospitalCapacity (Trust-Level)
SELECT TOP 5 * 
FROM vw_HospitalCapacity 
ORDER BY date DESC;

-- Sample from vw_SeasonalPressure (Regional Aggregates)
SELECT TOP 5 * 
FROM vw_SeasonalPressure 
ORDER BY date DESC;

-- Sample from vw_TrendCorrelation (Driver Analysis)
SELECT TOP 5 * 
FROM vw_TrendCorrelation 
ORDER BY date DESC;


/*
================================================================================
END OF DASHBOARD VIEWS
================================================================================
Power BI Connection Instructions:
1. Get Data -> SQL Server
2. Server: [Your SQL Server Instance]
3. Database: NHS_WinterPressure
4. Select all three views for import
5. Create relationships on 'date' column if not auto-detected

Dashboard Page Recommendations:
- Page 1: Executive Overview (Use vw_SeasonalPressure)
- Page 2: Regional Deep Dive (Use vw_HospitalCapacity with region slicer)
- Page 3: Correlation Analysis (Use vw_TrendCorrelation)
================================================================================
*/

