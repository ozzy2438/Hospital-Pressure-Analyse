"""
Quick data preview script to validate downloaded data
"""

import pandas as pd
from pathlib import Path

# Load weather data
weather_file = Path("data/raw/weather/2025-11-21/weather_data_2025-11-21.csv")
df_weather = pd.read_csv(weather_file)

print("=" * 70)
print("WEATHER DATA PREVIEW")
print("=" * 70)
print(f"Shape: {df_weather.shape}")
print(f"\nFirst 5 rows:")
print(df_weather.head())
print(f"\nData types:")
print(df_weather.dtypes)
print(f"\nBasic statistics:")
print(df_weather.describe())

# Load trends data
trends_file = Path("data/raw/trends/2025-11-21/google_trends_2025-11-21.csv")
df_trends = pd.read_csv(trends_file)

print("\n" + "=" * 70)
print("GOOGLE TRENDS DATA PREVIEW")
print("=" * 70)
print(f"Shape: {df_trends.shape}")
print(f"\nFirst 10 rows:")
print(df_trends.head(10))
print(f"\nKeyword distribution:")
print(df_trends['keyword'].value_counts())
print(f"\nBasic statistics:")
print(df_trends.describe())
