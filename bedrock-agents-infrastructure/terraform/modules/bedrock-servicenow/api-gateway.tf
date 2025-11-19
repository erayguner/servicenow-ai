# API Gateway for ServiceNow webhooks
# Provides REST endpoints for incoming ServiceNow events

resource "aws_api_gateway_rest_api" "servicenow_webhooks" {
  name        = "${local.name_prefix}-webhooks"
  description = "API Gateway for ServiceNow webhook integrations"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-webhooks-api"
    }
  )
}

# API Gateway Resource: /webhooks
resource "aws_api_gateway_resource" "webhooks" {
  rest_api_id = aws_api_gateway_rest_api.servicenow_webhooks.id
  parent_id   = aws_api_gateway_rest_api.servicenow_webhooks.root_resource_id
  path_part   = "webhooks"
}

# API Gateway Resource: /webhooks/incident
resource "aws_api_gateway_resource" "incident" {
  rest_api_id = aws_api_gateway_rest_api.servicenow_webhooks.id
  parent_id   = aws_api_gateway_resource.webhooks.id
  path_part   = "incident"
}

# API Gateway Resource: /webhooks/change
resource "aws_api_gateway_resource" "change" {
  rest_api_id = aws_api_gateway_rest_api.servicenow_webhooks.id
  parent_id   = aws_api_gateway_resource.webhooks.id
  path_part   = "change"
}

# API Gateway Resource: /webhooks/problem
resource "aws_api_gateway_resource" "problem" {
  rest_api_id = aws_api_gateway_rest_api.servicenow_webhooks.id
  parent_id   = aws_api_gateway_resource.webhooks.id
  path_part   = "problem"
}

# POST method for incident webhooks
resource "aws_api_gateway_method" "incident_post" {
  rest_api_id   = aws_api_gateway_rest_api.servicenow_webhooks.id
  resource_id   = aws_api_gateway_resource.incident.id
  http_method   = "POST"
  authorization = "NONE" # Use API key or AWS_IAM in production

  request_parameters = {
    "method.request.header.X-ServiceNow-Signature" = false
  }
}

# Integration with Lambda for incident webhooks
resource "aws_api_gateway_integration" "incident_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.servicenow_webhooks.id
  resource_id             = aws_api_gateway_resource.incident.id
  http_method             = aws_api_gateway_method.incident_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.webhook_processor.invoke_arn
}

# POST method for change webhooks
resource "aws_api_gateway_method" "change_post" {
  rest_api_id   = aws_api_gateway_rest_api.servicenow_webhooks.id
  resource_id   = aws_api_gateway_resource.change.id
  http_method   = "POST"
  authorization = "NONE"
}

# Integration with Lambda for change webhooks
resource "aws_api_gateway_integration" "change_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.servicenow_webhooks.id
  resource_id             = aws_api_gateway_resource.change.id
  http_method             = aws_api_gateway_method.change_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.webhook_processor.invoke_arn
}

# POST method for problem webhooks
resource "aws_api_gateway_method" "problem_post" {
  rest_api_id   = aws_api_gateway_rest_api.servicenow_webhooks.id
  resource_id   = aws_api_gateway_resource.problem.id
  http_method   = "POST"
  authorization = "NONE"
}

# Integration with Lambda for problem webhooks
resource "aws_api_gateway_integration" "problem_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.servicenow_webhooks.id
  resource_id             = aws_api_gateway_resource.problem.id
  http_method             = aws_api_gateway_method.problem_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.webhook_processor.invoke_arn
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "servicenow_webhooks" {
  rest_api_id = aws_api_gateway_rest_api.servicenow_webhooks.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.webhooks.id,
      aws_api_gateway_resource.incident.id,
      aws_api_gateway_resource.change.id,
      aws_api_gateway_resource.problem.id,
      aws_api_gateway_method.incident_post.id,
      aws_api_gateway_method.change_post.id,
      aws_api_gateway_method.problem_post.id,
      aws_api_gateway_integration.incident_lambda.id,
      aws_api_gateway_integration.change_lambda.id,
      aws_api_gateway_integration.problem_lambda.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.incident_lambda,
    aws_api_gateway_integration.change_lambda,
    aws_api_gateway_integration.problem_lambda
  ]
}

