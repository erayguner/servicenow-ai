# Agent Templates and Instruction Library

This directory contains reusable templates and instruction patterns for creating
AWS Bedrock agents.

## Contents

### 1. `base-agent-template.yaml`

A complete agent configuration template with placeholders for all required
fields. Use this as a starting point when creating new agents.

**Usage:**

```bash
# Copy the template
cp base-agent-template.yaml ../custom-agents/my-new-agent.yaml

# Replace placeholders with actual values
# ${AGENT_NAME} -> my-new-agent
# ${AGENT_DESCRIPTION} -> Description of the agent
# ${FOUNDATION_MODEL} -> anthropic.claude-3-5-sonnet-20241022-v2:0
# etc.
```

### 2. `instruction-templates.md`

A library of reusable instruction templates covering:

- Code Quality Standards
- Testing Best Practices
- Security Guidelines
- Documentation Standards
- Error Handling Patterns
- Performance Optimization
- AWS Best Practices

**Usage:** Mix and match instruction templates based on your agent's role. Copy
relevant sections into your agent's `instruction` field.

## Quick Start Guide

### Creating a New Agent

1. **Start with the base template:**

   ```bash
   cp base-agent-template.yaml ../my-category/my-agent.yaml
   ```

2. **Define the agent metadata:**

   - Set `agentName`
   - Write a clear `description`
   - Choose the appropriate `foundationModel`

3. **Craft comprehensive instructions:**

   - Start with relevant templates from `instruction-templates.md`
   - Add agent-specific guidance
   - Include examples and use cases
   - Define success criteria

4. **Configure action groups:**

   - Identify what actions the agent needs to perform
   - Reference Lambda functions that implement those actions
   - Link to API schema definitions

5. **Attach knowledge bases:**

   - Identify relevant knowledge domains
   - Reference knowledge base IDs
   - Enable/disable as needed

6. **Set up guardrails:**

   - Reference appropriate guardrail configuration
   - Define content filters and topic restrictions

7. **Add tags:**
   - Include required tags (Environment, Project, ManagedBy)
   - Add custom tags for organization

### Example: Creating a DevOps Agent

```yaml
---
agentName: devops-engineer-agent
agentResourceRoleArn: arn:aws:iam::${AWS_ACCOUNT_ID}:role/BedrockAgentRole

description: |
  DevOps automation agent specializing in CI/CD pipelines,
  infrastructure management, and deployment automation.

foundationModel: anthropic.claude-3-5-sonnet-20241022-v2:0

instruction: |
  You are a DevOps engineering specialist.

  # [Copy Code Quality Template]
  # [Copy AWS Best Practices Template]
  # [Copy Security Template]

  ## DevOps-Specific Responsibilities
  - Design and maintain CI/CD pipelines
  - Automate infrastructure provisioning
  - Monitor system health and performance
  - Implement deployment strategies
  - Manage containerized applications

  ## Tools and Technologies
  - CI/CD: GitHub Actions, Jenkins, GitLab CI
  - IaC: Terraform, CloudFormation, CDK
  - Containers: Docker, Kubernetes, ECS
  - Monitoring: CloudWatch, Prometheus, Grafana

  [Continue with specific guidelines...]

idleSessionTTLInSeconds: 600

actionGroups:
  - actionGroupName: cicd-tools
    description: CI/CD pipeline operations
    actionGroupExecutor:
      lambda: arn:aws:lambda:${AWS_REGION}:${AWS_ACCOUNT_ID}:function:CICDToolsFunction
    apiSchema:
      s3:
        s3BucketName: ${BEDROCK_BUCKET}
        s3ObjectKey: schemas/cicd-tools-schema.json

knowledgeBases:
  - knowledgeBaseId: ${DEVOPS_KB_ID}
    description: DevOps best practices and runbooks
    knowledgeBaseState: ENABLED

guardrailConfiguration:
  guardrailIdentifier: ${GUARDRAIL_ID}
  guardrailVersion: '1'

tags:
  Environment: ${ENVIRONMENT}
  Agent: devops-engineer
  Specialty: devops
  ManagedBy: terraform
  Project: servicenow-ai
```

