import json, os, boto3

TABLE = os.environ.get("TABLE")
ddb = boto3.client("dynamodb")

def handler(event, context):
    pid = (event.get("pathParameters") or {}).get("id")
    if not pid:
        return {"statusCode": 400, "body": "missing id"}

    res = ddb.get_item(TableName=TABLE, Key={"id": {"S": pid}})
    item = res.get("Item")
    if not item:
        return {"statusCode": 404, "body": "not found"}

    data = json.loads(item["data"]["S"])
    data["id"] = item["id"]["S"]
    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(data)
    }
