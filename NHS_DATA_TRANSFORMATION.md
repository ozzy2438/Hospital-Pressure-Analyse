# NHS Data Transformation Process

## Overview
This document explains how raw NHS hospital data was transformed into a clean, analysis-ready format using Python and Jupyter Notebook.

## Source Data
- **Location**: `data/raw/nhs/2025-11-21/`
- **Format**: 5 Excel files containing NHS Daily SitRep data
- **Content**: Hospital bed occupancy, critical care, flu cases, and patient flow metrics
- **Time Period**: November 2023 - March 2025 (259 unique dates)
- **Coverage**: 135 NHS hospital trusts across England

## Transformation Approach

### 1. Data Extraction
- Read multiple Excel sheets from 5 files
- Extracted 9 key metrics: General & Acute beds, Adult critical care, Flu, RSV, Norovirus (Adult/Paediatric), Long stay patients, A&E closures/diverts
- Parsed complex Excel structure with dates in columns and trusts in rows

### 2. Data Cleaning
- Removed aggregated "ENGLAND" summary rows (kept only trust-level data)
- Filtered out rows with missing trust codes or names
- Standardized column names across all sheets
- Converted all metrics to numeric format
- Handled missing values appropriately

### 3. Data Modeling - Star Schema
Created a dimensional model for efficient analysis:

**Dimension Tables:**
- `DimDate`: Date attributes (year, month, week, weekday, season, is_weekend)
- `DimOrganisation`: Hospital trust details (135 trusts with region, code, name)
- `DimService`: Service categories (9 types: beds, critical care, infections, emergency flow)

**Fact Tables:**
- `Fact_GA_Beds`: General & Acute bed metrics with occupancy rates
- `Fact_CC_Adult`: Adult critical care bed availability
- `Fact_Flu_Beds`: Flu patient bed occupancy
- `FactNhsDailyPressure`: Combined fact table (272,160 records) - all metrics in long format

### 4. Data Transformation Techniques
- **Unpivoting**: Converted wide format (dates as columns) to long format (dates as rows)
- **Surrogate Keys**: Added `date_key`, `org_key`, `service_key` for efficient joins
- **Calculated Metrics**: Created occupancy rate = beds_occupied / beds_open
- **Data Normalization**: Separated dimensions from facts to reduce redundancy

### 5. Output
All cleaned data saved in two formats:
- **CSV**: For easy viewing and compatibility
- **Parquet**: For faster loading and better compression

**Location**: `data/processed/`

## Why This Approach?

1. **Star Schema**: Makes it easy to analyze hospital pressure by date, location, or service type
2. **Long Format**: Enables flexible aggregation and time-series analysis
3. **Dimension Tables**: Allows filtering by region, season, weekday without repeating data
4. **Calculated Metrics**: Occupancy rate provides immediate insight into hospital capacity
5. **Reproducible**: All transformations documented in Jupyter notebook for transparency

## Key Insights Enabled
- Track hospital bed occupancy trends over time
- Compare pressure across different NHS regions
- Analyze seasonal patterns (winter pressure)
- Identify capacity issues by trust and service type
- Monitor flu/RSV impact on hospital resources

## Tools Used
- **Python**: pandas for data manipulation
- **Jupyter Notebook**: Interactive development and documentation
- **Excel parsing**: openpyxl for reading complex Excel structures

## Result
Transformed **5 complex Excel files** into **7 clean, structured tables** ready for:
- Time-series forecasting
- Machine learning models
- Interactive dashboards
- Statistical analysis

