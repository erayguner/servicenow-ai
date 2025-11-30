# copilot-instructions.md

<ai_meta> <parsing_rules> - Process infrastructure patterns in sequential
order - Use exact patterns and templates provided - Follow MUST/ALWAYS/REQUIRED
directives strictly - Never deviate from established architectural patterns
</parsing_rules> <file_conventions> - encoding: UTF-8 - line_endings: LF -
indent: 2 spaces (HCL/YAML), 4 spaces (Python) - extension: .tf for Terraform,
.tfvars for variables, .yaml for Kubernetes - structure: environments/ for env
configs, modules/ for reusable components, k8s/ for Kubernetes manifests
</file_conventions> <project_context> - domain: AI-powered ServiceNow agent
infrastructure - cloud_platform: Google Cloud Platform (GCP) - orchestration:
Google Kubernetes Engine (GKE) with Workload Identity - databases: Cloud SQL
(PostgreSQL 14), Firestore, Redis - ai_stack: KServe, vLLM, Vertex AI, hybrid
LLM routing - security: Zero-trust architecture, CMEK encryption, no service
account keys - microservices: 10 services (conversation-manager, llm-gateway,
knowledge-base, ticket-monitor, action-executor, notification-service,
internal-web-ui, api-gateway, analytics-service, document-ingestion)
</project_context> </ai_meta>

This project provides production-ready Infrastructure as Code (IaC) for a
ServiceNow AI Agent system on Google Cloud Platform. It implements secure,
scalable, and maintainable cloud infrastructure using Terraform and Kubernetes,
with modular design, automated deployment pipelines, comprehensive testing
strategies, and hybrid LLM serving capabilities.

## Agent Communication Guidelines

### Core Rules

- **REVIEW/ANALYZE/CHECK/EXAMINE:** READ-ONLY operations. Provide analysis and
  feedback, NEVER make changes.
- **IMPLEMENT/ADD/CREATE/FIX/CHANGE:** Implementation required. ALWAYS ask for
  confirmation and wait for explicit user choice before proceeding.
- **IMPROVE/OPTIMIZE/REFACTOR:** Always ask for specific approach before
  implementing.
- **MANDATORY WAIT:** When presenting implementation options, ALWAYS wait for
  explicit user choice before proceeding.

### Communication Flow

1. **Recognize Intent:** Review request vs. Implementation request?
2. **For Reviews:** Analyze and suggest, but don't change anything.
3. **For Implementation:**
   - ALWAYS ask for confirmation before implementing.
   - If multiple approaches exist, present numbered options A), B), C), D),
     ...).
   - ALWAYS end with "Other approach".
   - WAIT for user response before proceeding.
   - NEVER start implementation until user explicitly chooses an option.
4. **Critical Rule:** When presenting options, STOP and wait for user input. Do
   not continue with any implementation.

## Tech Stack

### Core Technologies

- **IaC Tool:** Terraform 1.5+ (HCL2 syntax)
- **Cloud Provider:** Google Cloud Platform (GCP)
- **State Management:** GCS backend with state locking
- **CI/CD:** GitHub Actions / Cloud Build for automated deployments
- **Testing:** Terratest (Go) for infrastructure testing

### Terraform Ecosystem

- **Configuration:** HCL2 with consistent formatting via `terraform fmt`
- **Validation:** `terraform validate`, `tflint`, and custom policy checks
- **Security Scanning:** Checkov, tfsec, Trivy for vulnerability detection
- **Documentation:** terraform-docs for automated module documentation

### GCP Services Integration

- **Identity:** Workload Identity Federation for secure authentication
- **Networking:** VPC, Cloud NAT, Private Service Connect
- **Compute:** GCE, GKE, Cloud Run, Cloud Functions
- **Storage:** GCS, Cloud SQL, Firestore, Memorystore
- **Security:** Secret Manager, KMS, Cloud Armor, IAM
- **Monitoring:** Cloud Monitoring, Cloud Logging, Error Reporting

### Development Tools

