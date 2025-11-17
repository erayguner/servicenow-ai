# Bedrock Agents Infrastructure - Operational Scripts

This directory contains comprehensive deployment and operational scripts for managing Bedrock agents infrastructure on AWS. All scripts include error handling, logging, dry-run support, and interactive modes where applicable.

## Overview

### Main Scripts

#### 1. **deploy.sh** - Main Deployment Script
Complete deployment orchestration for Bedrock agents infrastructure.

**Features:**
- Environment selection (dev/staging/prod)
- Terraform initialization, planning, and application
- Lambda function deployment and packaging
- Agent configuration upload to S3
- Health checks for deployed resources
- Dry-run mode for safe planning

**Usage:**
```bash
# Deploy to development environment
./deploy.sh -e dev

# Deploy to production with auto-approval
./deploy.sh -e prod --auto-approve

# Dry-run to see what would be deployed
./deploy.sh -e staging --dry-run

# List current resources
./deploy.sh -e dev --list-resources
```

**Options:**
- `-e, --environment ENV` - Target environment (dev/staging/prod)
- `-d, --dry-run` - Show changes without applying
- `-l, --list-resources` - List deployed resources
- `--skip-health-check` - Skip post-deployment health checks
- `--auto-approve` - Auto-approve Terraform changes
- `-h, --help` - Show help message

---

#### 2. **setup-knowledge-base.sh** - Knowledge Base Management
Creates and manages Bedrock knowledge bases with document uploads and embeddings.

**Features:**
- S3 bucket creation with versioning and security
- Document upload with metadata tagging
- Embeddings generation using Titan models
- Data source synchronization
- Chunking configuration support

**Usage:**
```bash
# Create new knowledge base with documents
./setup-knowledge-base.sh -c -n "policies" -d ./docs/policies

# Upload documents to existing knowledge base
./setup-knowledge-base.sh -u -n "policies" -d ./docs/policies-updated

# Sync data sources and generate embeddings
./setup-knowledge-base.sh -s -n "policies"

# Dry-run to preview operations
./setup-knowledge-base.sh -c -n "test-kb" -d ./docs --dry-run
```

**Options:**
- `-e, --environment ENV` - Environment name (default: dev)
- `-n, --name NAME` - Knowledge base name (required)
- `-d, --documents DIR` - Directory with documents to upload
- `-c, --create` - Create new knowledge base
- `-u, --upload` - Upload documents to existing KB
- `-s, --sync-sources` - Sync sources and generate embeddings
- `--dry-run` - Preview without executing
- `-h, --help` - Show help message

---

#### 3. **invoke-agent.sh** - Test Agent Invocation
Interactive CLI for testing Bedrock agents with session management.

**Features:**
- List available agents
- Interactive multi-turn conversations
- Session management and persistence
- Multiple output formats (JSON, text, table)
- Response formatting and history tracking

**Usage:**
```bash
# List available agents
./invoke-agent.sh --list-agents

# Invoke specific agent with message
./invoke-agent.sh -a "policy-advisor" -m "What is the return policy?"

# Interactive mode with new session
./invoke-agent.sh -a "support-agent" --new-session

# List active sessions
./invoke-agent.sh --list-sessions

# Format output as JSON
./invoke-agent.sh -a "agent-name" -m "query" -f json
```

**Options:**
- `-e, --environment ENV` - Environment (default: dev)
- `-a, --agent AGENT_NAME` - Agent to invoke
- `-m, --message MESSAGE` - User message/prompt
- `--session-id ID` - Use specific session
- `--new-session` - Start new session
- `--list-agents` - List available agents
- `--list-sessions` - List active sessions
- `-f, --format FORMAT` - Output format (json/text/table)
- `--timeout SECONDS` - Invocation timeout (default: 30)
- `-h, --help` - Show help message

---

#### 4. **orchestrate-workflow.sh** - Step Functions Workflow Management
Manages AWS Step Functions workflows for multi-agent orchestration.

**Features:**
- List available workflows
- Start new workflow executions
- Monitor execution progress in real-time
- View execution history and details
- Get workflow definitions
- Timeout management

**Usage:**
```bash
# List available workflows
./orchestrate-workflow.sh --list-workflows

# Start workflow execution
./orchestrate-workflow.sh -w "multi-agent-support" -i input.json

# Monitor execution in real-time
./orchestrate-workflow.sh --monitor "arn:aws:states:us-east-1:..."

# Get execution details
./orchestrate-workflow.sh --get-execution "arn:aws:states:..."

# Describe workflow definition
./orchestrate-workflow.sh -w "workflow-name" --describe-workflow

# Dry-run to see execution plan
./orchestrate-workflow.sh -w "workflow" -i input.json --dry-run
```

