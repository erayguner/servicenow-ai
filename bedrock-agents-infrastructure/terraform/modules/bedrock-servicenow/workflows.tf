# Step Functions workflows for ServiceNow automation

# Incident Management Workflow
resource "aws_sfn_state_machine" "incident_workflow" {
  name     = "${local.name_prefix}-incident-workflow"
  role_arn = aws_iam_role.step_functions.arn

  definition = jsonencode({
    Comment = "Automated incident management workflow"
    StartAt = "AnalyzeIncident"
    States = {
      AnalyzeIncident = {
        Type     = "Task"
        Resource = "arn:aws:states:::bedrock:invokeAgent"
        Parameters = {
          AgentId       = try(module.bedrock_agents["incident"].agent_id, "")
          AgentAliasId  = try(module.bedrock_agents["incident"].agent_aliases["production"].agent_alias_id, "")
          SessionId     = ".$$.Execution.Name"
          InputText     = "$.incident.description"
        }
        ResultPath = "$.analysis"
        Next       = "CheckSeverity"
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next        = "HandleError"
            ResultPath  = "$.error"
          }
        ]
      }

      CheckSeverity = {
        Type = "Choice"
        Choices = [
          {
            Variable      = "$.analysis.severity"
            NumericEquals = 1
            Next          = "EscalateImmediately"
          },
          {
            Variable      = "$.analysis.severity"
            NumericEquals = 2
            Next          = "AssignToTeam"
          }
        ]
        Default = "TriageTicket"
      }

      EscalateImmediately = {
        Type     = "Task"
        Resource = aws_lambda_function.servicenow_integration.arn
        Parameters = {
          action = "escalate"
          "incident.$" = "$.incident"
          "analysis.$" = "$.analysis"
        }
        ResultPath = "$.escalation"
        Next       = "NotifyManagement"
      }

      NotifyManagement = {
        Type     = "Task"
        Resource = "arn:aws:states:::sns:publish"
        Parameters = {
          TopicArn = aws_sns_topic.servicenow_notifications.arn
          Subject  = "Critical Incident Escalation"
          "Message.$" = "States.Format('Critical incident {} has been escalated. Severity: {}', $.incident.number, $.analysis.severity)"
        }
        Next = "UpdateState"
      }

      AssignToTeam = {
        Type     = "Task"
        Resource = aws_lambda_function.servicenow_integration.arn
        Parameters = {
          action = "assign"
          "incident.$" = "$.incident"
          "analysis.$" = "$.analysis"
        }
        ResultPath = "$.assignment"
        Next       = "StartSLAMonitor"
      }

      TriageTicket = {
        Type     = "Task"
        Resource = "arn:aws:states:::bedrock:invokeAgent"
        Parameters = {
          AgentId      = try(module.bedrock_agents["triage"].agent_id, "")
          AgentAliasId = try(module.bedrock_agents["triage"].agent_aliases["production"].agent_alias_id, "")
          SessionId    = ".$$.Execution.Name"
          "InputText.$" = "States.Format('Triage this incident: {}', $.incident.description)"
        }
        ResultPath = "$.triage"
        Next       = "CheckAutoAssignment"
      }

      CheckAutoAssignment = {
        Type = "Choice"
        Choices = [
          {
            Variable = "$.triage.confidence"
            NumericGreaterThanEquals = var.auto_assignment_confidence_threshold
            Next     = "AutoAssign"
          }
        ]
        Default = "ManualReview"
      }

      AutoAssign = {
        Type     = "Task"
        Resource = aws_lambda_function.servicenow_integration.arn
        Parameters = {
          action        = "auto_assign"
          "incident.$"  = "$.incident"
          "triage.$"    = "$.triage"
        }
        ResultPath = "$.assignment"
        Next       = "StartSLAMonitor"
      }

      ManualReview = {
        Type = "Pass"
        Result = {
          status = "pending_manual_review"
        }
        ResultPath = "$.review"
        Next       = "UpdateState"
      }

      StartSLAMonitor = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke.waitForTaskToken"
        Parameters = {
          FunctionName = aws_lambda_function.servicenow_integration.arn
          Payload = {
            action          = "start_sla_monitor"
            "incident.$"    = "$.incident"
            "taskToken.$"   = "$$.Task.Token"
            timeout_minutes = var.incident_escalation_timeout_minutes
          }
        }
        ResultPath = "$.sla"
        TimeoutSeconds = var.incident_escalation_timeout_minutes * 60
        Catch = [
          {
            ErrorEquals = ["States.Timeout"]
            Next        = "SLABreachWarning"
            ResultPath  = "$.timeout"
          }
        ]
        Next = "UpdateState"
      }

      SLABreachWarning = {
        Type     = "Task"
        Resource = "arn:aws:states:::sns:publish"
        Parameters = {
          TopicArn = aws_sns_topic.servicenow_notifications.arn
          Subject  = "SLA Breach Warning"
          "Message.$" = "States.Format('Incident {} is at risk of SLA breach', $.incident.number)"
        }
        Next = "EscalateImmediately"
      }

      UpdateState = {
        Type     = "Task"
        Resource = "arn:aws:states:::dynamodb:putItem"
        Parameters = {
          TableName = aws_dynamodb_table.servicenow_state.name
          Item = {
            ticketId = {
              "S.$" = "$.incident.sys_id"
            }
            timestamp = {
              "N.$" = "$$.State.EnteredTime"
            }
            status = {
              "S.$" = "States.Format('{}', $.incident.state)"
            }
            assignmentGroup = {
              "S.$" = "States.Format('{}', $.assignment.group)"
            }
            data = {
              "S.$" = "States.JsonToString($)"
            }
          }
        }
        ResultPath = "$.stateUpdate"
        Next       = "CheckKnowledgeCapture"
      }

      CheckKnowledgeCapture = {
        Type = "Choice"
        Choices = [
          {
            Variable      = "$.incident.state"
            NumericEquals = 6
            Next          = "CaptureKnowledge"
          }
        ]
        Default = "Success"
      }

      CaptureKnowledge = {
        Type     = "Task"
        Resource = "arn:aws:states:::bedrock:invokeAgent"
        Parameters = {
          AgentId      = try(module.bedrock_agents["knowledge"].agent_id, "")
          AgentAliasId = try(module.bedrock_agents["knowledge"].agent_aliases["production"].agent_alias_id, "")
          SessionId    = ".$$.Execution.Name"
          "InputText.$" = "States.Format('Create knowledge article from resolved incident: {}', States.JsonToString($.incident))"
        }
        ResultPath = "$.knowledge"
        Next       = "Success"
      }

      HandleError = {
        Type     = "Task"
        Resource = "arn:aws:states:::sns:publish"
        Parameters = {
          TopicArn = aws_sns_topic.servicenow_notifications.arn
          Subject  = "Incident Workflow Error"
          "Message.$" = "States.Format('Error in incident workflow: {}', $.error.Cause)"
        }
        Next = "Fail"
      }

      Success = {
        Type = "Succeed"
      }

      Fail = {
        Type = "Fail"
      }
    }
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.step_functions.arn}:*"
    include_execution_data = true
    level                  = var.step_function_log_level
  }

  tracing_configuration {
    enabled = true
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-incident-workflow"
    }
  )

  depends_on = [
    aws_iam_role.step_functions,
    aws_cloudwatch_log_group.step_functions
  ]
}

