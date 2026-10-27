output "lambda_arn" {
  value = aws_lambda_function.comprehend_lambda.arn
}
output "allow_s3_trigger" {
  description = "Policy for allowing s3 to trigger the lambda on upload"
  value = aws_lambda_permission.allow_s3
}