# S3 Bucket for .tfstate
terraform {
    backend "s3"{}
}

# Create S3 Bucket for resumes
resource "aws_s3_bucket" "s3_resume" {
    bucket_prefix          = "king-von"
    region                 = var.region
    force_destroy          = true
}

resource "aws_s3_bucket_cors_configuration" "s3_resume_cors_config" {
    bucket = aws_s3_bucket.s3_resume.bucket

    cors_rule {
        allowed_methods = ["PUT", "GET", "POST"]
        allowed_origins = ["*"]
        allowed_headers = ["*"]
    }
}

# Resume Processor Module
module "process_trigger_module" {
    source = "./modules/process_trigger"
    textract_lambda_arn = module.textract_module.lambda_arn
    comprehend_lambda_arn = module.comprehend_module.lambda_arn
    region = var.region
    bucket_arn = aws_s3_bucket.s3_resume.arn
    bucket = aws_s3_bucket.s3_resume.bucket
}

# Website module
module "website_module" {
    source = "./modules/website"

    key_name = var.key_name
    bucket_id = aws_s3_bucket.s3_resume.bucket
    bucket_arn = aws_s3_bucket.s3_resume.arn
    region = var.region
    availability_zone_a = var.availability_zone_a
    availability_zone_b = var.availability_zone_b
}

module "comprehend_module" {
    source = "./modules/comprehend"

    lambda_arn = module.bedrock_module.lambda_arn
    bucket_id = aws_s3_bucket.s3_resume.bucket
    bucket_arn = aws_s3_bucket.s3_resume.arn
    region = var.region
}

module "textract_module" {
    source = "./modules/textract"

    bucket_id = aws_s3_bucket.s3_resume.bucket
    bucket_arn = aws_s3_bucket.s3_resume.arn
    region = var.region
}

module "dynamodb_module" {
    source = "./modules/dynamoDB"

    lambda_arn = module.bedrock_module.lambda_arn
}

module "lambda" {
  source = "./modules/lambda/"
}

module "bedrock_module" {
    source = "./modules/bedrock"

    bucket_id = aws_s3_bucket.s3_resume.bucket
    bucket_arn = aws_s3_bucket.s3_resume.arn
    region = var.region
}
