# Cloud Run Module

Terraform module for deploying serverless containers on Google Cloud Run with integrated security, monitoring, and IAP protection.

## Overview

This module deploys a Cloud Run service configured for:

- **Internal-only access** - Service accessible only through Load Balancer
- **IAP protection** - Identity-Aware Proxy for authentication
- **VPC connectivity** - Private access to VPC resources
- **Secret management** - Integration with Secret Manager
- **Auto-scaling** - Automatic instance scaling based on load
- **Service account** - Dedicated IAM identity with least privilege

## Usage

### Basic Example

```hcl
module "cloud_run_service" {
  source = "../../modules/cloud_run"

  project_id   = var.project_id
  region       = var.region
  service_name = "ai-research-assistant"
  image        = "gcr.io/my-project/my-app:latest"

  vpc_connector = module.vpc.serverless_connector

  environment_variables = {
    NODE_ENV = "production"
    PORT     = "8080"
  }

  secret_environment_variables = {
    API_KEY = {
      secret  = "api-key-secret"
      version = "latest"
    }
  }
}
```

### Complete Example with IAP

```hcl
module "cloud_run_backend" {
  source = "../../modules/cloud_run"

  project_id   = var.project_id
  region       = "europe-west2"
  service_name = "research-assistant-backend"
  image        = "gcr.io/${var.project_id}/research-assistant-backend:latest"

  # VPC Configuration
  vpc_connector = google_vpc_access_connector.serverless.id

  # Scaling
  min_instances = 1
  max_instances = 10

  # Service Account
  create_service_account = true
  service_account_roles = [
    "roles/secretmanager.secretAccessor",
    "roles/firestore.user"
  ]

  # Environment Variables
  environment_variables = {
    NODE_ENV     = "production"
    PORT         = "8080"
    PROJECT_ID   = var.project_id
  }

  # Secrets from Secret Manager
  secret_environment_variables = {
    OPENAI_API_KEY = {
      secret  = google_secret_manager_secret.openai_key.secret_id
      version = "latest"
    }
    ANTHROPIC_API_KEY = {
      secret  = google_secret_manager_secret.anthropic_key.secret_id
      version = "latest"
    }
  }

  # IAP Members
  iap_members = [
    "user:admin@example.com",
    "group:developers@example.com"
  ]

  # Labels
  labels = {
    environment = "production"
    application = "ai-research-assistant"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `project_id` | GCP project ID | `string` | - | yes |
| `region` | GCP region for Cloud Run service | `string` | - | yes |
| `service_name` | Name of the Cloud Run service | `string` | - | yes |
| `image` | Container image URL | `string` | - | yes |
| `vpc_connector` | VPC Serverless Connector ID | `string` | - | yes |
| `min_instances` | Minimum number of instances | `number` | `0` | no |
| `max_instances` | Maximum number of instances | `number` | `100` | no |
| `environment_variables` | Environment variables as key-value pairs | `map(string)` | `{}` | no |
| `secret_environment_variables` | Secret Manager environment variables | `map(object)` | `{}` | no |
| `create_service_account` | Whether to create a new service account | `bool` | `false` | no |
| `service_account_email` | Existing service account email (if not creating) | `string` | `null` | no |
| `service_account_roles` | IAM roles to grant to service account | `list(string)` | `[]` | no |
| `iap_members` | List of IAM members for IAP access | `list(string)` | `[]` | no |
| `labels` | Resource labels | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `service_name` | Cloud Run service name |
| `service_url` | Cloud Run service URL |
| `service_account_email` | Service account email address |
| `service_id` | Full Cloud Run service ID |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Internet / Users                         │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│               Load Balancer + IAP                            │
│  (Identity-Aware Proxy for Authentication)                  │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│           Cloud Run Service (Internal Ingress)               │
│  ┌────────────────────────────────────────────────┐         │
│  │    Container (Serverless)                       │         │
│  │    - Auto-scaling: 0-100 instances              │         │
│  │    - Service Account Identity                   │         │
│  │    - Environment Variables                      │         │
│  │    - Secret Manager Integration                 │         │
│  └────────────────────────────────────────────────┘         │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│            VPC Serverless Connector                          │
│  (Private access to VPC resources)                          │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                VPC Resources                                 │
│  - Cloud SQL                                                 │
│  - Firestore                                                 │
│  - Redis                                                     │
│  - Other private services                                    │
└─────────────────────────────────────────────────────────────┘
```

## Features

### Security