# API Gateway Stage
resource "aws_api_gateway_stage" "servicenow_webhooks" {
  deployment_id = aws_api_gateway_deployment.servicenow_webhooks.id
  rest_api_id   = aws_api_gateway_rest_api.servicenow_webhooks.id
  stage_name    = var.api_gateway_stage_name

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId        = "$context.requestId"
      ip               = "$context.identity.sourceIp"
      caller           = "$context.identity.caller"
      user             = "$context.identity.user"
      requestTime      = "$context.requestTime"
      httpMethod       = "$context.httpMethod"
      resourcePath     = "$context.resourcePath"
      status           = "$context.status"
      protocol         = "$context.protocol"
      responseLength   = "$context.responseLength"
      integrationError = "$context.integrationErrorMessage"
    })
  }

  xray_tracing_enabled = true

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-${var.api_gateway_stage_name}"
    }
  )
}

# API Gateway Method Settings
resource "aws_api_gateway_method_settings" "servicenow_webhooks" {
  rest_api_id = aws_api_gateway_rest_api.servicenow_webhooks.id
  stage_name  = aws_api_gateway_stage.servicenow_webhooks.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled        = true
    logging_level          = var.enable_api_gateway_logging ? "INFO" : "OFF"
    data_trace_enabled     = var.enable_enhanced_monitoring
    throttling_burst_limit = 100
    throttling_rate_limit  = 50
  }
}

# API Gateway Usage Plan
resource "aws_api_gateway_usage_plan" "servicenow_webhooks" {
  name        = "${local.name_prefix}-usage-plan"
  description = "Usage plan for ServiceNow webhook API"

  api_stages {
    api_id = aws_api_gateway_rest_api.servicenow_webhooks.id
    stage  = aws_api_gateway_stage.servicenow_webhooks.stage_name
  }

  quota_settings {
    limit  = 10000
    period = "DAY"
  }

  throttle_settings {
    burst_limit = 100
    rate_limit  = 50
  }

  tags = local.common_tags
}

# API Gateway API Key
resource "aws_api_gateway_api_key" "servicenow_webhooks" {
  name        = "${local.name_prefix}-api-key"
  description = "API key for ServiceNow webhook integration"
  enabled     = true

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-api-key"
    }
  )
}

# Associate API Key with Usage Plan
resource "aws_api_gateway_usage_plan_key" "servicenow_webhooks" {
  key_id        = aws_api_gateway_api_key.servicenow_webhooks.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.servicenow_webhooks.id
}

# Resource Policy for API Gateway (IP restriction if configured)
resource "aws_api_gateway_rest_api_policy" "servicenow_webhooks" {
  count = length(var.allowed_ip_ranges) > 0 ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.servicenow_webhooks.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "execute-api:Invoke"
        Resource  = "${aws_api_gateway_rest_api.servicenow_webhooks.execution_arn}/*"
        Condition = {
          IpAddress = {
            "aws:SourceIp" = var.allowed_ip_ranges
          }
        }
      }
    ]
  })
}

# CORS Configuration for webhook endpoints
resource "aws_api_gateway_method" "incident_options" {
  rest_api_id   = aws_api_gateway_rest_api.servicenow_webhooks.id
  resource_id   = aws_api_gateway_resource.incident.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "incident_options" {
  rest_api_id = aws_api_gateway_rest_api.servicenow_webhooks.id
  resource_id = aws_api_gateway_resource.incident.id
  http_method = aws_api_gateway_method.incident_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "incident_options" {
  rest_api_id = aws_api_gateway_rest_api.servicenow_webhooks.id
  resource_id = aws_api_gateway_resource.incident.id
  http_method = aws_api_gateway_method.incident_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "incident_options" {
  rest_api_id = aws_api_gateway_rest_api.servicenow_webhooks.id
  resource_id = aws_api_gateway_resource.incident.id
  http_method = aws_api_gateway_method.incident_options.http_method
  status_code = aws_api_gateway_method_response.incident_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-ServiceNow-Signature'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_integration.incident_options]
}
