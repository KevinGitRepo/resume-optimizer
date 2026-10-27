import json
import boto3
import os
import re

# AWS clients
textract = boto3.client('textract')
dynamodb = boto3.client('dynamodb')
dynamodb_table_name = 'user_profile'

def lambda_handler(event, context):

    # Extract bucket & file info
    # s3_key = event['Records'][0]['s3']['object']['key']
    s3_key = event['key']
    print(s3_key)
    users_str = 'users/'
    users_index = s3_key.find(users_str)
    s3_key_split = s3_key[users_index + len(users_str):].split('/')
    username = s3_key_split[0]

    # if this is being called because textract is completed, update dynamodb
    if 'textract' in s3_key:
        if '.s3_access_check' in s3_key:
            return
        print('textract = true')
        rk_pattern = r"^(users/[^/]*/)textract/([^/]*)/.*$"
        rk_match = re.match(rk_pattern,s3_key)
        if not rk_match:
            return {
                'statusCode': 500,
                'body': json.dumps({'error': 'Textract output filename parsed incorrectly'})
            }
        rk_groups = rk_match.groups()
        resume_key = "".join(rk_groups)

        print(resume_key)
        dynamodb.update_item(
            TableName=dynamodb_table_name,
            Key={
                'user_name': {'S': username},
            },
            UpdateExpression='SET resume_key.#rk.textract = :val',
            ExpressionAttributeNames={
                '#rk': resume_key
            },
            ExpressionAttributeValues={
                ':val': {
                    'S': s3_key
                }
            }
        )
        return

    # bucket_name = event['Records'][0]['s3']['bucket']['name']
    bucket_name = event['bucket']

    file_name_split = s3_key.split('/')[-1]
    file_name_parse = s3_key[:s3_key.rfind(file_name_split)]

    file_prefix = f'{file_name_parse}textract/{file_name_split}'

    print(f"Processing file: {s3_key} from bucket: {bucket_name}")

    textract.start_document_text_detection(
        DocumentLocation={
            'S3Object': {
                'Bucket': bucket_name, 
                'Name': s3_key
            }
        },
        OutputConfig={
            'S3Bucket': bucket_name,
            'S3Prefix': file_prefix
        }
    )

    # RETURN
    return {
        'statusCode': 200,
        'body': json.dumps({
            'file': s3_key
        })
    }