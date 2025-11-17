# ==============================================================================
# EventBridge Monitoring Module - Basic Tests
# ==============================================================================

variables {
  project_name = "test-eventbridge"
  environment  = "test"
  create_event_bus = true
  tags = { Environment = "test" }
}

run "verify_event_bus" {
  command = plan
  assert {
    condition     = aws_cloudwatch_event_bus.bedrock.name != null
    error_message = "EventBridge event bus should be created"
  }
}

run "verify_bedrock_agent_rules" {
  command = plan
  assert {
    condition     = can(aws_cloudwatch_event_rule.bedrock_agent_invocations)
    error_message = "Bedrock agent invocations rule should be created"
  }
}

run "verify_archive" {
  command = plan
  assert {
    condition     = can(aws_cloudwatch_event_archive.bedrock)
    error_message = "EventBridge archive should be created"
  }
}
