{
  "widgets": [
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/Bedrock", "Invocations", {"stat": "Sum", "label": "Total Invocations"}],
          [".", "InvocationClientErrors", {"stat": "Sum", "label": "Client Errors"}],
          [".", "InvocationServerErrors", {"stat": "Sum", "label": "Server Errors"}]
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "${region}",
        "title": "Bedrock Agent Invocations",
        "period": 300,
        "yAxis": {
          "left": {
            "label": "Count"
          }
        }
      }
    },
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/Bedrock", "InvocationLatency", {"stat": "Average", "label": "Average Latency"}],
          ["...", {"stat": "p99", "label": "P99 Latency"}],
          ["...", {"stat": "Maximum", "label": "Max Latency"}]
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "${region}",
        "title": "Bedrock Agent Latency",
        "period": 300,
        "yAxis": {
          "left": {
            "label": "Milliseconds"
          }
        }
      }
    },
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/Bedrock", "ThrottledRequests", {"stat": "Sum"}]
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "${region}",
        "title": "Bedrock Agent Throttles",
        "period": 300
      }
    },
    {
      "type": "metric",
      "properties": {
        "metrics": [
          %{ for idx, func in jsondecode(lambda_functions) ~}
          ["AWS/Lambda", "Invocations", {"stat": "Sum", "label": "${func}"}]${idx < length(jsondecode(lambda_functions)) - 1 ? "," : ""}
          %{ endfor ~}
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "${region}",
        "title": "Lambda Invocations",
        "period": 300
      }
    },
    {
      "type": "metric",
      "properties": {
        "metrics": [
          %{ for idx, func in jsondecode(lambda_functions) ~}
          ["AWS/Lambda", "Errors", {"stat": "Sum", "label": "${func}"}]${idx < length(jsondecode(lambda_functions)) - 1 ? "," : ""}
          %{ endfor ~}
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "${region}",
        "title": "Lambda Errors",
        "period": 300
      }
    },
    {
      "type": "metric",
      "properties": {
        "metrics": [
          %{ for idx, func in jsondecode(lambda_functions) ~}
          ["AWS/Lambda", "Duration", {"stat": "Average", "label": "${func} (Avg)"}],
          ["...", {"stat": "Maximum", "label": "${func} (Max)"}]${idx < length(jsondecode(lambda_functions)) - 1 ? "," : ""}
          %{ endfor ~}
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "${region}",
        "title": "Lambda Duration",
        "period": 300,
        "yAxis": {
          "left": {
            "label": "Milliseconds"
          }
        }
      }
    },
    {
      "type": "metric",
      "properties": {
        "metrics": [
          %{ for idx, sfn in jsondecode(step_functions) ~}
          ["AWS/States", "ExecutionsStarted", {"stat": "Sum", "label": "Started"}],
          [".", "ExecutionsSucceeded", {"stat": "Sum", "label": "Succeeded"}],
          [".", "ExecutionsFailed", {"stat": "Sum", "label": "Failed"}],
          [".", "ExecutionsTimedOut", {"stat": "Sum", "label": "Timed Out"}]${idx < length(jsondecode(step_functions)) - 1 ? "," : ""}
          %{ endfor ~}
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "${region}",
        "title": "Step Functions Executions",
        "period": 300
      }
    },
    {
      "type": "metric",
      "properties": {
        "metrics": [
          %{ for idx, api in jsondecode(api_gateways) ~}
          ["AWS/ApiGateway", "Count", {"stat": "Sum", "label": "${api} Requests"}],
          [".", "4XXError", {"stat": "Sum", "label": "${api} 4XX"}],
          [".", "5XXError", {"stat": "Sum", "label": "${api} 5XX"}]${idx < length(jsondecode(api_gateways)) - 1 ? "," : ""}
          %{ endfor ~}
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "${region}",
        "title": "API Gateway Requests & Errors",
        "period": 300
      }
    },
    {
      "type": "metric",
      "properties": {
        "metrics": [
          %{ for idx, api in jsondecode(api_gateways) ~}
          ["AWS/ApiGateway", "Latency", {"stat": "Average", "label": "${api} (Avg)"}],
          ["...", {"stat": "p99", "label": "${api} (P99)"}]${idx < length(jsondecode(api_gateways)) - 1 ? "," : ""}
          %{ endfor ~}
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "${region}",
        "title": "API Gateway Latency",
        "period": 300,
        "yAxis": {
          "left": {
            "label": "Milliseconds"
          }
        }
      }
    },
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["${metric_namespace}", "BedrockErrorCount", {"stat": "Sum"}],
          [".", "BedrockTimeoutCount", {"stat": "Sum"}]
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "${region}",
        "title": "Custom Metrics - Errors & Timeouts",
        "period": 300
      }
    },
    {
      "type": "log",
      "properties": {
        "query": "SOURCE '/aws/bedrock/agents'\n| fields @timestamp, @message\n| filter @message like /ERROR/\n| sort @timestamp desc\n| limit 20",
        "region": "${region}",
        "title": "Recent Bedrock Errors",
        "stacked": false
      }
    }
  ]
}
