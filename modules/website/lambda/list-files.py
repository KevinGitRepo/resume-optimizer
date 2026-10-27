import json
import boto3
import os

s3 = boto3.client('s3')

def lambda_handler(event, context):
    bucket = os.environ['BUCKET']

    username = event['pathParameters'].get('username')
    if not username:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'Missing username'})
        }

    response = s3.list_objects_v2(
        Bucket=bucket, 
        Prefix=f'users/{username}/',
        Delimiter='/'
    )
    files = [obj['Key'].replace(f'users/{username}/', '') for obj in response.get('Contents', [])]

    return {
        'statusCode': 200,
        'body': json.dumps({'files': files})
    }