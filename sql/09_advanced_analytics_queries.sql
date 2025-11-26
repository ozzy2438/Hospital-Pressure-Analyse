/*
================================================================================
NHS WINTER PRESSURE ANALYTICS - ADVANCED ANALYTICS QUERIES
================================================================================
Author: Data Analyst Portfolio Project
Purpose: Production-ready analytical queries demonstrating:
         - Complex aggregations
         - Time-series analysis
         - Predictive signal detection
         - Performance benchmarking

These queries can be adapted for reporting, alerting, or ML pipelines.

Database: NHS_WinterPressure (SQL Server)
================================================================================
*/

-- ============================================================================
-- QUERY 1: DAILY SYSTEM-WIDE PRESSURE DASHBOARD
-- ============================================================================
-- Purpose: Real-time overview for operations center
-- Output: One row per day with key system metrics

SELECT 
    date,
    
    -- Capacity Utilization
    SUM(Beds_Open_General_Acute) AS System_Total_Beds,
    SUM(Beds_Occupied_General_Acute) AS System_Occupied_Beds,
    CAST(SUM(Beds_Occupied_General_Acute) AS FLOAT) / 
        NULLIF(SUM(Beds_Open_General_Acute), 0) AS System_Occupancy_Rate,
    
    -- Pressure Monitoring
    SUM(Flag_High_Pressure_Event) AS Trusts_Under_Pressure,
    COUNT(DISTINCT trust_code) AS Total_Trusts_Reporting,
    
    -- Critical Care Status
    SUM(Beds_Occupied_Critical_Care) AS CC_Patients,
    SUM(Beds_Occupied_Flu) AS Flu_Patients,
    
    -- Environmental Context
    AVG(Weather_Temp_Mean_C) AS Avg_Temperature_C,
    MAX(Google_Trend_Cold_Flu_Score) AS Flu_Search_Trend
    
FROM vw_HospitalCapacity
GROUP BY date
ORDER BY date DESC;


-- ============================================================================
-- QUERY 2: REGIONAL WEEKLY PERFORMANCE RANKING
-- ============================================================================
-- Purpose: Identify best and worst performing regions each week
-- Technique: RANK() window function

WITH WeeklyRegionalStats AS (
    SELECT 
        DATEPART(YEAR, date) AS year,
        DATEPART(WEEK, date) AS week_num,
        region_name,
        AVG(Region_Occupancy_Rate) AS Avg_Weekly_Occupancy,
        SUM(Count_Trusts_High_Pressure) AS Total_High_Pressure_Days,
        COUNT(DISTINCT date) AS Days_Reported
    FROM vw_SeasonalPressure
    GROUP BY DATEPART(YEAR, date), DATEPART(WEEK, date), region_name
)
SELECT 
    year,
    week_num,
    region_name,
    Avg_Weekly_Occupancy,
    Total_High_Pressure_Days,
    
    -- Rank: 1 = Highest Pressure (Worst)
    RANK() OVER (
        PARTITION BY year, week_num 
        ORDER BY Avg_Weekly_Occupancy DESC
    ) AS Pressure_Rank,
    
    -- Dense Rank for ties
    DENSE_RANK() OVER (
        PARTITION BY year, week_num 
        ORDER BY Total_High_Pressure_Days DESC
    ) AS High_Pressure_Days_Rank
    
FROM WeeklyRegionalStats
ORDER BY year DESC, week_num DESC, Pressure_Rank;


-- ============================================================================
-- QUERY 3: TRUST-LEVEL PERFORMANCE vs. REGIONAL AVERAGE
-- ============================================================================
-- Purpose: Identify trusts performing above/below regional average
-- Technique: Subquery comparison

SELECT 
    hc.date,
    hc.trust_code,
    hc.trust_name,
    hc.region_name,
    hc.Occupancy_Rate_General_Acute AS Trust_Occupancy,
    sp.Region_Occupancy_Rate AS Regional_Average,
    
    -- Variance from Regional Average
    hc.Occupancy_Rate_General_Acute - sp.Region_Occupancy_Rate AS Variance_From_Regional_Avg,
    
    -- Performance Flag
    CASE 
        WHEN hc.Occupancy_Rate_General_Acute > sp.Region_Occupancy_Rate + 0.05 
            THEN 'Above Average (+5%)'
        WHEN hc.Occupancy_Rate_General_Acute < sp.Region_Occupancy_Rate - 0.05 
            THEN 'Below Average (-5%)'
        ELSE 'Within Normal Range'
    END AS Performance_Status
    
FROM vw_HospitalCapacity hc
JOIN vw_SeasonalPressure sp 
    ON hc.date = sp.date 
    AND hc.region_name = sp.region_name
WHERE hc.Occupancy_Rate_General_Acute IS NOT NULL
ORDER BY hc.date DESC, Variance_From_Regional_Avg DESC;


-- ============================================================================
-- QUERY 4: EARLY WARNING SIGNAL DETECTION
-- ============================================================================
-- Purpose: Identify correlation between Google Trends and hospital admissions
-- Technique: LAG() to compare trend values with future admissions

