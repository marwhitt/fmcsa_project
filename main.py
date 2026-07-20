import os
import pandas as pd
from google.cloud import bigquery

# 1. Point Python to your securely stored JSON key file
# Make sure this matches your exact folder and file name!
KEY_PATH = "C:\gcp_keys\gcp-raw-ingestor.json"
os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = KEY_PATH

# 2. Initialize the BigQuery Client
client = bigquery.Client()

# 3. Define your target table destination
# Format: project_id.dataset_id.table_id
project_id = client.project
dataset_id = "raw_collected_data"
table_id = f"{project_id}.{dataset_id}.daily_ingested_events"

# 4. Create dummy "raw" data simulating an operational source
raw_data = {
    "event_timestamp": pd.date_range(start="now", periods=5, freq="min"),
    "device_type": ["mobile", "desktop", "mobile", "tablet", "desktop"],
    "payload_size_kb": [14.2, 45.1, 12.8, 88.4, 32.1],
    "is_processed": [False, False, False, False, False]
}
df = pd.DataFrame(raw_data)

# 5. Configure the ingestion rule (Append new data)
job_config = bigquery.LoadJobConfig()
job_config.write_disposition = bigquery.WriteDisposition.WRITE_APPEND
job_config.autodetect = True 

print(f"Starting ingestion to {table_id}...")

# 6. Execute the loading job
load_job = client.load_table_from_dataframe(
    df, table_id, job_config=job_config
)

# Wait for the job to complete successfully
load_job.result()

print(f"Success! Loaded {df.shape[0]} rows into BigQuery.")