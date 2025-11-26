"""
Winter Pressures - A&E & Bed Capacity Prediction System
Phase 1: Data Acquisition & ETL

This module handles data extraction from three primary sources:
1. NHS England UEC SitRep (Emergency Department attendance & bed occupancy)
2. Open-Meteo API (Historical weather data for UK cities)
3. Google Trends (Public search volume for flu/fever symptoms)

Author: Data Engineering Team
Date: 2025-11-21
"""

import logging
import requests
import pandas as pd
from datetime import datetime, timedelta
from pathlib import Path
import time

# Third-party libraries (install via: pip install pytrends openmeteo-requests requests-cache retry-requests)
try:
    from pytrends.request import TrendReq
except ImportError:
    print("⚠️  Pytrends not installed. Run: pip install pytrends")

import openmeteo_requests
import requests_cache
from retry_requests import retry


# ============================================================================
# CONFIGURATION
# ============================================================================

class Config:
    """Centralized configuration for data extraction"""

    # Project paths
    BASE_DIR = Path(__file__).parent
    DATA_DIR = BASE_DIR / "data"
    RAW_DATA_DIR = DATA_DIR / "raw"
    LOGS_DIR = BASE_DIR / "logs"

    # Data source directories
    NHS_DIR = RAW_DATA_DIR / "nhs"
    WEATHER_DIR = RAW_DATA_DIR / "weather"
    TRENDS_DIR = RAW_DATA_DIR / "trends"

    # Date range for historical data (2 years)
    END_DATE = datetime.now()
    START_DATE = END_DATE - timedelta(days=730)  # 2 years

    # UK Major Cities (lat, lon, name)
    UK_CITIES = [
        (51.5074, -0.1278, "London"),
        (53.4808, -2.2426, "Manchester"),
        (52.4862, -1.8904, "Birmingham"),
        (53.8008, -1.5491, "Leeds"),
        (55.9533, -3.1883, "Edinburgh"),
        (53.4084, -2.9916, "Liverpool"),
        (51.4545, -2.5879, "Bristol"),
        (52.6369, 1.1398, "Norwich"),  # East region
    ]

    # Google Trends keywords
    TRENDS_KEYWORDS = [
        "flu symptoms",
        "fever",
        "A&E wait times",
        "emergency room",
        "cold and flu"
    ]

    # NHS England UEC SitRep URLs (these may need manual updating)
    # Note: NHS typically publishes data weekly, not via API
    NHS_DATA_URL = "https://www.england.nhs.uk/statistics/statistical-work-areas/uec-daily-sitrep/"


# ============================================================================
# LOGGING SETUP
# ============================================================================

def setup_logging() -> logging.Logger:
    """Configure logging with both file and console handlers"""

    # Create logs directory
    Config.LOGS_DIR.mkdir(parents=True, exist_ok=True)

    # Configure logger
    logger = logging.getLogger("winter_pressures")
    logger.setLevel(logging.INFO)

    # File handler with timestamp
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    file_handler = logging.FileHandler(
        Config.LOGS_DIR / f"data_extraction_{timestamp}.log"
    )
    file_handler.setLevel(logging.DEBUG)

    # Console handler
    console_handler = logging.StreamHandler()
    console_handler.setLevel(logging.INFO)

    # Formatter
    formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    file_handler.setFormatter(formatter)
    console_handler.setFormatter(formatter)

    # Add handlers
    logger.addHandler(file_handler)
    logger.addHandler(console_handler)

    return logger


# ============================================================================
# DIRECTORY STRUCTURE SETUP
# ============================================================================

def create_folder_structure(logger: logging.Logger) -> None:
    """Create organized folder structure with version control"""

    timestamp = datetime.now().strftime("%Y-%m-%d")

    directories = [
        Config.NHS_DIR / timestamp,
        Config.WEATHER_DIR / timestamp,
        Config.TRENDS_DIR / timestamp,
        Config.DATA_DIR / "processed",
        Config.DATA_DIR / "models",
        Config.DATA_DIR / "outputs",
    ]

    for directory in directories:
        directory.mkdir(parents=True, exist_ok=True)
        logger.info(f"✓ Created directory: {directory}")


# ============================================================================
# NHS ENGLAND UEC SITREP DATA EXTRACTION
# ============================================================================

