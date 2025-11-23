# ==============================================================================
# Bedrock Security Hub Module
# ==============================================================================
# Purpose: Security posture management and compliance monitoring
# Features: CIS, PCI-DSS, AWS Foundational standards, automated remediation
# ==============================================================================

locals {
  common_tags = merge(
    var.tags,
    {
      Module        = "bedrock-security-hub"
      ManagedBy     = "terraform"
      SecurityLevel = "critical"
      Compliance    = "SOC2,HIPAA,PCI-DSS"
    }
  )
}

# ==============================================================================
# Security Hub
# ==============================================================================

resource "aws_securityhub_account" "main" {
  enable_default_standards  = var.enable_default_standards
  control_finding_generator = var.control_finding_generator

  auto_enable_controls = var.auto_enable_controls
}

# ==============================================================================
# Security Standards Subscriptions
# ==============================================================================

# AWS Foundational Security Best Practices
resource "aws_securityhub_standards_subscription" "aws_foundational" {
  count = var.enable_aws_foundational_standard ? 1 : 0

  depends_on    = [aws_securityhub_account.main]
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/aws-foundational-security-best-practices/v/1.0.0"
}

# CIS AWS Foundations Benchmark
resource "aws_securityhub_standards_subscription" "cis_aws_foundations" {
  count = var.enable_cis_aws_foundations ? 1 : 0

  depends_on    = [aws_securityhub_account.main]
  standards_arn = "arn:aws:securityhub:::ruleset/cis-aws-foundations-benchmark/v/1.2.0"
}

# PCI-DSS
resource "aws_securityhub_standards_subscription" "pci_dss" {
  count = var.enable_pci_dss ? 1 : 0

  depends_on    = [aws_securityhub_account.main]
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/pci-dss/v/3.2.1"
}

# NIST 800-53
resource "aws_securityhub_standards_subscription" "nist" {
  count = var.enable_nist ? 1 : 0

  depends_on    = [aws_securityhub_account.main]
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/nist-800-53/v/5.0.0"
}

# ==============================================================================
# Security Hub Insights
# ==============================================================================

resource "aws_securityhub_insight" "critical_findings" {
  filters {
    severity_label {
      comparison = "EQUALS"
      value      = "CRITICAL"
    }

    workflow_status {
      comparison = "EQUALS"
      value      = "NEW"
    }
  }

  group_by_attribute = "ResourceType"

  name = "${var.project_name}-critical-findings-${var.environment}"
}

resource "aws_securityhub_insight" "failed_compliance_checks" {
  filters {
    compliance_status {
      comparison = "EQUALS"
      value      = "FAILED"
    }

    workflow_status {
      comparison = "EQUALS"
      value      = "NEW"
    }
  }

  group_by_attribute = "ComplianceSecurityControlId"

  name = "${var.project_name}-failed-compliance-${var.environment}"
}

resource "aws_securityhub_insight" "bedrock_findings" {
  filters {
    resource_type {
      comparison = "EQUALS"
      value      = "AwsBedrock*"
    }

    workflow_status {
      comparison = "EQUALS"
      value      = "NEW"
    }
  }

  group_by_attribute = "ResourceId"

  name = "${var.project_name}-bedrock-findings-${var.environment}"
}

resource "aws_securityhub_insight" "iam_findings" {
  filters {
    resource_type {
      comparison = "EQUALS"
      value      = "AwsIamRole"
    }

    severity_label {
      comparison = "EQUALS"
      value      = "HIGH"
    }
  }

  group_by_attribute = "ResourceId"

  name = "${var.project_name}-iam-findings-${var.environment}"
}

# ==============================================================================
# EventBridge Rules for Security Hub Findings
# ==============================================================================

resource "aws_cloudwatch_event_rule" "security_hub_findings" {
  name        = "${var.project_name}-securityhub-findings-${var.environment}"
  description = "Capture all Security Hub findings"

  event_pattern = jsonencode({
    source      = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
  })

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "security_hub_sns" {
  rule      = aws_cloudwatch_event_rule.security_hub_findings.name
  target_id = "SendToSNS"
  arn       = var.sns_topic_arn
}

# High severity findings rule
resource "aws_cloudwatch_event_rule" "high_severity_findings" {
  name        = "${var.project_name}-securityhub-high-severity-${var.environment}"
  description = "Capture high severity Security Hub findings"

  event_pattern = jsonencode({
    source      = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        Severity = {
          Label = ["HIGH", "CRITICAL"]
        }
        Workflow = {
          Status = ["NEW"]
        }
      }
    }
  })

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "high_severity_sns" {
  rule      = aws_cloudwatch_event_rule.high_severity_findings.name
  target_id = "SendToSNSHighSeverity"
  arn       = var.high_severity_sns_topic_arn != "" ? var.high_severity_sns_topic_arn : var.sns_topic_arn
}

