# Cloud Monitoring Configuration
# Comprehensive monitoring, alerting, and SLO tracking

# Notification Channel for Slack
resource "google_monitoring_notification_channel" "slack_critical" {
  project      = var.project_id
  display_name = "Slack Critical Alerts"
  type         = "slack"

  labels = {
    channel_name = "#prod-alerts-critical"
  }

  sensitive_labels {
    auth_token = var.slack_webhook_token
  }

  enabled = true
}

resource "google_monitoring_notification_channel" "slack_warnings" {
  project      = var.project_id
  display_name = "Slack Warning Alerts"
  type         = "slack"

  labels = {
    channel_name = "#prod-alerts-warnings"
  }

  sensitive_labels {
    auth_token = var.slack_webhook_token
  }

  enabled = true
}

# Email notification channel
resource "google_monitoring_notification_channel" "email_oncall" {
  project      = var.project_id
  display_name = "On-Call Email"
  type         = "email"

  labels = {
    email_address = var.oncall_email
  }

  enabled = true
}

# Alert Policy: High Error Rate
resource "google_monitoring_alert_policy" "high_error_rate" {
  project      = var.project_id
  display_name = "High Error Rate (>5%)"
  combiner     = "OR"

  conditions {
    display_name = "Error rate exceeds 5%"

    condition_threshold {
      filter          = "resource.type=\"k8s_container\" AND resource.labels.namespace_name=\"production\" AND metric.type=\"logging.googleapis.com/log_entry_count\" AND metric.labels.severity=\"ERROR\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.05

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = [
    google_monitoring_notification_channel.slack_critical.id,
    google_monitoring_notification_channel.email_oncall.id
  ]

  alert_strategy {
    auto_close = "1800s"

    notification_rate_limit {
      period = "300s"
    }
  }

  documentation {
    content   = <<-EOT
      High error rate detected in production.

      Runbook: https://wiki.company.com/runbooks/high-error-rate

      Investigation steps:
      1. Check Cloud Logging for error details
      2. Review recent deployments
      3. Check external service status
      4. Investigate database connectivity
    EOT
    mime_type = "text/markdown"
  }
}

# Alert Policy: Pod Restart Rate
resource "google_monitoring_alert_policy" "pod_restart_rate" {
  project      = var.project_id
  display_name = "High Pod Restart Rate"
  combiner     = "OR"

  conditions {
    display_name = "Pods restarting frequently"

    condition_threshold {
      filter          = "resource.type=\"k8s_pod\" AND resource.labels.namespace_name=\"production\" AND metric.type=\"kubernetes.io/container/restart_count\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 3

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.labels.pod_name"]
      }
    }
  }

  notification_channels = [
    google_monitoring_notification_channel.slack_critical.id
  ]

  documentation {
    content = "Pods are restarting frequently. Check pod logs and resource limits."
  }
}

# Alert Policy: High Memory Usage
resource "google_monitoring_alert_policy" "high_memory_usage" {
  project      = var.project_id
  display_name = "High Memory Usage (>90%)"
  combiner     = "OR"

  conditions {
    display_name = "Memory usage exceeds 90%"

    condition_threshold {
      filter          = "resource.type=\"k8s_container\" AND resource.labels.namespace_name=\"production\" AND metric.type=\"kubernetes.io/container/memory/used_bytes\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.9

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }

      denominator_filter = "resource.type=\"k8s_container\" AND resource.labels.namespace_name=\"production\" AND metric.type=\"kubernetes.io/container/memory/limit_bytes\""

      denominator_aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = [
    google_monitoring_notification_channel.slack_warnings.id
  ]
}

# Alert Policy: High CPU Usage
resource "google_monitoring_alert_policy" "high_cpu_usage" {
  project      = var.project_id
  display_name = "High CPU Usage (>80%)"
  combiner     = "OR"

  conditions {
    display_name = "CPU usage exceeds 80%"

    condition_threshold {
      filter          = "resource.type=\"k8s_container\" AND resource.labels.namespace_name=\"production\" AND metric.type=\"kubernetes.io/container/cpu/core_usage_time\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.8

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = [
    google_monitoring_notification_channel.slack_warnings.id
  ]
}

# Alert Policy: Security - Prompt Injection Detected
resource "google_monitoring_alert_policy" "prompt_injection_detected" {
  project      = var.project_id
  display_name = "Security: Prompt Injection Detected"
  combiner     = "OR"

  conditions {
    display_name = "Prompt injection attempts detected"

    condition_threshold {
      filter          = "resource.type=\"k8s_container\" AND jsonPayload.securityEvent=true AND jsonPayload.type=\"prompt_injection\""
      duration        = "60s"
      comparison      = "COMPARISON_GT"
      threshold_value = 5

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_COUNT"
      }
    }
  }

  notification_channels = [
    google_monitoring_notification_channel.slack_critical.id,
    google_monitoring_notification_channel.email_oncall.id
  ]

  severity = "CRITICAL"

  documentation {
    content   = <<-EOT
      SECURITY ALERT: Multiple prompt injection attempts detected!

      Immediate actions:
      1. Review security audit logs
      2. Identify source IP/user
      3. Block malicious actor if confirmed
      4. Escalate to security team

      Security runbook: https://wiki.company.com/security/incident-response
    EOT
    mime_type = "text/markdown"
  }
}

# Alert Policy: Rate Limit Exceeded
resource "google_monitoring_alert_policy" "rate_limit_exceeded" {
  project      = var.project_id
  display_name = "Security: Rate Limit Exceeded"
  combiner     = "OR"

  conditions {
    display_name = "High rate of rate limit violations"

    condition_threshold {
      filter          = "resource.type=\"k8s_container\" AND jsonPayload.securityEvent=true AND jsonPayload.type=\"rate_limit_exceeded\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 50

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_COUNT"
      }
    }
  }

  notification_channels = [
    google_monitoring_notification_channel.slack_warnings.id
  ]

  severity = "WARNING"
}

# Alert Policy: Sensitive Data Detected
resource "google_monitoring_alert_policy" "sensitive_data_detected" {
  project      = var.project_id
  display_name = "Security: Sensitive Data Detected"
  combiner     = "OR"

  conditions {
    display_name = "Sensitive data detected in requests/responses"

    condition_threshold {
      filter          = "resource.type=\"k8s_container\" AND jsonPayload.securityEvent=true AND jsonPayload.type=\"sensitive_data_detected\""
      duration        = "60s"
      comparison      = "COMPARISON_GT"
      threshold_value = 10

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_COUNT"
      }
    }
  }

  notification_channels = [
    google_monitoring_notification_channel.slack_critical.id
  ]

  severity = "CRITICAL"
}

# Alert Policy: Cloud SQL Connection Failures
resource "google_monitoring_alert_policy" "cloudsql_connection_failures" {
  project      = var.project_id
  display_name = "Cloud SQL Connection Failures"
  combiner     = "OR"

  conditions {
    display_name = "High rate of Cloud SQL connection failures"

    condition_threshold {
      filter          = "resource.type=\"cloudsql_database\" AND metric.type=\"cloudsql.googleapis.com/database/network/connections\" AND metric.label.state=\"failed\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 10

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = [
    google_monitoring_notification_channel.slack_critical.id
  ]
}

# Alert Policy: Workload Identity Failures
resource "google_monitoring_alert_policy" "workload_identity_failures" {
  project      = var.project_id
  display_name = "Workload Identity Authentication Failures"
  combiner     = "OR"

  conditions {
    display_name = "Workload Identity auth failures"

    condition_threshold {
      filter          = "protoPayload.status.code=7 AND protoPayload.authenticationInfo.principalEmail=~\".*@${var.project_id}.iam.gserviceaccount.com\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 5

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_COUNT"
      }
    }
  }

  notification_channels = [
    google_monitoring_notification_channel.slack_critical.id
  ]
}

# SLO: API Availability (99.9%)
resource "google_monitoring_slo" "api_availability" {
  service      = google_monitoring_custom_service.api_service.service_id
  slo_id       = "api-availability-slo"
  display_name = "API Availability SLO (99.9%)"

  goal                = 0.999
  rolling_period_days = 30

  request_based_sli {
    good_total_ratio {
      total_service_filter = "metric.type=\"serviceruntime.googleapis.com/api/request_count\""

      good_service_filter = "metric.type=\"serviceruntime.googleapis.com/api/request_count\" AND metric.label.response_code_class=\"2xx\""
    }
  }
}

# Custom Service for SLO tracking
resource "google_monitoring_custom_service" "api_service" {
  service_id   = "api-service"
  display_name = "API Gateway Service"

  telemetry {
    resource_name = "//container.googleapis.com/projects/${var.project_id}/locations/${var.region}/clusters/prod-ai-agent-gke/k8s/namespaces/production/services/api-gateway"
  }
}

# Dashboard: Infrastructure Overview
resource "google_monitoring_dashboard" "infrastructure_overview" {
  project = var.project_id
  dashboard_json = jsonencode({
    displayName = "Infrastructure Overview"

    gridLayout = {
      widgets = [
        {
          title = "GKE Pod Count"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"k8s_pod\" AND resource.labels.namespace_name=\"production\""
                  aggregation = {
                    alignmentPeriod  = "60s"
                    perSeriesAligner = "ALIGN_COUNT"
                  }
                }
              }
            }]
          }
        },
        {
          title = "CPU Utilization"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"k8s_container\" AND metric.type=\"kubernetes.io/container/cpu/core_usage_time\""
                  aggregation = {
                    alignmentPeriod  = "60s"
                    perSeriesAligner = "ALIGN_RATE"
                  }
                }
              }
            }]
          }
        },
        {
          title = "Memory Utilization"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"k8s_container\" AND metric.type=\"kubernetes.io/container/memory/used_bytes\""
                  aggregation = {
                    alignmentPeriod  = "60s"
                    perSeriesAligner = "ALIGN_MEAN"
                  }
                }
              }
            }]
          }
        },
        {
          title = "Error Rate"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"k8s_container\" AND metric.type=\"logging.googleapis.com/log_entry_count\" AND metric.labels.severity=\"ERROR\""
                  aggregation = {
                    alignmentPeriod  = "60s"
                    perSeriesAligner = "ALIGN_RATE"
                  }
                }
              }
            }]
          }
        }
      ]
    }
  })
}