WITH TrendLag AS (
    SELECT 
        date,
        region_name,
        Total_Flu_Patients,
        Trend_Cold_Flu,
        
        -- Get trend value from 7 days ago
        LAG(Trend_Cold_Flu, 7) OVER (
            PARTITION BY region_name 
            ORDER BY date
        ) AS Trend_Cold_Flu_7Days_Prior,
        
        -- Get trend value from 14 days ago
        LAG(Trend_Cold_Flu, 14) OVER (
            PARTITION BY region_name 
            ORDER BY date
        ) AS Trend_Cold_Flu_14Days_Prior
        
    FROM vw_TrendCorrelation
)
SELECT 
    date,
    region_name,
    Total_Flu_Patients,
    Trend_Cold_Flu AS Current_Trend,
    Trend_Cold_Flu_7Days_Prior,
    Trend_Cold_Flu_14Days_Prior,
    
    -- Calculate if there's a spike pattern
    CASE 
        WHEN Trend_Cold_Flu_7Days_Prior > Trend_Cold_Flu_14Days_Prior * 1.2 
            THEN 'Trend Spike Detected 7 Days Prior'
        ELSE 'No Early Warning'
    END AS Early_Warning_Signal
    
FROM TrendLag
WHERE Trend_Cold_Flu_14Days_Prior IS NOT NULL
ORDER BY date DESC, region_name;


-- ============================================================================
-- QUERY 5: TEMPERATURE IMPACT ON CRITICAL CARE
-- ============================================================================
-- Purpose: Analyze relationship between cold weather and critical care demand
-- Technique: Bucketing continuous variable

SELECT 
    CASE 
        WHEN Avg_Temp_C < 0 THEN '< 0°C (Freezing)'
        WHEN Avg_Temp_C < 5 THEN '0-5°C (Very Cold)'
        WHEN Avg_Temp_C < 10 THEN '5-10°C (Cold)'
        WHEN Avg_Temp_C < 15 THEN '10-15°C (Mild)'
        ELSE '> 15°C (Warm)'
    END AS Temperature_Band,
    
    COUNT(*) AS Observation_Count,
    AVG(Total_Critical_Care_Patients) AS Avg_CC_Patients,
    AVG(Total_Flu_Patients) AS Avg_Flu_Patients,
    AVG(Total_GA_Patients) AS Avg_GA_Patients
    
FROM vw_TrendCorrelation
WHERE Avg_Temp_C IS NOT NULL
GROUP BY 
    CASE 
        WHEN Avg_Temp_C < 0 THEN '< 0°C (Freezing)'
        WHEN Avg_Temp_C < 5 THEN '0-5°C (Very Cold)'
        WHEN Avg_Temp_C < 10 THEN '5-10°C (Cold)'
        WHEN Avg_Temp_C < 15 THEN '10-15°C (Mild)'
        ELSE '> 15°C (Warm)'
    END
ORDER BY AVG(Total_CC_Patients) DESC;


-- ============================================================================
-- QUERY 6: WEEK-OVER-WEEK CHANGE DETECTION
-- ============================================================================
-- Purpose: Identify rapid changes in system pressure
-- Technique: Window function for week-over-week comparison

WITH WeeklyAggregates AS (
    SELECT 
        DATEPART(YEAR, date) AS year,
        DATEPART(WEEK, date) AS week_num,
        MIN(date) AS week_start_date,
        SUM(Region_Beds_Occupied) AS Total_Weekly_Occupied,
        AVG(Region_Occupancy_Rate) AS Avg_Weekly_Occupancy
    FROM vw_SeasonalPressure
    GROUP BY DATEPART(YEAR, date), DATEPART(WEEK, date)
)
SELECT 
    year,
    week_num,
    week_start_date,
    Total_Weekly_Occupied,
    Avg_Weekly_Occupancy,
    
    -- Previous Week Values
    LAG(Total_Weekly_Occupied, 1) OVER (ORDER BY year, week_num) AS Prev_Week_Occupied,
    LAG(Avg_Weekly_Occupancy, 1) OVER (ORDER BY year, week_num) AS Prev_Week_Occupancy,
    
    -- Week-over-Week Change
    Total_Weekly_Occupied - LAG(Total_Weekly_Occupied, 1) OVER (ORDER BY year, week_num) AS WoW_Change_Occupied,
    
    -- Percentage Change
    CASE 
        WHEN LAG(Total_Weekly_Occupied, 1) OVER (ORDER BY year, week_num) > 0 
        THEN (Total_Weekly_Occupied - LAG(Total_Weekly_Occupied, 1) OVER (ORDER BY year, week_num)) * 100.0 / 
             LAG(Total_Weekly_Occupied, 1) OVER (ORDER BY year, week_num)
        ELSE 0 
    END AS WoW_Pct_Change
    
FROM WeeklyAggregates
ORDER BY year DESC, week_num DESC;


/*
================================================================================
END OF ADVANCED ANALYTICS QUERIES
================================================================================
SQL Techniques Demonstrated:
1. Multi-level aggregations with GROUP BY
2. Window functions: RANK(), DENSE_RANK(), LAG()
3. CTEs for readable query structure
4. CASE expressions for data bucketing and flagging
5. Variance analysis (actual vs. benchmark)
6. Time-series analysis patterns
7. Cross-table joins for enrichment

Use Cases:
- Real-time operational dashboards
- Weekly executive reports
- Early warning alert systems
- Capacity planning analysis
================================================================================
*/

