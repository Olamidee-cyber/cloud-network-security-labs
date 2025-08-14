data "aws_iam_policy_document" "assume_lambda" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "${var.project_name}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json
}

# Permissions: read IAM policies + write results to S3 + write logs
data "aws_iam_policy_document" "lambda_policy" {
  statement {
    sid     = "IamRead"
    effect  = "Allow"
    actions = [
      "iam:ListPolicies",
      "iam:GetPolicyVersion",
      "iam:ListPolicyVersions",
      "iam:GetPolicy"
    ]
    resources = ["*"]
  }

  statement {
    sid     = "S3Write"
    effect  = "Allow"
    actions = ["s3:PutObject", "s3:AbortMultipartUpload", "s3:PutObjectAcl"]
    resources = ["${aws_s3_bucket.results.arn}/*"]
  }

  statement {
    sid     = "Logs"
    effect  = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "lambda_inline" {
  name   = "${var.project_name}-policy"
  policy = data.aws_iam_policy_document.lambda_policy.json
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_inline.arn
}

