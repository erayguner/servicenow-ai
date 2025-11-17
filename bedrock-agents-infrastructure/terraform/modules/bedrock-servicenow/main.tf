# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Generate unique identifier for resources
resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  name_prefix = "${var.name_prefix}-${var.environment}"
  resource_id = random_id.suffix.hex

  common_tags = merge(
    var.tags,
    {
      Module      = "bedrock-servicenow"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Service     = "ServiceNow-Integration"
    }
  )

  # Agent configurations
  agents_config = {
    incident = {
      name        = "${local.name_prefix}-incident-mgmt"
      description = "AI agent for automated incident management and resolution"
      enabled     = var.enable_incident_automation
      instruction = <<-EOT
        You are an expert ServiceNow incident management agent. Your responsibilities include:
        1. Analyzing incoming incidents and determining severity and priority
        2. Categorizing incidents based on description and affected services
        3. Recommending assignment groups based on incident category
        4. Suggesting resolution steps based on historical knowledge
        5. Monitoring SLA compliance and escalating when necessary
        6. Identifying patterns that may indicate larger problems

        Always provide clear, actionable recommendations with confidence scores.
      EOT
    }
    triage = {
      name        = "${local.name_prefix}-ticket-triage"
      description = "AI agent for intelligent ticket triage and routing"
      enabled     = var.enable_ticket_triage
      instruction = <<-EOT
        You are an expert ticket triage agent. Your responsibilities include:
        1. Analyzing ticket content to determine type (incident, request, problem, change)
        2. Extracting key information (affected services, urgency, business impact)
        3. Determining appropriate assignment group and priority
        4. Identifying duplicate or related tickets
        5. Suggesting automated responses for common requests
        6. Flagging tickets that require immediate attention

        Provide triage recommendations with confidence scores and reasoning.
      EOT
    }
    change = {
      name        = "${local.name_prefix}-change-mgmt"
      description = "AI agent for change management and approval workflows"
      enabled     = var.enable_change_management
      instruction = <<-EOT
        You are an expert change management agent. Your responsibilities include:
        1. Analyzing change requests for completeness and risk assessment
        2. Evaluating change impact and recommending approval/rejection
        3. Identifying dependencies and potential conflicts with other changes
        4. Suggesting implementation windows based on business calendars
        5. Monitoring change implementation and rollback triggers
        6. Tracking change success rates and improvement opportunities

        Always consider risk, business impact, and compliance requirements.
      EOT
    }
    problem = {
      name        = "${local.name_prefix}-problem-mgmt"
      description = "AI agent for problem management and root cause analysis"
      enabled     = var.enable_problem_management
      instruction = <<-EOT
        You are an expert problem management agent. Your responsibilities include:
        1. Analyzing incident patterns to identify underlying problems
        2. Conducting root cause analysis using historical data
        3. Suggesting permanent fixes and workarounds
        4. Tracking known errors and their resolutions
        5. Recommending proactive problem prevention measures
        6. Documenting lessons learned and knowledge articles

        Focus on identifying root causes and preventing recurrence.
      EOT
    }
    knowledge = {
      name        = "${local.name_prefix}-knowledge-base"
      description = "AI agent for knowledge base management and synchronization"
      enabled     = var.enable_knowledge_sync
      instruction = <<-EOT
        You are an expert knowledge management agent. Your responsibilities include:
        1. Analyzing resolved incidents for knowledge article opportunities
        2. Drafting knowledge articles from successful resolutions
        3. Maintaining knowledge base accuracy and relevance
        4. Suggesting article improvements based on user feedback
        5. Categorizing and tagging knowledge articles appropriately
        6. Identifying knowledge gaps and recommending new articles

        Ensure knowledge articles are clear, accurate, and actionable.
      EOT
    }
    sla = {
      name        = "${local.name_prefix}-sla-monitor"
      description = "AI agent for SLA monitoring and breach prevention"
      enabled     = var.enable_sla_monitoring
      instruction = <<-EOT
        You are an expert SLA monitoring agent. Your responsibilities include:
        1. Monitoring active tickets against SLA commitments
        2. Predicting SLA breaches based on current progress
        3. Recommending actions to prevent SLA violations
        4. Escalating tickets at risk of breach
        5. Analyzing SLA compliance trends and patterns
        6. Suggesting SLA optimization opportunities

        Proactively prevent SLA breaches and maintain high compliance rates.
      EOT
    }
  }

  # Filter enabled agents
  enabled_agents = {
    for key, config in local.agents_config : key => config
    if config.enabled
  }
}

# ServiceNow Credentials Secret (if not provided)
resource "aws_secretsmanager_secret" "servicenow_credentials" {
  count = var.servicenow_credentials_secret_arn == null ? 1 : 0

  name_prefix             = "${local.name_prefix}-credentials-"
  description             = "ServiceNow API credentials for ${var.servicenow_instance_url}"
  kms_key_id              = var.kms_key_id
  recovery_window_in_days = 7

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-credentials"
    }
  )
}

resource "aws_secretsmanager_secret_version" "servicenow_credentials" {
  count = var.servicenow_credentials_secret_arn == null ? 1 : 0

  secret_id = aws_secretsmanager_secret.servicenow_credentials[0].id
  secret_string = jsonencode({
    instance_url = var.servicenow_instance_url
    auth_type    = var.servicenow_auth_type
    username     = "REPLACE_WITH_USERNAME"
    password     = "REPLACE_WITH_PASSWORD"
    client_id    = var.servicenow_auth_type == "oauth" ? "REPLACE_WITH_CLIENT_ID" : null
    client_secret = var.servicenow_auth_type == "oauth" ? "REPLACE_WITH_CLIENT_SECRET" : null
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

locals {
  servicenow_credentials_secret_arn = var.servicenow_credentials_secret_arn != null ? var.servicenow_credentials_secret_arn : aws_secretsmanager_secret.servicenow_credentials[0].arn
}

# DynamoDB Table for State Tracking
resource "aws_dynamodb_table" "servicenow_state" {
  name           = "${local.name_prefix}-state-${local.resource_id}"
  billing_mode   = var.dynamodb_billing_mode
  hash_key       = "ticketId"
  range_key      = "timestamp"

  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "ticketId"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }

  attribute {
    name = "status"
    type = "S"
  }

  attribute {
    name = "assignmentGroup"
    type = "S"
  }

  global_secondary_index {
    name            = "StatusIndex"
    hash_key        = "status"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "AssignmentGroupIndex"
    hash_key        = "assignmentGroup"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = var.dynamodb_point_in_time_recovery
  }

  server_side_encryption {
    enabled     = var.enable_encryption_at_rest
    kms_key_arn = var.kms_key_id
  }

  ttl {
    enabled        = true
    attribute_name = "expirationTime"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-state-table"
    }
  )
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${local.name_prefix}"
  retention_in_days = 30
  kms_key_id        = var.kms_key_id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-api-logs"
    }
  )
}

resource "aws_cloudwatch_log_group" "step_functions" {
  name              = "/aws/states/${local.name_prefix}"
  retention_in_days = 30
  kms_key_id        = var.kms_key_id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-workflow-logs"
    }
  )
}