def download_nhs_data(logger: logging.Logger) -> pd.DataFrame:
    """
    Download NHS England UEC SitRep data

    Note: NHS England publishes data as Excel files on their website.
    This function includes multiple fallback strategies:
    1. Direct API call (if available)
    2. Scraping published Excel files
    3. Manual download instructions

    Returns:
        pd.DataFrame: NHS A&E and bed occupancy data
    """
    logger.info("=" * 70)
    logger.info("DOWNLOADING NHS ENGLAND UEC SITREP DATA")
    logger.info("=" * 70)

    timestamp = datetime.now().strftime("%Y-%m-%d")
    output_dir = Config.NHS_DIR / timestamp

    # Strategy 1: Check for publicly available datasets
    # NHS typically publishes weekly aggregate data

    logger.warning("⚠️  NHS England does not provide a direct API for UEC SitRep data")
    logger.info("📋 Please manually download the latest data from:")
    logger.info("   https://www.england.nhs.uk/statistics/statistical-work-areas/uec-daily-sitrep/")
    logger.info(f"   Save Excel/CSV files to: {output_dir}")

    # Strategy 2: Use NHS Digital API (if available)
    try:
        logger.info("🔍 Attempting to fetch data from NHS Digital API...")

        # Example: NHS Digital publishes some datasets via API
        # This is a placeholder - actual endpoint needs verification
        api_url = "https://digital.nhs.uk/api/uec-data"

        response = requests.get(api_url, timeout=30)

        if response.status_code == 200:
            data = response.json()
            df = pd.DataFrame(data)

            # Save to CSV
            output_file = output_dir / f"nhs_uec_sitrep_{timestamp}.csv"
            df.to_csv(output_file, index=False)
            logger.info(f"✓ NHS data saved to: {output_file}")

            return df
        else:
            logger.warning(f"API returned status code: {response.status_code}")

    except Exception as e:
        logger.error(f"❌ Error fetching NHS data: {str(e)}")

    # Strategy 3: Return instructions for manual download
    logger.info("\n📌 MANUAL DOWNLOAD INSTRUCTIONS:")
    logger.info("1. Visit: https://www.england.nhs.uk/statistics/statistical-work-areas/uec-daily-sitrep/")
    logger.info("2. Download the latest 'UEC Daily SitRep' Excel file")
    logger.info(f"3. Save to: {output_dir}")
    logger.info("4. Run this script again to process the data\n")

    # Create a placeholder README
    readme_path = output_dir / "README.txt"
    with open(readme_path, "w") as f:
        f.write("NHS England UEC SitRep Data\n")
        f.write("=" * 50 + "\n\n")
        f.write("Please download data from:\n")
        f.write("https://www.england.nhs.uk/statistics/statistical-work-areas/uec-daily-sitrep/\n\n")
        f.write("Required files:\n")
        f.write("- Daily A&E attendance data\n")
        f.write("- Hospital bed occupancy data\n")
        f.write("- General & Acute bed availability\n")

    return pd.DataFrame()  # Return empty for now


# ============================================================================
# OPEN-METEO WEATHER DATA EXTRACTION
# ============================================================================

