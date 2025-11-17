# EventBridge event bus and rules for ServiceNow events

# Custom Event Bus for ServiceNow events
resource "aws_cloudwatch_event_bus" "servicenow_events" {
  name = "${local.name_prefix}-events"

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-event-bus"
    }
  )
}

# EventBridge Rule: New Incident Created
resource "aws_cloudwatch_event_rule" "incident_created" {
  count = var.enable_incident_automation ? 1 : 0

  name           = "${local.name_prefix}-incident-created"
  description    = "Triggered when a new incident is created in ServiceNow"
  event_bus_name = aws_cloudwatch_event_bus.servicenow_events.name

  event_pattern = jsonencode({
    source      = ["servicenow.webhook"]
    detail-type = ["Incident Created"]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-incident-created-rule"
    }
  )
}

# Target: Start Incident Workflow
resource "aws_cloudwatch_event_target" "incident_workflow" {
  count = var.enable_incident_automation ? 1 : 0

  rule           = aws_cloudwatch_event_rule.incident_created[0].name
  event_bus_name = aws_cloudwatch_event_bus.servicenow_events.name
  arn            = aws_sfn_state_machine.incident_workflow.arn
  role_arn       = aws_iam_role.eventbridge.arn

  input_transformer {
    input_paths = {
      incident = "$.detail.incident"
    }
    input_template = <<-EOT
      {
        "incident": <incident>,
        "source": "eventbridge",
        "timestamp": "<aws.events.event.ingestion-time>"
      }
    EOT
  }
}

# EventBridge Rule: Incident Updated
resource "aws_cloudwatch_event_rule" "incident_updated" {
  count = var.enable_incident_automation ? 1 : 0

  name           = "${local.name_prefix}-incident-updated"
  description    = "Triggered when an incident is updated in ServiceNow"
  event_bus_name = aws_cloudwatch_event_bus.servicenow_events.name

  event_pattern = jsonencode({
    source      = ["servicenow.webhook"]
    detail-type = ["Incident Updated"]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-incident-updated-rule"
    }
  )
}

# Target: Process Incident Update
resource "aws_cloudwatch_event_target" "incident_update" {
  count = var.enable_incident_automation ? 1 : 0

  rule           = aws_cloudwatch_event_rule.incident_updated[0].name
  event_bus_name = aws_cloudwatch_event_bus.servicenow_events.name
  arn            = aws_lambda_function.webhook_processor.arn
  role_arn       = aws_iam_role.eventbridge.arn
}

# EventBridge Rule: SLA Breach Warning
resource "aws_cloudwatch_event_rule" "sla_breach_warning" {
  count = var.enable_sla_monitoring ? 1 : 0

  name           = "${local.name_prefix}-sla-breach-warning"
  description    = "Triggered when an SLA breach is imminent"
  event_bus_name = aws_cloudwatch_event_bus.servicenow_events.name

  event_pattern = jsonencode({
    source      = ["servicenow.sla"]
    detail-type = ["SLA Breach Warning"]
    detail = {
      breach_percentage = [{
        numeric = [">=", var.sla_breach_threshold]
      }]
    }
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-sla-warning-rule"
    }
  )
}

# Target: Send SLA Breach Notification
resource "aws_cloudwatch_event_target" "sla_notification" {
  count = var.enable_sla_monitoring ? 1 : 0

  rule           = aws_cloudwatch_event_rule.sla_breach_warning[0].name
  event_bus_name = aws_cloudwatch_event_bus.servicenow_events.name
  arn            = aws_sns_topic.servicenow_notifications.arn
  role_arn       = aws_iam_role.eventbridge.arn

  input_transformer {
    input_paths = {
      ticket_number = "$.detail.ticket_number"
      percentage    = "$.detail.breach_percentage"
      time_left     = "$.detail.time_remaining"
    }
    input_template = "\"SLA Breach Warning: Ticket <ticket_number> is at <percentage>% of SLA with <time_left> remaining.\""
  }
}

# EventBridge Rule: Change Request Created
resource "aws_cloudwatch_event_rule" "change_created" {
  count = var.enable_change_management ? 1 : 0

  name           = "${local.name_prefix}-change-created"
  description    = "Triggered when a new change request is created"
  event_bus_name = aws_cloudwatch_event_bus.servicenow_events.name

  event_pattern = jsonencode({
    source      = ["servicenow.webhook"]
    detail-type = ["Change Created"]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-change-created-rule"
    }
  )
}

# Target: Start Change Workflow
resource "aws_cloudwatch_event_target" "change_workflow" {
  count = var.enable_change_management ? 1 : 0

  rule           = aws_cloudwatch_event_rule.change_created[0].name
  event_bus_name = aws_cloudwatch_event_bus.servicenow_events.name
  arn            = aws_sfn_state_machine.change_workflow[0].arn
  role_arn       = aws_iam_role.eventbridge.arn

  input_transformer {
    input_paths = {
      change = "$.detail.change"
    }
    input_template = <<-EOT
      {
        "change": <change>,
        "source": "eventbridge",
        "timestamp": "<aws.events.event.ingestion-time>"
      }
    EOT
  }
}

