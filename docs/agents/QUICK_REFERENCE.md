# Agent Quick Reference Guide

## 🚀 Quick Start

### Check Agent Status
```bash
./scripts/agents/agent-status.sh
```

### Run Security Scan
```bash
./scripts/agents/run-security-scan.sh
./scripts/agents/run-security-scan.sh /home/user/servicenow-ai/terraform/modules/gke
```

### Run Terraform Tests
```bash
./scripts/agents/run-terraform-tests.sh all
./scripts/agents/run-terraform-tests.sh gke
```

### Run Code Review
```bash
./scripts/agents/run-code-review.sh
./scripts/agents/run-code-review.sh /home/user/servicenow-ai/terraform/modules/vpc
```

## 🤖 Deployed Agents

| Agent ID | Type | Primary Use |
|----------|------|-------------|
| `terraform-architect-001` | system-architect | Infrastructure design & architecture |
| `terraform-analyzer-001` | code-analyzer | Code quality & analysis |
| `security-auditor-001` | security-auditor | Security scanning & compliance |
| `cicd-engineer-001` | cicd-engineer | CI/CD pipeline management |
| `code-reviewer-001` | reviewer | Code quality & formatting |
| `test-validator-001` | tester | Testing & validation |
| `performance-monitor-001` | perf-analyzer | Performance & cost optimization |
| `repo-organizer-001` | repo-architect | Repository organization |

## 📋 Common Workflows

### Pre-Deployment Checklist
```bash
# 1. Run all tests
./scripts/agents/run-terraform-tests.sh all

# 2. Security scan
./scripts/agents/run-security-scan.sh

# 3. Code review
./scripts/agents/run-code-review.sh

# 4. Check status
./scripts/agents/agent-status.sh
```

### New Module Development
```bash
# 1. Design review
# Request architecture review from terraform-architect-001

# 2. Implement module
# Write Terraform code

# 3. Code analysis
./scripts/agents/run-code-review.sh terraform/modules/new-module

# 4. Security check
./scripts/agents/run-security-scan.sh terraform/modules/new-module

# 5. Run tests
./scripts/agents/run-terraform-tests.sh new-module
```

### Cost Optimization
```bash
# 1. Analyze current costs
# Use performance-monitor-001 agent

# 2. Review architecture
# Use terraform-architect-001 for optimization suggestions

# 3. Implement changes
# Update Terraform configurations

# 4. Validate
./scripts/agents/run-terraform-tests.sh
```

## 🔧 Tool Commands

### Terraform
```bash
# Format all files
terraform fmt -recursive

# Validate configuration
terraform validate

# Run module tests
terraform test
```

### Security (Checkov)
```bash
# Scan Terraform
checkov -d terraform/ --framework terraform

# Scan with specific frameworks
checkov -d terraform/ --framework terraform --check CKV_AWS_*

# Soft fail (non-blocking)
checkov -d terraform/ --soft-fail
```

### YAML Linting
```bash
# Lint all YAML files
yamllint .

# Lint specific file
yamllint .github/workflows/deploy.yml

# Use project config
yamllint -c .yamllint.yaml .
```

### Code Formatting
```bash
# Prettier (JSON, Markdown)
prettier --check "**/*.{json,md}"
prettier --write "**/*.{json,md}"

# Shell scripts
shfmt -d scripts/
shfmt -w scripts/
```

### Pre-commit Hooks
```bash
# Run all hooks
pre-commit run --all-files

# Run specific hook
pre-commit run terraform-fmt --all-files
pre-commit run checkov --all-files

# Update hooks
pre-commit autoupdate
```

## 🎯 Agent-Specific Commands

### Architecture Review
```bash
npx claude-flow@alpha agent execute terraform-architect-001 \
  "Review the Bedrock agents infrastructure module"
```

### Code Analysis
```bash
npx claude-flow@alpha agent execute terraform-analyzer-001 \
  "Analyze the VPC module for code quality issues"
```