def download_weather_data(logger: logging.Logger) -> pd.DataFrame:
    """
    Download historical weather data from Open-Meteo API

    Fetches daily temperature and precipitation data for major UK cities
    over the past 2 years.

    Returns:
        pd.DataFrame: Weather data with columns [date, city, temp_min, temp_max, precipitation]
    """
    logger.info("=" * 70)
    logger.info("DOWNLOADING OPEN-METEO WEATHER DATA")
    logger.info("=" * 70)

    timestamp = datetime.now().strftime("%Y-%m-%d")
    output_dir = Config.WEATHER_DIR / timestamp

    # Setup the Open-Meteo API client with cache and retry
    cache_session = requests_cache.CachedSession('.cache', expire_after=3600)
    retry_session = retry(cache_session, retries=5, backoff_factor=0.2)
    openmeteo = openmeteo_requests.Client(session=retry_session)

    all_weather_data = []

    for lat, lon, city_name in Config.UK_CITIES:
        logger.info(f"📍 Fetching weather data for {city_name} ({lat}, {lon})...")

        try:
            # Open-Meteo Historical Weather API
            url = "https://archive-api.open-meteo.com/v1/archive"

            params = {
                "latitude": lat,
                "longitude": lon,
                "start_date": Config.START_DATE.strftime("%Y-%m-%d"),
                "end_date": Config.END_DATE.strftime("%Y-%m-%d"),
                "daily": [
                    "temperature_2m_max",
                    "temperature_2m_min",
                    "temperature_2m_mean",
                    "precipitation_sum",
                    "rain_sum",
                    "snowfall_sum",
                    "precipitation_hours",
                    "wind_speed_10m_max",
                ],
                "timezone": "Europe/London"
            }

            responses = openmeteo.weather_api(url, params=params)
            response = responses[0]

            # Process daily data
            daily = response.Daily()
            daily_data = {
                "date": pd.date_range(
                    start=pd.to_datetime(daily.Time(), unit="s"),
                    end=pd.to_datetime(daily.TimeEnd(), unit="s"),
                    freq=pd.Timedelta(seconds=daily.Interval()),
                    inclusive="left"
                )
            }

            daily_data["city"] = city_name
            daily_data["latitude"] = lat
            daily_data["longitude"] = lon
            daily_data["temp_max"] = daily.Variables(0).ValuesAsNumpy()
            daily_data["temp_min"] = daily.Variables(1).ValuesAsNumpy()
            daily_data["temp_mean"] = daily.Variables(2).ValuesAsNumpy()
            daily_data["precipitation_sum"] = daily.Variables(3).ValuesAsNumpy()
            daily_data["rain_sum"] = daily.Variables(4).ValuesAsNumpy()
            daily_data["snowfall_sum"] = daily.Variables(5).ValuesAsNumpy()
            daily_data["precipitation_hours"] = daily.Variables(6).ValuesAsNumpy()
            daily_data["wind_speed_max"] = daily.Variables(7).ValuesAsNumpy()

            df_city = pd.DataFrame(data=daily_data)
            all_weather_data.append(df_city)

            logger.info(f"  ✓ Retrieved {len(df_city)} days of data for {city_name}")

            # Rate limiting - be respectful to the API
            time.sleep(0.5)

        except Exception as e:
            logger.error(f"  ❌ Error fetching data for {city_name}: {str(e)}")
            continue

    # Combine all city data
    if all_weather_data:
        df_weather = pd.concat(all_weather_data, ignore_index=True)

        # Save to CSV
        output_file = output_dir / f"weather_data_{timestamp}.csv"
        df_weather.to_csv(output_file, index=False)
        logger.info(f"\n✓ Weather data saved to: {output_file}")
        logger.info(f"  Total records: {len(df_weather)}")
        logger.info(f"  Date range: {df_weather['date'].min()} to {df_weather['date'].max()}")

        # Save Parquet for better performance
        parquet_file = output_dir / f"weather_data_{timestamp}.parquet"
        df_weather.to_parquet(parquet_file, index=False)
        logger.info(f"  Parquet format saved: {parquet_file}")

        return df_weather
    else:
        logger.error("❌ No weather data retrieved")
        return pd.DataFrame()


# ============================================================================
# GOOGLE TRENDS DATA EXTRACTION
# ============================================================================

def download_google_trends(logger: logging.Logger) -> pd.DataFrame:
    """
    Download Google Trends data using Pytrends

    Fetches search interest data for flu/fever-related keywords
    in the United Kingdom over the past 2 years.

    Returns:
        pd.DataFrame: Trends data with columns [date, keyword, search_volume]
    """
    logger.info("=" * 70)
    logger.info("DOWNLOADING GOOGLE TRENDS DATA")
    logger.info("=" * 70)

    timestamp = datetime.now().strftime("%Y-%m-%d")
    output_dir = Config.TRENDS_DIR / timestamp

    try:
        # Initialize Pytrends
        pytrends = TrendReq(hl='en-GB', tz=0)

        all_trends_data = []

        # Google Trends API limits: max 5 keywords per request, max 5 years timeframe
        for keyword in Config.TRENDS_KEYWORDS:
            logger.info(f"🔍 Fetching trends for: '{keyword}'")

            try:
                # Build payload
                pytrends.build_payload(
                    [keyword],
                    cat=0,  # All categories
                    timeframe=f'{Config.START_DATE.strftime("%Y-%m-%d")} {Config.END_DATE.strftime("%Y-%m-%d")}',
                    geo='GB',  # United Kingdom
                    gprop=''  # Web search
                )

                # Get interest over time
                df_trend = pytrends.interest_over_time()

                if not df_trend.empty:
                    # Remove 'isPartial' column
                    df_trend = df_trend.drop(columns=['isPartial'], errors='ignore')

                    # Reset index to get date as column
                    df_trend = df_trend.reset_index()
                    df_trend.rename(columns={'date': 'date', keyword: 'search_volume'}, inplace=True)
                    df_trend['keyword'] = keyword

                    all_trends_data.append(df_trend)
                    logger.info(f"  ✓ Retrieved {len(df_trend)} data points for '{keyword}'")
                else:
                    logger.warning(f"  ⚠️  No data returned for '{keyword}'")

                # Rate limiting - avoid hitting Google's limits
                time.sleep(2)

            except Exception as e:
                logger.error(f"  ❌ Error fetching trends for '{keyword}': {str(e)}")
                continue

        # Combine all keyword data
        if all_trends_data:
            df_trends = pd.concat(all_trends_data, ignore_index=True)

            # Save to CSV
            output_file = output_dir / f"google_trends_{timestamp}.csv"
            df_trends.to_csv(output_file, index=False)
            logger.info(f"\n✓ Google Trends data saved to: {output_file}")
            logger.info(f"  Total records: {len(df_trends)}")
            logger.info(f"  Keywords tracked: {len(Config.TRENDS_KEYWORDS)}")

            # Save Parquet
            parquet_file = output_dir / f"google_trends_{timestamp}.parquet"
            df_trends.to_parquet(parquet_file, index=False)
            logger.info(f"  Parquet format saved: {parquet_file}")

            return df_trends
        else:
            logger.error("❌ No Google Trends data retrieved")
            return pd.DataFrame()

    except Exception as e:
        logger.error(f"❌ Error initializing Pytrends: {str(e)}")
        logger.info("💡 Make sure to install: pip install pytrends")
        return pd.DataFrame()


