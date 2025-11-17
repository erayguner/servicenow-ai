# Incident Response Automation - EventBridge Rules
# This module configures automated incident detection and response workflows

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# EventBridge Rule for GuardDuty Findings
resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  name        = "incident-response-guardduty-findings"
  description = "Trigger incident response for GuardDuty findings"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [7, 7.0, 7.1, 7.2, 7.3, 8, 8.0, 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7, 8.8, 8.9, 9]
    }
  })

  tags = {
    Name        = "guardduty-incident-response"
    Environment = var.environment
    Purpose     = "Incident Response"
  }
}

# EventBridge Rule for CloudTrail Anomalies
resource "aws_cloudwatch_event_rule" "cloudtrail_anomalies" {
  name        = "incident-response-cloudtrail-anomalies"
  description = "Trigger incident response for CloudTrail anomalies"

  event_pattern = jsonencode({
    source      = ["aws.cloudtrail"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventName = [
        "DeleteTrail",
        "StopLogging",
        "PutEventSelectors",
        "CreateDBInstance",
        "CreateAccessKey",
        "AttachUserPolicy",
        "PutUserPolicy"
      ]
      userIdentity = {
        principalId = [{ anything-but = var.trusted_principals }]
      }
    }
  })

  tags = {
    Name        = "cloudtrail-incident-response"
    Environment = var.environment
    Purpose     = "Incident Response"
  }
}

# EventBridge Rule for Security Hub Findings
resource "aws_cloudwatch_event_rule" "security_hub_findings" {
  name        = "incident-response-security-hub-findings"
  description = "Trigger incident response for Security Hub findings"

  event_pattern = jsonencode({
    source      = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        Compliance = {
          Status = ["FAILED"]
        }
        Severity = {
          Label = ["CRITICAL", "HIGH"]
        }
      }
    }
  })

  tags = {
    Name        = "security-hub-incident-response"
    Environment = var.environment
    Purpose     = "Incident Response"
  }
}

# EventBridge Rule for VPC Flow Logs Anomalies
resource "aws_cloudwatch_event_rule" "vpc_anomalies" {
  name        = "incident-response-vpc-anomalies"
  description = "Trigger incident response for VPC anomalies"

  event_pattern = jsonencode({
    source      = ["custom.vpc"]
    detail-type = ["VPC Flow Log Anomaly"]
    detail = {
      anomalyType = ["RejectedFlows", "HighTrafficiateLatency", "PortScan"]
      severity    = ["HIGH", "CRITICAL"]
    }
  })

  tags = {
    Name        = "vpc-incident-response"
    Environment = var.environment
    Purpose     = "Incident Response"
  }
}

# EventBridge Rule for EC2 Unauthorized Access
resource "aws_cloudwatch_event_rule" "ec2_unauthorized_access" {
  name        = "incident-response-ec2-unauthorized-access"
  description = "Trigger incident response for unauthorized EC2 access"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventName = ["AuthorizeSecurityGroupIngress", "RevokeSecurityGroupIngress"]
      requestParameters = {
        cidrIp = ["0.0.0.0/0"]
      }
    }
  })

  tags = {
    Name        = "ec2-incident-response"
    Environment = var.environment
    Purpose     = "Incident Response"
  }
}

# EventBridge Rule for S3 Unauthorized Access
resource "aws_cloudwatch_event_rule" "s3_unauthorized_access" {
  name        = "incident-response-s3-unauthorized-access"
  description = "Trigger incident response for S3 unauthorized access"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventName = ["PutBucketPolicy", "PutBucketAcl", "DeleteBucket"]
      errorCode = [{ exists = false }]
    }
  })

  tags = {
    Name        = "s3-incident-response"
    Environment = var.environment
    Purpose     = "Incident Response"
  }
}

# EventBridge Rule for RDS Unauthorized Access
resource "aws_cloudwatch_event_rule" "rds_unauthorized_access" {
  name        = "incident-response-rds-unauthorized-access"
  description = "Trigger incident response for RDS unauthorized access"

  event_pattern = jsonencode({
    source      = ["aws.rds"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventName = [
        "ModifyDBInstance",
        "DeleteDBInstance",
        "CreateDBSnapshot",
        "ModifyDBCluster"
      ]
      errorCode = [{ exists = false }]
    }
  })

  tags = {
    Name        = "rds-incident-response"
    Environment = var.environment
    Purpose     = "Incident Response"
  }
}

