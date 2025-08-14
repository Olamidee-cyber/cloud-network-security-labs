import json, os, time, boto3
from botocore.config import Config

s3 = boto3.client("s3", config=Config(retries={"max_attempts": 5}))
iam = boto3.client("iam", config=Config(retries={"max_attempts": 5}))

BUCKET = os.environ["RESULTS_BUCKET"]
PREFIX = os.environ.get("RESULTS_PREFIX", "iam-guardian/")
ACCOUNT_ID = boto3.client("sts").get_caller_identity()["Account"]

# Heuristics for risky statements
def is_wildcard(action):
    if isinstance(action, str):
        return action == "*" or action.endswith(":*")
    if isinstance(action, list):
        return any(is_wildcard(a) for a in action)
    return False

def is_resource_wildcard(resource):
    if isinstance(resource, str):
        return resource == "*"
    if isinstance(resource, list):
        return any(r == "*" for r in resource)
    return False

def scan_policy_document(doc, policy_arn, policy_name):
    findings = []
    stmts = doc.get("Statement", [])
    if isinstance(stmts, dict):  # single statement normalization
        stmts = [stmts]

    for idx, st in enumerate(stmts, start=1):
        effect = st.get("Effect", "Allow")
        action = st.get("Action", [])
        resource = st.get("Resource", [])
        cond = st.get("Condition", {})

        wildcard_action = is_wildcard(action)
        wildcard_resource = is_resource_wildcard(resource)

        if effect == "Allow" and (wildcard_action or wildcard_resource):
            findings.append({
                "policy_arn": policy_arn,
                "policy_name": policy_name,
                "statement_index": idx,
                "wildcard_action": bool(wildcard_action),
                "wildcard_resource": bool(wildcard_resource),
                "has_condition": bool(cond),
                "condition_keys": list(cond.keys()) if isinstance(cond, dict) else [],
                "action": action,
                "resource": resource,
                "effect": effect
            })
    return findings

def list_customer_policies():
    paginator = iam.get_paginator("list_policies")
    for page in paginator.paginate(Scope="Local"):
        for p in page.get("Policies", []):
            yield p

def get_default_version_doc(policy):
    ver_id = policy["DefaultVersionId"]
    v = iam.get_policy_version(PolicyArn=policy["Arn"], VersionId=ver_id)["PolicyVersion"]
    # AWS returns PolicyDocument as URL-encoded JSON if fetched via get_policy_version
    # boto3 automatically decodes to dict
    return v["Document"]

def handler(event, context):
    ts = int(time.time())
    all_findings = []
    scanned = 0

    for p in list_customer_policies():
        try:
            doc = get_default_version_doc(p)
            f = scan_policy_document(doc, p["Arn"], p["PolicyName"])
            scanned += 1
            if f:
                all_findings.extend(f)
        except Exception as e:
            all_findings.append({
                "policy_arn": p.get("Arn"),
                "policy_name": p.get("PolicyName"),
                "error": str(e),
                "note": "Failed to parse or retrieve policy version"
            })

    summary = {
        "account_id": ACCOUNT_ID,
        "scanned_policies": scanned,
        "total_findings": len(all_findings),
        "generated_at_epoch": ts,
        "generated_at_iso": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(ts)),
        "findings": all_findings
    }

    key = f"{PREFIX}findings_{ACCOUNT_ID}_{ts}.json"
    s3.put_object(
        Bucket=BUCKET,
        Key=key,
        Body=json.dumps(summary, indent=2).encode("utf-8"),
        ContentType="application/json"
    )

    return {"ok": True, "s3_key": key, "scanned": scanned, "findings": len(all_findings)}


