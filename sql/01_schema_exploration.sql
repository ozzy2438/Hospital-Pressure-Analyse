/*
================================================================================
NHS WINTER PRESSURE ANALYTICS - SCHEMA EXPLORATION
================================================================================
Author: Data Analyst Portfolio Project
Purpose: Initial database schema exploration and table discovery
         This script explores the data warehouse structure to understand
         available tables, columns, and their relationships.

Database: NHS_WinterPressure (SQL Server)
================================================================================
*/

-- ============================================================================
-- SECTION 1: DATABASE TABLE DISCOVERY
-- ============================================================================
-- First step in any data project: understand what tables are available

SELECT 
    TABLE_NAME 
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;


-- ============================================================================
-- SECTION 2: FACT TABLE - FactNhsDailyPressure (Main Hospital Metrics)
-- ============================================================================
-- This is the primary fact table containing daily hospital pressure metrics

-- 2.1 Schema Discovery
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'FactNhsDailyPressure'
ORDER BY ORDINAL_POSITION;

-- 2.2 Sample Data Preview
SELECT TOP 10 *
FROM FactNhsDailyPressure
ORDER BY date DESC;


-- ============================================================================
-- SECTION 3: FACT TABLE - Fact_GA_Beds (General & Acute Beds)
-- ============================================================================
-- Contains bed occupancy data for General & Acute wards

-- 3.1 Schema Discovery
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Fact_GA_Beds'
ORDER BY ORDINAL_POSITION;

-- 3.2 Sample Data Preview
SELECT TOP 10 *
FROM Fact_GA_Beds
ORDER BY date DESC;


-- ============================================================================
-- SECTION 4: FACT TABLE - Fact_Flu_Beds (Flu-Related Beds)
-- ============================================================================
-- Tracks flu-related bed occupancy during winter pressure periods

-- 4.1 Schema Discovery
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Fact_Flu_Beds'
ORDER BY ORDINAL_POSITION;

-- 4.2 Sample Data Preview
SELECT TOP 10 *
FROM Fact_Flu_Beds
ORDER BY date DESC;


-- ============================================================================
-- SECTION 5: FACT TABLE - Fact_CC_Adult (Critical Care Adult Beds)
-- ============================================================================
-- Critical care bed availability and occupancy data

-- 5.1 Schema Discovery
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Fact_CC_Adult'
ORDER BY ORDINAL_POSITION;

-- 5.2 Sample Data Preview
SELECT TOP 10 *
FROM Fact_CC_Adult
ORDER BY date DESC;


-- ============================================================================
-- SECTION 6: DIMENSION TABLES
-- ============================================================================
-- Dimension tables provide context for the fact tables

-- 6.1 DimService - Service Categories
SELECT *
FROM DimService;

-- 6.2 DimDate - Date Dimension (Calendar attributes)
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'DimDate'
ORDER BY ORDINAL_POSITION;

SELECT TOP 10 *
FROM DimDate
ORDER BY date;

-- 6.3 DimOrganisation - NHS Trust Information
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'DimOrganisation'
ORDER BY ORDINAL_POSITION;

SELECT TOP 10 *
FROM DimOrganisation
ORDER BY org_key;


-- ============================================================================
-- SECTION 7: EXTERNAL DATA SOURCES
-- ============================================================================
-- Weather and Google Trends data for predictive analytics

-- 7.1 Weather Data Schema
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'weather_data_2025-11-21'
ORDER BY ORDINAL_POSITION;

-- 7.2 Weather Data Sample
SELECT TOP 10 *
FROM [weather_data_2025-11-21]
ORDER BY date DESC, city;

-- 7.3 Google Trends Data Schema
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'google_trends_2025-11-21'
ORDER BY ORDINAL_POSITION;

-- 7.4 Google Trends Sample
SELECT TOP 10 *
FROM [google_trends_2025-11-21]
ORDER BY date DESC, keyword;


/*
================================================================================
END OF SCHEMA EXPLORATION
================================================================================
Key Findings:
- 4 Fact Tables: FactNhsDailyPressure, Fact_GA_Beds, Fact_Flu_Beds, Fact_CC_Adult
- 3 Dimension Tables: DimDate, DimService, DimOrganisation
- 2 External Data Sources: Weather, Google Trends
- Star Schema Design for efficient analytical queries
================================================================================
*/

