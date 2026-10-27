data "archive_file" "bedrock_zip" {
    type = "zip"
    source_file = "${path.module}/lambda/bedrock.py"
    output_path = "${path.module}/bedrock-lambda.zip"
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "bedrock_invoke_role" {
  name = "bedrock_invoke_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "bedrock_invoke_policy" {
  name = "bedrock_invoke_policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = "arn:aws:bedrock:${var.region}::foundation-model/amazon.titan-text-express-v1"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "bedrock_attach" {
  role       = aws_iam_role.bedrock_invoke_role.name
  policy_arn = aws_iam_policy.bedrock_invoke_policy.arn
}

# Needed for Lambda to access S3 data
resource "aws_iam_role" "bedrock_lambda_role" {
    
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

# Bedrock IAM Policy for Role
resource "aws_iam_role_policy" "bedrock_lambda_policy" {
    name = "bedrock_lambda_policy"
    role = aws_iam_role.bedrock_lambda_role.id

    policy = jsonencode({
        Version = "2012-10-17",
        Statement = [
        {
            Effect = "Allow",
            Action = [
                "bedrock:*",
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

resource "aws_lambda_function" "bedrock_lambda" {
    function_name = "bedrock_processor"
    role          = aws_iam_role.bedrock_lambda_role.arn
    handler       = "bedrock.lambda_handler"
    runtime       = "python3.10"
    filename      = data.archive_file.bedrock_zip.output_path

    timeout       = 60

    depends_on = [aws_iam_role_policy.bedrock_lambda_policy]
    environment {
      variables = {
        BUCKET = var.bucket_id
      }
    }
}