import boto3
import json

# AWS clients
lambda_function = boto3.client('lambda')

def invoke_comprehend(param):
    lambda_function.invoke(
        FunctionName="comprehend_processor",
        InvocationType="Event",
        Payload=json.dumps(param)
    )

def invoke_textract(param):
    lambda_function.invoke(
        FunctionName="textract_processor",
        InvocationType="Event",
        Payload=json.dumps(param)
    )

def lambda_handler(event, context):
    bucket_name = event['Records'][0]['s3']['bucket']['name']
    s3_key = event['Records'][0]['s3']['object']['key']
    
    invoke_param = {
        'bucket': bucket_name,
        'key': s3_key
    }

    # logging the return values of both
    invoke_comprehend(param=invoke_param)
    invoke_textract(param=invoke_param)