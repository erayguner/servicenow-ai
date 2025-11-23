# Bedrock Agents Infrastructure

Production-ready AWS Bedrock Agents infrastructure for autonomous multi-agent systems using Terraform and AWS Lambda.

## Overview

This infrastructure provides a comprehensive foundation for deploying intelligent, autonomous agents using Amazon Bedrock. The system is designed for:

- **Multi-agent orchestration** - Coordinated agent workflows with Step Functions
- **Knowledge base integration** - RAG (Retrieval-Augmented Generation) with Vector Store
- **Autonomous action execution** - Lambda-based action groups for external integrations
- **Enterprise-grade scalability** - Auto-scaling, monitoring, and cost optimization
- **Security-first design** - IAM roles, encryption, and compliance built-in

## Key Features

### Agent Types

- **Specialist Agents** (Core Agents) - Domain-specific task executors
- **Orchestration Agents** - Multi-agent coordination and workflow management
- **SPARC Agents** - Specification, Pseudocode, Architecture, Refinement, Completion
- **Coordinator Agents** - Consensus and distributed coordination
- **Specialized Agents** - Custom task-specific implementations
- **Template Agents** - Reusable agent blueprints

### Infrastructure Components

- **Amazon Bedrock** - Managed generative AI service with Claude, Mistral, and other models
- **AWS Lambda** - Serverless compute for action groups
- **AWS Step Functions** - Workflow orchestration and multi-agent coordination
- **Amazon OpenSearch** - Vector database for knowledge base
- **AWS RDS** - PostgreSQL for agent state and metadata
- **AWS DynamoDB** - NoSQL database for conversation history
- **AWS S3** - Document storage and artifact management
- **Amazon CloudWatch** - Comprehensive monitoring and logging
- **AWS KMS** - Encryption key management
- **AWS Secrets Manager** - Secure credential storage

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Client Application                       │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│              API Gateway / Lambda Entrypoint                │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│            Step Functions State Machine                      │
│  (Agent Orchestration & Workflow Coordination)              │
└────────────────┬────────────────────────────────────────────┘
                 │
        ┌────────┴──────────┬─────────────┐
        ▼                   ▼             ▼
┌──────────────────┐  ┌──────────────┐  ┌──────────────────┐
│  Bedrock Agent 1 │  │ Bedrock Agent│  │ Bedrock Agent N  │
│  (Specialist)    │  │ 2 (Orchestr) │  │ (Custom)         │
└────────┬─────────┘  └──────┬───────┘  └────────┬─────────┘
         │                   │                   │
    ┌────┴───────┬───────────┴──────────┬────────┴───┐
    ▼            ▼                      ▼            ▼
 ┌──────┐  ┌──────────────┐  ┌───────────────┐  ┌──────────┐
 │ Knwl │  │   Lambda     │  │  CloudWatch   │  │  RDS/    │
 │ Base │  │  Action Grps │  │  Monitoring   │  │ DynamoDB │
 └──────┘  └──────────────┘  └───────────────┘  └──────────┘
```

## Quick Start

### Prerequisites

- AWS Account with appropriate permissions
- Terraform >= 1.11.0
- AWS CLI v2 configured
- Python 3.9+ (for agent code)
- Node.js 18+ (for orchestration scripts)

### 1. Clone and Navigate

```bash
cd bedrock-agents-infrastructure
```

### 2. Initialize Terraform

```bash
cd terraform
terraform init
```

### 3. Configure Environment

```bash
# Copy and edit environment variables
cp .env.example .env.dev
# Edit with your AWS account ID, region, etc.
```

### 4. Deploy Infrastructure

```bash
# Dev environment
terraform apply -var-file="environments/dev.tfvars"

# Production environment
terraform apply -var-file="environments/prod.tfvars"
```

### 5. Deploy Agents

```bash
cd ../agents
python deploy.py --environment dev
```

## Directory Structure

```
bedrock-agents-infrastructure/
├── docs/
│   ├── README.md                    # This file
│   ├── DEPLOYMENT.md                # Deployment guide
│   ├── AGENTS.md                    # Agent documentation
│   ├── ORCHESTRATION.md             # Orchestration patterns
│   ├── API.md                       # API reference
│   ├── COST.md                      # Cost analysis
│   ├── MIGRATION.md                 # Migration guide
│   └── examples/
│       ├── simple-agent.py          # Basic agent invocation
│       ├── multi-agent-coordination.py
│       ├── knowledge-base-query.py
│       └── custom-action-group.ts
├── terraform/
│   ├── main.tf                      # Root configuration
│   ├── variables.tf                 # Input variables
│   ├── outputs.tf                   # Output values
│   ├── modules/
│   │   ├── bedrock-agent/           # Agent creation module
│   │   ├── bedrock-action-group/    # Action group module
│   │   ├── bedrock-knowledge-base/  # Knowledge base module
│   │   └── bedrock-orchestration/   # Step Functions module
│   └── environments/
│       ├── dev.tfvars               # Dev configuration
│       ├── staging.tfvars           # Staging configuration
│       └── prod.tfvars              # Production configuration
├── agents/
│   ├── core-agents/                 # Specialist agents
│   ├── orchestration/               # Orchestration agents
│   ├── sparc-agents/                # SPARC methodology agents
│   ├── specialized/                 # Custom agents
│   ├── coordinators/                # Coordinator agents
│   └── agent-templates/             # Reusable templates
├── scripts/
│   ├── deploy.py                    # Deployment script
│   ├── monitoring/
│   │   ├── dashboard.py             # CloudWatch dashboard
│   │   └── alerts.py                # Alert configuration
│   └── utilities/
│       ├── knowledge-base-loader.py
│       └── agent-tester.py
└── .env.example                     # Environment template

