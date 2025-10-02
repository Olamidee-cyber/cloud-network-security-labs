import json, os, boto3

TABLE = os.environ.get("TABLE")
ddb = boto3.client("dynamodb")

def handler(event, context):
    pid = (event.get("pathParameters") or {}).get("id")
    if not pid:
        return {"statusCode": 400, "body": "missing id"}

    ddb.delete_item(TableName=TABLE, Key={"id": {"S": pid}})

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({"id": pid, "deleted": True})
    }

