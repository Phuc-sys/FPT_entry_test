import os
import logging

from airflow import DAG
from airflow.utils.dates import days_ago
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator
from airflow.decorators import dag, task

from google.cloud import storage
from airflow.providers.google.cloud.operators.bigquery import BigQueryCreateExternalTableOperator
import pyarrow.csv as pv
import pyarrow.parquet as pq


PROJECT_ID = "northern-union-373114"
BUCKET = "dtc_data_lake_northern-union-373114"
BIGQUERY_DATASET = "trips_data_all"

dataset_file = "yellow_tripdata_2021-01.csv"
parquet_file = "yellow_tripdata_2021-01.parquet"
dataset_url = f"https://d37ci6vzurychx.cloudfront.net/trip-data/{parquet_file}"
path_to_local_home = os.environ.get("AIRFLOW_HOME", "/opt/airflow/dataset")


# convert parquet to csv file
def format_to_parquet(src_file):
    if not src_file.endswith('.csv'):
        logging.error("Can only accept source files in CSV format, for the moment")
        return
    table = pv.read_csv(src_file)
    pq.write_table(table, src_file.replace('.csv', '.parquet'))


# upload to google cloud storage
def upload_to_gcs(bucket, object_name, local_file):
    """
    Ref: https://cloud.google.com/storage/docs/uploading-objects#storage-upload-object-python
    :param bucket: GCS bucket name
    :param object_name: target path & file-name
    :param local_file: source path & file-name
    :return:
    """
    storage.blob._MAX_MULTIPART_SIZE = 5 * 1024 * 1024  # 5 MB
    storage.blob._DEFAULT_CHUNKSIZE = 5 * 1024 * 1024  # 5 MB
    # End of Workaround

    client = storage.Client()
    bucket = client.bucket(bucket)

    blob = bucket.blob(object_name)
    blob.upload_from_filename(local_file)


default_args = {
    "owner": "airflow",
    "start_date": days_ago(1),
    "depends_on_past": False,
    "retries": 3,
    "email_on_failure":True,
    "email":'test@gmail.com',
}

# NOTE: DAG declaration - using a Context Manager (an implicit way)
with DAG(
    dag_id="data_ingestion_gcs_dag",
    schedule_interval="@daily",
    default_args=default_args,
    catchup=False,
    max_active_runs=1,
    tags=['dtc-de'],
) as dag:

    # download dataset
    download_dataset_task = BashOperator(
        task_id="download_dataset_task",
        bash_command=f"curl -sSL {dataset_url} > {path_to_local_home}/{parquet_file}",
        email_on_failure=True,
        email=['test@gmail.com'],
    )

    format_to_parquet_task = PythonOperator(
        task_id="format_to_parquet_task",
        python_callable=format_to_parquet,
        op_kwargs={
            "src_file": f"{path_to_local_home}/{dataset_file}",
        },
    )

    # load dataset from local to data lake
    local_to_gcs_task = PythonOperator(
        task_id="local_to_gcs_task",
        python_callable=upload_to_gcs,
        op_kwargs={
            "bucket": BUCKET,
            "object_name": f"raw/{parquet_file}",
            "local_file": f"{path_to_local_home}/{parquet_file}",
        },
    )

    # load dataset from data lake to data warehouse
    bigquery_external_table_task = BigQueryCreateExternalTableOperator(
        task_id="bigquery_external_table_task",
        table_resource={
            "tableReference": {
                "projectId": PROJECT_ID,
                "datasetId": BIGQUERY_DATASET,
                "tableId": "external_table",
            },
            "externalDataConfiguration": {
                "sourceFormat": "PARQUET",
                "sourceUris": [f"gs://{BUCKET}/raw/{parquet_file}"],
            },
        },
    )

    #download_dataset_task >> format_to_parquet_task >> local_to_gcs_task >> bigquery_external_table_task
    download_dataset_task >> local_to_gcs_task >> bigquery_external_table_task



# -------------- Operators & Decorators -------------

## download datset
## @task
## def dowload_dataset():
##     os.system(f"wget {dataset_url} -O {parquet_file}")


# """upload to google cloud storage"""
# @task
# def upload_to_gcs(bucket, object_name, local_file):
#     storage.blob._MAX_MULTIPART_SIZE = 5 * 1024 * 1024  # 5 MB
#     storage.blob._DEFAULT_CHUNKSIZE = 5 * 1024 * 1024  # 5 MB
#     # End of Workaround

#     client = storage.Client()
#     bucket = client.bucket(bucket)

#     blob = bucket.blob(object_name)
#     blob.upload_from_filename(local_file)


# @dag(default_args=default_args,schedule_interval=None, start_date=days_ago(2))
# def workflow():

#     # download dataset
#     download_dataset_task = BashOperator(
#         task_id="download_dataset_task",
#         bash_command=f"curl -sSL {dataset_url} > {path_to_local_home}/{parquet_file}",
#         email_on_failure=True,
#         email=['test@gmail.com'],
#     )

#     local_file = f"{path_to_local_home}/{parquet_file}"
#     bucket = BUCKET
#     object_name = f"raw/{parquet_file}"
    
#     upload = upload_to_gcs(bucket, object_name, local_file)

#     download_dataset_task >> upload

# workflow()