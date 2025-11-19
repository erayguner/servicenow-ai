# ==============================================================================
# AWS Config Monitoring Module - Advanced Tests
# ==============================================================================

variables {
  project_name             = "advanced-config"
  environment              = "prod"
  enable_config            = true
  recording_frequency      = "CONTINUOUS"
  include_global_resources = true
  enable_config_rules      = true
  tags                     = { Environment = "prod" }
}

run "verify_recording_all_resources" {
  command = plan
  assert {
    condition     = can(aws_config_configuration_recorder.bedrock.recording_group[0].all_supported == true)
    error_message = "Should record all supported resources"
  }
}

run "verify_global_resources" {
  command = plan
  assert {
    condition     = can(aws_config_configuration_recorder.bedrock.recording_group[0].include_global_resource_types == true)
    error_message = "Should include global resources"
  }
}

run "verify_config_rules" {
  command = plan
  assert {
    condition     = can(aws_config_config_rule.required_tags)
    error_message = "Config rules should be created"
  }
}

run "verify_sns_topic" {
  command = plan
  assert {
    condition     = can(aws_config_delivery_channel.bedrock.sns_topic_arn)
    error_message = "SNS topic should be configured for notifications"
  }
}
