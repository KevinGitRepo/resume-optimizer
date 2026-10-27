import boto3
import http.client
import json
import re

BEARER = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJzaW5ld3l1cmNoaW5AZ21haWwuY29tIiwicGVybWlzc2lvbnMiOiJ1c2VyIiwiY3JlYXRlZF9hdCI6IjIwMjUtMTEtMThUMDM6NDQ6MTEuODQzOTI3KzAwOjAwIn0.GCxLNZ1L0_O6c0MQ9CaiV1NSQ8aeJSKzT3BqPZG4di0"

comprehend = boto3.client('comprehend')
dynamodb = boto3.client('dynamodb')
dynamodb_table_name = 'user_profile'

def lambda_handler(event, context):
    # s3_key = event['Records'][0]['s3']['object']['key']
    s3_key = event['key']
    print(s3_key)
    users_str = 'users/'
    users_index = s3_key.find(users_str)

    if users_index == -1:
        return

    s3_key_split = s3_key[users_index + len(users_str):].split('/')
    username = s3_key_split[0]

    if 'textract' in s3_key:
        return

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
    
    resume_details = item.get('resume_key').get('M')[s3_key].get('M')
    print(resume_details)
    job_title = resume_details['job_title'].get('S')
    location = resume_details['location'].get('S')
    comprehend_string = resume_details['comprehend'].get('S')

    if comprehend_string != '':
        return
    
    conn = http.client.HTTPSConnection("api.theirstack.com")

    payload = json.dumps({
        "page": 0,
        "limit": 1,
        "job_country_code_or": ["US"],
        "posted_at_max_age_days": 7,
        "job_title_or": [job_title],
        "job_location_pattern_or": [location]
    })

    headers = {
        'Content-Type': "application/json",
        'Authorization': f"Bearer {BEARER}"
    }

    conn.request("POST", "/v1/jobs/search", payload, headers)

    res = conn.getresponse()
    data = res.read()

    json_data = json.loads(data.decode("utf-8"))
    combined_descriptions = ''
    for job in json_data['data']:
        description = job['description']
        description = re.sub(r'[^\x00-\x7F]', '', description)
        combined_descriptions = f'{combined_descriptions}{description}'

    # Extract key words from Comprehend
    # combined_descriptions has to under 100kb
    key_phrases = comprehend.detect_key_phrases(Text = combined_descriptions, LanguageCode = "en")
    # print(key_phrases)
    all_key_phrases = ''
    print(key_phrases['KeyPhrases'])
    for phrase in key_phrases['KeyPhrases']:
        phrase_text = phrase['Text']
        all_key_phrases = f'{all_key_phrases}{phrase_text}'
    
    dynamodb.update_item(
        TableName=dynamodb_table_name,
        Key={
            'user_name': {'S': username},
        },
        UpdateExpression='SET resume_key.#rk.comprehend = :val',
        ExpressionAttributeNames={
            '#rk': s3_key
        },
        ExpressionAttributeValues={
            ':val': {
                'S': all_key_phrases
            }
        }
    )
