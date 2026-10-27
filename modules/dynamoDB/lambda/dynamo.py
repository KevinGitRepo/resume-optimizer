import boto3
import json

bedrock_lambda = boto3.client('lambda')
dynamodb = boto3.client('dynamodb')
dynamodb_table_name = 'user_profile'

def lambda_handler(event, context):
    for record in event['Records']:
        if record['eventName'] != "MODIFY":
            continue

        new_resume_record = record['dynamodb']['NewImage']
        old_resume_record = record['dynamodb']['OldImage']

        new_resume_records = new_resume_record.get('resume_key').get('M')
        old_resume_records = old_resume_record.get('resume_key').get('M')

        for resume_key in new_resume_records.keys():
            try:
                new_comprehend_output = new_resume_records[resume_key].get('M')['comprehend']
                old_comprehend_output = old_resume_records[resume_key].get('M')['comprehend']
                new_textract_output = new_resume_records[resume_key].get('M')['textract']
                old_textract_output = old_resume_records[resume_key].get('M')['textract']
                comprehend_string = new_comprehend_output['S']
                textract_string = new_textract_output['S']
                print(f'comprehend: {comprehend_string[:20]}. textract: {textract_string}')
                if new_comprehend_output['S'] == "" or new_textract_output['S'] == "":
                    print('one does not exist')
                    continue
            except KeyError:
                continue

            if new_comprehend_output == old_comprehend_output and new_textract_output == old_textract_output:
                continue
            
            resume_record_json = {
                'changed_resume_key': resume_key
            }

            bedrock_function(resume_record_json)


def bedrock_function(resume_record):
    bedrock_lambda.invoke(
        FunctionName="bedrock_processor",
        InvocationType="Event",
        Payload=json.dumps(resume_record)
    )