- ✅ **Internal-only ingress** - No direct internet access to service
- ✅ **IAP authentication** - Identity verification before access
- ✅ **Service account identity** - Least-privilege IAM roles
- ✅ **Secret Manager integration** - Secure credential management
- ✅ **VPC egress control** - Private-only network egress

### Scalability

- ✅ **Auto-scaling** - Scales from 0 to configured max instances
- ✅ **Configurable concurrency** - Control requests per instance
- ✅ **Cold start optimization** - Min instances for faster response

### Observability

- ✅ **Cloud Logging** - Automatic log collection
- ✅ **Cloud Monitoring** - Metrics and dashboards
- ✅ **Cloud Trace** - Request tracing

## Security Considerations

### IAP Configuration

The module automatically configures IAP for the Cloud Run service. Ensure you:

1. Add appropriate members to `iap_members` variable
2. Use groups for team-based access
3. Regularly audit IAP access logs

### Service Account Permissions

The service account is granted only necessary roles:

```hcl
service_account_roles = [
  "roles/secretmanager.secretAccessor",  # Read secrets
  "roles/firestore.user",                # Access Firestore
  "roles/cloudsql.client"                # Connect to Cloud SQL
]
```

### Secrets Management

Never put secrets in environment variables directly. Use Secret Manager:

```hcl
secret_environment_variables = {
  API_KEY = {
    secret  = "my-secret-name"
    version = "latest"  # Or specific version like "1"
  }
}
```

## Cost Optimization

Cloud Run pricing is based on:

- **CPU and Memory** - Per 100ms of execution time
- **Requests** - Per million requests
- **Networking** - Egress traffic

### Cost-Saving Tips

1. **Set min_instances = 0** for dev/staging to avoid idle costs
2. **Use appropriate CPU/memory** - Don't over-provision
3. **Enable VPC egress control** - Reduce NAT gateway costs
4. **Use request timeout** - Prevent long-running requests

### Estimated Costs

| Configuration | Monthly Cost (estimate) |
|---------------|-------------------------|
| Dev (0 min instances, low traffic) | $5-20 |
| Staging (1 min instance, medium traffic) | $30-80 |
| Production (2 min instances, high traffic) | $100-500 |

## Monitoring

### Key Metrics

- **Request Count** - Total requests per second
- **Request Latency** - p50, p95, p99 latencies
- **Container Instance Count** - Active instances
- **Error Rate** - 4xx and 5xx errors
- **CPU Utilization** - Container CPU usage
- **Memory Utilization** - Container memory usage

### Example Monitoring Query

```sql
# Cloud Logging query for errors
resource.type="cloud_run_revision"
resource.labels.service_name="ai-research-assistant"
severity>=ERROR
```

## Testing

### Test with curl

```bash
# Get IAP token
gcloud auth print-identity-token

# Test service
curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  https://your-service-url.run.app/api/health
```

### Local Testing

```bash
# Run container locally
docker run -p 8080:8080 \
  -e NODE_ENV=development \
  -e PORT=8080 \
  gcr.io/your-project/your-image:latest

# Test locally
curl http://localhost:8080/api/health
```

## Troubleshooting

### Service Not Accessible

1. Check IAP configuration and member permissions
2. Verify VPC connector is created and healthy
3. Ensure Load Balancer is properly configured
4. Check service account IAM bindings

### Container Crashes

```bash
# View logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=your-service" --limit 50 --format json

# Check revision status
gcloud run revisions list --service your-service --region europe-west2
```

### High Latency

1. Increase min_instances to reduce cold starts
2. Check VPC connector capacity
3. Review container CPU/memory allocation
4. Enable Cloud CDN if serving static content

## Related Documentation

- [docs/AI_RESEARCH_ASSISTANT.md](../../../docs/AI_RESEARCH_ASSISTANT.md) - Complete deployment guide
- [Google Cloud Run Documentation](https://cloud.google.com/run/docs)
- [IAP Documentation](https://cloud.google.com/iap/docs)
- [VPC Serverless Access](https://cloud.google.com/vpc/docs/serverless-vpc-access)

## Example Deployments

See the AI Research Assistant deployment for a complete working example:

- Frontend: [docs/AI_RESEARCH_ASSISTANT.md](../../../docs/AI_RESEARCH_ASSISTANT.md)
- Backend API integration
- IAP configuration
- Load balancer setup

## Version Compatibility

- Terraform >= 1.11.0
- Google Provider >= 7.10.0
- Cloud Run API v2

## License

Same as parent project license.
