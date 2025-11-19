# Bedrock Agents Monitoring Modules

Comprehensive monitoring infrastructure for Amazon Bedrock agents, providing observability, compliance, and operational excellence.

## Overview

This directory contains 6 specialized monitoring modules designed to provide complete visibility into Bedrock agent operations:

1. **bedrock-monitoring-cloudwatch** - Metrics, dashboards, and alarms
2. **bedrock-monitoring-xray** - Distributed tracing
3. **bedrock-monitoring-config** - Compliance and configuration monitoring
4. **bedrock-monitoring-cloudtrail** - Audit logging
5. **bedrock-monitoring-synthetics** - Synthetic monitoring and API testing
6. **bedrock-monitoring-eventbridge** - Event-driven monitoring and automation

## Module Architecture

```
monitoring/
├── bedrock-monitoring-cloudwatch/
│   ├── main.tf                    # CloudWatch resources
│   ├── variables.tf               # Input variables
│   ├── outputs.tf                 # Output values
│   ├── versions.tf                # Provider versions
│   └── templates/
│       └── dashboard.json.tpl     # Dashboard template
│
├── bedrock-monitoring-xray/
│   ├── main.tf                    # X-Ray configuration
│   ├── variables.tf
│   ├── outputs.tf
│   └── versions.tf
│
├── bedrock-monitoring-config/
│   ├── main.tf                    # AWS Config rules
│   ├── variables.tf
│   ├── outputs.tf
│   └── versions.tf
│
├── bedrock-monitoring-cloudtrail/
│   ├── main.tf                    # CloudTrail configuration
│   ├── variables.tf
│   ├── outputs.tf
│   └── versions.tf
│
├── bedrock-monitoring-synthetics/
│   ├── main.tf                    # Synthetics canaries
│   ├── variables.tf
│   ├── outputs.tf
│   ├── versions.tf
│   ├── templates/
│   │   └── api-canary.js.tpl     # Canary script template
│   └── scripts/                   # Generated canary scripts
│
└── bedrock-monitoring-eventbridge/
    ├── main.tf                    # EventBridge rules
    ├── variables.tf
    ├── outputs.tf
    └── versions.tf
```

## Module Descriptions

### 1. bedrock-monitoring-cloudwatch

Provides comprehensive CloudWatch monitoring with:

- **Metrics & Alarms**:
  - Bedrock agent invocation metrics (errors, latency, throttles)
  - Lambda function metrics (errors, duration, throttles, concurrent executions)
  - Step Functions execution metrics (failures, timeouts)
  - API Gateway metrics (errors, latency)

- **Anomaly Detection**:
  - Machine learning-based anomaly detection for invocation patterns
  - Automatic baseline learning

- **Composite Alarms**:
  - Multi-condition health checks
  - Critical vs warning severity levels

- **Custom Metrics**:
  - Log-based metric filters
  - Error pattern detection
  - Timeout tracking

- **Dashboards**:
  - Real-time visualization
  - Multi-service correlation
  - CloudWatch Logs Insights queries

**Key Features**:
- SNS integration for notifications
- Configurable thresholds
- Multi-region support
- KMS encryption for logs

### 2. bedrock-monitoring-xray

Distributed tracing infrastructure providing:

- **Sampling Rules**:
  - Service-specific sampling rates
  - High-priority error sampling (100%)
  - Cost-optimized default sampling

- **Trace Groups**:
  - Error traces
  - High-latency requests
  - Cold start tracking
  - Custom filtering

- **Insights**:
  - Automatic anomaly detection
  - Root cause analysis
  - EventBridge integration for alerts

- **Service Maps**:
  - Visual dependency mapping
  - Performance bottleneck identification
  - Error propagation tracking

**Key Features**:
- KMS encryption for trace data
- Configurable retention
- Analytics queries
- Console URLs for easy access

### 3. bedrock-monitoring-config

AWS Config-based compliance monitoring:

- **Configuration Recording**:
  - Continuous or daily snapshots
  - Resource-specific tracking
  - Global resource support

- **Compliance Rules**:
  - Encryption compliance (S3, KMS, CloudWatch Logs)
  - Access control validation (S3 public access, IAM policies)
  - Lambda best practices (DLQ, VPC configuration)

- **Remediation**:
  - Automatic remediation (optional)
  - SSM Automation integration

- **Multi-Region Aggregation**:
  - Cross-region compliance view
  - Multi-account support

- **Notifications**:
  - SNS integration for compliance changes
  - Config rule evaluation alerts

**Key Features**:
- S3 lifecycle policies for cost optimization
- KMS encryption
- Compliance dashboard URLs
- Configuration snapshots

### 4. bedrock-monitoring-cloudtrail

Comprehensive audit logging:

