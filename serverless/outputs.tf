output "http_api_url" {
  value       = aws_apigatewayv2_stage.default.invoke_url
  description = "Base URL for the HTTP API stage"
}

