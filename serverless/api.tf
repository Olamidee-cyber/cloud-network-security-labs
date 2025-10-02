############################################
# Lambda execution role (+ CloudWatch logs)
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
  name               = "serverless-todo-lambda-exec"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

############################################
# Package Lambda code (one zip per function)
############################################
data "archive_file" "health_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/handler.py"
  output_path = "${path.module}/health.zip"
}

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

############################################
# API Gateway (HTTP API) with CORS
############################################
resource "aws_apigatewayv2_api" "http" {
  name          = "serverless-todo-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"] # tighten later to your S3 site origin
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers = ["content-type"]
    max_age       = 3600
  }
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true
}

############################################
# LAMBDAS + INTEGRATIONS + ROUTES + PERMS
############################################

# --- Health: GET /health ---
resource "aws_lambda_function" "health" {
  function_name    = "serverless-todo-health"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "handler.handler"
  runtime          = "python3.11"
  filename         = data.archive_file.health_zip.output_path
  source_code_hash = data.archive_file.health_zip.output_base64sha256
  timeout          = 5
}

resource "aws_apigatewayv2_integration" "health" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.health.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "health" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "GET /health"
  target    = "integrations/${aws_apigatewayv2_integration.health.id}"
}

resource "aws_lambda_permission" "apigw_health" {
  statement_id  = "AllowAPIGatewayInvokeHealth"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.health.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

# --- Create: POST /items ---
resource "aws_lambda_function" "put_item" {
  function_name    = "serverless-todo-put-item"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "put_item.handler"
  runtime          = "python3.11"
  filename         = data.archive_file.put_zip.output_path
  source_code_hash = data.archive_file.put_zip.output_base64sha256
  timeout          = 6
  environment { variables = { TABLE = aws_dynamodb_table.items.name } }
}

resource "aws_apigatewayv2_integration" "put_item" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.put_item.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "post_items" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "POST /items"
  target    = "integrations/${aws_apigatewayv2_integration.put_item.id}"
}

resource "aws_lambda_permission" "apigw_put" {
  statement_id  = "AllowAPIGatewayInvokePut"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.put_item.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

# --- Read: GET /items/{id} ---
resource "aws_lambda_function" "get_item" {
  function_name    = "serverless-todo-get-item"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "get_item.handler"
  runtime          = "python3.11"
  filename         = data.archive_file.get_zip.output_path
  source_code_hash = data.archive_file.get_zip.output_base64sha256
  timeout          = 6
  environment { variables = { TABLE = aws_dynamodb_table.items.name } }
}

resource "aws_apigatewayv2_integration" "get_item" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.get_item.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get_item" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "GET /items/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.get_item.id}"
}

resource "aws_lambda_permission" "apigw_get" {
  statement_id  = "AllowAPIGatewayInvokeGet"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_item.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

# --- Update: PUT /items/{id} ---
resource "aws_lambda_function" "update_item" {
  function_name    = "serverless-todo-update-item"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "update_item.handler"
  runtime          = "python3.11"
  filename         = data.archive_file.update_zip.output_path
  source_code_hash = data.archive_file.update_zip.output_base64sha256
  timeout          = 6
  environment { variables = { TABLE = aws_dynamodb_table.items.name } }
}

resource "aws_apigatewayv2_integration" "update_item" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.update_item.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "put_item" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "PUT /items/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.update_item.id}"
}

resource "aws_lambda_permission" "apigw_update" {
  statement_id  = "AllowAPIGatewayInvokeUpdate"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.update_item.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

# --- Delete: DELETE /items/{id} ---
resource "aws_lambda_function" "delete_item" {
  function_name    = "serverless-todo-delete-item"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "delete_item.handler"
  runtime          = "python3.11"
  filename         = data.archive_file.delete_zip.output_path
  source_code_hash = data.archive_file.delete_zip.output_base64sha256
  timeout          = 6
  environment { variables = { TABLE = aws_dynamodb_table.items.name } }
}

resource "aws_apigatewayv2_integration" "delete_item" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.delete_item.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "delete_item" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "DELETE /items/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.delete_item.id}"
}

resource "aws_lambda_permission" "apigw_delete" {
  statement_id  = "AllowAPIGatewayInvokeDelete"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.delete_item.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

############################################
# Optional output (REMOVE if you have outputs.tf already)
############################################