- **Version Control:** Git with protected main branch
- **Code Review:** Pull requests with automated checks
- **Local Development:** tfenv for Terraform version management
- **Pre-commit Hooks:** terraform fmt, validate, docs, security scans

## General Coding Guidelines

### Clean Code Principles

- **Readability First:** Infrastructure code must be self-documenting and clear
  to operators.
- **Meaningful Names:** Use descriptive resource names that reflect purpose and
  environment.
- **Single Responsibility:** Each module should manage one logical
  infrastructure component.
- **Small Modules:** Keep modules focused with clear inputs and outputs.
- **No Magic Values:** Use variables and locals instead of hardcoded values.
- **Avoid Deep Nesting:** Use flat module structures and explicit dependencies.

### Code Organization

- **Consistent Structure:** Follow standardized file naming conventions.
- **Separation of Concerns:** Keep resource definitions separate from data
  sources and variables.
- **Module Composition:** Build complex infrastructure from simple, reusable
  modules.
- **Environment Isolation:** Separate configurations for dev, staging, and
  production.

### Standard File Structure

Every Terraform module/root MUST follow this structure:

```
module-name/
├── main.tf           # Primary resource definitions
├── variables.tf      # Input variable declarations
├── outputs.tf        # Output value declarations
├── versions.tf       # Terraform and provider version constraints
├── locals.tf         # Local value computations (optional)
├── data.tf           # Data source definitions (optional)
├── README.md         # Module documentation
└── examples/         # Usage examples
    └── basic/
        ├── main.tf
        └── variables.tf
```

### Error Handling

- **Input Validation:** Use variable validation rules to catch errors early.
- **Preconditions:** Implement lifecycle preconditions for resource
  dependencies.
- **Fail Fast:** Validate configuration during plan phase, not apply.
- **Error Messages:** Provide actionable error messages with context.

### Documentation Standards

- **Module Documentation:** Every module MUST have a comprehensive README.
- **Variable Documentation:** All variables must have clear descriptions.
- **Output Documentation:** Document what each output represents and its usage.
- **Architecture Diagrams:** Include diagrams for complex infrastructure setups.

### Project Language Requirement

- **English for code and docs (REQUIRED):** Regardless of the natural language a
  user speaks when interacting with contributors or tools, all project-facing
  text must use English. This includes:

  - Documentation and README content
  - Inline comments and descriptions
  - Resource names, variable names, output names, and module names
  - Commit messages and code review comments
  - Tags, labels, and metadata where project conventions apply

  This rule ensures consistency across the codebase, improves discoverability
  for international contributors, and enables reliable tooling (linters,
  analyzers, and cloud provider interfaces). Use English even when writing
  examples or naming conventions; if localized strings are required for end-user
  facing resources, keep the canonical infrastructure code in English and add
  separate localized metadata.

## ServiceNow AI Agent Architecture

### System Overview

This project deploys a production-ready AI agent system that integrates with
ServiceNow for automated ticket management, intelligent responses, and workflow
automation. The architecture emphasizes security, scalability, and
cost-effectiveness through hybrid LLM routing.

### Microservices Architecture

The system consists of 10 specialized microservices, each with dedicated
Workload Identity:

1. **conversation-manager** - Orchestrates conversation flow, maintains context,
   manages dialogue state
2. **llm-gateway** - LLM API integration, rate limiting, request routing,
   response caching
3. **knowledge-base** - Vector search, document retrieval, RAG pipeline,
   embeddings management
4. **ticket-monitor** - ServiceNow ticket monitoring, webhook handling, event
   processing
5. **action-executor** - Execute actions in ServiceNow (create/update tickets,
   trigger workflows)
6. **notification-service** - Multi-channel notifications (Slack, email, Teams),
   alert management
7. **internal-web-ui** - Administrative dashboard, monitoring, configuration
   management
8. **api-gateway** - External API endpoint, authentication, request validation,
   rate limiting
9. **analytics-service** - Usage analytics, reporting, metrics aggregation, cost
   tracking
10. **document-ingestion** - Document processing pipeline, text extraction,
    chunking, embedding generation

### Kubernetes Architecture

