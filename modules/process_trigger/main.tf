data "archive_file" "initialize_zip" {
  type = "zip"
  source_file = "${path.module}/lambda/initialize.py"
  output_path = "${path.module}/initialize-lambda.zip"
}
data "aws_caller_identity" "current" {}

resource "aws_iam_role" "initialize_lambda_role" {
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

# Initialize IAM Policy for Role
resource "aws_iam_role_policy" "initialize_lambda_policy" {
    name = "initialize_lambda_policy"
    role = aws_iam_role.initialize_lambda_role.id

    policy = jsonencode({
        Version = "2012-10-17",
        Statement = [
        {
            Effect = "Allow",
            Action = [
                "s3:GetObject",
                "s3:PutObject",
                "s3:ListBucket"
            ],
            Resource = "*"
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

resource "aws_iam_role_policy" "lambda_invoke_policy" {
  name = "invoke_lambda"
  role = aws_iam_role.initialize_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "lambda:InvokeFunction",
        Resource = var.comprehend_lambda_arn
      },
      {
        Effect = "Allow",
        Action = "lambda:InvokeFunction",
        Resource = var.textract_lambda_arn
      }
    ]
  })
}

resource "aws_lambda_function" "initialize_lambda" {
  function_name = "initialize"
  role          = aws_iam_role.initialize_lambda_role.arn
  handler       = "initialize.lambda_handler"
  runtime       = "python3.10"
  filename      = data.archive_file.initialize_zip.output_path

  depends_on = [aws_iam_role_policy.lambda_invoke_policy]
}

resource "aws_lambda_permission" "initialize_lambda_allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.initialize_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = var.bucket_arn
}

# Trigger Lambdas on S3 Upload
resource "aws_s3_bucket_notification" "process_trigger" {
    bucket = var.bucket

    lambda_function {
        lambda_function_arn = aws_lambda_function.initialize_lambda.arn
        filter_prefix       = "users/"
        events              = ["s3:ObjectCreated:*"]
    }

    depends_on =  [aws_lambda_permission.initialize_lambda_allow_s3]
}
