resource "random_string" "suffix" {
  length  = 6
  upper   = false
  lower   = true
  numeric = true
  special = false
}

variable "site_bucket_prefix" {
  type    = string
  default = "serverless-todo-site"
}

resource "aws_s3_bucket" "site" {
  bucket = "${var.site_bucket_prefix}-${random_string.suffix.result}"
}

# Enable static website hosting
resource "aws_s3_bucket_website_configuration" "site" {
  bucket = aws_s3_bucket.site.id
  index_document { suffix = "index.html" }
  error_document { key = "error.html" }
}

# Allow public reads of objects (site files)
resource "aws_s3_bucket_public_access_block" "site" {
  bucket                  = aws_s3_bucket.site.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

data "aws_iam_policy_document" "site_policy" {
  statement {
    sid     = "PublicReadGetObjects"
    effect  = "Allow"
    actions = ["s3:GetObject"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    resources = ["${aws_s3_bucket.site.arn}/*"]
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.site_policy.json
}

# Upload files (Terraform-managed)
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.site.id
  key          = "index.html"
  content_type = "text/html"
  source       = "${path.module}/web/index.html"
  etag         = filemd5("${path.module}/web/index.html")
}

resource "aws_s3_object" "error" {
  bucket       = aws_s3_bucket.site.id
  key          = "error.html"
  content_type = "text/html"
  content      = "<h1>Oops</h1>"
}

output "website_url" {
  value       = "http://${aws_s3_bucket_website_configuration.site.website_endpoint}"
  description = "Public S3 static website URL"
}

