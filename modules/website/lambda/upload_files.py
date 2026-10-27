import json
import boto3
import os
import base64

s3 = boto3.client('s3')

def lambda_handler(event, context):
    bucket = os.environ['BUCKET']
    
    file_content_base64 = event['body']
    file_content = base64.b64decode(file_content_base64)

    filename = event['pathParameters']['filename']

    s3.put_object(Bucket=bucket, Key=filename, Body=file_content)

    return {
        'statusCode': 200,
        'headers': { 
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
            "Access-Control-Allow-Headers": "Content-Type, Authorization",
        },
        'body': json.dumps({'message': 'File Uploaded'})
    }