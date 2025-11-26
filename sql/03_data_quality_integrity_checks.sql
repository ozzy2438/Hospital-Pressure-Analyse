/*
================================================================================
NHS WINTER PRESSURE ANALYTICS - DATA QUALITY & INTEGRITY CHECKS
================================================================================
Author: Data Analyst Portfolio Project
Purpose: Comprehensive data quality assessment including:
         - Foreign Key integrity validation
         - NULL value analysis
         - Logical consistency checks
         - Data type verification
         
This is a critical step before any analytical work to ensure data reliability.

Database: NHS_WinterPressure (SQL Server)
================================================================================
*/

-- ============================================================================
-- SECTION 1: FOREIGN KEY INTEGRITY CHECKS
-- ============================================================================
-- Validate that all fact table keys have corresponding dimension records

-- 1.1 FactNhsDailyPressure Foreign Key Validation
SELECT 
    'FK Check' AS check_type,
    'FactNhsDailyPressure' AS table_name, 
    'org_key -> DimOrganisation' AS relation, 
    COUNT(*) AS mismatched_count
FROM FactNhsDailyPressure f 
LEFT JOIN DimOrganisation d ON f.org_key = d.org_key 
WHERE d.org_key IS NULL

UNION ALL

SELECT 'FK Check', 
       'FactNhsDailyPressure', 
       'service_key -> DimService', 
       COUNT(*)
FROM FactNhsDailyPressure f 
LEFT JOIN DimService d ON f.service_key = d.service_key 
WHERE d.service_key IS NULL

UNION ALL

SELECT 'FK Check', 
       'FactNhsDailyPressure', 
       'date -> DimDate', 
       COUNT(*)
FROM FactNhsDailyPressure f 
LEFT JOIN DimDate d ON f.date = d.date 
WHERE d.date IS NULL;


-- 1.2 Remaining Fact Tables FK Validation
SELECT 'FK Check' AS type, 
       'Fact_GA_Beds' AS table_name, 
       'org_key' AS column_name, 
       COUNT(*) AS missing 
FROM Fact_GA_Beds f 
LEFT JOIN DimOrganisation d ON f.org_key = d.org_key 
WHERE d.org_key IS NULL

UNION ALL

SELECT 'FK Check', 'Fact_GA_Beds', 'date', COUNT(*) 
FROM Fact_GA_Beds f 
LEFT JOIN DimDate d ON f.date = d.date 
WHERE d.date IS NULL

UNION ALL

SELECT 'FK Check', 'Fact_Flu_Beds', 'org_key', COUNT(*) 
FROM Fact_Flu_Beds f 
LEFT JOIN DimOrganisation d ON f.org_key = d.org_key 
WHERE d.org_key IS NULL

UNION ALL

SELECT 'FK Check', 'Fact_Flu_Beds', 'date', COUNT(*) 
FROM Fact_Flu_Beds f 
LEFT JOIN DimDate d ON f.date = d.date 
WHERE d.date IS NULL

UNION ALL

SELECT 'FK Check', 'Fact_CC_Adult', 'org_key', COUNT(*) 
FROM Fact_CC_Adult f 
LEFT JOIN DimOrganisation d ON f.org_key = d.org_key 
WHERE d.org_key IS NULL

UNION ALL

SELECT 'FK Check', 'Fact_CC_Adult', 'date', COUNT(*) 
FROM Fact_CC_Adult f 
LEFT JOIN DimDate d ON f.date = d.date 
WHERE d.date IS NULL;


-- ============================================================================
-- SECTION 2: NULL VALUE & NEGATIVE VALUE ANALYSIS
-- ============================================================================
-- Identify data quality issues in metric columns

SELECT 
    'FactNhsDailyPressure' AS table_name,
    COUNT(*) AS total_rows,
    SUM(CASE WHEN metric_value IS NULL THEN 1 ELSE 0 END) AS null_metrics,
    SUM(CASE WHEN metric_value < 0 THEN 1 ELSE 0 END) AS negative_metrics
FROM FactNhsDailyPressure

UNION ALL

SELECT 
    'Fact_GA_Beds',
    COUNT(*),
    SUM(CASE WHEN beds_open IS NULL OR beds_occupied IS NULL THEN 1 ELSE 0 END),
    SUM(CASE WHEN beds_open < 0 OR beds_occupied < 0 THEN 1 ELSE 0 END)
FROM Fact_GA_Beds

UNION ALL

SELECT 
    'Fact_Flu_Beds',
    COUNT(*),
    SUM(CASE WHEN flu_beds_occupied IS NULL OR flu_cc_beds_occupied IS NULL THEN 1 ELSE 0 END),
    SUM(CASE WHEN flu_beds_occupied < 0 OR flu_cc_beds_occupied < 0 THEN 1 ELSE 0 END)
FROM Fact_Flu_Beds

