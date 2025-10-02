
import json, os, boto3, uuid

TABLE = os.environ.get("TABLE")
ddb = boto3.client("dynamodb")

def handler(event, context):
    body = json.loads(event.get("body") or "{}")
    item_id = body.get("id") or str(uuid.uuid4())
    item = {
        "id": {"S": item_id},
        "data": {"S": json.dumps(body)}
    }
    ddb.put_item(TableName=TABLE, Item=item)
    return {
        "statusCode": 201,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({"id": item_id, "ok": True})
    }
