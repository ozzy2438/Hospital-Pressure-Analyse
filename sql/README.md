# NHS Winter Pressure Analytics - SQL Portfolio

## Project Overview

This repository contains a comprehensive SQL analysis of NHS England winter pressure data, demonstrating advanced data engineering and analytics capabilities. The project combines hospital operational data with external data sources (weather, Google Trends) to create predictive insights for healthcare capacity management.

## File Structure

| File | Description |
|------|-------------|
| `01_schema_exploration.sql` | Database schema discovery and table structure analysis |
| `02_data_summary_statistics.sql` | Comprehensive data profiling and statistics |
| `03_data_quality_integrity_checks.sql` | Data quality validation (FKs, NULLs, logical consistency) |
| `04_geographic_mapping.sql` | Weather data to NHS region geographic mapping |
| `05_dimensional_linking_master_join.sql` | Multi-source data integration with CTEs |
| `06_feature_engineering.sql` | ML-ready features with window functions |
| `07_analytical_view_hospital_capacity.sql` | Primary analytical view creation |
| `08_dashboard_views.sql` | Power BI optimized views |
| `09_advanced_analytics_queries.sql` | Production-ready analytical queries |

## SQL Skills Demonstrated

### Data Engineering
- **Star Schema Design**: Fact and dimension table relationships
- **ETL Patterns**: Data transformation from long to wide format (PIVOT)
- **Data Quality Frameworks**: Comprehensive integrity checks

### Advanced SQL Techniques
- **Common Table Expressions (CTEs)**: Multi-level query organization
- **Window Functions**: `LAG()`, `RANK()`, `AVG() OVER()`, rolling averages
- **Conditional Aggregation**: PIVOT pattern without native PIVOT operator
- **Complex JOINs**: Multi-table joins with geographic proxy mapping
- **Date Handling**: Weekly to daily data expansion, temporal alignment

### Analytics & Business Intelligence
- **Feature Engineering**: Calculated rates, flags, lag features for ML
- **View Design**: Optimized views for Power BI dashboards
- **KPI Calculation**: Occupancy rates, pressure thresholds, trend analysis

## Data Model

```
+---------------------+
|   DimOrganisation   |
|   (NHS Trusts)      |
+---------+-----------+
          |
          v
+---------------------+     +---------------------+
| FactNhsDailyPressure|<----|      DimDate        |
|   (Daily Metrics)   |     |   (Calendar)        |
+---------------------+     +---------------------+
          |
          v
+---------------------+     +---------------------+
|   Weather Data      |     |   Google Trends     |
|   (Daily/City)      |     |   (Weekly/Keyword)  |
+---------------------+     +---------------------+
```

## Key Business Questions Answered

1. **Capacity Monitoring**: What is the current bed occupancy across NHS regions?
2. **Pressure Detection**: Which trusts are operating above safe thresholds (>85%)?
3. **Trend Analysis**: How has system pressure changed week-over-week?
4. **Predictive Signals**: Can Google Trends predict hospital admissions 7 days ahead?
5. **Weather Impact**: How does temperature affect critical care demand?

## Usage

### Prerequisites
- SQL Server 2016+ (or Azure SQL)
- Database: `NHS_WinterPressure`

### Execution Order
1. Run schema exploration (01) to understand the data
2. Run data quality checks (02-03) before analysis
3. Create analytical views (07-08) for dashboard connections
4. Execute advanced queries (09) for specific insights

### Power BI Connection
```
Server: [Your SQL Server]
Database: NHS_WinterPressure
Tables: vw_HospitalCapacity, vw_SeasonalPressure, vw_TrendCorrelation
```

## Sample Output

### System Occupancy Trend
| Date | Occupancy Rate | Trusts Under Pressure |
|------|---------------|----------------------|
| 2024-12-01 | 94.2% | 47/152 |
| 2024-11-30 | 93.8% | 45/152 |
| 2024-11-29 | 92.1% | 38/152 |

## Domain Context

This analysis focuses on NHS England's winter pressure metrics, which track:
- **General & Acute Beds**: Standard hospital bed availability
- **Critical Care Beds**: ICU/HDU capacity
- **Flu Beds**: Seasonal influenza-related admissions

The 85% occupancy threshold is an industry standard for safe hospital operations; exceeding this level correlates with increased A&E wait times and patient safety concerns.

---

**Author**: Data Analytics Portfolio Project  
**Database**: SQL Server  
**Tools**: T-SQL, Power BI, Python (for data extraction)
