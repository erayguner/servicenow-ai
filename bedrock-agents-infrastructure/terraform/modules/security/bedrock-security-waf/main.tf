# ==============================================================================
# Bedrock Security WAF Module
# ==============================================================================
# Purpose: Web Application Firewall for API Gateway protection
# Features: Rate limiting, geo-blocking, SQL injection, XSS, IP reputation
# ==============================================================================

locals {
  common_tags = merge(
    var.tags,
    {
      Module        = "bedrock-security-waf"
      ManagedBy     = "terraform"
      SecurityLevel = "critical"
      Compliance    = "SOC2,HIPAA,PCI-DSS"
    }
  )
}

# ==============================================================================
# WAF Web ACL
# ==============================================================================

resource "aws_wafv2_web_acl" "main" {
  name  = "${var.project_name}-bedrock-waf-${var.environment}"
  scope = var.waf_scope

  default_action {
    allow {}
  }

  # Rule 1: Rate limiting
  rule {
    name     = "rate-limit-rule"
    priority = 1

    action {
      block {
        custom_response {
          response_code = 429
        }
      }
    }

    statement {
      rate_based_statement {
        limit              = var.rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-rate-limit-${var.environment}"
      sampled_requests_enabled   = true
    }
  }

  # Rule 2: AWS Managed Rules - Core Rule Set
  rule {
    name     = "aws-managed-core-rule-set"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        dynamic "rule_action_override" {
          for_each = var.enable_core_rule_exceptions ? toset(["SizeRestrictions_BODY"]) : []

          content {
            name = rule_action_override.value

            action_to_use {
              count {}
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-aws-core-rules-${var.environment}"
      sampled_requests_enabled   = true
    }
  }

  # Rule 3: SQL Injection Protection
  rule {
    name     = "sql-injection-protection"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-sqli-protection-${var.environment}"
      sampled_requests_enabled   = true
    }
  }

  # Rule 4: Known Bad Inputs
  rule {
    name     = "known-bad-inputs"
    priority = 4

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-bad-inputs-${var.environment}"
      sampled_requests_enabled   = true
    }
  }

  # Rule 5: Amazon IP Reputation List
  rule {
    name     = "amazon-ip-reputation-list"
    priority = 5

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-ip-reputation-${var.environment}"
      sampled_requests_enabled   = true
    }
  }

  # Rule 6: Anonymous IP List
  dynamic "rule" {
    for_each = var.enable_anonymous_ip_list ? [1] : []

    content {
      name     = "anonymous-ip-list"
      priority = 6

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesAnonymousIpList"
          vendor_name = "AWS"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.project_name}-anonymous-ip-${var.environment}"
        sampled_requests_enabled   = true
      }
    }
  }

  # Rule 7: Geo-blocking
  dynamic "rule" {
    for_each = length(var.blocked_countries) > 0 ? [1] : []

    content {
      name     = "geo-blocking"
      priority = 7

      action {
        block {
          custom_response {
            response_code = 403
          }
        }
      }

      statement {
        geo_match_statement {
          country_codes = var.blocked_countries
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.project_name}-geo-blocking-${var.environment}"
        sampled_requests_enabled   = true
      }
    }
  }

  # Rule 8: IP Whitelist
  dynamic "rule" {
    for_each = length(var.allowed_ip_addresses) > 0 ? [1] : []

    content {
      name     = "ip-whitelist"
      priority = 8

      action {
        allow {}
      }

      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.whitelist[0].arn
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.project_name}-ip-whitelist-${var.environment}"
        sampled_requests_enabled   = true
      }
    }
  }

  # Rule 9: IP Blacklist
  dynamic "rule" {
    for_each = length(var.blocked_ip_addresses) > 0 ? [1] : []

    content {
      name     = "ip-blacklist"
      priority = 9

      action {
        block {
          custom_response {
            response_code = 403
          }
        }
      }

      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.blacklist[0].arn
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.project_name}-ip-blacklist-${var.environment}"
        sampled_requests_enabled   = true
      }
    }
  }

  # Rule 10: Custom header validation
  dynamic "rule" {
    for_each = var.require_api_key_header ? [1] : []

    content {
      name     = "api-key-validation"
      priority = 10

      action {
        block {
          custom_response {
            response_code = 401
          }
        }
      }

      statement {
        not_statement {
          statement {
            byte_match_statement {
              search_string = var.api_key_header_value
              field_to_match {
                single_header {
                  name = var.api_key_header_name
                }
              }
              text_transformation {
                priority = 0
                type     = "NONE"
              }
              positional_constraint = "EXACTLY"
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.project_name}-api-key-validation-${var.environment}"
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-waf-${var.environment}"
    sampled_requests_enabled   = true
  }

  tags = local.common_tags
}

# ==============================================================================
# IP Sets
# ==============================================================================

resource "aws_wafv2_ip_set" "whitelist" {
  count = length(var.allowed_ip_addresses) > 0 ? 1 : 0

  name               = "${var.project_name}-whitelist-${var.environment}"
  scope              = var.waf_scope
  ip_address_version = "IPV4"
  addresses          = var.allowed_ip_addresses

  tags = local.common_tags
}

resource "aws_wafv2_ip_set" "blacklist" {
  count = length(var.blocked_ip_addresses) > 0 ? 1 : 0

  name               = "${var.project_name}-blacklist-${var.environment}"
  scope              = var.waf_scope
  ip_address_version = "IPV4"
  addresses          = var.blocked_ip_addresses

  tags = local.common_tags
}

# ==============================================================================
# WAF Association with API Gateway
# ==============================================================================

resource "aws_wafv2_web_acl_association" "api_gateway" {
  count = var.api_gateway_arn != "" ? 1 : 0

  resource_arn = var.api_gateway_arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}

# ==============================================================================
# WAF Logging Configuration
# ==============================================================================

resource "aws_wafv2_web_acl_logging_configuration" "main" {
  count = var.enable_waf_logging ? 1 : 0

  resource_arn            = aws_wafv2_web_acl.main.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf_logs[0].arn]

  redacted_fields {
    single_header {
      name = "authorization"
    }
  }

  redacted_fields {
    single_header {
      name = var.api_key_header_name
    }
  }
}

resource "aws_cloudwatch_log_group" "waf_logs" {
  count = var.enable_waf_logging ? 1 : 0

  name              = "/aws/wafv2/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = local.common_tags
}

# ==============================================================================
# CloudWatch Alarms for WAF
# ==============================================================================

resource "aws_cloudwatch_metric_alarm" "blocked_requests" {
  alarm_name          = "${var.project_name}-waf-blocked-requests-${var.environment}"
  alarm_description   = "Alert on high number of blocked requests"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.blocked_requests_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    WebACL = aws_wafv2_web_acl.main.name
    Region = var.waf_scope == "REGIONAL" ? data.aws_region.current.region : "global"
    Rule   = "ALL"
  }

  alarm_actions = [var.sns_topic_arn]
  ok_actions    = [var.sns_topic_arn]

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "rate_limit_exceeded" {
  alarm_name          = "${var.project_name}-waf-rate-limit-exceeded-${var.environment}"
  alarm_description   = "Alert when rate limit is frequently exceeded"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.rate_limit_alarm_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    WebACL = aws_wafv2_web_acl.main.name
    Region = var.waf_scope == "REGIONAL" ? data.aws_region.current.region : "global"
    Rule   = "rate-limit-rule"
  }

  alarm_actions = [var.sns_topic_arn]
  ok_actions    = [var.sns_topic_arn]

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "sql_injection_attempts" {
  alarm_name          = "${var.project_name}-waf-sqli-attempts-${var.environment}"
  alarm_description   = "Alert on SQL injection attempts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  treat_missing_data  = "notBreaching"

  dimensions = {
    WebACL = aws_wafv2_web_acl.main.name
    Region = var.waf_scope == "REGIONAL" ? data.aws_region.current.region : "global"
    Rule   = "sql-injection-protection"
  }

  alarm_actions = [var.sns_topic_arn]
  ok_actions    = [var.sns_topic_arn]

  tags = local.common_tags
}

# ==============================================================================
# EventBridge Rule for WAF Events
# ==============================================================================

resource "aws_cloudwatch_event_rule" "waf_blocked_requests" {
  name        = "${var.project_name}-waf-blocked-requests-${var.environment}"
  description = "Capture blocked requests from WAF"

  event_pattern = jsonencode({
    source      = ["aws.wafv2"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventName = ["BlockedRequest"]
    }
  })

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "waf_sns" {
  rule      = aws_cloudwatch_event_rule.waf_blocked_requests.name
  target_id = "SendToSNS"
  arn       = var.sns_topic_arn
}

# ==============================================================================
# Data Sources
# ==============================================================================

data "aws_region" "current" {}
