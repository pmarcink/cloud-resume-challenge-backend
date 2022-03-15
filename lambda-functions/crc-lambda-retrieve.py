from itertools import count
import json
from urllib import response
import boto3

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('cloud-resume-challenge')

def retrieve_count():
   response = table.get_item(Key={
   'ID':'0'
      })
   viewCount = response['Item']['viewerCount']
   return viewCount 

def lambda_handler(event, context):
   return {
      'statusCode': 200,
      'headers': {
         'Access-Control-Allow-Headers': 'Content-Type',
         'Access-Control-Allow-Origin': '*',
         'Access-Control-Allow-Methods': 'OPTIONS,PUT,GET',
      },
         'body': retrieve_count()
   }
   