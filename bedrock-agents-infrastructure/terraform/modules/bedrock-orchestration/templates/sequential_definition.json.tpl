{
  "Comment": "Sequential orchestration of Bedrock agents",
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
      "Next": "ProcessAgentsSequentially",
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "Next": "HandleError",
          "ResultPath": "$.error"
        }
      ]
    },
    "ProcessAgentsSequentially": {
      "Type": "Map",
      "ItemsPath": "$.agents",
      "MaxConcurrency": 1,
      "Iterator": {
        "StartAt": "InvokeAgent",
        "States": {
          "InvokeAgent": {
            "Type": "Task",
            "Resource": "arn:aws:states:::bedrock:invokeAgent",
            "Parameters": {
              "AgentId.$": "$.agentId",
              "AgentAliasId.$": "$.agentAliasId",
              "SessionId.$": "$$.Execution.Name",
              "InputText.$": "$.input"
            },
            "ResultPath": "$.agent_result",
            "Retry": [
              {
                "ErrorEquals": [
                  "States.TaskFailed",
                  "States.Timeout"
                ],
                "IntervalSeconds": 2,
                "MaxAttempts": ${max_retry_attempts},
                "BackoffRate": 2.0
              }
            ],
            "Catch": [
              {
                "ErrorEquals": ["States.ALL"],
                "Next": "LogAgentError",
                "ResultPath": "$.error"
              }
            ],
            "Next": "UpdateAgentStatus"
          },
          "UpdateAgentStatus": {
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
              "UpdateExpression": "SET agent_id = :agent_id, agent_status = :status, agent_result = :result",
              "ExpressionAttributeValues": {
                ":agent_id": {
                  "S.$": "$.agentId"
                },
                ":status": {
                  "S": "COMPLETED"
                },
                ":result": {
                  "S.$": "States.JsonToString($.agent_result)"
                }
              }
            },
            "ResultPath": "$.update_result",
            "End": true
          },
          "LogAgentError": {
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
              "UpdateExpression": "SET agent_id = :agent_id, agent_status = :status, error_info = :error",
              "ExpressionAttributeValues": {
                ":agent_id": {
                  "S.$": "$.agentId"
                },
                ":status": {
                  "S": "FAILED"
                },
                ":error": {
                  "S.$": "States.JsonToString($.error)"
                }
              }
            },
            "ResultPath": "$.log_result",
            "Next": "HandleAgentError"
          },
          "HandleAgentError": {
            "Type": "Choice",
            "Choices": [
              {
                "Variable": "$.error_handling",
                "StringEquals": "fail",
                "Next": "FailState"
              }
            ],
            "Default": "ContinueAfterError"
          },
          "ContinueAfterError": {
            "Type": "Pass",
            "Result": {
              "status": "CONTINUED_AFTER_ERROR"
            },
            "End": true
          },
          "FailState": {
            "Type": "Fail",
            "Error": "AgentExecutionFailed",
            "Cause": "Agent execution failed and error_handling is set to fail"
          }
        }
      },
      "ResultPath": "$.agents_results",
      "Next": "FinalizeExecution"
    },
    "FinalizeExecution": {
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
        "UpdateExpression": "SET #status = :status, end_time = :end_time, results = :results",
        "ExpressionAttributeNames": {
          "#status": "status"
        },
        "ExpressionAttributeValues": {
          ":status": {
            "S": "COMPLETED"
          },
          ":end_time": {
            "N.$": "$$.State.EnteredTime"
          },
          ":results": {
            "S.$": "States.JsonToString($.agents_results)"
          }
        }
      },
      "ResultPath": "$.finalize_result",
      "Next": "NotifySuccess"
    },
    "NotifySuccess": {
      "Type": "Task",
      "Resource": "arn:aws:states:::sns:publish",
      "Parameters": {
        "TopicArn": "${sns_topic_arn}",
        "Subject": "Bedrock Agent Orchestration Completed",
        "Message.$": "States.Format('Execution {} completed successfully. Results: {}', $$.Execution.Name, States.JsonToString($.agents_results))"
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
      "Cause": "Sequential agent orchestration failed"
    }
  }
}
