import json
import boto3

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('cloud-resume-challenge')

def lambda_handler(event, context):
    response = table.get_item(Key={
            'ID':'0'
    })
    
    viewerCount = response['Item']['viewerCount']
    viewerCount = viewerCount + 1
    print(viewerCount)    
    
    response = table.put_item(Item={
            'ID':'0',
            'viewerCount': viewerCount
    })
    
    return {
        'statusCode': 200,
        'headers': {
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'OPTIONS,PUT,GET'
                },
                'body': 'Retrieved!'
    }
  