- **Trail Configuration**:
  - Multi-region trails
  - Global service events (IAM, etc.)
  - Log file validation for integrity

- **Data Events**:
  - S3 object-level logging
  - Lambda invocation logging
  - Advanced event selectors for Bedrock

- **CloudTrail Insights**:
  - API call rate anomalies
  - Error rate anomalies
  - Automated detection

- **CloudWatch Logs Integration**:
  - Real-time log streaming
  - CloudWatch Insights queries
  - Metric filters

- **S3 Storage**:
  - Lifecycle policies (IA → Glacier → Expiration)
  - Versioning enabled
  - Public access blocked

**Key Features**:
- KMS encryption
- SNS notifications
- Pre-built Insights queries
- Bedrock-specific event filtering

### 5. bedrock-monitoring-synthetics

Synthetic monitoring with CloudWatch Synthetics:

- **API Canaries**:
  - Endpoint availability checks
  - Response time monitoring
  - Status code validation
  - Custom headers and body

- **Bedrock-Specific Tests**:
  - Agent invocation testing
  - Knowledge base queries
  - Action group execution

- **Visual Monitoring**:
  - Screenshot capture
  - HAR file generation
  - Network waterfall analysis

- **Scheduling**:
  - Configurable intervals (1 min - 1 hour)
  - Cron-like expressions
  - On-demand execution

- **Alarms**:
  - Success rate monitoring
  - Duration thresholds
  - SNS integration

**Key Features**:
- VPC support for private endpoints
- X-Ray integration
- Artifact retention policies
- Custom Node.js scripts

### 6. bedrock-monitoring-eventbridge

Event-driven monitoring and automation:

- **Event Detection**:
  - Bedrock state changes
  - API errors and throttling
  - Lambda errors and throttles
  - Step Functions failures
  - Config compliance changes
  - CloudTrail Insights
  - AWS Health events

- **Event Targets**:
  - SNS notifications
  - SQS queues
  - Lambda automation
  - Step Functions workflows

- **Event Archiving**:
  - Configurable retention
  - Cross-service event capture
  - Replay capability

- **Dead Letter Queue**:
  - Failed event handling
  - Debugging support
  - KMS encryption

- **Custom Patterns**:
  - Flexible event matching
  - Complex filtering
  - Multi-condition rules

**Key Features**:
- Custom event bus support
- Event transformation
- Cross-account events
- Console URLs for monitoring

## Usage Examples

### Example 1: Complete Monitoring Stack

