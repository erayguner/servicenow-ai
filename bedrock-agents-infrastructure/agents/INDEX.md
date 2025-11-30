# Bedrock Agents Configuration Index

This directory contains comprehensive agent configurations, templates, and
orchestration workflows for AWS Bedrock Agents.

## Directory Structure

```
bedrock-agents-infrastructure/agents/
│
├── core-agents/                      # Core development agents
│   ├── coder.yaml                    # Code generation agent
│   ├── reviewer.yaml                 # Code review agent
│   ├── tester.yaml                   # Testing agent
│   └── planner.yaml                  # Planning and architecture agent
│
├── sparc-agents/                     # SPARC methodology agents
│   ├── specification.yaml            # Requirements and specification phase
│   ├── pseudocode.yaml               # Algorithm design phase
│   ├── architecture.yaml             # System architecture phase
│   └── refinement.yaml               # TDD implementation phase
│
├── specialized/                      # Specialized domain agents
│   ├── backend-dev.yaml              # Backend development specialist
│   ├── frontend-dev.yaml             # Frontend development specialist
│   ├── ml-developer.yaml             # ML/AI development specialist
│   └── security-auditor.yaml         # Security auditing specialist
│
├── coordinators/                     # Multi-agent coordination
│   ├── hierarchical-coordinator.yaml # Top-down coordination
│   ├── mesh-coordinator.yaml         # Peer-to-peer coordination
│   └── adaptive-coordinator.yaml     # Dynamic strategy selection
│
├── servicenow/                       # ServiceNow ITSM agents
│   ├── incident-manager.yaml         # Incident management and SLA tracking
│   ├── ticket-analyzer.yaml          # Intelligent ticket analysis and routing
│   ├── change-request-agent.yaml     # Change management and risk assessment
│   ├── problem-resolver.yaml         # Root cause analysis and problem management
│   ├── knowledge-curator.yaml        # Knowledge base management and curation
│   └── service-catalog-assistant.yaml # Service catalog and request fulfillment
│
├── agent-templates/                  # Reusable templates
│   ├── base-agent-template.yaml      # Agent configuration template
│   ├── instruction-templates.md      # Reusable instruction library
│   └── README.md                     # Template usage guide
│
├── orchestration/                    # Step Functions workflows
│   ├── sparc-workflow.json           # SPARC methodology workflow
│   ├── full-stack-development-workflow.json  # Full-stack dev workflow
│   ├── adaptive-coordination-workflow.json   # Adaptive coordination
│   └── README.md                     # Workflow documentation
│
└── INDEX.md                          # This file
```

## Quick Reference

### Core Development Agents (4)

| Agent        | Purpose                            | Foundation Model  |
| ------------ | ---------------------------------- | ----------------- |
| **coder**    | Code generation and implementation | Claude 3.5 Sonnet |
| **reviewer** | Code quality analysis and review   | Claude 3.5 Sonnet |
| **tester**   | Test creation and validation       | Claude 3.5 Sonnet |
| **planner**  | Project planning and architecture  | Claude 3.5 Sonnet |

**Use Cases:** General software development, code reviews, testing, project
planning

---

### SPARC Methodology Agents (4)

| Agent             | SPARC Phase       | Focus                                      |
| ----------------- | ----------------- | ------------------------------------------ |
| **specification** | S - Specification | Requirements gathering and specification   |
| **pseudocode**    | P - Pseudocode    | Algorithm design in structured pseudocode  |
| **architecture**  | A - Architecture  | System design and component architecture   |
| **refinement**    | R - Refinement    | TDD implementation with Red-Green-Refactor |

**Use Cases:** Systematic software development, TDD projects, quality-critical
implementations

**Orchestration:** See `orchestration/sparc-workflow.json` for complete
automated workflow

---

### Specialized Development Agents (4)

| Agent                | Specialty               | Key Features                                |
| -------------------- | ----------------------- | ------------------------------------------- |
| **backend-dev**      | Backend/API Development | REST/GraphQL APIs, databases, microservices |
| **frontend-dev**     | Frontend/UI Development | React, Vue, TypeScript, accessibility       |
| **ml-developer**     | ML/AI Development       | SageMaker, Bedrock, RAG, model deployment   |
| **security-auditor** | Security & Compliance   | OWASP, vulnerability scanning, compliance   |

**Use Cases:** Specialized domain tasks, full-stack development, ML-powered
applications

**Orchestration:** See `orchestration/full-stack-development-workflow.json` for
parallel development

---

### Coordination Agents (3)

| Agent                        | Coordination Model         | Best For                                       |
| ---------------------------- | -------------------------- | ---------------------------------------------- |
| **hierarchical-coordinator** | Top-down delegation        | Complex projects, clear roles, quality gates   |
| **mesh-coordinator**         | Peer-to-peer collaboration | Innovation, self-organizing teams, experts     |
| **adaptive-coordinator**     | Dynamic strategy selection | Variable complexity, learning optimal patterns |