# Change Management Workflow
resource "aws_sfn_state_machine" "change_workflow" {
  count = var.enable_change_management ? 1 : 0

  name     = "${local.name_prefix}-change-workflow"
  role_arn = aws_iam_role.step_functions.arn

  definition = jsonencode({
    Comment = "Automated change management workflow"
    StartAt = "AnalyzeChange"
    States = {
      AnalyzeChange = {
        Type     = "Task"
        Resource = "arn:aws:states:::bedrock:invokeAgent"
        Parameters = {
          AgentId      = try(module.bedrock_agents["change"].agent_id, "")
          AgentAliasId = try(module.bedrock_agents["change"].agent_aliases["production"].agent_alias_id, "")
          SessionId    = ".$$.Execution.Name"
          "InputText.$" = "States.Format('Analyze this change request: {}', States.JsonToString($.change))"
        }
        ResultPath = "$.analysis"
        Next       = "AssessRisk"
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next        = "NotifyError"
            ResultPath  = "$.error"
          }
        ]
      }

      AssessRisk = {
        Type = "Choice"
        Choices = [
          {
            Variable     = "$.analysis.risk_level"
            StringEquals = "high"
            Next         = "RequireCABApproval"
          },
          {
            Variable     = "$.analysis.risk_level"
            StringEquals = "medium"
            Next         = "RequireManagerApproval"
          }
        ]
        Default = "AutoApprove"
      }

      RequireCABApproval = {
        Type = "Task"
        Resource = "arn:aws:states:::lambda:invoke.waitForTaskToken"
        Parameters = {
          FunctionName = aws_lambda_function.servicenow_integration.arn
          Payload = {
            action        = "request_cab_approval"
            "change.$"    = "$.change"
            "analysis.$"  = "$.analysis"
            "taskToken.$" = "$$.Task.Token"
          }
        }
        ResultPath     = "$.approval"
        TimeoutSeconds = var.change_approval_timeout_minutes * 60
        Catch = [
          {
            ErrorEquals = ["States.Timeout"]
            Next        = "ApprovalTimeout"
            ResultPath  = "$.timeout"
          }
        ]
        Next = "CheckApproval"
      }

      RequireManagerApproval = {
        Type = "Task"
        Resource = "arn:aws:states:::lambda:invoke.waitForTaskToken"
        Parameters = {
          FunctionName = aws_lambda_function.servicenow_integration.arn
          Payload = {
            action        = "request_manager_approval"
            "change.$"    = "$.change"
            "analysis.$"  = "$.analysis"
            "taskToken.$" = "$$.Task.Token"
          }
        }
        ResultPath     = "$.approval"
        TimeoutSeconds = var.change_approval_timeout_minutes * 60
        Catch = [
          {
            ErrorEquals = ["States.Timeout"]
            Next        = "ApprovalTimeout"
            ResultPath  = "$.timeout"
          }
        ]
        Next = "CheckApproval"
      }

      AutoApprove = {
        Type = "Pass"
        Result = {
          status   = "approved"
          approver = "automated"
        }
        ResultPath = "$.approval"
        Next       = "ScheduleChange"
      }

      CheckApproval = {
        Type = "Choice"
        Choices = [
          {
            Variable     = "$.approval.status"
            StringEquals = "approved"
            Next         = "ScheduleChange"
          }
        ]
        Default = "ChangeRejected"
      }

      ScheduleChange = {
        Type     = "Task"
        Resource = aws_lambda_function.servicenow_integration.arn
        Parameters = {
          action       = "schedule_change"
          "change.$"   = "$.change"
          "approval.$" = "$.approval"
        }
        ResultPath = "$.schedule"
        Next       = "UpdateChangeState"
      }

      UpdateChangeState = {
        Type     = "Task"
        Resource = "arn:aws:states:::dynamodb:putItem"
        Parameters = {
          TableName = aws_dynamodb_table.servicenow_state.name
          Item = {
            ticketId = {
              "S.$" = "$.change.sys_id"
            }
            timestamp = {
              "N.$" = "$$.State.EnteredTime"
            }
            status = {
              "S.$" = "$.approval.status"
            }
            assignmentGroup = {
              "S.$" = "$.change.assignment_group"
            }
            data = {
              "S.$" = "States.JsonToString($)"
            }
          }
        }
        Next = "Success"
      }

      ApprovalTimeout = {
        Type     = "Task"
        Resource = "arn:aws:states:::sns:publish"
        Parameters = {
          TopicArn = aws_sns_topic.servicenow_notifications.arn
          Subject  = "Change Approval Timeout"
          "Message.$" = "States.Format('Change {} approval timed out', $.change.number)"
        }
        Next = "ChangeRejected"
      }

      ChangeRejected = {
        Type     = "Task"
        Resource = aws_lambda_function.servicenow_integration.arn
        Parameters = {
          action     = "reject_change"
          "change.$" = "$.change"
          "reason.$" = "States.Format('Rejected: {}', $.approval.reason)"
        }
        Next = "Fail"
      }

      NotifyError = {
        Type     = "Task"
        Resource = "arn:aws:states:::sns:publish"
        Parameters = {
          TopicArn = aws_sns_topic.servicenow_notifications.arn
          Subject  = "Change Workflow Error"
          "Message.$" = "States.Format('Error in change workflow: {}', $.error.Cause)"
        }
        Next = "Fail"
      }

      Success = {
        Type = "Succeed"
      }

      Fail = {
        Type = "Fail"
      }
    }
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.step_functions.arn}:*"
    include_execution_data = true
    level                  = var.step_function_log_level
  }

  tracing_configuration {
    enabled = true
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-change-workflow"
    }
  )

  depends_on = [
    aws_iam_role.step_functions,
    aws_cloudwatch_log_group.step_functions
  ]
}
