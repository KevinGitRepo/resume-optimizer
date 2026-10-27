import json
import boto3
import os

s3 = boto3.client('s3')
dynamodb = boto3.client('dynamodb')
dynamodb_table_name = 'user_profile'

# Used to setup the PUT function
def lambda_handler(event, context):
    bucket = os.environ['BUCKET']

    if 'body' not in event:
        return
    
    # body = json.loads(event['body'])
    # job_title = body.get('jobtitle')
    # location = body.get('location')
    job_title = 'Software Engineer'
    location = 'New York'

    filename = event['pathParameters']['filename']
    username = event['pathParameters'].get('username')

    if not username:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'Missing username'})
        }

    if not filename:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'Missing filename'})
        }
    
    s3_key = f'users/{username}/{filename}'

    response = dynamodb.get_item(
        TableName=dynamodb_table_name,
        Key={'user_name': {'S': username}},
        ProjectionExpression='password, resume_key'
    )

    item = response.get('Item')
    if not item:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'User not found'})
        }
    
    resume_key_map = item.get('resume_key', {}).get('M', {})
    i = 1
    while s3_key in resume_key_map:
        index = s3_key.rfind('.')
        s3_key = f'{s3_key[:index]}{i}{s3_key[index:]}'
        i += 1
    
    dynamodb.update_item(
        TableName=dynamodb_table_name,
        Key={
            'user_name': {'S': username},
        },
        UpdateExpression='SET resume_key.#rk = :val',
        ExpressionAttributeNames={
            '#rk': s3_key
        },
        ExpressionAttributeValues={
            ':val': {
                'M': {
                    'application_score': {'N': '0'},
                    'job_title': {'S': job_title},
                    'location': {'S': location},
                    'comprehend': {'S': ''},
                    'textract': {'S': ''}
                }
            }
        }
    )

    url = s3.generate_presigned_url(
        ClientMethod='put_object',
        Params={
            'Bucket': bucket,
            'Key': s3_key,
            'ContentType': 'application/octet-stream', # For file uploads
        },
        ExpiresIn=60,
    )

    return {
        'statusCode': 200,
        'headers': { 'Content-Type': 'application/json' },
        'body': json.dumps({'url': url})
    }