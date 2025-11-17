# ==============================================================================
# Synthetics Monitoring Module - Advanced Tests
# ==============================================================================

variables {
  project_name = "advanced-synthetics"
  environment  = "prod"
  canaries = {
    bedrock_full_journey = {
      handler             = "customCanary.handler"
      runtime_version     = "syn-python-selenium-1.0"
      schedule_expression = "rate(1 minute)"
      endpoint_url        = "https://api.example.com"
      timeout_in_seconds  = 300
      memory_in_mb        = 1024
      vpc_config = {
        subnet_ids         = ["subnet-123", "subnet-456"]
        security_group_ids = ["sg-123"]
      }
    }
  }
  enable_alarms = true
  tags          = { Environment = "prod" }
}

run "verify_vpc_configuration" {
  command = plan
  assert {
    condition     = can(aws_synthetics_canary.this["bedrock_full_journey"].vpc_config)
    error_message = "Canary should be configured for VPC"
  }
}

run "verify_memory_configuration" {
  command = plan
  assert {
    condition     = can(aws_synthetics_canary.this["bedrock_full_journey"].run_config[0].memory_in_mb == 1024)
    error_message = "Canary memory should match configuration"
  }
}

run "verify_alarms" {
  command = plan
  assert {
    condition     = can(aws_cloudwatch_metric_alarm.canary_failed)
    error_message = "Canary failure alarms should be created"
  }
}