UNION ALL

SELECT 
    'Fact_CC_Adult',
    COUNT(*),
    SUM(CASE WHEN cc_adult_beds_open IS NULL OR cc_adult_beds_occupied IS NULL THEN 1 ELSE 0 END),
    SUM(CASE WHEN cc_adult_beds_open < 0 OR cc_adult_beds_occupied < 0 THEN 1 ELSE 0 END)
FROM Fact_CC_Adult;


-- ============================================================================
-- SECTION 3: DATE COLUMN TYPE VERIFICATION
-- ============================================================================
-- Ensure date columns are properly typed for temporal analysis

SELECT 
    TABLE_NAME, 
    COLUMN_NAME, 
    DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE COLUMN_NAME LIKE '%date%' 
  AND TABLE_NAME IN (
      'FactNhsDailyPressure', 
      'Fact_GA_Beds', 
      'Fact_Flu_Beds', 
      'Fact_CC_Adult', 
      'DimDate', 
      'weather_data_2025-11-21', 
      'google_trends_2025-11-21'
  )
ORDER BY TABLE_NAME;


-- ============================================================================
-- SECTION 4: DIMENSION TABLE UNIQUENESS
-- ============================================================================
-- Verify dimension tables have unique business keys

SELECT 'DimOrganisation' AS table_name, 
       COUNT(*) AS total, 
       COUNT(DISTINCT trust_code) AS unique_codes 
FROM DimOrganisation

UNION ALL

SELECT 'DimService', 
       COUNT(*), 
       COUNT(DISTINCT service_category) 
FROM DimService;


-- ============================================================================
-- SECTION 5: LOGICAL CONSISTENCY - OCCUPANCY VALIDATION
-- ============================================================================
-- Check for illogical data where occupancy exceeds capacity

SELECT 
    'Fact_GA_Beds' AS table_name,
    COUNT(*) AS total_issues,
    SUM(CASE WHEN beds_occupied > beds_open THEN 1 ELSE 0 END) AS occupancy_exceeds_capacity,
    MAX(CASE WHEN beds_open > 0 
             THEN (beds_occupied * 100.0 / beds_open) 
             ELSE 0 END) AS max_occupancy_rate
FROM Fact_GA_Beds
WHERE beds_open IS NOT NULL AND beds_occupied IS NOT NULL

UNION ALL

SELECT 
    'Fact_CC_Adult',
    COUNT(*),
    SUM(CASE WHEN cc_adult_beds_occupied > cc_adult_beds_open THEN 1 ELSE 0 END),
    MAX(CASE WHEN cc_adult_beds_open > 0 
             THEN (cc_adult_beds_occupied * 100.0 / cc_adult_beds_open) 
             ELSE 0 END)
FROM Fact_CC_Adult
WHERE cc_adult_beds_open IS NOT NULL AND cc_adult_beds_occupied IS NOT NULL;


-- ============================================================================
-- SECTION 6: TRUST CONSISTENCY CHECK
-- ============================================================================
-- Ensure trust codes and names have 1:1 relationship

-- Check for duplicate names for same code
SELECT 
    'Duplicate Names for Code' AS issue_type,
    trust_code,
    COUNT(DISTINCT trust_name) AS name_count
FROM DimOrganisation
GROUP BY trust_code
HAVING COUNT(DISTINCT trust_name) > 1;

-- Check for duplicate codes for same name
SELECT 
    'Duplicate Codes for Name' AS issue_type,
    trust_name,
    COUNT(DISTINCT trust_code) AS code_count
FROM DimOrganisation
GROUP BY trust_name
HAVING COUNT(DISTINCT trust_code) > 1;


-- ============================================================================
-- SECTION 7: NULL DISTRIBUTION ANALYSIS
-- ============================================================================
-- Deep dive into NULL patterns to understand data gaps

-- NULLs by Region
SELECT 
    'Nulls by Region' AS analysis_type,
    region_name,
    COUNT(*) AS null_count
FROM FactNhsDailyPressure
WHERE metric_value IS NULL
GROUP BY region_name
ORDER BY null_count DESC;

-- NULLs by Date (showing dates with high NULL counts)
SELECT 
    'Nulls by Date' AS analysis_type,
    CAST(date AS VARCHAR) AS date_str,
    COUNT(*) AS null_count
FROM FactNhsDailyPressure
WHERE metric_value IS NULL
GROUP BY date
HAVING COUNT(*) > 50
ORDER BY null_count DESC;


/*
================================================================================
END OF DATA QUALITY & INTEGRITY CHECKS
================================================================================
Key Findings to Document:
- Foreign Key integrity status
- NULL/Negative value counts by table
- Any logical inconsistencies (occupancy > capacity)
- Dimension uniqueness validation results

Note: Results from these checks should inform data cleaning strategies
================================================================================
*/

