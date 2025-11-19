{
  "Comment": "Map-based orchestration of Bedrock agents for batch processing",
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
          "total_items": {
            "N.$": "States.Format('{}', States.ArrayLength($.items))"
          },
          "ttl": {
            "N.$": "States.MathAdd($$.State.EnteredTime, 86400)"
          }
        }
      },
      "ResultPath": "$.dynamodb_result",
      "Next": "ProcessItemsWithAgents",
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "Next": "HandleError",
          "ResultPath": "$.error"
        }
      ]
    },
    "ProcessItemsWithAgents": {
      "Type": "Map",
      "ItemsPath": "$.items",
      "MaxConcurrency": 10,
      "Iterator": {
        "StartAt": "DetermineAgentForItem",
        "States": {
          "DetermineAgentForItem": {
            "Type": "Pass",
            "Parameters": {
              "item.$": "$",
              "agent.$": "$.assigned_agent",
              "execution_id.$": "$$.Execution.Name"
            },
            "ResultPath": "$.processing_context",
            "Next": "InvokeAgentForItem"
          },
          "InvokeAgentForItem": {
            "Type": "Task",
            "Resource": "arn:aws:states:::bedrock:invokeAgent",
            "Parameters": {
              "AgentId.$": "$.processing_context.agent.agentId",
              "AgentAliasId.$": "$.processing_context.agent.agentAliasId",
              "SessionId.$": "States.Format('{}_{}_{}', $.processing_context.execution_id, $.processing_context.item.id, $.processing_context.agent.agentId)",
              "InputText.$": "$.processing_context.item.input"
            },
            "ResultPath": "$.agent_result",
            "TimeoutSeconds": 120,
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
                "Next": "HandleItemError",
                "ResultPath": "$.error"
              }
            ],
            "Next": "RecordItemSuccess"
          },
          "RecordItemSuccess": {
            "Type": "Task",
            "Resource": "arn:aws:states:::dynamodb:putItem",
            "Parameters": {
              "TableName": "${dynamodb_table_name}",
              "Item": {
                "execution_id": {
                  "S.$": "$.processing_context.execution_id"
                },
                "timestamp": {
                  "N.$": "$$.State.EnteredTime"
                },
                "item_id": {
                  "S.$": "$.processing_context.item.id"
                },
                "agent_id": {
                  "S.$": "$.processing_context.agent.agentId"
                },
                "status": {
                  "S": "ITEM_COMPLETED"
                },
                "result": {
                  "S.$": "States.JsonToString($.agent_result)"
                },
                "ttl": {
                  "N.$": "States.MathAdd($$.State.EnteredTime, 86400)"
                }
              }
            },
            "ResultPath": "$.record_result",
            "Next": "TransformItemResult"
          },
          "TransformItemResult": {
            "Type": "Pass",
            "Parameters": {
              "item_id.$": "$.processing_context.item.id",
              "agent_id.$": "$.processing_context.agent.agentId",
              "status": "SUCCESS",
              "result.$": "$.agent_result",
              "timestamp.$": "$$.State.EnteredTime"
            },
            "End": true
          },
          "HandleItemError": {
            "Type": "Task",
            "Resource": "arn:aws:states:::dynamodb:putItem",
            "Parameters": {
              "TableName": "${dynamodb_table_name}",
              "Item": {
                "execution_id": {
                  "S.$": "$.processing_context.execution_id"
                },
                "timestamp": {
                  "N.$": "$$.State.EnteredTime"
                },
                "item_id": {
                  "S.$": "$.processing_context.item.id"
                },
                "agent_id": {
                  "S.$": "$.processing_context.agent.agentId"
                },
                "status": {
                  "S": "ITEM_FAILED"
                },
                "error": {
                  "S.$": "States.JsonToString($.error)"
                },
                "ttl": {
                  "N.$": "States.MathAdd($$.State.EnteredTime, 86400)"
                }
              }
            },
            "ResultPath": "$.error_record_result",
            "Next": "DecideOnErrorHandling"
          },
          "DecideOnErrorHandling": {
            "Type": "Choice",
            "Choices": [
              {
                "Variable": "$${error_handling}",
                "StringEquals": "fail",
                "Next": "FailItemProcessing"
              }
            ],
            "Default": "ContinueAfterItemError"
          },
          "ContinueAfterItemError": {
            "Type": "Pass",
            "Parameters": {
              "item_id.$": "$.processing_context.item.id",
              "agent_id.$": "$.processing_context.agent.agentId",
              "status": "ERROR_CONTINUED",
              "error.$": "$.error",
              "timestamp.$": "$$.State.EnteredTime"
            },
            "End": true
          },
          "FailItemProcessing": {
            "Type": "Fail",
            "Error": "ItemProcessingFailed",
            "Cause": "Failed to process item and error_handling is set to fail"
          }
        }
      },
      "ResultPath": "$.map_results",
      "Next": "AggregateMapResults"
    },
    "AggregateMapResults": {
      "Type": "Pass",
      "Parameters": {
        "execution_id.$": "$$.Execution.Name",
        "total_items.$": "States.ArrayLength($.map_results)",
        "successful_items.$": "States.ArrayLength(States.ArrayPartition($.map_results, 100)[0])",
        "results.$": "$.map_results",
        "timestamp.$": "$$.State.EnteredTime"
      },
      "ResultPath": "$.aggregated_results",
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
        "UpdateExpression": "SET #status = :status, end_time = :end_time, total_processed = :total, results_summary = :summary",
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
          ":total": {
            "N.$": "States.Format('{}', $.aggregated_results.total_items)"
          },
          ":summary": {
            "S.$": "States.JsonToString($.aggregated_results)"
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
        "Subject": "Bedrock Agent Batch Processing Completed",
        "Message.$": "States.Format('Execution {} completed. Processed {} items using map-based orchestration.', $$.Execution.Name, $.aggregated_results.total_items)"
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
        "Subject": "Bedrock Agent Batch Processing Failed",
        "Message.$": "States.Format('Execution {} failed. Error: {}', $$.Execution.Name, States.JsonToString($.error))"
      },
      "ResultPath": "$.notification_result",
      "Next": "ExecutionFailed"
    },
    "ExecutionFailed": {
      "Type": "Fail",
      "Error": "OrchestrationFailed",
      "Cause": "Map-based agent orchestration failed"
    }
  }
}
