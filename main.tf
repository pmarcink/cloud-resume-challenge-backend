terraform {
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

#S3 Bucket
resource "aws_s3_bucket" "s3-CRC" {
  bucket = "resume.pmarcinkevicius.com"
  versioning {
    enabled = true
  }
  website {
    error_document = "error.html"
    index_document = "index.html"
  }
  cors_rule {
    allowed_headers = ["Content-Type,Access-Control-Allow-Origin"]
    allowed_methods = ["GET", "PUT"]
    allowed_origins = ["'*'"]
  }
}

#S3 Bucket Policy
resource "aws_s3_bucket_policy" "PolicyForCloudFrontPrivateContent" {
  bucket = "resume.pmarcinkevicius.com"
  policy = data.aws_iam_policy_document.PolicyForCloudFrontPrivateContent.json
}
data "aws_iam_policy_document" "PolicyForCloudFrontPrivateContent" {
  statement {
    sid       = "PublicReadGetObject"
    effect    = "Allow"
    resources = ["arn:aws:s3:::resume.pmarcinkevicius.com/*"]
    actions   = ["s3:GetObject"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

#Cloudfront Distribution 
resource "aws_cloudfront_distribution" "CF-CRC" {
  origin {
    domain_name = "resume.pmarcinkevicius.com.s3-website-us-east-1.amazonaws.com"
    origin_id = "S3-resume.pmarcinkevicius.com"

    custom_origin_config {
      http_port = 80
      https_port = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }
  enabled = true
  is_ipv6_enabled = true
  default_root_object = "index.html"

  aliases = ["resume.pmarcinkevicius.com"]

  default_cache_behavior {
    allowed_methods = ["GET", "HEAD"]
    cached_methods = ["GET", "HEAD"]
    target_origin_id = "S3-resume.pmarcinkevicius.com"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl = 31536000
    default_ttl = 31536000
    max_ttl = 31536000
    compress = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = "arn:aws:acm:us-east-1:812419716925:certificate/74f1cc8e-2032-43ca-bae9-319b5cab6474"
    ssl_support_method = "sni-only"
    minimum_protocol_version = "TLSv1.1_2016"
  }

}

#DynamoDB Table
resource "aws_dynamodb_table" "CRC-DynamoDB" {
  name = "cloud-resume-challenge"
  hash_key = "ID"
  billing_mode = "PAY_PER_REQUEST"
  attribute {
    name = "ID"
    type = "S"
  }
}

#Lambda Function for updating view count
resource "aws_lambda_function" "CRC-Lambda-Update" {
  filename = "crc-lambda-update.zip"
  function_name = "crc-lambda-update"
  handler = "crc-lambda-update.lambda_handler"
  runtime = "python3.9"
  role = "arn:aws:iam::812419716925:role/CRC-Lambda-Role"
}

#Lambda Function for retrieving view count
resource "aws_lambda_function" "CRC-Lambda-Retrieve" {
  filename = "crc-lambda-retrieve.zip"
  function_name = "crc-lambda-retrieve"
  handler = "crc-lambda-retrieve.lambda_handler"
  runtime = "python3.9"
  role = "arn:aws:iam::812419716925:role/CRC-Lambda-Role"
}

resource "aws_lambda_permission" "lambda_update-rights" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = "crc-lambda-update"
  principal     = "apigateway.amazonaws.com"
}

resource "aws_lambda_permission" "retrieve-rights" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = "crc-lambda-retrieve"
  principal     = "apigateway.amazonaws.com"
}


# need to re-deploy resource and methods for CORS on creation - does not correctly apply / will work on this later. Commeting out so CI/CD doesn't break it for now
## api gateway
#resource "aws_api_gateway_rest_api" "crc-api" {
#    name          = "crc-api"
#    description   = "API by terraform"
#}
#
## api resource
#resource "aws_api_gateway_resource" "crc-api-resource" {
#    path_part     = "method"
#    parent_id     = aws_api_gateway_rest_api.crc-api.root_resource_id
#    rest_api_id   = aws_api_gateway_rest_api.crc-api.id
#}
## GET method
#resource "aws_api_gateway_method" "GET_method" {
#    rest_api_id   = aws_api_gateway_rest_api.crc-api.id
#    resource_id   = aws_api_gateway_resource.crc-api-resource.id
#    http_method   = "GET"
#    authorization = "NONE"
#}
#
## GET method response
#resource "aws_api_gateway_method_response" "GET_method_response_200" {
#    rest_api_id   = aws_api_gateway_rest_api.crc-api.id
#    resource_id   = aws_api_gateway_resource.crc-api-resource.id
#    http_method   = aws_api_gateway_method.GET_method.http_method
#    status_code   = "200"
#    response_parameters = {
#        "method.response.header.Access-Control-Allow-Headers" = true,
#        "method.response.header.Access-Control-Allow-Methods" = true,
#        "method.response.header.Access-Control-Allow-Origin" = true
#    }
#    depends_on = [aws_api_gateway_method.GET_method]
#}
#
## GET integration
#resource "aws_api_gateway_integration" "GET_integration" {
#    rest_api_id   = aws_api_gateway_rest_api.crc-api.id
#    resource_id   = aws_api_gateway_resource.crc-api-resource.id
#    http_method   = aws_api_gateway_method.GET_method.http_method
#    integration_http_method = "GET"
#    type          = "AWS"
#    uri           = aws_lambda_function.CRC-Lambda-Retrieve.invoke_arn
#    depends_on    = [aws_api_gateway_method.GET_method, aws_lambda_function.CRC-Lambda-Retrieve]
#}
#
## GET integration response
#resource "aws_api_gateway_integration_response" "GET_integration_response" {
#  rest_api_id = aws_api_gateway_rest_api.crc-api.id
#  resource_id = aws_api_gateway_resource.crc-api-resource.id
#  http_method = aws_api_gateway_method.GET_method.http_method
#  status_code = aws_api_gateway_method_response.GET_method_response_200.status_code
#  
#    response_parameters  = {
#        "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
#        "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,PUT'", 
#        "method.response.header.Access-Control-Allow-Origin" = "'*'"
#      } 
#     depends_on = [aws_api_gateway_method_response.GET_method_response_200]
#}
#
## OPTIONS method
#resource "aws_api_gateway_method" "OPTIONS_method" {
#    rest_api_id   = aws_api_gateway_rest_api.crc-api.id
#    resource_id   = aws_api_gateway_resource.crc-api-resource.id
#    http_method   = "OPTIONS"
#    authorization = "NONE"
#}
#
## OPTIONS method response
#resource "aws_api_gateway_method_response" "OPTIONS_200" {
#    rest_api_id   = aws_api_gateway_rest_api.crc-api.id
#    resource_id   = aws_api_gateway_resource.crc-api-resource.id
#    http_method   = aws_api_gateway_method.OPTIONS_method.http_method
#    status_code   = "200"
#    response_models = {
#        "application/json" = "Empty"
#    }
#    response_parameters = {
#        "method.response.header.Access-Control-Allow-Headers" = true,
#        "method.response.header.Access-Control-Allow-Methods" = true,
#        "method.response.header.Access-Control-Allow-Origin" = true
#    }
#    depends_on = [aws_api_gateway_method.OPTIONS_method]
#}
#
#
## OPTIONS integration
#resource "aws_api_gateway_integration" "OPTIONS_integration" {
#    rest_api_id   = aws_api_gateway_rest_api.crc-api.id
#    resource_id   = aws_api_gateway_resource.crc-api-resource.id
#    http_method   = aws_api_gateway_method.OPTIONS_method.http_method
#    type          = "MOCK"
#    depends_on = [aws_api_gateway_method.OPTIONS_method]
#}
#
## OPTIONS integration response
#resource "aws_api_gateway_integration_response" "OPTIONS_integration_response" {
#    rest_api_id   = aws_api_gateway_rest_api.crc-api.id
#    resource_id   = aws_api_gateway_resource.crc-api-resource.id
#    http_method   = aws_api_gateway_method.OPTIONS_method.http_method
#    status_code   = aws_api_gateway_method_response.OPTIONS_200.status_code
#    response_parameters = {
#        "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
#        "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,PUT,PUT'",
#        "method.response.header.Access-Control-Allow-Origin" = "'*'"
#    }
#    depends_on = [aws_api_gateway_method_response.OPTIONS_200]
#}
#
## PUT method
#resource "aws_api_gateway_method" "PUT_method" {
#    rest_api_id   = aws_api_gateway_rest_api.crc-api.id
#    resource_id   = aws_api_gateway_resource.crc-api-resource.id
#    http_method   = "PUT"
#    authorization = "NONE"
#}
#
## PUT method response
#resource "aws_api_gateway_method_response" "PUT_method_response_200" {
#    rest_api_id   = aws_api_gateway_rest_api.crc-api.id
#    resource_id   = aws_api_gateway_resource.crc-api-resource.id
#    http_method   = aws_api_gateway_method.PUT_method.http_method
#    status_code   = "200"
#    response_parameters = {
#        "method.response.header.Access-Control-Allow-Headers" = true,
#        "method.response.header.Access-Control-Allow-Methods" = true,
#        "method.response.header.Access-Control-Allow-Origin" = true
#    }
#    depends_on = [aws_api_gateway_method.PUT_method]
#}
#
## PUT integration
#resource "aws_api_gateway_integration" "PUT_integration" {
#    rest_api_id   = aws_api_gateway_rest_api.crc-api.id
#    resource_id   = aws_api_gateway_resource.crc-api-resource.id
#    http_method   = aws_api_gateway_method.PUT_method.http_method
#    integration_http_method = "PUT"
#    type          = "AWS"
#    uri           = aws_lambda_function.CRC-Lambda-Update.invoke_arn
#    depends_on    = [aws_api_gateway_method.PUT_method, aws_lambda_function.CRC-Lambda-Update]
#}
#
## PUT integration response
#resource "aws_api_gateway_integration_response" "PUT_integration_response" {
#  rest_api_id = aws_api_gateway_rest_api.crc-api.id
#  resource_id = aws_api_gateway_resource.crc-api-resource.id
#  http_method = aws_api_gateway_method.PUT_method.http_method
#  status_code = aws_api_gateway_method_response.PUT_method_response_200.status_code
#  
#    response_parameters  = {
#        "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
#        "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,PUT'", 
#        "method.response.header.Access-Control-Allow-Origin" = "'*'"
#      } 
#     depends_on = [aws_api_gateway_method_response.PUT_method_response_200]
#}
#
## deploy api
#resource "aws_api_gateway_deployment" "deployment" {
#    rest_api_id   = aws_api_gateway_rest_api.crc-api.id
#    stage_name    = "Dev"
#    depends_on    = [aws_api_gateway_integration.PUT_integration]
#}
#
#