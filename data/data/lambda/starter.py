import os, boto3

sf_client = boto3.client("stepfunctions")
SF_ARN = os.environ.get("STEP_FUNCTION_ARN")

def handler(event, context):
    record = event['detail']
    bucket = record['bucket']['name']
    key = record['object']['key']

    input_payload = {
        "s3_object": f"s3://{bucket}/{key}",
        "final_output_s3": f"s3://{os.environ['PROCESSED_BUCKET']}/{key.rsplit('/',1)[0]}",
        "manifest_table": os.environ["MANIFEST_TABLE"]
    }

    response = sf_client.start_execution(stateMachineArn=SF_ARN, input=json.dumps(input_payload))
    return response