**Use Cases:** Multi-agent workflows, complex orchestration, adaptive systems

**Orchestration:** See `orchestration/adaptive-coordination-workflow.json` for
intelligent coordination

---

### ServiceNow ITSM Agents (6)

| Agent                         | ITIL Process         | Key Capabilities                                                                       |
| ----------------------------- | -------------------- | -------------------------------------------------------------------------------------- |
| **incident-manager**          | Incident Management  | Create/update/resolve incidents, SLA monitoring, auto-assignment, escalation workflows |
| **ticket-analyzer**           | Service Desk         | NLP-powered categorization, sentiment analysis, urgency detection, KB matching         |
| **change-request-agent**      | Change Management    | Risk assessment, approval workflows, impact analysis, rollback planning                |
| **problem-resolver**          | Problem Management   | Root cause analysis, incident correlation, KEDB management, workaround documentation   |
| **knowledge-curator**         | Knowledge Management | Auto-create KB articles, update existing content, tag/categorize, identify gaps        |
| **service-catalog-assistant** | Request Fulfillment  | Catalog navigation, auto-fulfillment, request tracking, approval orchestration         |

**Use Cases:** IT Service Management, ServiceNow automation, ITIL process
optimization, helpdesk operations

**Integration:** All agents use `servicenow-integration` action group for REST
API operations

**Features:**

- ITIL best practices built-in
- Intelligent automation and routing
- SLA monitoring and compliance
- Knowledge base integration
- Multi-stage approval workflows
- Comprehensive audit trails

---

## Agent Configuration Format

Each agent configuration includes:

```yaml
agentName: agent-name
agentResourceRoleArn: arn:aws:iam::${AWS_ACCOUNT_ID}:role/BedrockAgentRole
description: |
  Agent purpose and responsibilities

foundationModel: anthropic.claude-3-5-sonnet-20241022-v2:0

instruction: |
  Comprehensive agent instructions
  - Core competencies
  - Best practices
  - Quality standards
  - Output format

idleSessionTTLInSeconds: 600

promptOverrideConfiguration:
  promptConfigurations:
    - promptType: PRE_PROCESSING
    - promptType: ORCHESTRATION
    - promptType: POST_PROCESSING

actionGroups:
  - actionGroupName: action-group-name
    description: What this action group does
    actionGroupExecutor:
      lambda: arn:aws:lambda:${AWS_REGION}:${AWS_ACCOUNT_ID}:function:FunctionName
    apiSchema:
      s3:
        s3BucketName: ${BEDROCK_BUCKET}
        s3ObjectKey: schemas/schema-name.json

knowledgeBases:
  - knowledgeBaseId: ${KB_ID}
    description: Knowledge base purpose
    knowledgeBaseState: ENABLED

guardrailConfiguration:
  guardrailIdentifier: ${GUARDRAIL_ID}
  guardrailVersion: '1'

tags:
  Environment: ${ENVIRONMENT}
  Agent: agent-name
  ManagedBy: terraform
  Project: servicenow-ai
```

## Usage Patterns

### Pattern 1: Single Agent Task

```bash
# Invoke a single agent for a specific task
aws bedrock-agent-runtime invoke-agent \
  --agent-id ${CODER_AGENT_ID} \
  --agent-alias-id ${CODER_AGENT_ALIAS_ID} \
  --session-id session-123 \
  --input-text "Implement a REST API endpoint..."
```

### Pattern 2: SPARC Workflow

```bash
# Execute full SPARC methodology via Step Functions
aws stepfunctions start-execution \
  --state-machine-arn arn:aws:states:region:account:stateMachine:sparc-workflow \
  --input '{
    "sessionId": "sparc-session-123",
    "userRequirements": "Build a user authentication system...",
    ...
  }'
```

### Pattern 3: Full-Stack Development

```bash
# Parallel development of backend, frontend, ML
aws stepfunctions start-execution \
  --state-machine-arn arn:aws:states:region:account:stateMachine:full-stack-workflow \
  --input '{
    "sessionId": "fullstack-session-123",
    "projectRequirements": "E-commerce platform with recommendations...",
    ...
  }'
```

### Pattern 4: Adaptive Coordination

```bash
# Intelligent strategy selection and adaptation
aws stepfunctions start-execution \
  --state-machine-arn arn:aws:states:region:account:stateMachine:adaptive-workflow \
  --input '{
    "sessionId": "adaptive-session-123",
    "taskDescription": "Complex distributed system...",
    "teamSize": 8,
    "deadline": "2024-02-01",
    ...
  }'
```

## Creating New Agents

