import os
import json
import uuid
import boto3

s3 = boto3.client("s3")
dynamodb = boto3.resource("dynamodb")
sqs = boto3.client("sqs")

INDEX_BATCH_BUCKET = os.environ["INDEX_BATCH_BUCKET"]
BATCH_TABLE = os.environ["BATCH_TABLE"]
INDEX_QUEUE_URL = os.environ["INDEX_QUEUE_URL"]

def handler(event, context):
    """Create index batches from enriched data and send SQS messages."""
    enriched_s3 = event["enriched_s3"].replace("s3://", "")
    bucket, key = enriched_s3.split("/", 1)
    
    # Read enriched JSON file
    obj = s3.get_object(Bucket=bucket, Key=key)
    records = json.loads(obj["Body"].read())

    # Split into batches of N records
    batch_size = 2  # configurable
    for i in range(0, len(records), batch_size):
        batch_records = records[i:i + batch_size]
        batch_id = str(uuid.uuid4())
        batch_key = f"batches/{batch_id}.ndjson"

        # Convert to NDJSON
        ndjson_data = "\n".join([json.dumps(r) for r in batch_records])
        s3.put_object(Bucket=INDEX_BATCH_BUCKET, Key=batch_key, Body=ndjson_data)

        # DynamoDB record (for idempotency + tracking)
        table = dynamodb.Table(BATCH_TABLE)
        table.put_item(Item={
            "batch_id": batch_id,
            "status": "pending",
            "s3_key": batch_key
        })

        # Trigger indexer via SQS
        msg = {"batch_id": batch_id, "s3_key": batch_key}
        sqs.send_message(QueueUrl=INDEX_QUEUE_URL, MessageBody=json.dumps(msg))

    return {"status": "batches_created", "total_batches": len(records) // batch_size}