# ============================================================================
# DATA VALIDATION & SUMMARY
# ============================================================================

def validate_and_summarize(
    df_nhs: pd.DataFrame,
    df_weather: pd.DataFrame,
    df_trends: pd.DataFrame,
    logger: logging.Logger
) -> None:
    """Generate summary report of downloaded data"""

    logger.info("=" * 70)
    logger.info("DATA VALIDATION & SUMMARY")
    logger.info("=" * 70)

    timestamp = datetime.now().strftime("%Y-%m-%d")
    summary_file = Config.DATA_DIR / f"data_summary_{timestamp}.txt"

    with open(summary_file, "w") as f:
        f.write("WINTER PRESSURES DATA EXTRACTION SUMMARY\n")
        f.write("=" * 70 + "\n\n")
        f.write(f"Extraction Date: {timestamp}\n")
        f.write(f"Date Range: {Config.START_DATE.strftime('%Y-%m-%d')} to {Config.END_DATE.strftime('%Y-%m-%d')}\n\n")

        # NHS Data
        f.write("1. NHS ENGLAND UEC SITREP DATA\n")
        f.write("-" * 40 + "\n")
        if not df_nhs.empty:
            f.write(f"   Records: {len(df_nhs)}\n")
            f.write(f"   Columns: {', '.join(df_nhs.columns)}\n")
            f.write(f"   Date Range: {df_nhs.iloc[0, 0]} to {df_nhs.iloc[-1, 0]}\n")
        else:
            f.write("   Status: Manual download required\n")
            f.write("   See: data/raw/nhs/README.txt\n")
        f.write("\n")

        # Weather Data
        f.write("2. OPEN-METEO WEATHER DATA\n")
        f.write("-" * 40 + "\n")
        if not df_weather.empty:
            f.write(f"   Records: {len(df_weather)}\n")
            f.write(f"   Cities: {df_weather['city'].nunique()}\n")
            f.write(f"   Date Range: {df_weather['date'].min()} to {df_weather['date'].max()}\n")
            f.write(f"   Columns: {', '.join(df_weather.columns)}\n")
        else:
            f.write("   Status: No data retrieved\n")
        f.write("\n")

        # Trends Data
        f.write("3. GOOGLE TRENDS DATA\n")
        f.write("-" * 40 + "\n")
        if not df_trends.empty:
            f.write(f"   Records: {len(df_trends)}\n")
            f.write(f"   Keywords: {df_trends['keyword'].nunique()}\n")
            f.write(f"   Date Range: {df_trends['date'].min()} to {df_trends['date'].max()}\n")
            f.write(f"   Keywords Tracked: {', '.join(df_trends['keyword'].unique())}\n")
        else:
            f.write("   Status: No data retrieved\n")

    logger.info(f"✓ Summary report saved to: {summary_file}")

    # Print to console
    with open(summary_file, "r") as f:
        print("\n" + f.read())


# ============================================================================
# MAIN EXECUTION
# ============================================================================

def main():
    """Main execution function"""

    # Setup logging
    logger = setup_logging()

    logger.info("🚀 WINTER PRESSURES DATA EXTRACTION - PHASE 1")
    logger.info("=" * 70)

    # Create folder structure
    create_folder_structure(logger)

    # Download data from all sources
    df_nhs = download_nhs_data(logger)
    df_weather = download_weather_data(logger)
    df_trends = download_google_trends(logger)

    # Validate and summarize
    validate_and_summarize(df_nhs, df_weather, df_trends, logger)

    logger.info("\n✅ DATA EXTRACTION COMPLETE!")
    logger.info(f"Check logs at: {Config.LOGS_DIR}")


if __name__ == "__main__":
    main()
