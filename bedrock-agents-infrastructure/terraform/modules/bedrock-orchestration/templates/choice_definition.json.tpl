{
  "Comment": "Conditional orchestration of Bedrock agents based on routing logic",
  "StartAt": "InitializeExecution",
  "TimeoutSeconds": ${timeout_seconds},
  "States": {
    "InitializeExecution": {
      "Type": "Task",
      "Resource": "arn:aws:states:::dynamodb:putItem",
      "Parameters": {
        "TableName": "${dynamodb_table_name}",
        "Item": {
          "execution_id": {
            "S.$": "$$.Execution.Name"
          },
          "timestamp": {
            "N.$": "$$.State.EnteredTime"
          },
          "status": {
            "S": "STARTED"
          },
          "input": {
            "S.$": "States.JsonToString($.input)"
          },
          "ttl": {
            "N.$": "States.MathAdd($$.State.EnteredTime, 86400)"
          }
        }
      },
      "ResultPath": "$.dynamodb_result",
      "Next": "EvaluateRoutingCondition",
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "Next": "HandleError",
          "ResultPath": "$.error"
        }
      ]
    },
    "EvaluateRoutingCondition": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.routing.strategy",
          "StringEquals": "priority",
          "Next": "RouteByPriority"
        },
        {
          "Variable": "$.routing.strategy",
          "StringEquals": "capability",
          "Next": "RouteByCapability"
        },
        {
          "Variable": "$.routing.strategy",
          "StringEquals": "load",
          "Next": "RouteByLoad"
        }
      ],
      "Default": "RouteSequentially"
    },
    "RouteByPriority": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.routing.priority",
          "StringEquals": "high",
          "Next": "InvokeHighPriorityAgent"
        },
        {
          "Variable": "$.routing.priority",
          "StringEquals": "medium",
          "Next": "InvokeMediumPriorityAgent"
        }
      ],
      "Default": "InvokeLowPriorityAgent"
    },
    "RouteByCapability": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.routing.capability",
          "StringEquals": "analysis",
          "Next": "InvokeAnalysisAgent"
        },
        {
          "Variable": "$.routing.capability",
          "StringEquals": "generation",
          "Next": "InvokeGenerationAgent"
        },
        {
          "Variable": "$.routing.capability",
          "StringEquals": "validation",
          "Next": "InvokeValidationAgent"
        }
      ],
      "Default": "InvokeGeneralAgent"
    },
    "RouteByLoad": {
      "Type": "Task",
      "Resource": "arn:aws:states:::dynamodb:query",
      "Parameters": {
        "TableName": "${dynamodb_table_name}",
        "IndexName": "StatusIndex",
        "KeyConditionExpression": "#status = :status",
        "ExpressionAttributeNames": {
          "#status": "status"
        },
        "ExpressionAttributeValues": {
          ":status": {
            "S": "IN_PROGRESS"
          }
        }
      },
      "ResultPath": "$.load_check",
      "Next": "DetermineAvailableAgent"
    },
    "DetermineAvailableAgent": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.load_check.Count",
          "NumericLessThan": 5,
          "Next": "InvokeAgent1"
        },
        {
          "Variable": "$.load_check.Count",
          "NumericLessThan": 10,
          "Next": "InvokeAgent2"
        }
      ],
      "Default": "InvokeAgent3"
    },
    "InvokeHighPriorityAgent": {
      "Type": "Task",
      "Resource": "arn:aws:states:::bedrock:invokeAgent",
      "Parameters": {
        "AgentId.$": "$.agents[0].agentId",
        "AgentAliasId.$": "$.agents[0].agentAliasId",
        "SessionId.$": "$$.Execution.Name",
        "InputText.$": "$.input"
      },
      "ResultPath": "$.agent_result",
      "Retry": [
        {
          "ErrorEquals": ["States.TaskFailed", "States.Timeout"],
          "IntervalSeconds": 2,
          "MaxAttempts": ${max_retry_attempts},
          "BackoffRate": 2.0
        }
      ],
      "Next": "ProcessAgentResponse"
    },
    "InvokeMediumPriorityAgent": {
      "Type": "Task",
      "Resource": "arn:aws:states:::bedrock:invokeAgent",
      "Parameters": {
        "AgentId.$": "$.agents[1].agentId",
        "AgentAliasId.$": "$.agents[1].agentAliasId",
        "SessionId.$": "$$.Execution.Name",
        "InputText.$": "$.input"
      },
      "ResultPath": "$.agent_result",
      "Retry": [
        {
          "ErrorEquals": ["States.TaskFailed", "States.Timeout"],
          "IntervalSeconds": 2,
          "MaxAttempts": ${max_retry_attempts},
          "BackoffRate": 2.0
        }
      ],
      "Next": "ProcessAgentResponse"
    },
    "InvokeLowPriorityAgent": {
      "Type": "Task",
      "Resource": "arn:aws:states:::bedrock:invokeAgent",
      "Parameters": {
        "AgentId.$": "$.agents[2].agentId",
        "AgentAliasId.$": "$.agents[2].agentAliasId",
        "SessionId.$": "$$.Execution.Name",
        "InputText.$": "$.input"
      },
      "ResultPath": "$.agent_result",
      "Retry": [
        {
          "ErrorEquals": ["States.TaskFailed", "States.Timeout"],
          "IntervalSeconds": 2,
          "MaxAttempts": ${max_retry_attempts},
          "BackoffRate": 2.0
        }
      ],
      "Next": "ProcessAgentResponse"
    },
    "InvokeAnalysisAgent": {
      "Type": "Task",
      "Resource": "arn:aws:states:::bedrock:invokeAgent",
      "Parameters": {
        "AgentId.$": "$.agents[0].agentId",
        "AgentAliasId.$": "$.agents[0].agentAliasId",
        "SessionId.$": "$$.Execution.Name",
        "InputText.$": "$.input"
      },
      "ResultPath": "$.agent_result",
      "Retry": [
        {
          "ErrorEquals": ["States.TaskFailed", "States.Timeout"],
          "IntervalSeconds": 2,
          "MaxAttempts": ${max_retry_attempts},
          "BackoffRate": 2.0
        }
      ],
      "Next": "ProcessAgentResponse"
    },
    "InvokeGenerationAgent": {
      "Type": "Task",
      "Resource": "arn:aws:states:::bedrock:invokeAgent",
      "Parameters": {
        "AgentId.$": "$.agents[1].agentId",
        "AgentAliasId.$": "$.agents[1].agentAliasId",
        "SessionId.$": "$$.Execution.Name",
        "InputText.$": "$.input"
      },
      "ResultPath": "$.agent_result",
      "Retry": [
        {
          "ErrorEquals": ["States.TaskFailed", "States.Timeout"],
          "IntervalSeconds": 2,
          "MaxAttempts": ${max_retry_attempts},
          "BackoffRate": 2.0
        }
      ],
      "Next": "ProcessAgentResponse"
    },
    "InvokeValidationAgent": {
      "Type": "Task",
      "Resource": "arn:aws:states:::bedrock:invokeAgent",
      "Parameters": {
        "AgentId.$": "$.agents[2].agentId",
        "AgentAliasId.$": "$.agents[2].agentAliasId",
        "SessionId.$": "$$.Execution.Name",
        "InputText.$": "$.input"
      },
      "ResultPath": "$.agent_result",
      "Retry": [
        {
          "ErrorEquals": ["States.TaskFailed", "States.Timeout"],
          "IntervalSeconds": 2,
          "MaxAttempts": ${max_retry_attempts},
          "BackoffRate": 2.0
        }
      ],
      "Next": "ProcessAgentResponse"
    },
    "InvokeGeneralAgent": {
      "Type": "Task",
      "Resource": "arn:aws:states:::bedrock:invokeAgent",
      "Parameters": {
        "AgentId.$": "$.agents[3].agentId",
        "AgentAliasId.$": "$.agents[3].agentAliasId",
        "SessionId.$": "$$.Execution.Name",
        "InputText.$": "$.input"
      },
      "ResultPath": "$.agent_result",
      "Retry": [
        {
          "ErrorEquals": ["States.TaskFailed", "States.Timeout"],
          "IntervalSeconds": 2,
          "MaxAttempts": ${max_retry_attempts},
          "BackoffRate": 2.0
        }
      ],
      "Next": "ProcessAgentResponse"
    },
    "InvokeAgent1": {
      "Type": "Task",
      "Resource": "arn:aws:states:::bedrock:invokeAgent",
      "Parameters": {
        "AgentId.$": "$.agents[0].agentId",
        "AgentAliasId.$": "$.agents[0].agentAliasId",
        "SessionId.$": "$$.Execution.Name",
        "InputText.$": "$.input"
      },
      "ResultPath": "$.agent_result",
      "Retry": [
        {
          "ErrorEquals": ["States.TaskFailed", "States.Timeout"],
          "IntervalSeconds": 2,
          "MaxAttempts": ${max_retry_attempts},
          "BackoffRate": 2.0
        }
      ],
      "Next": "ProcessAgentResponse"
    },
    "InvokeAgent2": {
      "Type": "Task",
      "Resource": "arn:aws:states:::bedrock:invokeAgent",
      "Parameters": {
        "AgentId.$": "$.agents[1].agentId",
        "AgentAliasId.$": "$.agents[1].agentAliasId",
        "SessionId.$": "$$.Execution.Name",
        "InputText.$": "$.input"
      },
      "ResultPath": "$.agent_result",
      "Retry": [
        {
          "ErrorEquals": ["States.TaskFailed", "States.Timeout"],
          "IntervalSeconds": 2,
          "MaxAttempts": ${max_retry_attempts},
          "BackoffRate": 2.0
        }
      ],
      "Next": "ProcessAgentResponse"
    },
    "InvokeAgent3": {
      "Type": "Task",
      "Resource": "arn:aws:states:::bedrock:invokeAgent",
      "Parameters": {
        "AgentId.$": "$.agents[2].agentId",
        "AgentAliasId.$": "$.agents[2].agentAliasId",
        "SessionId.$": "$$.Execution.Name",
        "InputText.$": "$.input"
      },
      "ResultPath": "$.agent_result",
      "Retry": [
        {
          "ErrorEquals": ["States.TaskFailed", "States.Timeout"],
          "IntervalSeconds": 2,
          "MaxAttempts": ${max_retry_attempts},
          "BackoffRate": 2.0
        }
      ],
      "Next": "ProcessAgentResponse"
    },
    "RouteSequentially": {
      "Type": "Pass",
      "Result": {
        "routing": "sequential"
      },
      "Next": "InvokeAgent1"
    },
    "ProcessAgentResponse": {
      "Type": "Task",
      "Resource": "arn:aws:states:::dynamodb:updateItem",
      "Parameters": {
        "TableName": "${dynamodb_table_name}",
        "Key": {
          "execution_id": {
            "S.$": "$$.Execution.Name"
          },
          "timestamp": {
            "N.$": "$.dynamodb_result.Item.timestamp.N"
          }
        },
        "UpdateExpression": "SET #status = :status, agent_result = :result",
        "ExpressionAttributeNames": {
          "#status": "status"
        },
        "ExpressionAttributeValues": {
          ":status": {
            "S": "COMPLETED"
          },
          ":result": {
            "S.$": "States.JsonToString($.agent_result)"
          }
        }
      },
      "ResultPath": "$.update_result",
      "Next": "NotifySuccess"
    },
    "NotifySuccess": {
      "Type": "Task",
      "Resource": "arn:aws:states:::sns:publish",
      "Parameters": {
        "TopicArn": "${sns_topic_arn}",
        "Subject": "Bedrock Agent Orchestration Completed",
        "Message.$": "States.Format('Execution {} completed successfully with choice-based routing.', $$.Execution.Name)"
      },
      "ResultPath": "$.notification_result",
      "End": true
    },
    "HandleError": {
      "Type": "Task",
      "Resource": "arn:aws:states:::dynamodb:updateItem",
      "Parameters": {
        "TableName": "${dynamodb_table_name}",
        "Key": {
          "execution_id": {
            "S.$": "$$.Execution.Name"
          },
          "timestamp": {
            "N.$": "$$.State.EnteredTime"
          }
        },
        "UpdateExpression": "SET #status = :status, error_info = :error",
        "ExpressionAttributeNames": {
          "#status": "status"
        },
        "ExpressionAttributeValues": {
          ":status": {
            "S": "FAILED"
          },
          ":error": {
            "S.$": "States.JsonToString($.error)"
          }
        }
      },
      "ResultPath": "$.error_log_result",
      "Next": "NotifyFailure"
    },
    "NotifyFailure": {
      "Type": "Task",
      "Resource": "arn:aws:states:::sns:publish",
      "Parameters": {
        "TopicArn": "${sns_topic_arn}",
        "Subject": "Bedrock Agent Orchestration Failed",
        "Message.$": "States.Format('Execution {} failed. Error: {}', $$.Execution.Name, States.JsonToString($.error))"
      },
      "ResultPath": "$.notification_result",
      "Next": "ExecutionFailed"
    },
    "ExecutionFailed": {
      "Type": "Fail",
      "Error": "OrchestrationFailed",
      "Cause": "Choice-based agent orchestration failed"
    }
  }
}
