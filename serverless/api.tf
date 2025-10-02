############################################
# IAM: Lambda execution role + logs
############################################

data "aws_iam_policy_document" "lambda_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name               = "${var.project}-lambda-exec"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

############################################
# Lambda: /health (code in lambda/handler.py)
# NOTE: main.tf packages lambda.zip for this
############################################

resource "aws_lambda_function" "health" {
  function_name    = "${var.project}-health"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "handler.handler"
  runtime          = "python3.11"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 5
}

############################################
# API Gateway HTTP API v2
############################################

resource "aws_apigatewayv2_api" "http" {
  name          = "${var.project}-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.health.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "health" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "GET /health"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.health.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

############################################
# IAM: DynamoDB policy for CRUD on our table
############################################

data "aws_iam_policy_document" "ddb_rw_doc" {
  statement {
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
    ]
    resources = [aws_dynamodb_table.items.arn]
  }
}

resource "aws_iam_policy" "ddb_rw" {
  name   = "${var.project}-ddb-rw"
  policy = data.aws_iam_policy_document.ddb_rw_doc.json
}

resource "aws_iam_role_policy_attachment" "lambda_ddb_rw" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.ddb_rw.arn
}

############################################
# Lambdas: POST /items, GET /items/{id},
#          PUT /items/{id}, DELETE /items/{id}
############################################

# --- package zips for these lambdas ---
data "archive_file" "put_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/put_item.py"
  output_path = "${path.module}/put_item.zip"
}

data "archive_file" "get_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/get_item.py"
  output_path = "${path.module}/get_item.zip"
}

data "archive_file" "update_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/update_item.py"
  output_path = "${path.module}/update_item.zip"
}

data "archive_file" "delete_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/delete_item.py"
  output_path = "${path.module}/delete_item.zip"
}

# --- lambda functions ---
resource "aws_lambda_function" "put_item" {
  function_name    = "${var.project}-put-item"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "put_item.handler"
  runtime          = "python3.11"
  filename         = data.archive_file.put_zip.output_path
  source_code_hash = data.archive_file.put_zip.output_base64sha256
  timeout          = 6
  environment { variables = { TABLE = aws_dynamodb_table.items.name } }
}

resource "aws_lambda_function" "get_item" {
  function_name    = "${var.project}-get-item"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "get_item.handler"
  runtime          = "python3.11"
  filename         = data.archive_file.get_zip.output_path
  source_code_hash = data.archive_file.get_zip.output_base64sha256
  timeout          = 6
  environment { variables = { TABLE = aws_dynamodb_table.items.name } }
}

resource "aws_lambda_function" "update_item" {
  function_name    = "${var.project}-update-item"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "update_item.handler"
  runtime          = "python3.11"
  filename         = data.archive_file.update_zip.output_path
  source_code_hash = data.archive_file.update_zip.output_base64sha256
  timeout          = 6
  environment { variables = { TABLE = aws_dynamodb_table.items.name } }
}

resource "aws_lambda_function" "delete_item" {
  function_name    = "${var.project}-delete-item"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "delete_item.handler"
  runtime          = "python3.11"
  filename         = data.archive_file.delete_zip.output_path
  source_code_hash = data.archive_file.delete_zip.output_base64sha256
  timeout          = 6
  environment { variables = { TABLE = aws_dynamodb_table.items.name } }
}

# --- integrations ---
resource "aws_apigatewayv2_integration" "put_integ" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.put_item.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "get_integ" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.get_item.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "update_integ" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.update_item.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "delete_integ" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.delete_item.invoke_arn
  payload_format_version = "2.0"
}

# --- routes ---
resource "aws_apigatewayv2_route" "post_items" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "POST /items"
  target    = "integrations/${aws_apigatewayv2_integration.put_integ.id}"
}

resource "aws_apigatewayv2_route" "get_item" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "GET /items/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.get_integ.id}"
}

resource "aws_apigatewayv2_route" "put_item" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "PUT /items/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.update_integ.id}"
}

resource "aws_apigatewayv2_route" "delete_item" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "DELETE /items/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.delete_integ.id}"
}

# --- invoke permissions for API Gateway ---
resource "aws_lambda_permission" "apigw_put" {
  statement_id  = "AllowAPIGatewayInvokePut"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.put_item.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_get" {
  statement_id  = "AllowAPIGatewayInvokeGet"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_item.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_update" {
  statement_id  = "AllowAPIGatewayInvokeUpdate"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.update_item.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_delete" {
  statement_id  = "AllowAPIGatewayInvokeDelete"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.delete_item.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