# EventBridge Rule for IAM Privilege Escalation
resource "aws_cloudwatch_event_rule" "iam_privilege_escalation" {
  name        = "incident-response-iam-privilege-escalation"
  description = "Trigger incident response for IAM privilege escalation"

  event_pattern = jsonencode({
    source      = ["aws.iam"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventName = [
        "AttachUserPolicy",
        "AttachGroupPolicy",
        "AttachRolePolicy",
        "PutUserPolicy",
        "PutGroupPolicy",
        "PutRolePolicyPolicy",
        "CreateAccessKey",
        "CreateLoginProfile"
      ]
    }
  })

  tags = {
    Name        = "iam-incident-response"
    Environment = var.environment
    Purpose     = "Incident Response"
  }
}

# EventBridge Rule for Data Exfiltration Detection
resource "aws_cloudwatch_event_rule" "data_exfiltration" {
  name        = "incident-response-data-exfiltration"
  description = "Trigger incident response for data exfiltration detection"

  event_pattern = jsonencode({
    source      = ["custom.dlp"]
    detail-type = ["Data Exfiltration Detection"]
    detail = {
      severity = ["HIGH", "CRITICAL"]
      detection = [
        "UnusualDataTransfer",
        "LargeS3Download",
        "UnauthorizedDataAccess"
      ]
    }
  })

  tags = {
    Name        = "data-exfiltration-detection"
    Environment = var.environment
    Purpose     = "Incident Response"
  }
}

# EventBridge Rule for Lambda Function Errors
resource "aws_cloudwatch_event_rule" "lambda_function_errors" {
  name        = "incident-response-lambda-errors"
  description = "Trigger incident response for Lambda function errors"

  event_pattern = jsonencode({
    source      = ["aws.lambda"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventName = ["UpdateFunctionCode", "UpdateFunctionConfiguration"]
      errorCode = ["UnauthorizedOperation", "AccessDenied"]
    }
  })

  tags = {
    Name        = "lambda-incident-response"
    Environment = var.environment
    Purpose     = "Incident Response"
  }
}

# EventBridge Rule for Failed Authentication Attempts
resource "aws_cloudwatch_event_rule" "failed_authentication" {
  name        = "incident-response-failed-auth"
  description = "Trigger incident response for multiple failed authentication attempts"

  event_pattern = jsonencode({
    source      = ["aws.signin"]
    detail-type = ["AWS Console Sign-In Failure", "AWS API Call"]
    detail = {
      eventName = ["ConsoleLogin", "GetUser"]
      errorCode = ["InvalidUserID.Malformed", "AuthFailure"]
    }
  })

  tags = {
    Name        = "failed-auth-incident-response"
    Environment = var.environment
    Purpose     = "Incident Response"
  }
}

# EventBridge Rule for Bedrock Agent Anomalies
resource "aws_cloudwatch_event_rule" "bedrock_agent_anomalies" {
  name        = "incident-response-bedrock-anomalies"
  description = "Trigger incident response for Bedrock agent anomalies"

  event_pattern = jsonencode({
    source      = ["aws.bedrock"]
    detail-type = ["Bedrock Agent Anomaly Detection"]
    detail = {
      severity = ["HIGH", "CRITICAL"]
      anomalyType = [
        "UnusualAgentBehavior",
        "UnauthorizedInvocation",
        "ResourceExhaustion",
        "ConfigurationChange"
      ]
    }
  })

  tags = {
    Name        = "bedrock-incident-response"
    Environment = var.environment
    Purpose     = "Incident Response"
  }
}

# Variables
variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "trusted_principals" {
  description = "List of trusted principal IDs"
  type        = list(string)
  default     = []
}

variable "incident_response_topic_arn" {
  description = "SNS topic ARN for incident response"
  type        = string
}

variable "lambda_responder_role_arn" {
  description = "IAM role ARN for Lambda responder functions"
  type        = string
}

variable "step_functions_state_machine_arn" {
  description = "ARN of the incident response Step Functions state machine"
  type        = string
}

# Outputs
output "guardduty_rule_arn" {
  value       = aws_cloudwatch_event_rule.guardduty_findings.arn
  description = "ARN of GuardDuty incident response rule"
}

output "cloudtrail_rule_arn" {
  value       = aws_cloudwatch_event_rule.cloudtrail_anomalies.arn
  description = "ARN of CloudTrail incident response rule"
}

output "security_hub_rule_arn" {
  value       = aws_cloudwatch_event_rule.security_hub_findings.arn
  description = "ARN of Security Hub incident response rule"
}

output "bedrock_rule_arn" {
  value       = aws_cloudwatch_event_rule.bedrock_agent_anomalies.arn
  description = "ARN of Bedrock incident response rule"
}