- **Namespace Strategy:** Separate namespaces for dev, staging, production
- **Node Pools:**
  - General pool (2-10 nodes): API services, web UI, monitoring
  - AI pool (1-5 nodes): LLM inference, embedding generation
  - Vector pool (1-5 nodes): Vector search, similarity matching
- **Workload Identity:** Each service has its own Kubernetes ServiceAccount
  linked to GCP service account
- **Network Policies:** Default-deny with explicit allow rules between services
- **Pod Security:** Restricted profile (non-root, read-only filesystem, no
  privilege escalation)

### LLM Serving Strategy (Hybrid Routing)

The system uses intelligent routing to optimize cost and performance:

#### Self-hosted (KServe + vLLM)

- **Models:** Mistral-7B, CodeLlama-13B
- **Infrastructure:** GPU-enabled nodes, disaggregated serving
- **Cost:** ~$0.01 per 1M tokens
- **Use Cases:** Simple queries, code generation, summarization
- **Performance:** 50% faster for queries under 50K tokens

#### Cloud-based LLMs

- **Vertex AI Gemini:** 1M token context window for long documents
- **OpenAI GPT-4:** Complex reasoning, creative tasks
- **Anthropic Claude:** Long-form analysis, safety-critical responses
- **Cost:** $0.50-$15 per 1M tokens
- **Use Cases:** Complex reasoning, very long context, specialized tasks

#### Routing Logic

```python
# Automatic model selection based on request characteristics
if token_count < 50000 and complexity == "simple":
    route_to = "self-hosted-mistral"  # 70% of queries
elif token_count > 100000:
    route_to = "vertex-ai-gemini"     # Long context
elif requires_reasoning:
    route_to = "claude-opus"          # Complex analysis
else:
    route_to = "gpt-4-turbo"          # Default fallback
```

### Zero-Trust Security Model

- **No Service Account Keys:** All authentication via Workload Identity
- **Default-Deny Network:** VPC firewall rules and Kubernetes NetworkPolicies
- **CMEK Encryption:** Customer-managed keys for all data at rest (90-day
  rotation)
- **Private GKE Cluster:** No public endpoints, authorized networks for kubectl
- **mTLS:** Service-to-service encryption (future: Istio service mesh)
- **Binary Authorization:** Container image verification before deployment
- **Secret Management:** All secrets in GCP Secret Manager, accessed via
  Workload Identity

### Data Flow Example

```
1. ServiceNow Webhook → ticket-monitor
2. ticket-monitor → Pub/Sub topic "new-tickets"
3. conversation-manager subscribes → processes ticket
4. conversation-manager → knowledge-base (vector search)
5. knowledge-base → Vertex AI Matching Engine
6. conversation-manager → llm-gateway (generate response)
7. llm-gateway → hybrid-router → selects model
8. hybrid-router → vLLM or Vertex AI (inference)
9. conversation-manager → action-executor (update ticket)
10. action-executor → ServiceNow API
11. notification-service → Slack (notify team)
```

### Key Design Patterns

- **Event-Driven:** Pub/Sub for asynchronous communication
- **CQRS:** Separate read (Firestore) and write (Cloud SQL) paths
- **Circuit Breaker:** LLM gateway implements retry and fallback logic
- **Caching:** Redis for session state, response caching, rate limit tracking
- **Observability:** Cloud Logging, Cloud Monitoring, structured logs with trace
  IDs

### Module Relationships

```
vpc → gke, cloudsql, redis
kms → storage, cloudsql, secret_manager
gke → workload_identity (per-service)
workload_identity_federation → GitHub Actions CI/CD
vertex_ai → knowledge-base service
pubsub → event routing between services
```

### Environment-Specific Configurations

- **Dev:** Zonal GKE (europe-west2-a), minimal node pools, relaxed security for
  testing
- **Staging:** Regional GKE (europe-west2), production-like config, reduced
  capacity
- **Prod:** Regional GKE (europe-west2), full HA, all security features,
  monitoring/alerting

### Commit Message Standard