```

## Environments

### Development

- **Purpose**: Feature development and testing
- **Cost**: ~$100-200/month
- **Features**: Single-AZ, basic monitoring, limited concurrency
- **Auto-cleanup**: Scheduled deletion to minimize costs

### Staging

- **Purpose**: Pre-production validation
- **Cost**: ~$400-600/month
- **Features**: Multi-AZ, enhanced monitoring, medium concurrency

### Production

- **Purpose**: Customer-facing workloads
- **Cost**: ~$1,500-3,000+/month (scales with usage)
- **Features**: Multi-AZ HA, comprehensive monitoring, auto-scaling, 99.99% SLA

## Core Concepts

### Agents

An agent is an autonomous entity that:
- Receives instructions and context
- Reason about available tools/action groups
- Decides on actions to take
- Executes actions via Lambda function calls
- Learns from outcomes and adjusts behavior

### Action Groups

Lambda functions that agents can invoke:
- **REST APIs** - Integration with external services
- **Database Operations** - Direct data manipulation
- **System Tasks** - Infrastructure management
- **Custom Functions** - Domain-specific logic

### Knowledge Bases

Vector databases storing searchable information:
- **Document storage** - PDFs, text files, structured data
- **Semantic search** - Find relevant information by meaning
- **RAG Integration** - Provide context to agents for accurate responses

### Orchestration

Step Functions workflows coordinating multiple agents:
- **Sequential flows** - Agent A then Agent B
- **Parallel execution** - Multiple agents simultaneously
- **Conditional routing** - Branch based on conditions
- **Error handling** - Retry and fallback mechanisms

## Security

### Default-Deny Approach

- No permissions granted by default
- Explicit IAM policies for each component
- Regular security audits

### Encryption

- **At Rest**: AWS KMS-managed keys
- **In Transit**: TLS 1.2+ for all connections
- **Secrets**: AWS Secrets Manager for sensitive data

### Compliance

- CloudTrail logging for audit trail
- VPC endpoints for private connectivity
- No internet-facing databases

## Monitoring & Observability

- **CloudWatch Metrics** - Agent performance, latency, errors
- **CloudWatch Logs** - Detailed execution logs
- **X-Ray Tracing** - Distributed tracing across services
- **Custom Dashboards** - Real-time monitoring
- **Alarms** - Automatic alerting on anomalies

## Cost Management

- **Reserved Capacity** - 30-40% savings for stable workloads
- **Spot Instances** - 70% savings for non-critical tasks
- **Auto-scaling** - Pay only for what you use
- **Cost tracking** - Detailed analysis by agent and operation

See [COST.md](COST.md) for detailed cost analysis.

## Getting Help

- **Deployment Issues**: See [DEPLOYMENT.md](DEPLOYMENT.md)
- **Agent Development**: See [AGENTS.md](AGENTS.md)
- **Orchestration Patterns**: See [ORCHESTRATION.md](ORCHESTRATION.md)
- **API Integration**: See [API.md](API.md)
- **Cost Questions**: See [COST.md](COST.md)
- **Migration from claude-flow**: See [MIGRATION.md](MIGRATION.md)

## Best Practices

1. **Test in Dev First** - Always test agents in development environment
2. **Version Control Agents** - Track agent code and configurations
3. **Monitor Costs** - Set up CloudWatch alarms for cost anomalies
4. **Document Action Groups** - Clear documentation for Lambda functions
5. **Regular Backups** - Backup knowledge bases and agent configurations
6. **Security Scanning** - Run regular security audits
7. **Load Testing** - Test agent performance before production
8. **Incident Response** - Have playbooks for common issues

## Next Steps

1. Read [DEPLOYMENT.md](DEPLOYMENT.md) for step-by-step setup
2. Explore [examples/](examples/) for code samples
3. Review [AGENTS.md](AGENTS.md) to understand agent types
4. Check [API.md](API.md) for integration guidelines
5. Plan for cost with [COST.md](COST.md)

## Support & Contributions

For issues, feature requests, or contributions, please refer to the main project's CONTRIBUTING.md.

---

**Version**: 1.0.0
**Last Updated**: 2025-01-17
**Maintainers**: AI Infrastructure Team