```hcl
# SNS Topic for all alarms
resource "aws_sns_topic" "monitoring" {
  name = "bedrock-monitoring-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.monitoring.arn
  protocol  = "email"
  endpoint  = "devops@example.com"
}

# CloudWatch Monitoring
module "cloudwatch_monitoring" {
  source = "./modules/monitoring/bedrock-monitoring-cloudwatch"

  project_name       = "my-bedrock-project"
  environment        = "prod"
  bedrock_agent_id   = "AGENT123"
  bedrock_agent_alias_id = "ALIAS456"

  lambda_function_names = [
    "bedrock-action-handler",
    "bedrock-preprocessor"
  ]

  step_function_state_machine_arns = [
    aws_sfn_state_machine.orchestration.arn
  ]

  api_gateway_ids = [
    aws_api_gateway_rest_api.main.name
  ]

  # Use existing SNS topic
  create_sns_topic    = false
  alarm_sns_topic_arn = aws_sns_topic.monitoring.arn

  # Enable all features
  enable_anomaly_detection = true
  enable_composite_alarms  = true
  create_dashboard        = true

  # Custom thresholds
  bedrock_error_rate_threshold = 2
  lambda_error_rate_threshold  = 1

  sns_email_subscriptions = ["ops@example.com"]

  tags = {
    Project = "BedrockAgents"
    Team    = "AI-Platform"
  }
}

# X-Ray Tracing
module "xray_tracing" {
  source = "./modules/monitoring/bedrock-monitoring-xray"

  project_name = "my-bedrock-project"
  environment  = "prod"

  enable_xray_tracing = true
  enable_insights     = true

  # Sampling rates
  bedrock_sampling_rate     = 0.1   # 10% of Bedrock calls
  lambda_sampling_rate      = 0.05  # 5% of Lambda calls
  api_gateway_sampling_rate = 0.1   # 10% of API calls

  # Notifications
  insights_notifications_enabled = true
  sns_topic_arn                 = aws_sns_topic.monitoring.arn

  kms_key_id = aws_kms_key.main.id

  tags = {
    Project = "BedrockAgents"
  }
}

# AWS Config Compliance
module "config_compliance" {
  source = "./modules/monitoring/bedrock-monitoring-config"

  project_name = "my-bedrock-project"
  environment  = "prod"

  enable_config   = true
  enable_recorder = true

  recording_frequency = "CONTINUOUS"
  delivery_frequency  = "TwentyFour_Hours"

  # Create S3 bucket for config
  create_s3_bucket = true

  # Enable compliance rules
  enable_compliance_rules = true
  enable_remediation     = false  # Manual remediation in prod

  # Multi-region aggregation
  enable_aggregator    = true
  aggregator_regions   = ["us-east-1", "us-west-2"]

  sns_topic_arn = aws_sns_topic.monitoring.arn
  kms_key_id    = aws_kms_key.main.id

  tags = {
    Project = "BedrockAgents"
  }
}

# CloudTrail Audit Logging
module "cloudtrail_audit" {
  source = "./modules/monitoring/bedrock-monitoring-cloudtrail"

  project_name = "my-bedrock-project"
  environment  = "prod"

  enable_trail                  = true
  is_multi_region_trail        = true
  include_global_service_events = true
  enable_log_file_validation   = true

  # CloudWatch Logs integration
  create_cloudwatch_logs_group     = true
  cloudwatch_logs_retention_days   = 90

  # CloudTrail Insights
  enable_insights = true
  insight_selector_type = [
    "ApiCallRateInsight",
    "ApiErrorRateInsight"
  ]

  # Use advanced event selectors for Bedrock
  use_advanced_event_selectors = true

  # S3 lifecycle
  s3_lifecycle_transition_days = 30
  s3_lifecycle_expiration_days = 365

  kms_key_id = aws_kms_key.main.id

  tags = {
    Project = "BedrockAgents"
  }
}

# Synthetics Canaries
module "synthetics_monitoring" {
  source = "./modules/monitoring/bedrock-monitoring-synthetics"

  project_name = "my-bedrock-project"
  environment  = "prod"

  enable_synthetics = true

  # Bedrock agent endpoints
  bedrock_agent_endpoints = [
    {
      name         = "production-agent"
      endpoint_url = "https://bedrock-agent.us-east-1.amazonaws.com/invoke"
      headers = {
        "Authorization" = "Bearer ${var.api_token}"
        "Content-Type"  = "application/json"
      }
    }
  ]

  # Custom canaries
  canaries = {
    health_check = {
      endpoint_url         = "https://api.example.com/health"
      method              = "GET"
      expected_status     = 200
      schedule_expression = "rate(1 minute)"
      timeout_seconds     = 30
    }
  }

  # Storage
  create_s3_bucket             = true
  s3_lifecycle_expiration_days = 30

  # Alarms
  alarm_sns_topic_arn = aws_sns_topic.monitoring.arn

  # X-Ray integration
  enable_active_tracing = true

  kms_key_id = aws_kms_key.main.id

  tags = {
    Project = "BedrockAgents"
  }
}

# EventBridge Monitoring
module "eventbridge_monitoring" {
  source = "./modules/monitoring/bedrock-monitoring-eventbridge"

  project_name = "my-bedrock-project"
  environment  = "prod"

  enable_eventbridge = true

  # Use default event bus
  event_bus_name          = "default"
  create_custom_event_bus = false

  # Enable all event types
  enable_bedrock_state_change_events = true
  enable_bedrock_error_events       = true
  enable_lambda_error_events        = true
  enable_step_functions_events      = true
  enable_cloudtrail_insights_events = true
  enable_config_compliance_events   = true
  enable_health_events              = true

  # Targets
  sns_topic_arn = aws_sns_topic.monitoring.arn

  # Archiving
  enable_event_archiving  = true
  archive_retention_days  = 90

  # DLQ for failed events
  enable_dlq = true

  kms_key_id = aws_kms_key.main.id

  tags = {
    Project = "BedrockAgents"
  }
}
```

### Example 2: Development Environment (Cost-Optimized)

```hcl
# Minimal monitoring for dev
module "dev_cloudwatch" {
  source = "./modules/monitoring/bedrock-monitoring-cloudwatch"

  project_name     = "bedrock-dev"
  environment      = "dev"
  bedrock_agent_id = "DEV_AGENT"

  # Lower retention for cost savings
  retention_in_days = 7

  # Disable advanced features
  enable_anomaly_detection = false
  enable_composite_alarms  = false

  # Reduced alarm sensitivity
  bedrock_error_rate_threshold = 10

  tags = {
    Environment = "dev"
  }
}

module "dev_xray" {
  source = "./modules/monitoring/bedrock-monitoring-xray"

  project_name = "bedrock-dev"
  environment  = "dev"

  # Higher sampling for debugging
  bedrock_sampling_rate = 0.5
  lambda_sampling_rate  = 0.5

  # Disable insights in dev
  enable_insights = false

  tags = {
    Environment = "dev"
  }
}
```

