import boto3

def list_users():
    iam = boto3.client('iam')
    users = iam.list_users()['Users']
    return [user['UserName'] for user in users]

def list_user_policies(user):
    iam = boto3.client('iam')
    attached = iam.list_attached_user_policies(UserName=user)['AttachedPolicies']
    inline = iam.list_user_policies(UserName=user)
    return attached, inline['PolicyNames']

def get_policy_document(policy_arn):
    iam = boto3.client('iam')
    version = iam.get_policy(PolicyArn=policy_arn)['Policy']['DefaultVersionId']
    doc = iam.get_policy_version(PolicyArn=policy_arn, VersionId=version)['PolicyVersion']['Document']
    return doc

def scan_policy(doc):
    for stmt in doc.get('Statement', []):
        actions = stmt.get('Action', [])
        resources = stmt.get('Resource', [])
        if isinstance(actions, str):
            actions = [actions]
        if isinstance(resources, str):
            resources = [resources]

        if '*' in actions or '*' in resources:
            return True
    return False

def main():
    flagged = []
    users = list_users()
    for user in users:
        attached, inline = list_user_policies(user)

        for pol in attached:
            doc = get_policy_document(pol['PolicyArn'])
            if scan_policy(doc):
                flagged.append((user, pol['PolicyName']))

        if inline:
            flagged.append((user, "[Inline Policy]"))

    if flagged:
        print("🔒 Flagged Policies:")
        for user, policy in flagged:
            print(f"User: {user} | Policy: {policy}")
    else:
        print("✅ No over-permissive policies found.")

if __name__ == "__main__":
    main()