# Failed compliance checks rule
resource "aws_cloudwatch_event_rule" "failed_compliance" {
  name        = "${var.project_name}-securityhub-failed-compliance-${var.environment}"
  description = "Capture failed compliance checks"

  event_pattern = jsonencode({
    source      = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        Compliance = {
          Status = ["FAILED"]
        }
      }
    }
  })

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "failed_compliance_sns" {
  rule      = aws_cloudwatch_event_rule.failed_compliance.name
  target_id = "SendToSNSComplianceFailed"
  arn       = var.sns_topic_arn
}

# ==============================================================================
# GuardDuty Integration
# ==============================================================================

resource "aws_securityhub_product_subscription" "guardduty" {
  count = var.enable_guardduty_integration ? 1 : 0

  depends_on  = [aws_securityhub_account.main]
  product_arn = "arn:aws:securityhub:${data.aws_region.current.name}::product/aws/guardduty"
}

# ==============================================================================
# AWS Config Integration
# ==============================================================================

resource "aws_securityhub_product_subscription" "config" {
  count = var.enable_config_integration ? 1 : 0

  depends_on  = [aws_securityhub_account.main]
  product_arn = "arn:aws:securityhub:${data.aws_region.current.name}::product/aws/config"
}

# ==============================================================================
# Inspector Integration
# ==============================================================================

resource "aws_securityhub_product_subscription" "inspector" {
  count = var.enable_inspector_integration ? 1 : 0

  depends_on  = [aws_securityhub_account.main]
  product_arn = "arn:aws:securityhub:${data.aws_region.current.name}::product/aws/inspector"
}

# ==============================================================================
# IAM Access Analyzer Integration
# ==============================================================================

resource "aws_securityhub_product_subscription" "access_analyzer" {
  count = var.enable_access_analyzer_integration ? 1 : 0

  depends_on  = [aws_securityhub_account.main]
  product_arn = "arn:aws:securityhub:${data.aws_region.current.name}::product/aws/access-analyzer"
}

# ==============================================================================
# CloudWatch Alarms for Security Hub
# ==============================================================================

resource "aws_cloudwatch_metric_alarm" "critical_findings" {
  alarm_name          = "${var.project_name}-securityhub-critical-findings-${var.environment}"
  alarm_description   = "Alert on critical Security Hub findings"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CriticalFindings"
  namespace           = "${var.project_name}/SecurityHub"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  treat_missing_data  = "notBreaching"

  alarm_actions = [var.high_severity_sns_topic_arn != "" ? var.high_severity_sns_topic_arn : var.sns_topic_arn]
  ok_actions    = [var.sns_topic_arn]

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "failed_compliance_checks" {
  alarm_name          = "${var.project_name}-securityhub-failed-compliance-${var.environment}"
  alarm_description   = "Alert on failed compliance checks"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FailedComplianceChecks"
  namespace           = "${var.project_name}/SecurityHub"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.failed_compliance_threshold
  treat_missing_data  = "notBreaching"

  alarm_actions = [var.sns_topic_arn]
  ok_actions    = [var.sns_topic_arn]

  tags = local.common_tags
}

# ==============================================================================
# Lambda Function for Automated Remediation
# ==============================================================================

resource "aws_lambda_function" "auto_remediation" {
  count = var.enable_auto_remediation ? 1 : 0

  filename      = var.auto_remediation_zip_path
  function_name = "${var.project_name}-securityhub-remediation-${var.environment}"
  role          = aws_iam_role.auto_remediation[0].arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 300

  environment {
    variables = {
      SNS_TOPIC_ARN = var.sns_topic_arn
      ENVIRONMENT   = var.environment
      PROJECT_NAME  = var.project_name
      DRY_RUN       = var.remediation_dry_run ? "true" : "false"
    }
  }

  tags = local.common_tags
}

resource "aws_iam_role" "auto_remediation" {
  count = var.enable_auto_remediation ? 1 : 0

  name = "${var.project_name}-securityhub-remediation-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "auto_remediation_basic" {
  count = var.enable_auto_remediation ? 1 : 0

  role       = aws_iam_role.auto_remediation[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "auto_remediation_policy" {
  count = var.enable_auto_remediation ? 1 : 0

  name = "auto-remediation-policy"
  role = aws_iam_role.auto_remediation[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "securityhub:BatchUpdateFindings",
          "securityhub:GetFindings"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:UpdateAccessKey",
          "iam:DeleteAccessKey",
          "ec2:ModifyInstanceAttribute",
          "s3:PutBucketPublicAccessBlock",
          "s3:PutBucketVersioning"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = var.sns_topic_arn
      }
    ]
  })
}

resource "aws_lambda_permission" "auto_remediation" {
  count = var.enable_auto_remediation ? 1 : 0

  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auto_remediation[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.high_severity_findings.arn
}

resource "aws_cloudwatch_event_target" "auto_remediation" {
  count = var.enable_auto_remediation ? 1 : 0

  rule      = aws_cloudwatch_event_rule.high_severity_findings.name
  target_id = "SendToLambdaRemediation"
  arn       = aws_lambda_function.auto_remediation[0].arn
}

# ==============================================================================
# Data Sources
# ==============================================================================

data "aws_region" "current" {}