### Example 3: Integration with Security Modules

```hcl
# KMS key for monitoring data
module "monitoring_kms" {
  source = "./modules/security/bedrock-kms"

  project_name = "my-bedrock-project"
  environment  = "prod"

  key_purpose = "monitoring"

  enable_key_rotation = true

  key_administrators = [
    "arn:aws:iam::123456789012:role/DevOpsAdmin"
  ]

  key_users = [
    "arn:aws:iam::123456789012:role/CloudWatchRole",
    "arn:aws:iam::123456789012:role/CloudTrailRole",
    "arn:aws:iam::123456789012:role/ConfigRole"
  ]

  tags = {
    Project = "BedrockAgents"
  }
}

# Use KMS key across all monitoring modules
module "cloudwatch_monitoring" {
  source = "./modules/monitoring/bedrock-monitoring-cloudwatch"

  # ... other configuration ...

  kms_key_id = module.monitoring_kms.key_id
}

module "cloudtrail_audit" {
  source = "./modules/monitoring/bedrock-monitoring-cloudtrail"

  # ... other configuration ...

  kms_key_id = module.monitoring_kms.key_id
}
```

## Key Features

### Security & Compliance

- **Encryption at Rest**: KMS encryption for all data storage (S3, CloudWatch Logs, SQS)
- **Encryption in Transit**: TLS 1.2+ for all API communications
- **Access Control**: IAM policies with least privilege
- **Audit Trail**: Complete CloudTrail logging of all monitoring activities
- **Compliance Rules**: AWS Config rules for security best practices

### Operational Excellence

- **High Availability**: Multi-region support
- **Scalability**: Auto-scaling metric collection
- **Cost Optimization**: Lifecycle policies, sampling rates, retention management
- **Automation**: EventBridge-driven responses
- **Documentation**: Comprehensive inline documentation

### Performance

- **Low Latency**: Real-time metric collection
- **Efficient Sampling**: Cost-optimized X-Ray sampling
- **Batch Processing**: Efficient log aggregation
- **Query Optimization**: Pre-built CloudWatch Insights queries

## Best Practices

### 1. Alarm Configuration

- Set appropriate thresholds based on baseline metrics
- Use composite alarms for complex health checks
- Configure SNS fanout for different teams
- Test alarm actions in non-production first

### 2. Cost Management

- Adjust retention periods based on compliance requirements
- Use lifecycle policies for S3 storage
- Configure appropriate sampling rates for X-Ray
- Archive events instead of deleting for audit purposes

### 3. Security

- Always use KMS encryption for sensitive data
- Implement least privilege IAM policies
- Enable log file validation for CloudTrail
- Use VPC endpoints for private API access

### 4. Monitoring Strategy

- Start with basic monitoring and add complexity
- Monitor business metrics, not just technical metrics
- Set up dashboards for different audiences (ops, dev, business)
- Regularly review and adjust thresholds

## Outputs

Each module provides comprehensive outputs:

- **Resource ARNs**: For cross-module integration
- **Console URLs**: For quick access to AWS Console
- **Metric Namespaces**: For custom metric publishing
- **Query Definitions**: For programmatic log analysis

## Integration Points

These modules integrate with:

- **bedrock-agent**: Agent IDs, alias IDs
- **bedrock-action-group**: Lambda ARNs
- **bedrock-orchestration**: Step Functions ARNs
- **bedrock-security-iam**: IAM roles and policies
- **bedrock-kms**: KMS keys for encryption

## Troubleshooting

### Common Issues

1. **Missing Metrics**:
   - Verify resource IDs are correct
   - Check IAM permissions for CloudWatch
   - Ensure X-Ray SDK is configured in Lambda

2. **High Costs**:
   - Review retention periods
   - Adjust X-Ray sampling rates
   - Implement lifecycle policies

3. **Alarm Noise**:
   - Increase evaluation periods
   - Adjust thresholds based on baseline
   - Use composite alarms for complex conditions

4. **Missing Events**:
   - Verify EventBridge event patterns
   - Check CloudTrail is enabled
   - Ensure resources are in the same region

## Version Compatibility

- **Terraform**: >= 1.11.0
- **AWS Provider**: ~> 5.80
- **Archive Provider**: ~> 2.0 (for Synthetics)

## Contributing

When adding new monitoring capabilities:

1. Follow the existing module structure
2. Include comprehensive variable validation
3. Provide detailed outputs
4. Add usage examples to documentation
5. Include cost optimization options

## License

See the main project LICENSE file.

## Support

For issues and questions:
- Open a GitHub issue
- Contact the DevOps team
- Review AWS documentation for specific services
