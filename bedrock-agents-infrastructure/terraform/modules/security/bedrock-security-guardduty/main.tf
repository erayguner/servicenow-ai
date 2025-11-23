# ==============================================================================
# Bedrock Security GuardDuty Module
# ==============================================================================
# Purpose: Threat detection for Bedrock agent infrastructure
# Features: S3, Lambda, RDS, EKS/ECS protection, automated notifications
# ==============================================================================

locals {
  common_tags = merge(
    var.tags,
    {
      Module        = "bedrock-security-guardduty"
      ManagedBy     = "terraform"
      SecurityLevel = "critical"
      Compliance    = "SOC2,HIPAA,PCI-DSS"
    }
  )
}

# ==============================================================================
# GuardDuty Detector
# ==============================================================================

resource "aws_guardduty_detector" "main" {
  enable                       = true
  finding_publishing_frequency = var.finding_publishing_frequency

  datasources {
    s3_logs {
      enable = var.enable_s3_protection
    }

    kubernetes {
      audit_logs {
        enable = var.enable_eks_protection
      }
    }

    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = var.enable_malware_protection
        }
      }
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-guardduty-detector-${var.environment}"
    }
  )
}

# ==============================================================================
# GuardDuty Filter for High Severity Findings
# ==============================================================================

resource "aws_guardduty_filter" "high_severity" {
  name        = "${var.project_name}-high-severity-findings-${var.environment}"
  action      = "ARCHIVE"
  detector_id = aws_guardduty_detector.main.id
  rank        = 1
  description = "Filter for high severity findings"

  finding_criteria {
    criterion {
      field  = "severity"
      equals = ["8", "9", "10"]
    }
  }

  tags = local.common_tags
}

# ==============================================================================
# S3 Protection Configuration
# ==============================================================================

resource "aws_guardduty_organization_configuration_feature" "s3_protection" {
  count = var.enable_s3_protection && var.enable_organization_configuration ? 1 : 0

  detector_id = aws_guardduty_detector.main.id
  name        = "S3_DATA_EVENTS"
  auto_enable = "ALL"
}

# ==============================================================================
# EKS Protection Configuration
# ==============================================================================

resource "aws_guardduty_organization_configuration_feature" "eks_protection" {
  count = var.enable_eks_protection && var.enable_organization_configuration ? 1 : 0

  detector_id = aws_guardduty_detector.main.id
  name        = "EKS_AUDIT_LOGS"
  auto_enable = "ALL"
}

# ==============================================================================
# Lambda Protection Configuration
# ==============================================================================

resource "aws_guardduty_organization_configuration_feature" "lambda_protection" {
  count = var.enable_lambda_protection && var.enable_organization_configuration ? 1 : 0

  detector_id = aws_guardduty_detector.main.id
  name        = "LAMBDA_NETWORK_LOGS"
  auto_enable = "ALL"
}

# ==============================================================================
# RDS Protection Configuration
# ==============================================================================

resource "aws_guardduty_organization_configuration_feature" "rds_protection" {
  count = var.enable_rds_protection && var.enable_organization_configuration ? 1 : 0

  detector_id = aws_guardduty_detector.main.id
  name        = "RDS_LOGIN_EVENTS"
  auto_enable = "ALL"
}

# ==============================================================================
# EventBridge Rule for GuardDuty Findings
# ==============================================================================

resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  name        = "${var.project_name}-guardduty-findings-${var.environment}"
  description = "Capture all GuardDuty findings"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
  })

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "sns" {
  rule      = aws_cloudwatch_event_rule.guardduty_findings.name
  target_id = "SendToSNS"
  arn       = var.sns_topic_arn
}

# ==============================================================================
# EventBridge Rule for High Severity Findings
# ==============================================================================

resource "aws_cloudwatch_event_rule" "high_severity_findings" {
  name        = "${var.project_name}-guardduty-high-severity-${var.environment}"
  description = "Capture high severity GuardDuty findings"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [
        { numeric = [">=", 7] }
      ]
    }
  })

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "high_severity_sns" {
  rule      = aws_cloudwatch_event_rule.high_severity_findings.name
  target_id = "SendToSNSHighSeverity"
  arn       = var.high_severity_sns_topic_arn != "" ? var.high_severity_sns_topic_arn : var.sns_topic_arn
}

# ==============================================================================
# EventBridge Rule for Specific Threat Types
# ==============================================================================