- **Conventional Commits (REQUIRED):** This project uses the Conventional
  Commits specification for commit messages. Commit messages must follow the
  format:

  - <type>(<scope>): <short description>
  - Optionally include a longer body and/or footer for references (breaking
    changes, issue numbers).

  Common types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`,
  `build`, `ci`, `chore`, `revert`.

  Example:

  - feat(networking): add private service connect endpoint
  - fix(gke): update cluster version to address CVE-2024-1234
  - docs(storage): add bucket lifecycle policy examples

  Following this convention enables automated changelog generation, semantic
  versioning tools, and clearer git history.

  Brief rules (self-contained):

  - A commit message MUST start with a type, optionally a scope, then a short
    description.
  - Types indicate the kind of change (e.g., `feat`, `fix`, `docs`, `style`,
    `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`).
  - The scope is optional and should be a noun describing the infrastructure
    area affected (e.g., `networking`, `compute`, `storage`, `iam`).
  - An optional body may follow after a blank line to explain motivation and
    impact.
  - Breaking changes MUST be indicated in the footer with
    `BREAKING CHANGE: <description>`.
  - Multiple line footer entries can reference issues or metadata (e.g.,
    `Closes #123`, `Ref: PROJECT-456`).

### Testing Requirements

- **Test Coverage:** All modules must have example configurations that serve as
  tests.
- **Integration Tests:** Use Terratest for critical infrastructure components.
- **Validation Tests:** Run `terraform validate` and `terraform plan` in CI/CD.
- **Security Tests:** Automated security scanning on every pull request.

### Performance Considerations

- **State Management:** Use remote state with locking to prevent concurrent
  modifications.
- **Resource Creation:** Use `count` and `for_each` efficiently to avoid state
  bloat.
- **API Rate Limits:** Be mindful of GCP API quotas and implement retry logic.
- **Parallel Execution:** Leverage Terraform's parallelism where safe.

## Terraform Best Practices

### Resource Naming Conventions

```hcl
# Pattern: {project}-{environment}-{resource-type}-{purpose}-{index}
# Examples:
resource "google_compute_instance" "web_server" {
  name = "${var.project_id}-${var.environment}-vm-web-01"
}

resource "google_storage_bucket" "data_lake" {
  name = "${var.project_id}-${var.environment}-gcs-datalake"
}
```

### Variable Definitions

```hcl
# Always include: description, type, validation
variable "project_id" {
  description = "The GCP project ID where resources will be created"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Project ID must be 6-30 characters, start with a letter, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "region" {
  description = "The GCP region for resource deployment"
  type        = string
  default     = "us-central1"

  validation {
    condition     = contains(["us-central1", "us-east1", "europe-west1", "asia-southeast1"], var.region)
    error_message = "Region must be one of the approved regions for this organization."
  }
}
```

### Output Definitions

```hcl
# Include description and mark sensitive data appropriately
output "instance_ip" {
  description = "The external IP address of the compute instance"
  value       = google_compute_instance.web_server.network_interface[0].access_config[0].nat_ip
}

output "database_connection_name" {
  description = "The connection name for Cloud SQL instance"
  value       = google_sql_database_instance.main.connection_name
  sensitive   = false
}

output "database_password" {
  description = "The database root password (sensitive)"
  value       = random_password.db_password.result
  sensitive   = true
}
```

### Module Usage Pattern

```hcl
# Use semantic versioning for module sources
module "vpc" {
  source  = "terraform-google-modules/network/google"
  version = "~> 9.0"

  project_id   = var.project_id
  network_name = "${var.project_id}-${var.environment}-vpc"
  routing_mode = "GLOBAL"

  subnets = [
    {
      subnet_name           = "subnet-01"
      subnet_ip             = "10.10.10.0/24"
      subnet_region         = var.region
      subnet_private_access = "true"
    }
  ]
}
```

### Security Best Practices

```hcl
# Example: Secure GCS bucket configuration
resource "google_storage_bucket" "secure_bucket" {
  name     = "${var.project_id}-${var.environment}-secure-data"
  location = var.region

  # Enable versioning for data recovery
  versioning {
    enabled = true
  }

  # Encrypt with customer-managed key
  encryption {
    default_kms_key_name = google_kms_crypto_key.bucket_key.id
  }

  # Enable uniform bucket-level access
  uniform_bucket_level_access = true

  # Prevent public access
  public_access_prevention = "enforced"

  # Lifecycle rules
  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  # Prevent accidental deletion
  lifecycle {
    prevent_destroy = true
  }
}
```