# Dashboard: Security Monitoring
resource "google_monitoring_dashboard" "security_monitoring" {
  project = var.project_id
  dashboard_json = jsonencode({
    displayName = "Security Monitoring"

    gridLayout = {
      widgets = [
        {
          title = "Prompt Injection Attempts"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "jsonPayload.securityEvent=true AND jsonPayload.type=\"prompt_injection\""
                  aggregation = {
                    alignmentPeriod  = "60s"
                    perSeriesAligner = "ALIGN_COUNT"
                  }
                }
              }
            }]
          }
        },
        {
          title = "Rate Limit Violations"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "jsonPayload.securityEvent=true AND jsonPayload.type=\"rate_limit_exceeded\""
                  aggregation = {
                    alignmentPeriod  = "60s"
                    perSeriesAligner = "ALIGN_COUNT"
                  }
                }
              }
            }]
          }
        },
        {
          title = "Unauthorized Tool Requests"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "jsonPayload.securityEvent=true AND jsonPayload.type=\"unauthorized_tool\""
                  aggregation = {
                    alignmentPeriod  = "60s"
                    perSeriesAligner = "ALIGN_COUNT"
                  }
                }
              }
            }]
          }
        },
        {
          title = "Sensitive Data Detections"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "jsonPayload.securityEvent=true AND jsonPayload.type=\"sensitive_data_detected\""
                  aggregation = {
                    alignmentPeriod  = "60s"
                    perSeriesAligner = "ALIGN_COUNT"
                  }
                }
              }
            }]
          }
        }
      ]
    }
  })
}

# Uptime Check: API Gateway
resource "google_monitoring_uptime_check_config" "api_gateway_uptime" {
  project      = var.project_id
  display_name = "API Gateway Health Check"
  timeout      = "10s"
  period       = "60s"

  http_check {
    path           = "/healthz"
    port           = 443
    use_ssl        = true
    validate_ssl   = true
    request_method = "GET"
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = var.api_gateway_domain
    }
  }

  checker_type = "STATIC_IP_CHECKERS"
}

# Variables
variable "slack_webhook_token" {
  description = "Slack webhook token for notifications"
  type        = string
  sensitive   = true
}

variable "oncall_email" {
  description = "Email address for on-call notifications"
  type        = string
  default     = "oncall@company.com"
}

variable "api_gateway_domain" {
  description = "API Gateway domain for uptime checks"
  type        = string
  default     = "api.servicenow-ai.com"
}
