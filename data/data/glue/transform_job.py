import sys
import json
import boto3
import time
from awsglue.context import GlueContext
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from pyspark.sql.functions import lower, col

# Required arguments passed from Step Functions or Terraform
args = getResolvedOptions(sys.argv, ['JOB_NAME', 'S3Input', 'S3Output', 'ManifestTable'])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session

s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')
manifest_table = dynamodb.Table(args['ManifestTable'])

input_path = args['S3Input']
output_path = args['S3Output']
job_id = f"{args['JOB_NAME']}-{int(time.time())}"

print(f"Starting Glue job {job_id}")
print(f"Reading data from {input_path}")


# Step 1: Read raw CSV

df = spark.read.option("header", True).csv(input_path)


# Step 2: Transform (clean up)


df_clean = (
    df.withColumn("name", lower(col("name")))
      .withColumn("company", lower(col("company")))
      .withColumn("email", lower(col("email")))
)


# Step 3: Write processed data

print(f"Writing cleaned data to {output_path}")
df_clean.repartition(1).write.mode("overwrite").json(output_path)


# Step 4: Write manifest

bucket, prefix = output_path.replace("s3://", "").split("/", 1)
manifest_key = f"{prefix.rstrip('/')}/_MANIFEST.json"

manifest_data = {
    "job_id": job_id,
    "source": input_path,
    "output": output_path,
    "timestamp": int(time.time()),
    "record_count": df_clean.count(),
}

s3.put_object(
    Bucket=bucket,
    Key=manifest_key,
    Body=json.dumps(manifest_data, indent=2).encode("utf-8")
)


# Step 5: Update DynamoDB table

manifest_table.put_item(
    Item={
        "job_id": job_id,
        "source_path": input_path,
        "output_path": output_path,
        "status": "PROCESSED",
        "timestamp": int(time.time())
    }
)

print(f"Glue job {job_id} completed successfully.")