### IAM Management

```hcl
# Use authoritative bindings for critical roles
resource "google_project_iam_binding" "project_editors" {
  project = var.project_id
  role    = "roles/editor"
  members = var.project_editors

  condition {
    title       = "expires_after_2025"
    description = "Expiring at end of 2025"
    expression  = "request.time < timestamp(\"2026-01-01T00:00:00Z\")"
  }
}

# Use non-authoritative members for additive permissions
resource "google_project_iam_member" "service_account_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.app.email}"
}
```

### Tagging and Labeling

```hcl
# Standard labels for all resources
locals {
  common_labels = {
    environment = var.environment
    managed_by  = "terraform"
    project     = var.project_id
    cost_center = var.cost_center
    owner       = var.owner_email
  }
}

resource "google_compute_instance" "app_server" {
  name = "${var.project_id}-${var.environment}-vm-app"

  labels = merge(
    local.common_labels,
    {
      role = "application-server"
      tier = "frontend"
    }
  )
}
```

## Kubernetes Best Practices

### Manifest Organization

```
k8s/
├── deployments/          # Deployment manifests for microservices
├── service-accounts/     # ServiceAccounts with Workload Identity annotations
├── network-policies/     # NetworkPolicy resources for zero-trust networking
├── pod-security/         # Pod Security Standards enforcement
├── services/             # Service definitions
├── ingress/              # Ingress resources
└── llm-serving/          # KServe InferenceService and LLM configs
    ├── kserve-runtime.yaml
    ├── foundational-models.yaml
    └── hybrid-routing.yaml
```

### Workload Identity Pattern

Every microservice MUST use Workload Identity for GCP authentication:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: conversation-manager-sa
  namespace: production
  annotations:
    # Link to GCP service account
    iam.gke.io/gcp-service-account: conversation-manager@PROJECT_ID.iam.gserviceaccount.com
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: conversation-manager
  namespace: production
spec:
  template:
    spec:
      # Use the ServiceAccount
      serviceAccountName: conversation-manager-sa
      containers:
        - name: conversation-manager
          image: gcr.io/PROJECT_ID/conversation-manager:latest
          # No need for service account keys!
```

**Terraform side:**

```hcl
# Create GCP service account
module "conversation_manager_wi" {
  source = "../../modules/workload_identity"

  project_id         = var.project_id
  service_account_id = "conversation-manager"
  roles = [
    "roles/cloudsql.client",
    "roles/secretmanager.secretAccessor",
    "roles/pubsub.publisher"
  ]
  k8s_namespace      = "production"
  k8s_service_account = "conversation-manager-sa"
}
```

### Network Policy Pattern

ALWAYS implement default-deny network policies:

```yaml
# Default deny all traffic
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
---
# Allow specific traffic
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: conversation-manager-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: conversation-manager
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: api-gateway
      ports:
        - protocol: TCP
          port: 8080
  egress:
    # Allow DNS
    - to:
        - namespaceSelector:
            matchLabels:
              name: kube-system
      ports:
        - protocol: UDP
          port: 53
    # Allow Cloud SQL
    - to:
        - podSelector:
            matchLabels:
              app: cloud-sql-proxy
      ports:
        - protocol: TCP
          port: 5432
    # Allow llm-gateway
    - to:
        - podSelector:
            matchLabels:
              app: llm-gateway
      ports:
        - protocol: TCP
          port: 8080
```

### Pod Security Standards

All pods MUST follow the restricted profile:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: conversation-manager
spec:
  template:
    spec:
      # Required: Run as non-root
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: conversation-manager
          securityContext:
            # Required: No privilege escalation
            allowPrivilegeEscalation: false
            # Required: Read-only root filesystem
            readOnlyRootFilesystem: true
            # Required: Drop all capabilities
            capabilities:
              drop:
                - ALL
          # Required: Resource limits
          resources:
            requests:
              memory: '256Mi'
              cpu: '100m'
            limits:
              memory: '512Mi'
              cpu: '500m'
          # Use emptyDir for temporary writes
          volumeMounts:
            - name: tmp
              mountPath: /tmp
      volumes:
        - name: tmp
          emptyDir: {}
```