**Options:**
- `-e, --environment ENV` - Environment (dev/staging/prod)
- `-w, --workflow NAME` - Workflow name
- `-i, --input FILE` - JSON input file
- `--list-workflows` - List available workflows
- `--start-execution` - Start new execution
- `--get-execution EXEC_ID` - Get execution details
- `--list-executions` - List recent executions
- `--monitor EXEC_ID` - Monitor execution
- `--describe-workflow` - Get workflow definition
- `--timeout SECONDS` - Execution timeout (default: 300)
- `--dry-run` - Show plan without running
- `-h, --help` - Show help message

---

#### 5. **cleanup.sh** - Resource Cleanup
Safely cleans up Bedrock agents infrastructure with confirmation prompts.

**Features:**
- Terraform resource destruction
- S3 bucket emptying and deletion
- CloudWatch logs cleanup
- Lambda function removal
- IAM role cleanup
- Local state file cleanup
- Dry-run mode for safe preview

**Usage:**
```bash
# Preview cleanup with dry-run
./cleanup.sh -e dev --dry-run

# Destroy Terraform resources only
./cleanup.sh -e dev --tf-destroy

# Clean S3 buckets and logs
./cleanup.sh -e staging --clean-s3 --clean-logs

# Remove everything with confirmation
./cleanup.sh -e prod -a

# Remove everything without confirmation (DANGEROUS!)
./cleanup.sh -e dev -a --confirm
```

**Options:**
- `-e, --environment ENV` - Environment (required)
- `-a, --all` - Remove all resources
- `--tf-destroy` - Destroy Terraform resources
- `--clean-s3` - Clean S3 buckets
- `--clean-logs` - Remove CloudWatch logs
- `--clean-state` - Remove local state
- `--confirm` - Skip confirmation prompt
- `--dry-run` - Preview without deletion
- `-h, --help` - Show help message

---

### Monitoring Scripts

Located in the `monitoring/` subdirectory:

#### **monitoring/setup-dashboards.sh** - CloudWatch Dashboards
Creates and manages CloudWatch dashboards for infrastructure monitoring.

**Usage:**
```bash
./monitoring/setup-dashboards.sh -e dev -c
./monitoring/setup-dashboards.sh -e prod -u
./monitoring/setup-dashboards.sh -l
```

#### **monitoring/export-metrics.sh** - Metrics Export
Exports CloudWatch metrics to CSV for analysis.

**Usage:**
```bash
./monitoring/export-metrics.sh -e dev -m lambda
./monitoring/export-metrics.sh -e prod -m all -o metrics.csv
```

#### **monitoring/cost-analysis.sh** - Cost Analysis
Analyzes AWS resource costs for the infrastructure.

**Usage:**
```bash
./monitoring/cost-analysis.sh -e prod -m 2024-11
./monitoring/cost-analysis.sh -e dev -s bedrock -o cost_report.txt
```

---

## Installation & Setup

### Prerequisites

**Required Tools:**
- AWS CLI (v2 or later)
- Terraform (v1.0 or later)
- Bash 4.0+
- jq (JSON processor)
- Python 3.8+

**AWS Permissions:**
Scripts require permissions for:
- Bedrock, Lambda, S3, CloudWatch
- API Gateway, Step Functions, IAM
- CloudWatch Logs, EC2 (for networking)

**Installation:**
```bash
# Clone repository
git clone <repository-url>
cd bedrock-agents-infrastructure/scripts

# Make scripts executable
chmod +x *.sh
chmod +x monitoring/*.sh

# Install Python dependencies (optional)
pip install -r requirements.txt

# Configure AWS credentials
aws configure
```

---

## Common Workflows

### 1. Initial Deployment

```bash
# 1. Plan deployment
./deploy.sh -e dev --dry-run

# 2. Deploy to development
./deploy.sh -e dev

# 3. Setup knowledge base
./setup-knowledge-base.sh -c -n "kb-docs" -d ./documents

# 4. Create monitoring dashboards
./monitoring/setup-dashboards.sh -e dev -c

# 5. Run health checks
./deploy.sh -e dev --list-resources
```

### 2. Testing Agents