### Security Audit
```bash
npx claude-flow@alpha agent execute security-auditor-001 \
  "Run comprehensive security scan on staging environment"
```

### CI/CD Optimization
```bash
npx claude-flow@alpha agent execute cicd-engineer-001 \
  "Analyze GitHub Actions workflows for optimization opportunities"
```

### Performance Analysis
```bash
npx claude-flow@alpha agent execute performance-monitor-001 \
  "Analyze GKE cluster costs and resource utilization"
```

## 💾 Memory Commands

### Store Information
```bash
npx claude-flow@alpha memory store "swarm/global/decisions" \
  '{"decision": "Use mesh topology for agent coordination"}'
```

### Retrieve Information
```bash
npx claude-flow@alpha memory retrieve "swarm/global/decisions"
npx claude-flow@alpha memory retrieve "swarm/security/findings"
```

### List All Keys
```bash
npx claude-flow@alpha memory list
```

### Clear Memory
```bash
npx claude-flow@alpha memory clear "swarm/agent/*"
```

## 🔄 Session Management

### Start New Session
```bash
npx claude-flow@alpha hooks session-restore --session-id "servicenow-ai-infra-dev"
```

### End Session
```bash
npx claude-flow@alpha hooks session-end --export-metrics true
```

### Session Status
```bash
npx claude-flow@alpha swarm status --session-id "servicenow-ai-infra-dev"
```

## 📊 Monitoring & Metrics

### Agent Metrics
```bash
npx claude-flow@alpha agent metrics terraform-architect-001
```

### Swarm Metrics
```bash
npx claude-flow@alpha swarm metrics --session-id "servicenow-ai-infra-dev"
```

### Agent Status
```bash
npx claude-flow@alpha swarm status
```

## 🚨 Troubleshooting

### Agent Not Responding
```bash
# Check status
npx claude-flow@alpha agent status terraform-architect-001

# Restart agent
npx claude-flow@alpha agent restart terraform-architect-001
```

### Clear Stuck Session
```bash
# Export current state
npx claude-flow@alpha hooks session-end --export-metrics true

# Start fresh
npx claude-flow@alpha swarm init --topology mesh --session-id "servicenow-ai-infra-dev"
```

### Tool Not Found
```bash
# Check installation
./scripts/agents/agent-status.sh

# Install missing tools
# Terraform: https://terraform.io
# Checkov: pip install checkov
# yamllint: pip install yamllint
# Prettier: npm install -g prettier
# shfmt: brew install shfmt (macOS) or download from GitHub
```

## 📚 Documentation

- **Complete Guide**: [docs/agents/AGENT_DEPLOYMENT_GUIDE.md](AGENT_DEPLOYMENT_GUIDE.md)
- **Configuration**: [coordination/agents/agent-deployment-manifest.json](/home/user/servicenow-ai/coordination/agents/agent-deployment-manifest.json)
- **Scripts**: [scripts/agents/](/home/user/servicenow-ai/scripts/agents/)

## 🔗 Useful Links

- **Claude-Flow**: https://github.com/ruvnet/claude-flow
- **Terraform**: https://terraform.io
- **Checkov**: https://www.checkov.io
- **Pre-commit**: https://pre-commit.com

## 💡 Tips

1. **Always run security scans** before deploying to production
2. **Use pre-commit hooks** to catch issues early
3. **Run tests locally** before pushing to GitHub
4. **Check agent status** if things seem slow
5. **Store important decisions** in shared memory for team coordination
6. **Review agent metrics** to optimize workflows
7. **Use the mesh topology** for complex multi-agent tasks

## 🎓 Learning Resources

- Run `./scripts/agents/agent-status.sh` to verify all tools are installed
- Check the full deployment guide for detailed agent capabilities
- Use memory commands to see what agents have learned
- Review session metrics to understand agent performance