### Service Naming Convention

```yaml
# Pattern: {service-name}-{type}
# Examples:
apiVersion: v1
kind: Service
metadata:
  name: conversation-manager-svc
  namespace: production
  labels:
    app: conversation-manager
    environment: production
    managed-by: terraform
---
# Internal service (ClusterIP)
spec:
  type: ClusterIP
  selector:
    app: conversation-manager
  ports:
    - name: http
      port: 8080
      targetPort: 8080
```

### ConfigMap and Secret Management

```yaml
# ConfigMap for non-sensitive config
apiVersion: v1
kind: ConfigMap
metadata:
  name: conversation-manager-config
  namespace: production
data:
  LOG_LEVEL: 'info'
  MAX_CONTEXT_LENGTH: '8192'
  CACHE_TTL: '3600'
---
# NEVER put secrets in ConfigMaps!
# Use Secret Manager + Workload Identity instead
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
        - name: conversation-manager
          env:
            # Config from ConfigMap
            - name: LOG_LEVEL
              valueFrom:
                configMapKeyRef:
                  name: conversation-manager-config
                  key: LOG_LEVEL
            # Secrets from GCP Secret Manager (via app code)
            # App uses Workload Identity to access secrets
            - name: GCP_PROJECT_ID
              value: 'my-project'
```

### Health Checks

ALWAYS implement proper health checks:

```yaml
spec:
  containers:
    - name: conversation-manager
      livenessProbe:
        httpGet:
          path: /healthz
          port: 8080
        initialDelaySeconds: 30
        periodSeconds: 10
        timeoutSeconds: 5
        failureThreshold: 3
      readinessProbe:
        httpGet:
          path: /ready
          port: 8080
        initialDelaySeconds: 10
        periodSeconds: 5
        timeoutSeconds: 3
        failureThreshold: 3
      startupProbe:
        httpGet:
          path: /startup
          port: 8080
        initialDelaySeconds: 0
        periodSeconds: 5
        timeoutSeconds: 3
        failureThreshold: 30
```

### KServe InferenceService Pattern

For LLM serving with KServe and vLLM:

```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: mistral-7b
  namespace: production
spec:
  predictor:
    serviceAccountName: llm-gateway-sa
    containers:
      - name: vllm
        image: vllm/vllm-openai:latest
        command:
          - python3
          - -m
          - vllm.entrypoints.openai.api_server
        args:
          - --model=mistralai/Mistral-7B-Instruct-v0.2
          - --dtype=auto
          - --max-model-len=8192
          - --tensor-parallel-size=1
        resources:
          requests:
            nvidia.com/gpu: 1
            memory: '16Gi'
          limits:
            nvidia.com/gpu: 1
            memory: '16Gi'
        env:
          - name: HUGGING_FACE_HUB_TOKEN
            valueFrom:
              secretKeyRef:
                name: hf-token
                key: token
    nodeSelector:
      cloud.google.com/gke-nodepool: ai-pool
    tolerations:
      - key: 'nvidia.com/gpu'
        operator: 'Exists'
        effect: 'NoSchedule'
```

### HorizontalPodAutoscaler

Implement autoscaling for production workloads:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: conversation-manager-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: conversation-manager
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Percent
          value: 50
          periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
        - type: Percent
          value: 100
          periodSeconds: 30
        - type: Pods
          value: 2
          periodSeconds: 30
      selectPolicy: Max