```bash
# 1. List available agents
./invoke-agent.sh --list-agents

# 2. Test specific agent
./invoke-agent.sh -a "support-agent" -m "Hello, how can I help?"

# 3. Start interactive session
./invoke-agent.sh -a "support-agent" --new-session
```

### 3. Workflow Orchestration

```bash
# 1. List available workflows
./orchestrate-workflow.sh --list-workflows

# 2. Start execution
./orchestrate-workflow.sh -w "multi-step-flow" -i input.json --start-execution

# 3. Monitor progress
./orchestrate-workflow.sh --monitor "execution-arn"
```

### 4. Cost Analysis

```bash
# 1. Export metrics
./monitoring/export-metrics.sh -e prod -m all -o metrics.csv

# 2. Generate cost report
./monitoring/cost-analysis.sh -e prod -m 2024-11

# 3. View dashboards
./monitoring/setup-dashboards.sh -e prod -l
```

### 5. Cleanup

```bash
# 1. Preview cleanup
./cleanup.sh -e staging --dry-run

# 2. Clean specific resources
./cleanup.sh -e staging --clean-logs --clean-s3

# 3. Destroy all (with confirmation)
./cleanup.sh -e dev -a
```

---

## Logging & Debugging

All scripts create detailed logs in the `logs/` directory:

```bash
# View recent logs
tail -f logs/deploy_*.log

# Search logs
grep -i "error" logs/*.log

# Check specific operation
grep "deploy" logs/*.log
```

Log files include:
- Timestamps for all operations
- Command outputs and errors
- Resource ARNs and IDs
- Performance metrics

---

## Error Handling

Scripts include comprehensive error handling:

1. **Prerequisite checks** - Validates required tools and AWS credentials
2. **Input validation** - Checks arguments and file existence
3. **Operation verification** - Confirms success of each step
4. **Rollback support** - Some operations support rollback
5. **Detailed error messages** - Clear guidance on failures

**Common Issues:**

| Issue | Solution |
|-------|----------|
| AWS credentials not found | Run `aws configure` |
| Terraform state locked | Use `terraform force-unlock` |
| Permission denied on scripts | Run `chmod +x *.sh` |
| Missing dependencies | Install with `pip install -r requirements.txt` |

---

## Advanced Usage

### Dry-Run Mode

All scripts support `--dry-run` to preview changes:

```bash
./deploy.sh -e prod --dry-run  # See what would be deployed
./cleanup.sh -e dev --dry-run  # Preview cleanup
```

### Custom Environments

Create environment-specific variables:

```bash
# Create custom environment
ENVIRONMENT="custom" ./deploy.sh
```

### Parallel Execution

For faster deployment, scripts support concurrent operations:

```bash
# Deploy to multiple environments
./deploy.sh -e dev &
./deploy.sh -e staging &
wait
```

### Integration with CI/CD

Scripts are CI/CD friendly:

```bash
# In GitLab CI/GitHub Actions
- name: Deploy
  run: ./deploy.sh -e prod --auto-approve

- name: Test agents
  run: ./invoke-agent.sh --list-agents
```

---

## Configuration Files

### Environment Variables

Create `.env.local` for custom settings:

```bash
export AWS_REGION=us-east-1
export TERRAFORM_BACKEND=s3://my-bucket/terraform
export LOG_LEVEL=DEBUG
```

### Agent Configuration

Agent configurations are stored in `config/agents/`:

```json
{
  "name": "support-agent",
  "description": "Customer support assistant",
  "model": "claude-3-sonnet",
  "max_tokens": 4096
}
```

---

## Performance Considerations

- **Deployment time:** 5-15 minutes (varies by environment size)
- **Lambda build:** 2-5 minutes per function
- **Knowledge base sync:** 1-3 minutes per 100MB documents
- **Health checks:** 1-2 minutes

---

## Security Best Practices

1. **Never use `--confirm` flag in production**
2. **Always use `--dry-run` before destructive operations**
3. **Rotate AWS credentials regularly**
4. **Use separate AWS accounts for dev/staging/prod**
5. **Enable CloudTrail for audit logging**
6. **Review IAM policies before deployment**

---

## Support & Contributing

For issues or questions:
1. Check logs in `logs/` directory
2. Review this README
3. Run with `-h` flag for script help
4. Check AWS CloudWatch for service errors

---

## License

MIT License - See LICENSE file for details

---

## Changelog

### v1.0.0 (2024-11-17)
- Initial release
- All core deployment scripts
- Monitoring and cost analysis tools
- Comprehensive documentation
