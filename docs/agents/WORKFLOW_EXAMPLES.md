# Agent Workflow Examples

## Overview

This document provides real-world workflow examples using the deployed agents
for the ServiceNow AI infrastructure project.

## Table of Contents

1. [Pre-Deployment Validation](#pre-deployment-validation)
2. [New Feature Development](#new-feature-development)
3. [Security Audit](#security-audit)
4. [Cost Optimization](#cost-optimization)
5. [CI/CD Pipeline Optimization](#cicd-pipeline-optimization)
6. [Module Refactoring](#module-refactoring)
7. [Compliance Validation](#compliance-validation)
8. [Performance Tuning](#performance-tuning)

---

## Pre-Deployment Validation

### Scenario

You're about to deploy infrastructure changes to the staging environment and
need comprehensive validation.

### Workflow

**Step 1: Run Security Scan**

```bash
# Execute security audit agent
./scripts/agents/run-security-scan.sh /home/user/servicenow-ai/terraform/environments/staging

# Review findings
cat /home/user/servicenow-ai/coordination/sessions/results_json.json
```

**Step 2: Execute All Module Tests**

```bash
# Run comprehensive test suite
./scripts/agents/run-terraform-tests.sh all

# Review any failures
npx claude-flow@alpha memory retrieve "swarm/tester/results"
```

**Step 3: Code Quality Review**

```bash
# Run code quality checks
./scripts/agents/run-code-review.sh /home/user/servicenow-ai/terraform/environments/staging

# Fix any formatting issues
terraform fmt -recursive terraform/environments/staging/
prettier --write "**/*.{json,md}"
```

**Step 4: Architecture Review**

```bash
# Get architecture feedback
npx claude-flow@alpha agent execute terraform-architect-001 \
  "Review staging environment configuration for production readiness"
```

**Step 5: Performance Analysis**

```bash
# Check resource sizing
npx claude-flow@alpha agent execute performance-monitor-001 \
  "Analyze staging environment for cost and performance optimization"
```

**Step 6: Plan Validation**

```bash
cd /home/user/servicenow-ai/terraform/environments/staging
terraform init
terraform plan -out=staging.tfplan

# Review plan
terraform show staging.tfplan
```

### Success Criteria

- ✅ Zero critical security findings
- ✅ All tests passing
- ✅ No code quality issues
- ✅ Architecture review approved
- ✅ Terraform plan verified

---

## New Feature Development

### Scenario

You need to add a new Terraform module for AWS Lambda functions with Bedrock
integration.

### Workflow

**Phase 1: Design & Planning**

```bash
# Request architecture design
npx claude-flow@alpha agent execute terraform-architect-001 \
  "Design a new Terraform module for AWS Lambda functions that integrate with Bedrock agents. Include best practices for security, scalability, and maintainability."

# Store design decisions
npx claude-flow@alpha memory store "swarm/global/decisions" \
  '{"feature": "lambda-bedrock-integration", "design": "approved", "date": "2025-11-23"}'
```

**Phase 2: Implementation**

```bash
# Create module structure
mkdir -p /home/user/servicenow-ai/terraform/modules/lambda-bedrock
cd /home/user/servicenow-ai/terraform/modules/lambda-bedrock

# Create base files
touch main.tf variables.tf outputs.tf versions.tf README.md

# Implement the module (write Terraform code)
# ...

# Format code
terraform fmt -recursive
```

**Phase 3: Code Analysis**

```bash
# Analyze code quality
npx claude-flow@alpha agent execute terraform-analyzer-001 \
  "Analyze the new lambda-bedrock module for code quality, best practices, and potential improvements"

# Run code review
./scripts/agents/run-code-review.sh /home/user/servicenow-ai/terraform/modules/lambda-bedrock
```

**Phase 4: Security Validation**

```bash
# Security scan
./scripts/agents/run-security-scan.sh /home/user/servicenow-ai/terraform/modules/lambda-bedrock

# Review security findings
npx claude-flow@alpha agent execute security-auditor-001 \
  "Review security scan results for lambda-bedrock module and prioritize remediation"
```

**Phase 5: Testing**

```bash
# Create test file
cat > /home/user/servicenow-ai/terraform/modules/lambda-bedrock/lambda-bedrock.tftest.hcl <<'EOF'
# Test configuration
run "validate_lambda_creation" {
  command = plan

  variables {
    function_name = "test-bedrock-integration"
    runtime       = "python3.11"
  }

  assert {
    condition     = aws_lambda_function.main.runtime == "python3.11"
    error_message = "Lambda runtime must be python3.11"
  }
}
EOF

# Run tests
./scripts/agents/run-terraform-tests.sh lambda-bedrock
```

**Phase 6: Documentation**

```bash
# Request documentation review
npx claude-flow@alpha agent execute repo-organizer-001 \
  "Review documentation for lambda-bedrock module and suggest improvements"

# Update README
# Add module to main documentation
```

**Phase 7: Integration**

```bash
# Add to environment configuration
cd /home/user/servicenow-ai/terraform/environments/dev

# Update main.tf to include new module
# ...

# Validate integration
terraform init -upgrade
terraform validate
terraform plan
```

### Success Criteria

- ✅ Architecture design approved
- ✅ Code quality score > 90%
- ✅ Zero critical security issues
- ✅ All tests passing
- ✅ Documentation complete
- ✅ Successfully integrated into dev environment

---

## Security Audit

### Scenario

Quarterly security audit is due. Need comprehensive security assessment of
entire infrastructure.

### Workflow

**Step 1: Full Infrastructure Scan**

```bash
# Scan all Terraform code
./scripts/agents/run-security-scan.sh /home/user/servicenow-ai/terraform

# Scan AWS infrastructure
./scripts/agents/run-security-scan.sh /home/user/servicenow-ai/aws-infrastructure

# Scan Bedrock infrastructure
./scripts/agents/run-security-scan.sh /home/user/servicenow-ai/bedrock-agents-infrastructure
```

**Step 2: Compliance Validation**

```bash
# Check SOC 2 compliance
checkov -d /home/user/servicenow-ai/terraform \
  --framework soc2 \
  --output json \
  --output-file-path /home/user/servicenow-ai/coordination/sessions/soc2-compliance.json

# Check GDPR compliance
checkov -d /home/user/servicenow-ai/terraform \
  --framework gdpr \
  --output json \
  --output-file-path /home/user/servicenow-ai/coordination/sessions/gdpr-compliance.json

# Check HIPAA compliance
checkov -d /home/user/servicenow-ai/terraform \
  --check CKV_AWS_HIPAA* \
  --output json \
  --output-file-path /home/user/servicenow-ai/coordination/sessions/hipaa-compliance.json
```

**Step 3: Agent-Assisted Analysis**

```bash
# Prioritize findings
npx claude-flow@alpha agent execute security-auditor-001 \
  "Analyze all security scan results, categorize by severity, and create remediation plan with priorities"

# Review IAM policies
npx claude-flow@alpha agent execute security-auditor-001 \
  "Review all IAM policies and service accounts for least-privilege compliance"

# Check encryption
npx claude-flow@alpha agent execute security-auditor-001 \
  "Verify all data stores use customer-managed encryption keys (CMEK) and validate key rotation"
```

**Step 4: Kubernetes Security**

```bash
# Lint Kubernetes manifests
find /home/user/servicenow-ai/k8s -name "*.yaml" -exec kube-linter lint {} \;

# Review NetworkPolicies
npx claude-flow@alpha agent execute security-auditor-001 \
  "Review all Kubernetes NetworkPolicies for zero-trust compliance"

# Check Pod Security Standards
kubectl --dry-run=client apply -f /home/user/servicenow-ai/k8s/pod-security/
```

**Step 5: Secrets Management**

```bash
# Check for hardcoded secrets
git secrets --scan

# Verify Secret Manager usage
npx claude-flow@alpha agent execute security-auditor-001 \
  "Audit all secret references to ensure they use Secret Manager, not environment variables or ConfigMaps"
```

**Step 6: Generate Audit Report**

```bash
# Compile findings
npx claude-flow@alpha agent execute security-auditor-001 \
  "Generate comprehensive security audit report with executive summary, findings categorized by severity, compliance status, and remediation roadmap"

# Store audit results
npx claude-flow@alpha memory store "swarm/security/quarterly-audit" \
  '{"date": "2025-11-23", "status": "completed", "findings": "stored"}'
```

### Success Criteria

- ✅ All environments scanned
- ✅ Compliance validated (SOC2, GDPR, HIPAA)
- ✅ Findings prioritized and categorized
- ✅ Remediation plan created
- ✅ Audit report generated
- ✅ No critical or high-severity findings (or documented exceptions)

---

## Cost Optimization

### Scenario

Monthly cloud costs are trending upward. Need to identify and implement cost
optimizations.

### Workflow

**Step 1: Cost Analysis**

```bash
# Analyze current infrastructure
npx claude-flow@alpha agent execute performance-monitor-001 \
  "Analyze GCP and AWS resource usage across all environments. Identify over-provisioned resources, idle resources, and cost optimization opportunities."

# Check GKE node utilization
npx claude-flow@alpha agent execute performance-monitor-001 \
  "Analyze GKE node pool utilization. Identify opportunities for node size optimization and autoscaling tuning."
```

**Step 2: Storage Optimization**

```bash
# Review storage buckets
npx claude-flow@alpha agent execute performance-monitor-001 \
  "Review all Cloud Storage buckets and S3 buckets. Check lifecycle policies, storage classes, and recommend optimizations."

# Analyze database sizing
npx claude-flow@alpha agent execute performance-monitor-001 \
  "Analyze Cloud SQL and RDS instance sizes. Check CPU/memory utilization and recommend right-sizing."
```

**Step 3: Architecture Review**

```bash
# Get architecture recommendations
npx claude-flow@alpha agent execute terraform-architect-001 \
  "Review infrastructure architecture for cost optimization. Consider reserved instances, committed use discounts, preemptible/spot instances, and architectural changes."
```

**Step 4: Implement Optimizations**

```bash
# Example: Add lifecycle policy to storage module
cd /home/user/servicenow-ai/terraform/modules/storage

# Update main.tf with lifecycle rules
# ...

# Example: Optimize GKE node pools
cd /home/user/servicenow-ai/terraform/modules/gke

# Adjust node sizes and autoscaling
# ...

# Validate changes
terraform fmt -recursive
terraform validate
```

**Step 5: Test Impact**

```bash
# Run tests
./scripts/agents/run-terraform-tests.sh storage
./scripts/agents/run-terraform-tests.sh gke

# Plan changes
cd /home/user/servicenow-ai/terraform/environments/dev
terraform plan
```

**Step 6: Monitor Results**

```bash
# Store optimization actions
npx claude-flow@alpha memory store "swarm/perf/optimizations" \
  '{"date": "2025-11-23", "actions": ["lifecycle-policies", "node-sizing"], "estimated-savings": "30%"}'

# Set up monitoring
npx claude-flow@alpha agent execute performance-monitor-001 \
  "Create monitoring plan to track cost savings over next 30 days"
```

### Success Criteria

- ✅ Cost analysis completed
- ✅ Optimization opportunities identified
- ✅ Changes implemented and tested
- ✅ Estimated savings calculated
- ✅ Monitoring plan in place

---

## CI/CD Pipeline Optimization

### Scenario

GitHub Actions workflows are slow and consuming excessive runner minutes.

### Workflow

**Step 1: Analyze Current Workflows**

```bash
# Review workflow performance
npx claude-flow@alpha agent execute cicd-engineer-001 \
  "Analyze all GitHub Actions workflows. Identify bottlenecks, redundant steps, and optimization opportunities."
```

**Step 2: Check Parallelization**

```bash
# Review parallel execution
npx claude-flow@alpha agent execute cicd-engineer-001 \
  "Review terraform-ci-optimized.yml and parallel-tests.yml. Recommend additional parallelization opportunities."
```

**Step 3: Optimize Caching**

```bash
# Analyze cache effectiveness
npx claude-flow@alpha agent execute cicd-engineer-001 \
  "Review cache configurations in all workflows. Recommend improvements for Terraform plugins, npm packages, and Docker layers."
```

**Step 4: Implement Improvements**

```bash
# Update workflow files
cd /home/user/servicenow-ai/.github/workflows

# Example: Improve caching
# Edit terraform-ci-optimized.yml
# ...

# Validate YAML
yamllint -c /home/user/servicenow-ai/.yamllint.yaml .github/workflows/
```

**Step 5: Test Changes**

```bash
# Run code review
./scripts/agents/run-code-review.sh .github/workflows/

# Commit and push to test branch
git checkout -b optimize-workflows
git add .github/workflows/
git commit -m "feat(ci): optimize GitHub Actions workflows for performance"
git push origin optimize-workflows
```

**Step 6: Monitor Performance**

```bash
# Track improvements
npx claude-flow@alpha memory store "swarm/cicd/optimizations" \
  '{"date": "2025-11-23", "changes": ["improved-caching", "increased-parallelization"], "estimated-improvement": "40%"}'
```

### Success Criteria

- ✅ Workflow analysis completed
- ✅ Bottlenecks identified
- ✅ Optimizations implemented
- ✅ Workflows tested
- ✅ Performance improvement measured

---

## Module Refactoring

### Scenario

The VPC module has grown to 800 lines and needs refactoring for better
maintainability.

### Workflow

**Step 1: Code Analysis**

```bash
# Analyze current module
npx claude-flow@alpha agent execute terraform-analyzer-001 \
  "Analyze the VPC module (/home/user/servicenow-ai/terraform/modules/vpc). Identify code smells, duplication, and refactoring opportunities."
```

**Step 2: Architecture Review**

```bash
# Get refactoring recommendations
npx claude-flow@alpha agent execute terraform-architect-001 \
  "Review VPC module architecture. Recommend how to split into smaller sub-modules while maintaining backward compatibility."
```

**Step 3: Create Refactoring Plan**

```bash
# Store plan in memory
npx claude-flow@alpha memory store "swarm/global/decisions" \
  '{"module": "vpc", "action": "refactor", "plan": "split-into-submodules", "date": "2025-11-23"}'
```

**Step 4: Implement Refactoring**

```bash
# Create sub-modules
mkdir -p /home/user/servicenow-ai/terraform/modules/vpc/{subnets,firewall,nat,peering}

# Split code into sub-modules
# ...

# Update main VPC module to use sub-modules
# ...

# Format code
terraform fmt -recursive terraform/modules/vpc/
```

**Step 5: Testing**

```bash
# Run comprehensive tests
./scripts/agents/run-terraform-tests.sh vpc

# Test in dev environment
cd /home/user/servicenow-ai/terraform/environments/dev
terraform init -upgrade
terraform plan

# Verify no changes (backward compatibility)
```

**Step 6: Code Review**

```bash
# Quality check
./scripts/agents/run-code-review.sh terraform/modules/vpc

# Get final review
npx claude-flow@alpha agent execute code-reviewer-001 \
  "Review refactored VPC module for code quality, documentation, and maintainability"
```

### Success Criteria

- ✅ Module split into logical sub-modules
- ✅ Each sub-module < 500 lines
- ✅ Backward compatibility maintained
- ✅ All tests passing
- ✅ Documentation updated
- ✅ Code quality improved

---

## Compliance Validation

### Scenario

Need to validate infrastructure compliance with UK AI Playbook requirements.

### Workflow

**Step 1: Framework Analysis**

```bash
# Check compliance frameworks
npx claude-flow@alpha agent execute security-auditor-001 \
  "Review bedrock-agents-infrastructure/compliance/frameworks/ and validate against UK AI Playbook requirements"
```

**Step 2: Run Compliance Scans**

```bash
# ISO 27001 compliance
checkov -f /home/user/servicenow-ai/bedrock-agents-infrastructure/compliance/frameworks/iso27001.yaml

# GDPR compliance (UK/EU)
checkov -f /home/user/servicenow-ai/bedrock-agents-infrastructure/compliance/frameworks/gdpr.yaml

# SOC 2 Type II
checkov -f /home/user/servicenow-ai/bedrock-agents-infrastructure/compliance/frameworks/soc2.yaml
```

**Step 3: Audit Trail Validation**

```bash
# Check CloudTrail configuration
npx claude-flow@alpha agent execute security-auditor-001 \
  "Validate CloudTrail and Cloud Logging configurations meet audit requirements for UK AI Playbook"

# Review evidence collection
cat /home/user/servicenow-ai/bedrock-agents-infrastructure/compliance/audit/evidence-collection.yaml
```

**Step 4: Generate Compliance Report**

```bash
# Create comprehensive report
npx claude-flow@alpha agent execute security-auditor-001 \
  "Generate UK AI Playbook compliance report including: compliance percentage, gaps, remediation steps, and evidence collection status"
```

**Step 5: Track Compliance**

```bash
# Store compliance status
npx claude-flow@alpha memory store "swarm/security/compliance" \
  '{"framework": "UK-AI-Playbook", "date": "2025-11-23", "status": "95%", "target": "100%"}'
```

### Success Criteria

- ✅ All compliance frameworks validated
- ✅ Gaps identified and documented
- ✅ Remediation plan created
- ✅ Evidence collection process verified
- ✅ Compliance report generated

---

## Performance Tuning

### Scenario

Application response times are increasing. Need to optimize infrastructure
performance.

### Workflow

**Step 1: Performance Baseline**

```bash
# Analyze current performance
npx claude-flow@alpha agent execute performance-monitor-001 \
  "Establish performance baseline for all services: response times, throughput, resource utilization"
```

**Step 2: Bottleneck Identification**

```bash
# Identify bottlenecks
npx claude-flow@alpha agent execute performance-monitor-001 \
  "Analyze infrastructure for performance bottlenecks: database queries, network latency, compute constraints"

# Review architecture
npx claude-flow@alpha agent execute terraform-architect-001 \
  "Review architecture for performance improvements: caching strategies, load balancing, database optimization"
```

**Step 3: Optimize Resources**

```bash
# Database optimization
npx claude-flow@alpha agent execute performance-monitor-001 \
  "Analyze Cloud SQL performance. Recommend instance sizing, read replicas, and query optimization"

# Network optimization
npx claude-flow@alpha agent execute performance-monitor-001 \
  "Review VPC peering, NAT gateway configuration, and network egress costs"

# Caching optimization
npx claude-flow@alpha agent execute terraform-architect-001 \
  "Review Redis configuration and recommend caching strategy improvements"
```

**Step 4: Implement Changes**

```bash
# Update Terraform configurations
cd /home/user/servicenow-ai/terraform/modules

# Example: Optimize Cloud SQL
# Edit modules/cloudsql/main.tf
# ...

# Example: Optimize Redis
# Edit modules/redis/main.tf
# ...

# Validate changes
terraform fmt -recursive
./scripts/agents/run-terraform-tests.sh
```

**Step 5: Load Testing**

```bash
# Performance testing would be executed here
# Example: k6 load tests

# Monitor results
npx claude-flow@alpha agent execute performance-monitor-001 \
  "Monitor performance metrics during and after optimization. Compare against baseline."
```

**Step 6: Document Results**

```bash
# Store performance data
npx claude-flow@alpha memory store "swarm/perf/tuning" \
  '{"date": "2025-11-23", "baseline": "500ms p95", "optimized": "200ms p95", "improvement": "60%"}'
```

### Success Criteria

- ✅ Performance baseline established
- ✅ Bottlenecks identified
- ✅ Optimizations implemented
- ✅ Performance improved by > 30%
- ✅ Results documented

---

## Best Practices

### General Tips

1. **Always start with analysis** before making changes
2. **Use memory to store decisions** for team coordination
3. **Run security scans** before every deployment
4. **Test locally first** before pushing to CI/CD
5. **Document all changes** for audit trails
6. **Monitor metrics** to validate improvements
7. **Collaborate agents** for complex tasks

### Agent Collaboration Patterns

**Architecture + Analysis**:

- Architect designs solution
- Analyzer validates code quality
- Best for: New features, major refactoring

**Security + Review**:

- Security auditor scans for vulnerabilities
- Reviewer checks code standards
- Best for: Pre-deployment, compliance audits

**Performance + Testing**:

- Performance monitor identifies bottlenecks
- Tester validates improvements
- Best for: Optimization initiatives

**CI/CD + All Others**:

- CI/CD engineer orchestrates workflows
- Other agents execute validation steps
- Best for: Pipeline automation

---

## Additional Resources

- [Agent Deployment Guide](AGENT_DEPLOYMENT_GUIDE.md)
- [Quick Reference](QUICK_REFERENCE.md)
- [Project README](/home/user/servicenow-ai/README.md)
- [Claude-Flow Documentation](https://github.com/ruvnet/claude-flow)
