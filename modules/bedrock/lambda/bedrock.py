import base64
import boto3
import json
import os
from datetime import datetime

bedrock = boto3.client("bedrock-runtime")
s3 = boto3.client("s3")
dynamodb = boto3.client("dynamodb")
dynamodb_table_name = 'user_profile'

BUCKET = os.environ.get("BUCKET")
MODEL_ID = os.environ.get("MODEL_ID", "amazon.titan-text-express-v1")

def lambda_handler(event, context):

    s3_key = event['changed_resume_key']
    users_str = 'users/'
    users_index = s3_key.find(users_str)
    s3_key_split = s3_key[users_index + len(users_str):].split('/')
    username = s3_key_split[0]
    # username = event["username"]

    # Get Key phrases from DynamoDB
    dynamo_info = dynamodb.get_item(
        TableName=dynamodb_table_name,
        Key={'user_name': {'S': username}}
    )['Item']
    key_phrases = dynamo_info.get('resume_key').get('M')[s3_key].get('M')['comprehend']['S']
    textract_file_object = dynamo_info.get('resume_key').get('M')[s3_key].get('M')['textract']['S']

    # Get resume text 
    response = s3.get_object(Bucket=BUCKET, Key=textract_file_object)
    print(s3_key)
    body_json = json.loads(response['Body'].read())
    resume_lines = []
    for block in body_json.get('Blocks', []):
        if block.get('BlockType') == 'LINE':
            resume_lines.append(block.get('Text', ''))
    resume_text = '\n'.join(resume_lines)

    # Build optimized resume prompt
    prompt = f"""
You are an expert resume optimization system.

You will receive:
1. Raw extracted resume text
2. Key phrases and entities from related job descriptions

Use ALL information to rewrite and optimize the resume.
Do not create skills or roles.

Raw Resume Text:
{resume_text}

Job Description Key Phrases:
{key_phrases}
"""

    print('Invoking Bedrock...')
    try:
        response = bedrock.invoke_model(
            modelId=MODEL_ID,
            body=json.dumps({
                "inputText": prompt,
                "textGenerationConfig": {
                    "maxTokenCount": 2000,
                    "temperature": 0.7,
                    "topP": 0.9
                }
            })
        )
        print('Bedrock Success')
    except Exception as e:
        print('Bedrock Failed.')
    print(response)

    output = json.loads(response["body"].read())
    optimized_resume = output["results"][0]["outputText"]
    print(optimized_resume[:100])

    # Save to S3
    key = f"optimized/{username}_optimized_resume_{datetime.now().timestamp()}.txt"
    print(key)

    s3.put_object(
        Bucket=BUCKET,
        Key=key,
        Body=optimized_resume.encode('utf-8'),
    )

    return {
        "status": "success",
        "optimized_resume_s3_key": key
    }