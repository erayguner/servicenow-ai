# ==============================================================================
# Bedrock Orchestration Module - Advanced Tests
# ==============================================================================
# Tests advanced features including SNS, EventBridge, and X-Ray
# ==============================================================================

variables {
  orchestration_name = "advanced-orchestration"
  agent_arns = [
    "arn:aws:bedrock:us-east-1:123456789012:agent/AGENT1",
    "arn:aws:bedrock:us-east-1:123456789012:agent/AGENT2"
  ]

  create_dynamodb_table = true
  state_machine_type = "EXPRESS"

  enable_logging = true
  log_level = "ALL"

  enable_xray_tracing = true

  enable_sns_notifications = true
  sns_email_subscriptions = ["test@example.com"]

  enable_eventbridge_trigger = true
  eventbridge_schedule_expression = "rate(1 hour)"

  kms_key_id = "12345678-1234-1234-1234-123456789012"

  tags = {
    Environment = "advanced-test"
  }
}

run "verify_express_workflow" {
  command = plan

  assert {
    condition     = aws_sfn_state_machine.this.type == "EXPRESS"
    error_message = "State machine should be EXPRESS type"
  }
}

run "verify_logging_configuration" {
  command = plan

  assert {
    condition     = length(aws_cloudwatch_log_group.state_machine) == 1
    error_message = "Should create CloudWatch log group"
  }

  assert {
    condition     = can(aws_sfn_state_machine.this.logging_configuration[0].level == "ALL")
    error_message = "Log level should be ALL"
  }

  assert {
    condition     = can(aws_sfn_state_machine.this.logging_configuration[0].include_execution_data == true)
    error_message = "Should include execution data in logs"
  }
}

run "verify_xray_tracing" {
  command = plan

  assert {
    condition     = can(aws_sfn_state_machine.this.tracing_configuration[0].enabled == true)
    error_message = "X-Ray tracing should be enabled"
  }
}

run "verify_sns_topic_creation" {
  command = plan

  assert {
    condition     = length(aws_sns_topic.notifications) == 1
    error_message = "Should create SNS topic for notifications"
  }

  assert {
    condition     = can(aws_sns_topic.notifications[0].kms_master_key_id != null)
    error_message = "SNS topic should be encrypted"
  }
}

run "verify_email_subscriptions" {
  command = plan

  assert {
    condition     = length(aws_sns_topic_subscription.email) == 1
    error_message = "Should create email subscription"
  }

  assert {
    condition     = can(aws_sns_topic_subscription.email["test@example.com"].protocol == "email")
    error_message = "Subscription protocol should be email"
  }
}

run "verify_eventbridge_rule" {
  command = plan

  assert {
    condition     = length(aws_cloudwatch_event_rule.trigger) == 1
    error_message = "Should create EventBridge rule"
  }

  assert {
    condition     = can(aws_cloudwatch_event_rule.trigger[0].schedule_expression == "rate(1 hour)")
    error_message = "Schedule expression should match input"
  }
}

run "verify_eventbridge_target" {
  command = plan

  assert {
    condition     = length(aws_cloudwatch_event_target.state_machine) == 1
    error_message = "Should create EventBridge target"
  }
}

run "verify_dynamodb_encryption" {
  command = plan

  assert {
    condition     = can(aws_dynamodb_table.state[0].server_side_encryption[0].enabled == true)
    error_message = "DynamoDB table should have encryption enabled"
  }

  assert {
    condition     = can(aws_dynamodb_table.state[0].server_side_encryption[0].kms_key_arn != null)
    error_message = "DynamoDB table should use KMS encryption"
  }
}

run "verify_point_in_time_recovery" {
  command = plan

  assert {
    condition     = can(aws_dynamodb_table.state[0].point_in_time_recovery[0].enabled == true)
    error_message = "Point-in-time recovery should be enabled"
  }
}

run "verify_ttl_configuration" {
  command = plan

  assert {
    condition     = can(aws_dynamodb_table.state[0].ttl[0].enabled == true)
    error_message = "TTL should be enabled on DynamoDB table"
  }

  assert {
    condition     = can(aws_dynamodb_table.state[0].ttl[0].attribute_name == "ttl")
    error_message = "TTL attribute should be named ttl"
  }
}
