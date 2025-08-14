output "results_bucket" {
  value = aws_s3_bucket.results.bucket
}

output "lambda_function_name" {
  value = aws_lambda_function.scanner.function_name
}

output "schedule_expression" {
  value = var.schedule_expression
}

