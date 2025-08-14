data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/${var.project_name}.zip"
}

resource "aws_lambda_function" "scanner" {
  function_name = "${var.project_name}-scanner"
  role          = aws_iam_role.lambda_role.arn
  handler       = "handler.handler"
  runtime       = "python3.12"
  filename      = data.archive_file.lambda_zip.output_path
  architectures = ["arm64"]

  environment {
    variables = {
      RESULTS_BUCKET = aws_s3_bucket.results.bucket
      RESULTS_PREFIX = var.results_prefix
    }
  }

  timeout     = 60
  memory_size = 256
}

# CloudWatch Logs group (optional but nice)
resource "aws_cloudwatch_log_group" "lg" {
  name              = "/aws/lambda/${aws_lambda_function.scanner.function_name}"
  retention_in_days = 30
}

# Schedule to run it
resource "aws_cloudwatch_event_rule" "schedule" {
  name                = "${var.project_name}-schedule"
  schedule_expression = var.schedule_expression
}

resource "aws_cloudwatch_event_target" "target" {
  rule      = aws_cloudwatch_event_rule.schedule.name
  target_id = "lambda"
  arn       = aws_lambda_function.scanner.arn
}

resource "aws_lambda_permission" "allow_events" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scanner.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule.arn
}