# EventBridge Rule: Problem Detection
resource "aws_cloudwatch_event_rule" "problem_detected" {
  count = var.enable_problem_management ? 1 : 0

  name           = "${local.name_prefix}-problem-detected"
  description    = "Triggered when a pattern indicates a problem"
  event_bus_name = aws_cloudwatch_event_bus.servicenow_events.name

  event_pattern = jsonencode({
    source      = ["servicenow.analysis"]
    detail-type = ["Problem Pattern Detected"]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-problem-detected-rule"
    }
  )
}

# Target: Invoke Problem Management Agent
resource "aws_cloudwatch_event_target" "problem_analysis" {
  count = var.enable_problem_management ? 1 : 0

  rule           = aws_cloudwatch_event_rule.problem_detected[0].name
  event_bus_name = aws_cloudwatch_event_bus.servicenow_events.name
  arn            = aws_lambda_function.servicenow_integration.arn
  role_arn       = aws_iam_role.eventbridge.arn

  input_transformer {
    input_paths = {
      pattern = "$.detail.pattern"
      incidents = "$.detail.related_incidents"
    }
    input_template = <<-EOT
      {
        "action": "analyze_problem",
        "pattern": <pattern>,
        "incidents": <incidents>
      }
    EOT
  }
}

# EventBridge Rule: Knowledge Sync Schedule
resource "aws_cloudwatch_event_rule" "knowledge_sync_schedule" {
  count = var.enable_knowledge_sync ? 1 : 0

  name                = "${local.name_prefix}-knowledge-sync-schedule"
  description         = "Scheduled knowledge base synchronization"
  schedule_expression = var.knowledge_sync_schedule

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-knowledge-sync-schedule"
    }
  )
}

# Target: Trigger Knowledge Sync Lambda
resource "aws_cloudwatch_event_target" "knowledge_sync" {
  count = var.enable_knowledge_sync ? 1 : 0

  rule = aws_cloudwatch_event_rule.knowledge_sync_schedule[0].name
  arn  = aws_lambda_function.knowledge_sync[0].arn
}

# Lambda permission for EventBridge to invoke knowledge sync
resource "aws_lambda_permission" "eventbridge_knowledge_sync" {
  count = var.enable_knowledge_sync ? 1 : 0

  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.knowledge_sync[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.knowledge_sync_schedule[0].arn
}

# EventBridge Rule: DynamoDB Stream for State Changes
resource "aws_cloudwatch_event_rule" "state_change" {
  name           = "${local.name_prefix}-state-change"
  description    = "Monitor state changes in DynamoDB"
  event_bus_name = "default"

  event_pattern = jsonencode({
    source      = ["aws.dynamodb"]
    detail-type = ["DynamoDB Stream Record"]
    resources   = [aws_dynamodb_table.servicenow_state.arn]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-state-change-rule"
    }
  )
}

# Archive for event replay capability
resource "aws_cloudwatch_event_archive" "servicenow_events" {
  name             = "${local.name_prefix}-event-archive"
  event_source_arn = aws_cloudwatch_event_bus.servicenow_events.arn
  retention_days   = 90

  description = "Archive of ServiceNow events for replay and audit"
}

# API Destination for webhook callbacks (optional)
resource "aws_cloudwatch_event_connection" "servicenow_api" {
  name               = "${local.name_prefix}-api-connection"
  description        = "Connection to ServiceNow API"
  authorization_type = var.servicenow_auth_type == "oauth" ? "OAUTH_CLIENT_CREDENTIALS" : "BASIC"

  auth_parameters {
    dynamic "basic" {
      for_each = var.servicenow_auth_type == "basic" ? [1] : []
      content {
        username = "placeholder"
        password = "placeholder"
      }
    }

    dynamic "oauth" {
      for_each = var.servicenow_auth_type == "oauth" ? [1] : []
      content {
        authorization_endpoint = "${var.servicenow_instance_url}/oauth_auth.do"
        http_method           = "POST"

        oauth_http_parameters {
          body {
            key   = "grant_type"
            value = "client_credentials"
          }
        }

        client_parameters {
          client_id     = "placeholder"
          client_secret = "placeholder"
        }
      }
    }
  }
}

resource "aws_cloudwatch_event_api_destination" "servicenow" {
  name                = "${local.name_prefix}-api-destination"
  description         = "API destination for ServiceNow callbacks"
  invocation_endpoint = "${var.servicenow_instance_url}/api/now/v2/table/incident"
  http_method         = "POST"
  connection_arn      = aws_cloudwatch_event_connection.servicenow_api.arn

  invocation_rate_limit_per_second = 10
}