## Best Practices for Agent Instructions

### 1. Be Specific and Clear

- Use precise language
- Avoid ambiguity
- Provide concrete examples
- Define success criteria

### 2. Structure Instructions Logically

```markdown
## Section 1: Overview and Responsibilities

## Section 2: Core Competencies

## Section 3: Standards and Best Practices

## Section 4: Specific Guidelines

## Section 5: Error Handling

## Section 6: Output Format
```

### 3. Include Examples

Show, don't just tell. Include code examples, sample outputs, and use cases.

### 4. Define Quality Criteria

Be explicit about what "good" looks like:

- Code quality standards
- Test coverage requirements
- Documentation expectations
- Performance benchmarks

### 5. Provide Context

Help the agent understand:

- Why these practices matter
- When to apply different approaches
- Trade-offs between options

### 6. Keep Instructions Updated

- Review and update regularly
- Incorporate lessons learned
- Remove outdated guidance
- Add new patterns as they emerge

## Instruction Template Categories

### Development Agents

Recommended templates:

- Code Quality
- Testing
- Documentation
- Error Handling
- Performance

### Security Agents

Recommended templates:

- Security
- Code Quality
- Documentation
- AWS Best Practices

### Architecture/Planning Agents

Recommended templates:

- Code Quality
- Documentation
- AWS Best Practices
- Performance

### Coordinator Agents

Recommended templates:

- Documentation
- Error Handling
- (Custom coordination patterns)

## Variable Placeholders

Use these placeholders in templates for dynamic configuration:

```yaml
${AGENT_NAME}              # Name of the agent
${AWS_ACCOUNT_ID}          # AWS account ID
${AWS_REGION}              # AWS region
${ENVIRONMENT}             # Environment (dev, staging, prod)
${FOUNDATION_MODEL}        # Claude model ID
${BEDROCK_BUCKET}          # S3 bucket for schemas
${GUARDRAIL_ID}            # Guardrail identifier
${IDLE_SESSION_TTL}        # Session timeout in seconds
${*_KB_ID}                 # Knowledge base IDs
```

These will be replaced during Terraform deployment.

## Testing Your Agent Configuration

1. **Validate YAML syntax:**

   ```bash
   yamllint my-agent.yaml
   ```

2. **Check for required fields:**

   - agentName
   - agentResourceRoleArn
   - description
   - foundationModel
   - instruction

3. **Review instructions:**

   - Clear and comprehensive?
   - Includes examples?
   - Defines success criteria?
   - No contradictions?

4. **Verify references:**
   - Action group Lambda functions exist?
   - API schemas are defined?
   - Knowledge bases are created?
   - IAM roles have correct permissions?

## Integration with Terraform

These YAML configurations are consumed by Terraform modules:

```hcl
module "bedrock_agent" {
  source = "./modules/bedrock-agent"

  agent_config_file = "${path.module}/agents/core-agents/coder.yaml"

  # Variables will be interpolated
  variables = {
    AWS_ACCOUNT_ID = data.aws_caller_identity.current.account_id
    AWS_REGION     = var.aws_region
    ENVIRONMENT    = var.environment
    # ... other variables
  }
}
```

## Contributing

When adding new templates or examples:

1. Follow existing structure and naming conventions
2. Include comprehensive documentation
3. Provide usage examples
4. Test with actual agent deployments
5. Update this README

## Support and Resources

- [AWS Bedrock Agents Documentation](https://docs.aws.amazon.com/bedrock/latest/userguide/agents.html)
- [Claude Model Documentation](https://docs.anthropic.com/claude/docs)
- [Agent Best Practices](https://docs.aws.amazon.com/bedrock/latest/userguide/agents-best-practices.html)
- [Prompt Engineering Guide](https://docs.anthropic.com/claude/docs/prompt-engineering)

## License

These templates are part of the ServiceNow AI project and follow the same
license terms.