### Step 1: Choose Template

```bash
cp agent-templates/base-agent-template.yaml my-category/my-agent.yaml
```

### Step 2: Customize Configuration

- Set agent name and description
- Choose foundation model (Claude 3.5 Sonnet recommended)
- Define comprehensive instructions
- Configure action groups
- Attach knowledge bases
- Set up guardrails

### Step 3: Add Instructions

Use reusable templates from `agent-templates/instruction-templates.md`:

- Code Quality Template
- Testing Template
- Security Template
- Documentation Template
- Error Handling Template
- Performance Template
- AWS Best Practices Template

### Step 4: Deploy with Terraform

```hcl
module "my_agent" {
  source = "./modules/bedrock-agent"

  agent_config_file = "${path.module}/agents/my-category/my-agent.yaml"

  variables = {
    AWS_ACCOUNT_ID = data.aws_caller_identity.current.account_id
    AWS_REGION     = var.aws_region
    ENVIRONMENT    = var.environment
  }
}
```

## Integration Points

### Action Groups

Define custom actions agents can perform:

- API calls
- Database operations
- File operations
- External service integrations

Each action group requires:

1. Lambda function implementation
2. OpenAPI schema definition
3. IAM permissions

### Knowledge Bases

Provide agents with domain knowledge:

- Code patterns and examples
- Best practices
- API documentation
- Architecture patterns
- Security guidelines

Knowledge bases use:

- S3 for document storage
- Amazon Kendra or OpenSearch for indexing
- Embeddings for semantic search

### Guardrails

Control agent behavior and outputs:

- Content filtering (hate, violence, sexual)
- Topic restrictions
- PII redaction
- Custom word filters

## Cost Optimization

### Model Selection

- **Claude 3.5 Sonnet**: Best for complex reasoning (agents that need deep
  analysis)
- **Claude 3.5 Haiku**: More cost-effective for simpler tasks
- Choose based on task complexity

### Session Management

- Set appropriate `idleSessionTTLInSeconds`
- Reuse sessions when possible
- Clean up inactive sessions

### Knowledge Base Optimization

- Index only necessary documents
- Use appropriate chunking strategies
- Cache frequent queries

## Security Best Practices

### IAM Roles

- Principle of least privilege
- Separate roles per agent
- Enable CloudTrail logging
- Regular permission audits

### Secrets Management

- Use AWS Secrets Manager
- Never hardcode credentials
- Rotate secrets regularly
- Audit secret access

### Data Protection

- Enable encryption at rest
- Use VPC endpoints
- Implement request validation
- Monitor for anomalies

## Monitoring and Observability

### CloudWatch Metrics

- Agent invocation count
- Token usage
- Latency (p50, p95, p99)
- Error rates

### CloudWatch Logs

- Agent inputs/outputs
- Action group executions
- Knowledge base queries
- Error traces

### Custom Dashboards

Create dashboards tracking:

- Agent performance by type
- Cost per agent
- Success/failure rates
- Workflow completion times

## Troubleshooting

### Common Issues

**Agent Not Found**

- Verify agent ID and alias ID
- Check agent is in correct region
- Ensure agent is deployed

**Permission Denied**

- Review IAM role permissions
- Check action group Lambda permissions
- Verify knowledge base access

**Timeout Errors**

- Increase agent timeout settings
- Optimize action group Lambda functions
- Check knowledge base response times

**Quality Issues**

- Review agent instructions
- Add more examples
- Enhance knowledge bases
- Adjust guardrails

## Version History

- **v1.0** - Initial agent configurations
  - 4 core development agents
  - 4 SPARC methodology agents
  - 4 specialized domain agents
  - 3 coordination agents
  - Reusable templates library
  - 3 orchestration workflows

## Contributing

When adding new agents:

1. Follow existing naming conventions
2. Use appropriate foundation models
3. Write comprehensive instructions
4. Include examples and use cases
5. Document action groups and knowledge bases
6. Test thoroughly before deploying
7. Update this index

## Related Documentation

- [Agent Templates Guide](agent-templates/README.md)
- [Instruction Templates Library](agent-templates/instruction-templates.md)
- [Orchestration Workflows](orchestration/README.md)
- [AWS Bedrock Agents Documentation](https://docs.aws.amazon.com/bedrock/latest/userguide/agents.html)
- [Claude Documentation](https://docs.anthropic.com/claude/docs)

## Support

For questions or issues:

1. Review relevant README files
2. Check AWS Bedrock documentation
3. Review CloudWatch logs
4. Open an issue in the project repository

---

**Last Updated:** 2024-11-17 **Total Agents:** 21 agent configurations (15
development + 6 ServiceNow) **Total Workflows:** 3 orchestration workflows
**Total Templates:** 7+ reusable instruction templates