resource "aws_cloudwatch_event_rule" "crypto_mining" {
  count = var.enable_crypto_mining_detection ? 1 : 0

  name        = "${var.project_name}-guardduty-crypto-mining-${var.environment}"
  description = "Detect cryptocurrency mining activity"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      type = [
        { prefix = "CryptoCurrency" }
      ]
    }
  })

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "crypto_mining_sns" {
  count = var.enable_crypto_mining_detection ? 1 : 0

  rule      = aws_cloudwatch_event_rule.crypto_mining[0].name
  target_id = "SendToSNSCryptoMining"
  arn       = var.sns_topic_arn
}

# ==============================================================================
# GuardDuty Threat Intel Set
# ==============================================================================

resource "aws_guardduty_threat_intel_set" "custom" {
  count = var.custom_threat_intel_set_location != "" ? 1 : 0

  activate    = true
  detector_id = aws_guardduty_detector.main.id
  format      = "TXT"
  location    = var.custom_threat_intel_set_location
  name        = "${var.project_name}-custom-threat-intel-${var.environment}"

  tags = local.common_tags
}

# ==============================================================================
# GuardDuty IP Set (Trusted IPs)
# ==============================================================================

resource "aws_guardduty_ipset" "trusted" {
  count = var.trusted_ip_set_location != "" ? 1 : 0

  activate    = true
  detector_id = aws_guardduty_detector.main.id
  format      = "TXT"
  location    = var.trusted_ip_set_location
  name        = "${var.project_name}-trusted-ips-${var.environment}"

  tags = local.common_tags
}

# ==============================================================================
# CloudWatch Metric Filters for GuardDuty Findings
# ==============================================================================

resource "aws_cloudwatch_log_group" "guardduty_findings" {
  name              = "/aws/guardduty/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = local.common_tags
}

# ==============================================================================
# CloudWatch Alarms for GuardDuty
# ==============================================================================

resource "aws_cloudwatch_metric_alarm" "guardduty_findings_count" {
  alarm_name          = "${var.project_name}-guardduty-findings-count-${var.environment}"
  alarm_description   = "Alert when GuardDuty findings exceed threshold"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FindingCount"
  namespace           = "AWS/GuardDuty"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.findings_count_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    DetectorId = aws_guardduty_detector.main.id
  }

  alarm_actions = [var.sns_topic_arn]
  ok_actions    = [var.sns_topic_arn]

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "high_severity_findings" {
  alarm_name          = "${var.project_name}-guardduty-high-severity-${var.environment}"
  alarm_description   = "Alert on high severity GuardDuty findings"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "HighSeverityFindingCount"
  namespace           = "${var.project_name}/Security"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  treat_missing_data  = "notBreaching"

  alarm_actions = [var.high_severity_sns_topic_arn != "" ? var.high_severity_sns_topic_arn : var.sns_topic_arn]
  ok_actions    = [var.sns_topic_arn]

  tags = local.common_tags
}

# ==============================================================================
# Lambda Function for GuardDuty Findings Processing
# ==============================================================================

resource "aws_lambda_function" "guardduty_processor" {
  count = var.enable_findings_processor ? 1 : 0

  filename      = var.findings_processor_zip_path
  function_name = "${var.project_name}-guardduty-processor-${var.environment}"
  role          = aws_iam_role.guardduty_processor[0].arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 60

  environment {
    variables = {
      SNS_TOPIC_ARN = var.sns_topic_arn
      ENVIRONMENT   = var.environment
      PROJECT_NAME  = var.project_name
    }
  }

  tags = local.common_tags
}

resource "aws_iam_role" "guardduty_processor" {
  count = var.enable_findings_processor ? 1 : 0

  name = "${var.project_name}-guardduty-processor-${var.environment}"

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

resource "aws_iam_role_policy_attachment" "guardduty_processor_basic" {
  count = var.enable_findings_processor ? 1 : 0

  role       = aws_iam_role.guardduty_processor[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_permission" "guardduty_processor" {
  count = var.enable_findings_processor ? 1 : 0

  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.guardduty_processor[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.guardduty_findings.arn
}

resource "aws_cloudwatch_event_target" "guardduty_processor" {
  count = var.enable_findings_processor ? 1 : 0

  rule      = aws_cloudwatch_event_rule.guardduty_findings.name
  target_id = "SendToLambda"
  arn       = aws_lambda_function.guardduty_processor[0].arn
}

# ==============================================================================
# Data Sources
# ==============================================================================
