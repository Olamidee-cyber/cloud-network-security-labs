import json, os, boto3

TABLE = os.environ.get("TABLE")
ddb = boto3.client("dynamodb")

def handler(event, context):
    pid = (event.get("pathParameters") or {}).get("id")
    if not pid:
        return {"statusCode": 400, "body": "missing id"}

    body = json.loads(event.get("body") or "{}")
    # store whole object under "data" (simple pattern for the lab)
    ddb.update_item(
        TableName=TABLE,
        Key={"id": {"S": pid}},
        UpdateExpression="SET data = :d",
        ExpressionAttributeValues={":d": {"S": json.dumps(body)}}
    )

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({"id": pid, "ok": True})
    }

