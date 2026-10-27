import json
import boto3
import os
import hashlib

dynamodb = boto3.client('dynamodb')
dynamodb_table_name = 'user_profile'

def lambda_handler(event, context):
    bucket = os.environ['BUCKET']
    body = json.loads(event['body'])
    username = body.get('username')
    password = body.get('password')
    hashed_password = hashlib.sha256(password.encode('utf-8')).hexdigest()

    response = dynamodb.get_item(
        TableName=dynamodb_table_name,
        Key={
            'user_name': {'S': str(username)}
        },
        ProjectionExpression='password'
    )

    if 'Item' not in response:
        hashed_password = hashlib.sha256(password.encode('utf-8')).hexdigest()
        dynamodb.put_item(
            TableName=dynamodb_table_name,
            Item={
                'user_name': {'S': username},
                'password': {'S': hashed_password},
                'resume_key': {'M': {}}
            }
        )
        return {
            'statusCode': 201,
            'body': json.dumps({'message': 'Account created successfully!'})
        }

    stored_hashed_password = response['Item']['password']['S']

    hashed_password = hashlib.sha256(password.encode('utf-8')).hexdigest()

    if hashed_password != stored_hashed_password:
        return {
            'statusCode': 401,
            'body': json.dumps({'message': 'Invalid username or password!'})
        }

    return {
        'statusCode': 200,
        'body': json.dumps({'message': 'Login Successful!'})
    }
