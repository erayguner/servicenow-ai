# ServiceNow AI Infrastructure - Claude Code Configuration

## Project Overview

Multi-cloud infrastructure-as-code repository for deploying a production-ready
ServiceNow AI Agent system on **Google Cloud Platform (GCP)** and **Amazon Web
Services (AWS)**.

## Project Structure

```
servicenow-ai/
├── terraform/                    # GCP Infrastructure (Terraform)
├── aws-infrastructure/           # AWS Infrastructure (Terraform)
├── bedrock-agents-infrastructure/ # AWS Bedrock AI Agents
├── backend/                      # Node.js/TypeScript API
├── frontend/                     # Next.js React Application
├── k8s/                          # Kubernetes Manifests
├── servicenow/                   # ServiceNow Integration
├── scripts/                      # Utility Scripts
└── docs/                         # Documentation
```

## Technology Stack

- **Infrastructure**: Terraform 1.11.0+, Kubernetes 1.33+
- **Cloud Providers**: GCP (primary), AWS (secondary)
- **Backend**: Node.js, TypeScript, Express
- **Frontend**: Next.js, React, TailwindCSS
- **AI/ML**: Vertex AI, AWS Bedrock, vLLM, KServe
- **Database**: PostgreSQL (Cloud SQL/RDS), Firestore, DynamoDB
- **Caching**: Redis (Memorystore/ElastiCache)

## Development Commands

### Terraform

```bash
# Initialize and validate
cd terraform/environments/dev
terraform init
terraform validate
terraform plan

# Apply changes
terraform apply

# Run tests
cd terraform/tests
terraform test
```

### Backend (Node.js)

```bash
cd backend
npm install
npm run dev      # Development server
npm run build    # Build for production
npm run test     # Run tests
npm run lint     # Lint code
```

### Frontend (Next.js)

```bash
cd frontend
npm install
npm run dev      # Development server (localhost:3000)
npm run build    # Production build
npm run lint     # Lint code
```

### Pre-commit Hooks

```bash
# Install hooks
pre-commit install

# Run all checks
pre-commit run --all-files

# Run specific hook
pre-commit run terraform_fmt --all-files
```

### Make Commands

```bash
make init        # Initialize all components
make validate    # Run all validations
make test        # Run all tests
make lint        # Run linters
make security    # Security checks
```

## Code Style Guidelines

### Terraform

- Use snake_case for resource names
- Prefix resources with environment: `${var.environment}-resource-name`
- Always define variables in `variables.tf` with descriptions
- Output sensitive values with `sensitive = true`
- Use modules for reusable components
- Maximum file size: 500 lines

### TypeScript/JavaScript

- Use ESLint configuration in `.eslintrc.js`
- Prettier for formatting (`.prettierrc.json`)
- Strict TypeScript mode enabled
- Use async/await over promises

### Kubernetes

- Use kube-linter for manifest validation (`.kube-linter.yaml`)
- Apply resource limits on all containers
- Use NetworkPolicies for pod isolation
- Prefer Deployments over bare Pods

## Security Guidelines

- Never hardcode secrets - use Secret Manager / Secrets Manager
- Use Workload Identity for GCP, IAM Roles for AWS
- Enable encryption at rest (KMS/CMEK)
- Follow least-privilege principle for IAM
- Run `pre-commit run --all-files` before committing

## Environment Configuration

### GCP Environments

- `terraform/environments/dev/` - Development
- `terraform/environments/staging/` - Staging
- `terraform/environments/prod/` - Production

### AWS Environments

- `aws-infrastructure/terraform/environments/dev/` - Development
- `aws-infrastructure/terraform/environments/prod/` - Production

### Bedrock Agents

- `bedrock-agents-infrastructure/terraform/environments/dev/`
- `bedrock-agents-infrastructure/terraform/environments/staging/`
- `bedrock-agents-infrastructure/terraform/environments/prod/`

## CI/CD Workflows

Located in `.github/workflows/`:

- `lint.yml` - Code linting and formatting
- `parallel-tests.yml` - Terraform and unit tests
- `security-check.yml` - Security scanning
- `deploy.yml` - Deployment pipeline
- `release-please.yml` - Automated releases

## MCP Tools Available

This project has access to specialized MCP tools for infrastructure work:

### Terraform Tools

- `mcp__MCP_DOCKER__ExecuteTerraformCommand` - Run terraform commands
- `mcp__MCP_DOCKER__RunCheckovScan` - Security scanning
- `mcp__MCP_DOCKER__SearchAwsProviderDocs` - AWS provider documentation

### AWS Tools

- `mcp__MCP_DOCKER__get_cost_and_usage` - Cost analysis
- `mcp__MCP_DOCKER__get_cost_forecast` - Cost forecasting

### Diagram Tools

- `mcp__MCP_DOCKER__generate_diagram` - Architecture diagrams

## Working with Infrastructure

### Adding a New Terraform Module

1. Create module directory: `terraform/modules/<module-name>/`
2. Add required files: `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`
3. Reference in environment: `module "<name>" { source = "../../modules/<name>" }`
4. Run `terraform init` and `terraform validate`

### Adding AWS Bedrock Agent

1. Update `bedrock-agents-infrastructure/terraform/modules/`
2. Define action groups in `bedrock-action-group/`
3. Configure knowledge bases in `bedrock-knowledge-base/`
4. Test with `terraform plan` before applying

## File Organization Rules

- Infrastructure code goes in respective `terraform/` directories
- Application code in `backend/` or `frontend/`
- Kubernetes manifests in `k8s/`
- Documentation in `docs/`
- Scripts in `scripts/`
- Never save working files to root directory

## Testing

### Terraform Tests

```bash
# Run all module tests
cd terraform/tests
terraform test

# Test specific module
terraform test -filter=tests/vpc_test.tftest.hcl
```

### Backend Tests

```bash
cd backend
npm test
npm run test:coverage
```

## Troubleshooting

### Common Issues

1. **Terraform state lock**: Wait or run `terraform force-unlock <LOCK_ID>`
2. **Pre-commit fails**: Run `pre-commit run --all-files` to see details
3. **GCP auth issues**: Run `gcloud auth application-default login`
4. **AWS auth issues**: Configure `~/.aws/credentials` or use SSO

## Resources

- [GCP Terraform Provider](https://registry.terraform.io/providers/hashicorp/google/latest)
- [AWS Terraform Provider](https://registry.terraform.io/providers/hashicorp/aws/latest)
- [AWS Bedrock Documentation](https://docs.aws.amazon.com/bedrock/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
