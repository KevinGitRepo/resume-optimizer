data "archive_file" "textract_zip" {
    type = "zip"
    source_file = "${path.module}/lambda/textract.py"
    output_path = "${path.module}/textract-lambda.zip"
}

data "aws_caller_identity" "current" {}

# Textract IAM Role for Lambda
resource "aws_iam_role" "textract_lambda_role" {

    assume_role_policy = jsonencode({
    Statement = [{
            Effect = "Allow",
            Principal = { Service = "lambda.amazonaws.com" },
            Action = "sts:AssumeRole" 
        }]
    })

    tags = {
        name = "textract_lambda_role"
    }
  
}

# Textract IAM Policy for Role
resource "aws_iam_role_policy" "textract_lambda_policy" {
    name = "textract_lambda_policy"
    role = aws_iam_role.textract_lambda_role.id

    policy = jsonencode({
        Statement = [
        {
            Effect = "Allow",
            Action = [
                "textract:*",
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
        }
        ]
    })
}

# Lambda Function
resource "aws_lambda_function" "textract_lambda" {
    function_name = "textract_processor"
    role          = aws_iam_role.textract_lambda_role.arn
    handler       = "textract.lambda_handler"
    runtime       = "python3.10"
    filename         = data.archive_file.textract_zip.output_path

    depends_on = [aws_iam_role_policy.textract_lambda_policy]

    environment {
        variables = {
            BUCKET_NAME = var.bucket_id
        }
    }
}

#Lambda Permissions for S3 Trigger
resource "aws_lambda_permission" "allow_s3" {
    statement_id    = "AllowS3Invoke"
    action          = "lambda:InvokeFunction"
    function_name   = aws_lambda_function.textract_lambda.function_name
    principal       = "s3.amazonaws.com"
    source_arn      = var.bucket_arn
}