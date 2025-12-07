# Terraform Assistant Guide

This guide provides the exact patterns, templates, and commands for Terraform in
this repository.

## Scope and Structure

- Root: `terraform/`
- Environments: `terraform/environments/{dev,staging,prod}`
- Modules: `terraform/modules/*`
- Shared: `terraform/shared/*`
- Docs: `terraform/docs/*`
- Ops notes: `terraform/ops.md`

## Version Policy (Latest Required)

- Terraform: Always target the latest stable major series and keep patch/minor
  up to date. Policy: `>= 1.11.0, < 2.0.0` (update lower bound when new majors
  are adopted).
- Providers: Use the latest stable provider releases. Prefer compatible ranges
  that auto-adopt patch/minor updates:
  - google: `~> 7.0`
  - google-beta: `~> 7.0`
  - random: `~> 3.5`
- When bumping to a new major, perform a full validation cycle (fmt, validate,
  plan, scans) in `dev` first.

### Upgrade Steps

- Update constraints in `versions.tf` (root and modules) to the latest
  compatible ranges.
- In dev environment, run:
  - `terraform init -upgrade`
  - `terraform fmt -recursive`
  - `terraform validate`
  - `terraform plan`
- Address any deprecations noted by providers; document changes in module
  `README.md`.

## Versions and Providers

- Terraform >= 1.11.0
- Providers: google (~> 7.0), google-beta (~> 7.0), random (~> 3.5)
- Define providers in `versions.tf` (root and modules must pin constraints).

Provider template:

```
terraform {
  required_version = ">= 1.11.0, < 2.0.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 7.0"
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

## Backend Configuration

Use a GCS backend per environment via `backend.tf` in each env directory:

```
terraform {
  backend "gcs" {
    bucket = "PROJECT_ID-terraform-state"
    prefix = "env/ENVIRONMENT_NAME"
  }
}
```

Replace `PROJECT_ID` and `ENVIRONMENT_NAME` via env-specific vars or scripts in
`terraform/scripts/`.

## Module Layout (Required)

Each module must include:

- `main.tf` — resources
- `variables.tf` — inputs with type + validation + description
- `outputs.tf` — outputs with description; mark `sensitive` when needed
- `versions.tf` — constraints and providers
- `locals.tf` — optional
- `data.tf` — optional
- `README.md` — usage, inputs/outputs table
- `examples/basic/main.tf` and `examples/basic/variables.tf`

## Naming Conventions

```
# {project}-{environment}-{resource-type}-{purpose}-{index}
name = "${var.project_id}-${var.environment}-vm-web-01"
```

Use `locals.common_labels` for labels across resources:

```
locals {
  common_labels = {
    environment = var.environment
    managed_by  = "terraform"
    project     = var.project_id
    cost_center = var.cost_center
    owner       = var.owner_email
  }
}
```

## Variables (with validation)

```
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

## Outputs

```
output "database_connection_name" {
  description = "The connection name for Cloud SQL instance"
  value       = google_sql_database_instance.main.connection_name
}
```

Mark secrets with `sensitive = true`.

## Security Practices

- No service account keys. Use Workload Identity only.
- Buckets: CMEK, UBUA, public access prevention.
- `prevent_destroy` for critical resources.
- Authoritative bindings for critical roles; additive members for extras.
- IAM conditions for time-bound access.

## Environment Strategy

- Dev: europe-west2-a (zonal), minimal node pools.
- Staging: europe-west2 (regional), reduced capacity.
- Prod: europe-west2 (regional), HA and full security/monitoring.
  Keep isolation via per-env backend and `terraform.tfvars`.

## Multi-Region Pattern

```
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

## CI/CD and Validation

- Run `terraform fmt`, `terraform validate`, `tflint`.
- Keep providers current: `terraform init -upgrade` in dev after constraint
  changes.
- Security: Checkov, tfsec, Trivy.
- Docs: terraform-docs.
- Plans: create and store plan files for review.
- Use `Makefile` targets and scripts in `terraform/scripts/` where available.

## Testing

- Examples serve as smoke tests.
- Terratest for critical components (Cloud SQL, GKE, IAM, KMS).
- In CI: `terraform plan` must succeed; scans must pass.

## ServiceNow Integration Notes

- Reference `servicenow/` for flows, rules, scripted REST.
- Ensure IAM permissions for ServiceNow webhook receivers and Pub/Sub topics.
- Observe event routing patterns in `docs/SERVICENOW_INTEGRATION.md`.

## AWS Parity

This guide focuses on GCP. For AWS parity and mapping, see `aws-infrastructure/`
and `docs/GCP_TO_AWS_MAPPING.md`.
