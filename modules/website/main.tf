provider "aws" {
    region = var.region
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "lambda_role" {
    name = "lambda_s3_role"
    assume_role_policy = jsonencode({
        Version = "2012-10-17",
        Statement = [
            {
                Action = "sts:AssumeRole"
                Effect = "Allow"
                Principal = {
                    Service = "lambda.amazonaws.com"
                }
            }
        ]
    })
}

resource "aws_iam_policy" "lambda_policy" {
    name = "lambda_s3_policy"
    policy = jsonencode({
        Version = "2012-10-17",
        Statement = [
            {
                Effect = "Allow",
                Action = ["s3:PutObject", "s3:ListBucket"],
                Resource = [
                    var.bucket_arn,
                    "${var.bucket_arn}/*"
                ]
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

resource "aws_iam_role_policy_attachment" "lambda_attach" {
    role = aws_iam_role.lambda_role.name
    policy_arn = aws_iam_policy.lambda_policy.arn
}

data "archive_file" "index_zip" {
    type = "zip"
    source_file = "${path.module}/lambda/index.py"
    output_path = "${path.module}/index-lambda.zip"
}

data "archive_file" "upload_files_zip" {
    type = "zip"
    source_file = "${path.module}/lambda/upload_files.py"
    output_path = "${path.module}/upload-files-lambda.zip"
}

data "archive_file" "list_files_zip" {
    type = "zip"
    source_file = "${path.module}/lambda/list-files.py"
    output_path = "${path.module}/list-files-lambda.zip"
}

data "archive_file" "login_zip" {
    type = "zip"
    source_file = "${path.module}/lambda/login.py"
    output_path = "${path.module}/login-lambda.zip"
}

resource "aws_lambda_function" "s3_upload_file" {
    function_name = "s3_upload_file"
    role = aws_iam_role.lambda_role.arn
    handler = "index.lambda_handler"
    runtime = "python3.8"
    filename = data.archive_file.index_zip.output_path
    environment {
        variables = {
            BUCKET = var.bucket_id
        }
    }
}

resource "aws_lambda_function" "s3_upload_file_put" {
    function_name = "s3_upload_file_put"
    role = aws_iam_role.lambda_role.arn
    handler = "upload_files.lambda_handler"
    runtime = "python3.8"
    filename = data.archive_file.upload_files_zip.output_path
    environment {
        variables = {
            BUCKET = var.bucket_id
        }
    }
}

resource "aws_lambda_function" "list_files" {
    function_name = "list_files"
    role = aws_iam_role.lambda_role.arn
    handler = "list-files.lambda_handler"
    runtime = "python3.8"
    filename = data.archive_file.list_files_zip.output_path
    environment {
        variables = {
            BUCKET = var.bucket_id
        }
    }
}

resource "aws_lambda_function" "login" {
    function_name = "login"
    role = aws_iam_role.lambda_role.arn
    handler = "login.lambda_handler"
    runtime = "python3.8"
    filename = data.archive_file.login_zip.output_path
    environment {
        variables = {
            BUCKET = var.bucket_id
        }
    }
}

resource "aws_apigatewayv2_api" "http_api" {
    name = "s3-upload-api"
    protocol_type = "HTTP"
    cors_configuration {
        allow_origins = ["*"]
        allow_methods = ["GET", "POST", "OPTIONS", "PUT"]
        allow_headers = ["Content-Type", "Authorization"]
    }
}

resource "aws_apigatewayv2_integration" "upload_file" {
    api_id = aws_apigatewayv2_api.http_api.id
    integration_type = "AWS_PROXY"
    integration_uri = aws_lambda_function.s3_upload_file.invoke_arn
    integration_method = "POST"
    payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "upload_file_put" {
    api_id = aws_apigatewayv2_api.http_api.id
    integration_type = "AWS_PROXY"
    integration_uri = aws_lambda_function.s3_upload_file_put.invoke_arn
    integration_method = "POST"
    payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "list_files" {
    api_id = aws_apigatewayv2_api.http_api.id
    integration_type = "AWS_PROXY"
    integration_uri = aws_lambda_function.list_files.invoke_arn
    integration_method = "POST"
    payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "login" {
    api_id = aws_apigatewayv2_api.http_api.id
    integration_type = "AWS_PROXY"
    integration_uri = aws_lambda_function.login.invoke_arn
    integration_method = "POST"
    payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "upload_file" {
    api_id = aws_apigatewayv2_api.http_api.id
    route_key = "POST /upload-file/{username}/{filename}"
    target = "integrations/${aws_apigatewayv2_integration.upload_file.id}"
}

resource "aws_apigatewayv2_route" "upload_file_put" {
    api_id = aws_apigatewayv2_api.http_api.id
    route_key = "PUT /upload-file/{username}/{filename}"
    target = "integrations/${aws_apigatewayv2_integration.upload_file_put.id}"
}

resource "aws_apigatewayv2_route" "list_files" {
    api_id = aws_apigatewayv2_api.http_api.id
    route_key = "GET /list-files/{username}"
    target = "integrations/${aws_apigatewayv2_integration.list_files.id}"
}

resource "aws_apigatewayv2_route" "login" {
    api_id = aws_apigatewayv2_api.http_api.id
    route_key = "POST /login"
    target = "integrations/${aws_apigatewayv2_integration.login.id}"
}

resource "aws_apigatewayv2_stage" "default" {
    api_id = aws_apigatewayv2_api.http_api.id
    name = "$default"
    auto_deploy = true
}

resource "aws_lambda_permission" "api_gateway" {
    statement_id = "AllowAPIGatewayInvoke"
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.s3_upload_file.function_name
    principal = "apigateway.amazonaws.com"
    source_arn = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_gateway_list_files" {
    statement_id = "AllowAPIGatewayInvoke"
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.list_files.function_name
    principal = "apigateway.amazonaws.com"
    source_arn = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_gateway_login" {
    statement_id = "AllowAPIGatewayInvoke"
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.login.function_name
    principal = "apigateway.amazonaws.com"
    source_arn = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

resource "aws_iam_policy" "ec2_ssm_get_parameter_policy" {
    name = "EC2SSMGetParameterPolicy"
    description = "Allows EC2 role to read from SSM parameter"
    policy = jsonencode({
        Version = "2012-10-17",
        Statement = [
            {
                Effect = "Allow"
                Action = "ssm:GetParameter"
                Resource = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/resume/api_gateway_url"
            }
        ]
    })
}

resource "aws_iam_role_policy_attachment" "attach_ssm_get_parameter_policy" {
    role = aws_iam_role.ec2_s3_read_role.name
    policy_arn = aws_iam_policy.ec2_ssm_get_parameter_policy.arn
}

resource "aws_ssm_parameter" "api_url" {
    name = "/resume/api_gateway_url"
    type = "String"
    value = aws_apigatewayv2_api.http_api.api_endpoint
}

resource "aws_iam_role" "ec2_s3_read_role" {
    name = "ec2_s3_read_role"
    assume_role_policy = jsonencode({
        Version = "2012-10-17",
        Statement = [
            {
                Effect = "Allow",
                Principal = {
                    Service = "ec2.amazonaws.com"
                },
                Action = "sts:AssumeRole"
            }
        ]
    })
}

resource "aws_iam_policy" "ec2_s3_read_policy" {
    name = "ec2_s3_read_policy"
    policy = jsonencode({
        Version = "2012-10-17",
        Statement = [
            {
                Effect = "Allow",
                Action = ["s3:ListBucket"],
                Resource = "arn:aws:s3:::final-project-shared-bucket",
                Condition = {
                    StringLike = {
                        "s3:prefix" = "website/*"
                    }
                }
            },
            {
                Effect = "Allow",
                Action = ["s3:GetObject"],
                Resource = "arn:aws:s3:::final-project-shared-bucket/website/*",
            }
        ]
    })
}

resource "aws_iam_role_policy_attachment" "ec2_s3_read_attach" {
    role = aws_iam_role.ec2_s3_read_role.name
    policy_arn = aws_iam_policy.ec2_s3_read_policy.arn
    depends_on = [aws_iam_policy.ec2_s3_read_policy, aws_iam_role.ec2_s3_read_role]
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
    name = "ec2_s3_read_profile"
    role = aws_iam_role.ec2_s3_read_role.name
    depends_on = [aws_iam_role_policy_attachment.ec2_s3_read_attach]
}

resource "aws_security_group" "web_sg" {
    name = "web_sg"
    description = "Allow inbound HTTP traffic"
    vpc_id      = aws_vpc.vpc.id

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]  # Allow SSH access from anywhere
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_instance" "web_server" {
    ami                    = data.aws_ami.amazonlinux.id  # Use the AMI we filtered above
    instance_type          = "t2.micro"  # Free tier eligible instance type
    subnet_id              = aws_subnet.public_subnet.id  # Place in the public subnet
    vpc_security_group_ids = [aws_security_group.web_sg.id]  # Attach the EC2 security group
    iam_instance_profile   = aws_iam_instance_profile.ec2_instance_profile.name
    key_name               = var.key_name  # Replace with your SSH key pair name

    user_data = templatefile("${path.module}/website_install.tpl", {})
    
    tags = {
        Name = "Website"
    }

    depends_on = [aws_iam_instance_profile.ec2_instance_profile]
}

# VPC
resource "aws_vpc" "vpc" {
    cidr_block           = "10.0.0.0/16"
    enable_dns_hostnames = true
    enable_dns_support   = true
    tags = {
        Name = "Project VPC"
    }
}

# Public Subnet
resource "aws_subnet" "public_subnet" {
    vpc_id                  = aws_vpc.vpc.id
    cidr_block              = "10.0.1.0/24"
    availability_zone       = var.availability_zone_a
    map_public_ip_on_launch = true
    tags = {
        Name = "Project Public Subnet"
    }
}

# Private Subnet
resource "aws_subnet" "private_subnet" {
    vpc_id            = aws_vpc.vpc.id
    cidr_block        = "10.0.2.0/24"
    availability_zone = var.availability_zone_b
    tags = {
        Name = "Project Private Subnet"
    }
}

# Internet Gateway for Public Access
resource "aws_internet_gateway" "Resume_project" {
    vpc_id = aws_vpc.vpc.id
    tags = {
        Name = "Project Internet Gateway"
    }
}

# Public Route Table
resource "aws_route_table" "public_rt" {
    vpc_id = aws_vpc.vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.Resume_project.id
    }
    tags = {
        Name = "Project Public Route Table"
    }
}

# Associate Public Subnet with Public Route Table
resource "aws_route_table_association" "public_rta" {
    subnet_id      = aws_subnet.public_subnet.id
    route_table_id = aws_route_table.public_rt.id
}
