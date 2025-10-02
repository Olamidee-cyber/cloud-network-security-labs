import json, os, uuid, boto3

TABLE = os.environ.get("TABLE")
ddb = boto3.client("dynamodb")

def handler(event, context):
    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return {"statusCode": 400, "body": "invalid json"}

    task = body.get("task")
    priority = body.get("priority", "medium")
    if not task:
        return {"statusCode": 400, "body": "missing task"}

    item_id = str(uuid.uuid4())

    # store as two attributes: id (S) and data (S: JSON string)
    ddb.put_item(
        TableName=TABLE,
        Item={
            "id": {"S": item_id},
            "data": {"S": json.dumps({"task": task, "priority": priority})},
        },
        ConditionExpression="attribute_not_exists(id)"
    )

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({"ok": True, "id": item_id})
    }