```

### Kubernetes Validation

- **KubeLinter:** Run `kube-linter lint k8s/` before committing
- **Pre-commit:** KubeLinter runs automatically via pre-commit hooks
- **Required Checks:**
  - No privileged containers
  - Resource limits defined
  - Non-root user
  - Read-only root filesystem
  - Health checks present
  - No latest image tags in production

## Architecture Patterns

### Environment Structure

```
terraform/
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   ├── staging/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   └── prod/
│       ├── main.tf
│       ├── variables.tf
│       ├── terraform.tfvars
│       └── backend.tf
├── modules/
│   ├── networking/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── versions.tf
│   │   └── README.md
│   ├── compute/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── versions.tf
│   │   └── README.md
│   └── database/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── versions.tf
│       └── README.md
├── global/
│   ├── iam/
│   ├── dns/
│   └── monitoring/
└── scripts/
    ├── init-backend.sh
    ├── plan.sh
    └── apply.sh
```

### Backend Configuration Pattern

```hcl
# backend.tf - Environment-specific state configuration
terraform {
  backend "gcs" {
    bucket = "PROJECT_ID-terraform-state"
    prefix = "env/ENVIRONMENT_NAME"
  }
}
```

### Provider Configuration Pattern

```hcl
# versions.tf - Version constraints and provider configuration
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}
```

### Multi-Region Deployment

```hcl
# Use for_each for multi-region resources
locals {
  regions = {
    primary   = "us-central1"
    secondary = "europe-west1"
    tertiary  = "asia-southeast1"
  }
}

module "regional_deployment" {
  source   = "./modules/regional-app"
  for_each = local.regions

  project_id  = var.project_id
  region      = each.value
  environment = var.environment
  is_primary  = each.key == "primary"
}
```

### Workspace Strategy

- **Avoid Workspaces:** Prefer separate state files per environment
- **Directory Structure:** Use directory-based environment separation
- **State Isolation:** Each environment has its own backend configuration
- **Variable Management:** Environment-specific tfvars files

### CI/CD Integration

```yaml
# Example GitHub Actions workflow structure
name: Terraform CI/CD

on:
  pull_request:
    paths:
      - 'terraform/**'
  push:
    branches:
      - main
    paths:
      - 'terraform/**'

jobs:
  validate:
    # Format, validate, security scan, plan

  deploy-dev:
    # Automatic deployment to dev

  deploy-staging:
    # Manual approval for staging

  deploy-prod:
    # Manual approval + change review for production
```

### Disaster Recovery

- **State Backups:** Automated state file backups with versioning
- **Plan Archives:** Store approved plan files for audit trail
- **Rollback Strategy:** Maintain previous working configurations
- **Documentation:** Keep infrastructure diagrams and runbooks updated

The following instructions are only to be applied when performing a code review.

## README updates

- [ ] The new file should be added to the `README.md`.

## Prompt file guide

**Only apply to files that end in `.prompt.md`**

- [ ] The prompt has markdown front matter.
- [ ] The prompt has a `mode` field specified of either `agent` or `ask`.
- [ ] The prompt has a `description` field.
- [ ] The `description` field is not empty.
- [ ] The `description` field value is wrapped in single quotes.
- [ ] The file name is lower case, with words separated by hyphens.
- [ ] Encourage the use of `tools`, but it's not required.
- [ ] Strongly encourage the use of `model` to specify the model that the prompt
      is optimised for.

## Instruction file guide

**Only apply to files that end in `.instructions.md`**

- [ ] The instruction has markdown front matter.
- [ ] The instruction has a `description` field.
- [ ] The `description` field is not empty.
- [ ] The `description` field value is wrapped in single quotes.
- [ ] The file name is lower case, with words separated by hyphens.
- [ ] The instruction has an `applyTo` field that specifies the file or files to
      which the instructions apply. If they wish to specify multiple file paths
      they should formated like `'**.js, **.ts'`.

## Chat Mode file guide

**Only apply to files that end in `.chatmode.md`**

- [ ] The chat mode has markdown front matter.
- [ ] The chat mode has a `description` field.
- [ ] The `description` field is not empty.
- [ ] The `description` field value is wrapped in single quotes.
- [ ] The file name is lower case, with words separated by hyphens.
- [ ] Encourage the use of `tools`, but it's not required.
- [ ] Strongly encourage the use of `model` to specify the model that the chat
      mode is optimised for.
