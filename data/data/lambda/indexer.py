import os
import json
import boto3
import requests

s3 = boto3.client("s3")
dynamodb = boto3.resource("dynamodb")

OPENSEARCH_URL = os.environ["OPENSEARCH_URL"] #need to replace it with vpc endpoint url or can pass it as env var.
INDEX_ALIAS = os.environ["INDEX_ALIAS"]
BATCH_TABLE = os.environ["BATCH_TABLE"]
INDEX_BATCH_BUCKET = os.environ["INDEX_BATCH_BUCKET"]

def handler(event, context):
    """Consume SQS messages and index data batches into OpenSearch."""
    table = dynamodb.Table(BATCH_TABLE)

    for record in event["Records"]:
        msg = json.loads(record["body"])
        batch_id = msg["batch_id"]
        batch_key = msg["s3_key"]

        # Check if batch already indexed (idempotent)
        item = table.get_item(Key={"batch_id": batch_id}).get("Item", {})
        if item.get("status") == "done":
            print(f"Batch {batch_id} already processed.")
            continue

        # Fetch NDJSON batch
        obj = s3.get_object(Bucket=INDEX_BATCH_BUCKET, Key=batch_key)
        lines = obj["Body"].read().decode("utf-8").splitlines()

        # Prepare bulk payload for OpenSearch
        bulk_payload = ""
        for line in lines:
            doc = json.loads(line)
            doc_id = f"{doc['name']}_{doc['company']}"
            bulk_payload += json.dumps({"index": {"_index": INDEX_ALIAS, "_id": doc_id}}) + "\n"
            bulk_payload += json.dumps(doc) + "\n"

        # Send bulk request
        headers = {"Content-Type": "application/x-ndjson"}
        resp = requests.post(f"{OPENSEARCH_URL}/_bulk", data=bulk_payload, headers=headers)
        if resp.status_code >= 300:
            print(f"Error indexing batch {batch_id}: {resp.text}")
            continue

        # Update DynamoDB status
        table.update_item(
            Key={"batch_id": batch_id},
            UpdateExpression="SET #s = :s",
            ExpressionAttributeNames={"#s": "status"},
            ExpressionAttributeValues={":s": "done"}
        )

        print(f"Batch {batch_id} indexed successfully.")

    return {"status": "success"}
