data "archive_file" "dynamo_zip" {
    type = "zip"
    source_file = "${path.module}/lambda/dynamo.py"
    output_path = "${path.module}/dynamo-lambda.zip"
}

resource "aws_dynamodb_table" "user_profile"{
    name         = "user_profile" # This is the name of teh table
    billing_mode = "PAY_PER_REQUEST" # meaing we will pay based on the resources used
    hash_key     = "user_name" # for quick look up of tabel based on user_name (partion key)

    # This is the user_name (has to be unique), name of the user
    attribute{
        name = "user_name"
        type = "S"
    }

    stream_enabled = true
    stream_view_type = "NEW_AND_OLD_IMAGES" # Returns the entire entity that was modified
}

resource "aws_iam_role" "dynamo_lambda_role" {
    name = "dynamo_lambda_role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17",
        Statement = [{
            Effect = "Allow",
            Principal = { Service = "lambda.amazonaws.com" },
            Action = "sts:AssumeRole"
        }]
    })
}

# Custom policy for DynamoDB access and CloudWatch logging
resource "aws_iam_policy" "dynamo_lambda_policy" {
    name        = "dynamo_lambda_policy"
    description = "Custom policy for Lambda to access DynamoDB and write logs"

    policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
        {
        Effect   = "Allow"
        Action   = [
            "dynamodb:*"
        ]
        Resource = "*"
        },
        {
        Effect   = "Allow"
        Action   = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
        ]
        Resource = "*"
        }
    ]
    })
}

resource "aws_iam_role_policy_attachment" "dynamo_lambda_policy_attachment" {
    role = aws_iam_role.dynamo_lambda_role.name
    policy_arn = aws_iam_policy.dynamo_lambda_policy.arn
}

#perms to access bedrock lambda
resource "aws_iam_role_policy" "lambda_invoke_policy" {
    name = "invoke_lambda"
    role = aws_iam_role.dynamo_lambda_role.id

    policy = jsonencode({
        Version = "2012-10-17",
        Statement = [{
            Effect = "Allow",
            Action = "lambda:InvokeFunction",
            Resource = var.lambda_arn
        }]
    })
}

resource "aws_lambda_function" "dynamo_lambda_function" {
    function_name = "dynamo_lambda"
    handler = "dynamo.lambda_handler"
    runtime = "python3.10"
    role = aws_iam_role.dynamo_lambda_role.arn
    filename = data.archive_file.dynamo_zip.output_path
}

resource "aws_lambda_event_source_mapping" "dynamo_stream" {
    event_source_arn = aws_dynamodb_table.user_profile.stream_arn
    function_name = aws_lambda_function.dynamo_lambda_function.arn
    starting_position = "LATEST"
    batch_size = 1
}