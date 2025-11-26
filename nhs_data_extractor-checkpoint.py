"""
NHS Data Extraction Script
Extracts and processes NHS UEC SitRep data from Excel files
"""

import pandas as pd
import numpy as np
from pathlib import Path
from datetime import datetime
import logging

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def extract_nhs_sheet(file_path, sheet_name):
    """
    Extract and reshape NHS data from a single sheet.

    Args:
        file_path: Path to NHS Excel file
        sheet_name: Name of sheet to extract

    Returns:
        pd.DataFrame in long format with columns: date, region, trust_code, trust_name, metric, value
    """
    logger.info(f"Extracting sheet: {sheet_name} from {Path(file_path).name}")

    # Read raw data
    xl = pd.ExcelFile(file_path)
    df_raw = xl.parse(sheet_name, header=None)

    # Row 13 contains dates (0-indexed = row 13)
    # Row 14 contains metric names
    # Row 15 onwards contains data

    dates_row = 13
    headers_row = 14
    data_start_row = 15

    # Extract date headers from row 13
    dates = []
    for col_idx in range(5, len(df_raw.columns)):  # Start from column 5 (after metadata columns)
        date_val = df_raw.iloc[dates_row, col_idx]
        if pd.notna(date_val) and isinstance(date_val, (pd.Timestamp, datetime)):
            dates.append(date_val)
        elif dates:  # Forward fill date for metric columns under same date
            dates.append(dates[-1])
        else:
            dates.append(None)

    # Extract metric names from row 14
    metrics = df_raw.iloc[headers_row, 5:].tolist()

    # Extract metadata columns
    metadata_cols = ['region', 'region_code', 'trust_code', 'trust_name']

    # Read actual data starting from row 15
    df_data = df_raw.iloc[data_start_row:, :].copy()

    # Set column names
    df_data.columns = ['_drop1', 'region', '_drop2', 'trust_code', 'trust_name'] + metrics

    # Drop unnecessary columns
    df_data = df_data.drop(columns=['_drop1', '_drop2'])

    # Remove rows with all NaN in data columns
    data_cols = df_data.columns[4:]  # After metadata columns
    df_data = df_data.dropna(subset=data_cols, how='all')

    # Remove rows where trust_name is NaN (summary rows or blanks)
    df_data = df_data[df_data['trust_name'].notna()]

    # Reshape from wide to long format
    # Group columns by date
    date_metric_map = []
    for i, (date, metric) in enumerate(zip(dates, metrics)):
        if date and metric:
            date_metric_map.append({
                'col_idx': i + 4,  # +4 because first 4 cols are metadata
                'date': pd.to_datetime(date),
                'metric': str(metric).strip()
            })

    # Create long format DataFrame
    records = []
    for _, row in df_data.iterrows():
        for dm in date_metric_map:
            # Get column name by index
            col_name = df_data.columns[dm['col_idx']]
            records.append({
                'date': dm['date'],
                'region': row['region'],
                'trust_code': row['trust_code'],
                'trust_name': row['trust_name'],
                'metric': f"{sheet_name}_{dm['metric']}",
                'value': row[col_name]
            })

    df_long = pd.DataFrame(records)

    # Convert value to numeric
    df_long['value'] = pd.to_numeric(df_long['value'], errors='coerce')

    # Remove rows with NaN values
    df_long = df_long.dropna(subset=['value'])

    logger.info(f"Extracted {len(df_long):,} records from {sheet_name}")

    return df_long


def extract_all_nhs_data(nhs_folder):
    """
    Extract data from all NHS Excel files and sheets.

    Args:
        nhs_folder: Path to folder containing NHS Excel files

    Returns:
        pd.DataFrame with all extracted data
    """
    nhs_path = Path(nhs_folder)
    excel_files = list(nhs_path.glob('*.xlsx'))

    logger.info(f"Found {len(excel_files)} Excel files")

    # Use only the first file (others appear to be duplicates)
    main_file = excel_files[0]

    # Sheets to extract
    target_sheets = [
        'Total G&A beds',
        'Adult G&A beds',
        'Adult critical care',
        'Flu',
        'RSV'
    ]

    all_data = []

    for sheet in target_sheets:
        try:
            df = extract_nhs_sheet(main_file, sheet)
            all_data.append(df)
        except Exception as e:
            logger.error(f"Error extracting {sheet}: {e}")
            continue

    # Combine all sheets
    df_combined = pd.concat(all_data, ignore_index=True)

    logger.info(f"Total records extracted: {len(df_combined):,}")
    logger.info(f"Date range: {df_combined['date'].min()} to {df_combined['date'].max()}")
    logger.info(f"Unique trusts: {df_combined['trust_name'].nunique()}")

    return df_combined


if __name__ == "__main__":
    # Extract NHS data
    nhs_folder = 'data/raw/nhs/2025-11-21'
    df_nhs = extract_all_nhs_data(nhs_folder)

    # Save to processed folder
    output_path = Path('data/processed')
    output_path.mkdir(parents=True, exist_ok=True)

    output_file = output_path / 'nhs_extracted.csv'
    df_nhs.to_csv(output_file, index=False)
    logger.info(f"Saved extracted data to {output_file}")

    # Save summary
    summary = f"""
NHS Data Extraction Summary
===========================
Extraction Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

Records Extracted: {len(df_nhs):,}
Date Range: {df_nhs['date'].min().strftime('%Y-%m-%d')} to {df_nhs['date'].max().strftime('%Y-%m-%d')}
Total Days: {df_nhs['date'].nunique()}
Unique Trusts: {df_nhs['trust_name'].nunique()}
Unique Metrics: {df_nhs['metric'].nunique()}

Metrics Extracted:
{chr(10).join([f"- {m}" for m in sorted(df_nhs['metric'].unique())])}

Regions:
{chr(10).join([f"- {r}" for r in sorted(df_nhs['region'].dropna().unique())])}
"""

    summary_file = output_path / 'nhs_extraction_summary.txt'
    with open(summary_file, 'w') as f:
        f.write(summary)
    logger.info(f"Saved summary to {summary_file}")

    print("\n" + summary)
