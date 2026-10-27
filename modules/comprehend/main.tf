## Lambda Function
data "archive_file" "comprehend_zip" {
    type = "zip"
    source_file = "${path.module}/lambda/comprehend.py"
    output_path = "${path.module}/comprehend-lambda.zip"
}

data "aws_caller_identity" "current" {}

# Needed for Lambda to access S3 data
resource "aws_iam_role" "comprehend_lambda_role" {
    
    assume_role_policy = jsonencode({
        Statement = [{
            Action = "sts:AssumeRole",
            Effect = "Allow",
            Principal = {
                Service = "lambda.amazonaws.com"
            }
        }]
    })
}

# Comprehend IAM Policy for Role
resource "aws_iam_role_policy" "comprehend_lambda_policy" {
    name = "comprehend_lambda_policy"
    role = aws_iam_role.comprehend_lambda_role.id

    policy = jsonencode({
        Version = "2012-10-17",
        Statement = [
        {
            Effect = "Allow",
            Action = [
                "comprehend:*",
                "s3:GetObject",
                "s3:PutObject",
                "s3:ListBucket"
            ],
            Resource = "*"
        },
        {
            Effect = "Allow",
            Action = [
                "dynamodb:GetItem",
                "dynamodb:PutItem",
                "dynamodb:UpdateItem"
            ],
            Resource = "arn:aws:dynamodb:${var.region}:${data.aws_caller_identity.current.account_id}:table/user_profile"
        },
        {
            Effect = "Allow",
            Action = [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            Resource = "*"
        }]
    })
}

resource "aws_lambda_function" "comprehend_lambda" {
    function_name = "comprehend_processor"
    role          = aws_iam_role.comprehend_lambda_role.arn
    handler       = "comprehend.lambda_handler"
    runtime       = "python3.10"
    filename      = data.archive_file.comprehend_zip.output_path

    depends_on = [aws_iam_role_policy.comprehend_lambda_policy]
}

# Lambda Permissions for S3 Trigger
resource "aws_lambda_permission" "allow_s3" {
    statement_id  = "AllowS3Invoke"
    action        = "lambda:InvokeFunction"
    function_name = aws_lambda_function.comprehend_lambda.function_name
    principal     = "s3.amazonaws.com"
    source_arn    = var.bucket_arn
}

# Perms to access bedrock lambda
resource "aws_iam_role_policy" "lambda_invoke_policy" {
    name = "invoke_lambda"
    role = aws_iam_role.comprehend_lambda_role.id

    policy = jsonencode({
        Version = "2012-10-17",
        Statement = [{
            Effect = "Allow",
            Action = "lambda:InvokeFunction",
            Resource = var.lambda_arn
        }]
    })
}