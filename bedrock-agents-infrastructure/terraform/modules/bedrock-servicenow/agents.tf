# Bedrock Agents for ServiceNow Integration
# Creates specialized AI agents for different ServiceNow functions

module "bedrock_agents" {
  source   = "../bedrock-agent"
  for_each = local.enabled_agents

  agent_name       = each.value.name
  description      = each.value.description
  model_id         = var.agent_model_id
  foundation_model = var.agent_model_id
  instruction      = each.value.instruction

  idle_session_ttl_in_seconds = var.agent_idle_session_ttl
  prepare_agent               = true

  # Associate with knowledge bases if provided
  knowledge_bases = length(var.knowledge_base_ids) > 0 ? [
    for kb_id in var.knowledge_base_ids : {
      knowledge_base_id = kb_id
      description       = "ServiceNow knowledge base for ${each.key} agent"
    }
  ] : []

  # Action groups for each agent type
  action_groups = each.key == "incident" ? [
    {
      action_group_name = "incident-actions"
      description       = "Actions for incident management"
      lambda_arn        = aws_lambda_function.servicenow_integration.arn
      api_schema = jsonencode({
        openapi = "3.0.0"
        info = {
          title   = "Incident Management Actions"
          version = "1.0.0"
        }
        paths = {
          "/incident/create" = {
            post = {
              summary     = "Create a new incident"
              description = "Creates a new incident in ServiceNow"
              operationId = "createIncident"
              requestBody = {
                required = true
                content = {
                  "application/json" = {
                    schema = {
                      type = "object"
                      properties = {
                        short_description = { type = "string" }
                        description       = { type = "string" }
                        priority          = { type = "integer" }
                        urgency           = { type = "integer" }
                        impact            = { type = "integer" }
                        category          = { type = "string" }
                        assignment_group  = { type = "string" }
                      }
                      required = ["short_description"]
                    }
                  }
                }
              }
              responses = {
                "200" = {
                  description = "Incident created successfully"
                  content = {
                    "application/json" = {
                      schema = {
                        type = "object"
                        properties = {
                          incident_id     = { type = "string" }
                          incident_number = { type = "string" }
                          status          = { type = "string" }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
          "/incident/update" = {
            post = {
              summary     = "Update an existing incident"
              description = "Updates an incident in ServiceNow"
              operationId = "updateIncident"
              requestBody = {
                required = true
                content = {
                  "application/json" = {
                    schema = {
                      type = "object"
                      properties = {
                        incident_id      = { type = "string" }
                        work_notes       = { type = "string" }
                        state            = { type = "integer" }
                        assignment_group = { type = "string" }
                        assigned_to      = { type = "string" }
                      }
                      required = ["incident_id"]
                    }
                  }
                }
              }
              responses = {
                "200" = {
                  description = "Incident updated successfully"
                }
              }
            }
          }
          "/incident/resolve" = {
            post = {
              summary     = "Resolve an incident"
              description = "Marks an incident as resolved"
              operationId = "resolveIncident"
              requestBody = {
                required = true
                content = {
                  "application/json" = {
                    schema = {
                      type = "object"
                      properties = {
                        incident_id      = { type = "string" }
                        resolution_notes = { type = "string" }
                        close_code       = { type = "string" }
                      }
                      required = ["incident_id", "resolution_notes"]
                    }
                  }
                }
              }
              responses = {
                "200" = {
                  description = "Incident resolved successfully"
                }
              }
            }
          }
        }
      })
      enabled = true
    }
    ] : each.key == "triage" ? [
    {
      action_group_name = "triage-actions"
      description       = "Actions for ticket triage"
      lambda_arn        = aws_lambda_function.servicenow_integration.arn
      api_schema = jsonencode({
        openapi = "3.0.0"
        info = {
          title   = "Ticket Triage Actions"
          version = "1.0.0"
        }
        paths = {
          "/triage/analyze" = {
            post = {
              summary     = "Analyze ticket for triage"
              description = "Analyzes ticket content to determine routing"
              operationId = "analyzeTicket"
              requestBody = {
                required = true
                content = {
                  "application/json" = {
                    schema = {
                      type = "object"
                      properties = {
                        ticket_id   = { type = "string" }
                        description = { type = "string" }
                        requestor   = { type = "string" }
                      }
                      required = ["ticket_id", "description"]
                    }
                  }
                }
              }
              responses = {
                "200" = {
                  description = "Triage analysis complete"
                  content = {
                    "application/json" = {
                      schema = {
                        type = "object"
                        properties = {
                          recommended_group = { type = "string" }
                          priority          = { type = "integer" }
                          category          = { type = "string" }
                          confidence_score  = { type = "number" }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
          "/triage/assign" = {
            post = {
              summary     = "Assign ticket to group"
              description = "Assigns ticket based on triage analysis"
              operationId = "assignTicket"
              requestBody = {
                required = true
                content = {
                  "application/json" = {
                    schema = {
                      type = "object"
                      properties = {
                        ticket_id        = { type = "string" }
                        assignment_group = { type = "string" }
                        assigned_to      = { type = "string" }
                      }
                      required = ["ticket_id", "assignment_group"]
                    }
                  }
                }
              }
              responses = {
                "200" = {
                  description = "Ticket assigned successfully"
                }
              }
            }
          }
        }
      })
      enabled = true
    }
    ] : each.key == "knowledge" ? [
    {
      action_group_name = "knowledge-actions"
      description       = "Actions for knowledge base management"
      lambda_arn        = aws_lambda_function.servicenow_integration.arn
      api_schema = jsonencode({
        openapi = "3.0.0"
        info = {
          title   = "Knowledge Base Actions"
          version = "1.0.0"
        }
        paths = {
          "/knowledge/search" = {
            post = {
              summary     = "Search knowledge base"
              description = "Searches for relevant knowledge articles"
              operationId = "searchKnowledge"
              requestBody = {
                required = true
                content = {
                  "application/json" = {
                    schema = {
                      type = "object"
                      properties = {
                        query    = { type = "string" }
                        category = { type = "string" }
                        limit    = { type = "integer" }
                      }
                      required = ["query"]
                    }
                  }
                }
              }
              responses = {
                "200" = {
                  description = "Search results"
                  content = {
                    "application/json" = {
                      schema = {
                        type = "object"
                        properties = {
                          articles = {
                            type = "array"
                            items = {
                              type = "object"
                              properties = {
                                article_id = { type = "string" }
                                title      = { type = "string" }
                                content    = { type = "string" }
                                relevance  = { type = "number" }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
          "/knowledge/create" = {
            post = {
              summary     = "Create knowledge article"
              description = "Creates a new knowledge article"
              operationId = "createKnowledgeArticle"
              requestBody = {
                required = true
                content = {
                  "application/json" = {
                    schema = {
                      type = "object"
                      properties = {
                        title       = { type = "string" }
                        content     = { type = "string" }
                        category    = { type = "string" }
                        subcategory = { type = "string" }
                        keywords    = { type = "array", items = { type = "string" } }
                      }
                      required = ["title", "content"]
                    }
                  }
                }
              }
              responses = {
                "200" = {
                  description = "Article created successfully"
                }
              }
            }
          }
        }
      })
      enabled = true
    }
  ] : []

  # Agent aliases for versioning
  agent_aliases = {
    production = {
      description = "Production alias for ${each.value.name}"
      tags = {
        AliasType = "production"
      }
    }
    staging = {
      description = "Staging alias for ${each.value.name}"
      tags = {
        AliasType = "staging"
      }
    }
  }

  kms_key_id                  = var.kms_key_id
  customer_encryption_key_arn = var.kms_key_id

  tags = merge(
    local.common_tags,
    {
      AgentType = each.key
      Purpose   = "ServiceNow-${each.key}"
    }
  )

  depends_on = [
    aws_lambda_function.servicenow_integration,
    aws_iam_role.lambda_execution
  ]
}

# Outputs for agent information
output "agent_details" {
  description = "Details of all created Bedrock agents"
  value = {
    for key, agent in module.bedrock_agents : key => {
      agent_id      = agent.agent_id
      agent_arn     = agent.agent_arn
      agent_name    = agent.agent_name
      agent_aliases = agent.agent_aliases
    }
  }
}
