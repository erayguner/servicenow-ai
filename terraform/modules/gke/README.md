# GKE (Google Kubernetes Engine) Module

Terraform module for creating a production-ready, private GKE cluster with multiple node pools and security hardening.

## Features

- ✅ **Private cluster** - Private nodes, optionally private endpoint
- ✅ **Workload Identity** - Pod-to-GCP service account authentication
- ✅ **Binary Authorization** - Container image verification
- ✅ **Network Policy** - Pod-to-pod traffic control
- ✅ **Autopilot or Standard** - Flexible cluster mode
- ✅ **Multiple node pools** - General, AI workloads, vector search
- ✅ **Autoscaling** - Dynamic node scaling per pool
- ✅ **Release channels** - Managed Kubernetes version updates
- ✅ **Security hardening** - Shielded nodes, secure boot, integrity monitoring

## Usage

### Basic Example

```hcl
module "gke" {
  source = "../../modules/gke"

  project_id  = "my-project-id"
  region      = "europe-west2"
  network     = module.vpc.network_name
  subnetwork  = module.vpc.subnetwork_name

  cluster_name = "my-gke-cluster"
  environment  = "dev"

  # Node pool sizing
  general_pool_size = { min = 1, max = 5 }
  ai_pool_size      = { min = 0, max = 3 }
  vector_pool_size  = { min = 0, max = 2 }

  # Networking
  subnetwork_name          = "gke-subnet"
  master_ipv4_cidr_block   = "172.16.0.0/28"

  # Optional: Authorize specific IPs to access control plane
  authorized_master_cidrs = [
    {
      cidr_block   = "203.0.113.0/24"
      display_name = "office-network"
    }
  ]

  labels = {
    environment = "dev"
    managed_by  = "terraform"
  }
}
```

### Regional Cluster (High Availability)

```hcl
module "gke_prod" {
  source = "../../modules/gke"

  project_id  = "prod-project-id"
  region      = "europe-west2"  # Regional cluster across 3 zones
  network     = module.vpc.network_name
  subnetwork  = module.vpc.subnetwork_name

  cluster_name    = "prod-gke-cluster"
  environment     = "prod"
  release_channel = "STABLE"  # More conservative updates

  # Higher node counts for production
  general_pool_size = { min = 3, max = 10 }
  ai_pool_size      = { min = 2, max = 8 }
  vector_pool_size  = { min = 1, max = 5 }

  # Security: Private endpoint
  master_ipv4_cidr_block = "172.16.0.0/28"
  authorized_master_cidrs = [
    {
      cidr_block   = "10.0.0.0/8"  # Internal VPN only
      display_name = "internal-vpn"
    }
  ]

  labels = {
    environment = "production"
    managed_by  = "terraform"
    compliance  = "pci-dss"
  }
}
```

### Zonal Cluster (Cost-Optimized)

```hcl
# For development/testing - lower cost, single zone
module "gke_dev" {
  source = "../../modules/gke"

  project_id  = "dev-project-id"
  region      = "europe-west2-a"  # Zonal cluster
  network     = module.vpc.network_name
  subnetwork  = module.vpc.subnetwork_name

  cluster_name    = "dev-gke-cluster"
  environment     = "dev"
  release_channel = "RAPID"  # Get latest features

  # Minimal for dev
  general_pool_size = { min = 1, max = 3 }
  ai_pool_size      = { min = 0, max = 2 }
  vector_pool_size  = { min = 0, max = 1 }

  master_ipv4_cidr_block = "172.16.0.0/28"
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `project_id` | GCP project ID | `string` | - | yes |
| `region` | GCP region or zone (zone for zonal cluster) | `string` | - | yes |
| `network` | VPC network name | `string` | - | yes |
| `subnetwork` | VPC subnetwork name | `string` | - | yes |
| `subnetwork_name` | Subnetwork name for secondary ranges | `string` | - | yes |
| `cluster_name` | Name of the GKE cluster | `string` | - | yes |
| `environment` | Environment name (dev, staging, prod) | `string` | `"dev"` | no |
| `release_channel` | GKE release channel (RAPID, REGULAR, STABLE) | `string` | `"REGULAR"` | no |
| `master_ipv4_cidr_block` | CIDR for GKE control plane | `string` | `"172.16.0.0/28"` | no |
| `authorized_master_cidrs` | CIDRs allowed to access control plane | `list(object)` | `[]` | no |
| `general_pool_size` | Min/max nodes for general workloads | `object({ min, max })` | - | yes |
| `ai_pool_size` | Min/max nodes for AI workloads | `object({ min, max })` | - | yes |
| `vector_pool_size` | Min/max nodes for vector search | `object({ min, max })` | - | yes |
| `labels` | Labels to apply to cluster | `map(string)` | `{}` | no |
| `tags` | Network tags for cluster nodes | `list(string)` | `[]` | no |
| `google_domain` | Google Workspace domain for RBAC | `string` | `"example.com"` | no |

## Outputs

| Name | Description | Sensitive |
|------|-------------|-----------|
| `cluster_name` | Name of the GKE cluster | no |
| `cluster_endpoint` | Control plane endpoint IP | yes |
| `cluster_ca_certificate` | Base64-encoded CA certificate | yes |
| `cluster_id` | Unique cluster identifier | no |
| `cluster_location` | Cluster region or zone | no |

## Node Pools

This module creates three specialized node pools:

### 1. General Workload Pool
- **Purpose**: Backend API, frontend, databases
- **Machine type**: `n2-standard-4` (4 vCPU, 16GB RAM)
- **Disk**: 100GB SSD
- **Autoscaling**: Configured via `general_pool_size`
- **Taints**: None

### 2. AI Workload Pool
- **Purpose**: LLM serving, ML inference
- **Machine type**: `n2-standard-8` (8 vCPU, 32GB RAM)
- **Optional GPU**: NVIDIA T4/L4
- **Disk**: 200GB SSD
- **Autoscaling**: Configured via `ai_pool_size`
- **Taints**: `workload=ai:NoSchedule`

### 3. Vector Search Pool
- **Purpose**: Vector database, embeddings
- **Machine type**: `n2-highmem-4` (4 vCPU, 32GB RAM)
- **Disk**: 100GB SSD
- **Autoscaling**: Configured via `vector_pool_size`
- **Taints**: `workload=vector:NoSchedule`

## Security Features

### Workload Identity

Enabled by default. Allows pods to authenticate as GCP service accounts:

```bash
# Kubernetes service account → GCP service account binding
kubectl annotate serviceaccount my-ksa \
  iam.gke.io/gcp-service-account=my-gsa@PROJECT.iam.gserviceaccount.com
```

### Network Policy

Calico network policy enabled for pod-to-pod traffic control:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
spec:
  podSelector: {}
  policyTypes:
    - Ingress
```

### Binary Authorization

Container image verification before deployment:

```bash
# Enable Binary Authorization
gcloud container binauthz policy import policy.yaml
```

### Private Cluster

- **Private nodes**: No external IP addresses
- **Private endpoint** (optional): Control plane not publicly accessible
- **Cloud NAT**: Nodes access internet via NAT gateway

### Shielded Nodes

All nodes use shielded VMs with:
- Secure Boot
- Virtual Trusted Platform Module (vTPM)
- Integrity Monitoring

## Networking

### IP Ranges

The module requires:
1. **Primary subnet**: Node IP addresses
2. **Secondary range (pods)**: Pod IP addresses (`gke-pods`)
3. **Secondary range (services)**: Service IP addresses (`gke-services`)

Example VPC subnet configuration:

```hcl
resource "google_compute_subnetwork" "gke" {
  name          = "gke-subnet"
  ip_cidr_range = "10.0.0.0/20"  # Primary range (nodes)
  region        = "europe-west2"
  network       = google_compute_network.vpc.id

  secondary_ip_range {
    range_name    = "gke-pods"
    ip_cidr_range = "10.4.0.0/14"  # 262,144 IPs for pods
  }

  secondary_ip_range {
    range_name    = "gke-services"
    ip_cidr_range = "10.8.0.0/20"  # 4,096 IPs for services
  }
}
```

### Control Plane Access

By default, control plane is private. Authorize specific CIDRs:

```hcl
authorized_master_cidrs = [
  {
    cidr_block   = "203.0.113.0/24"
    display_name = "office"
  },
  {
    cidr_block   = "198.51.100.0/24"
    display_name = "vpn"
  }
]
```

## Upgrades and Maintenance

### Release Channels

- **RAPID**: Newest features, ~weekly updates, early access
- **REGULAR** (default): Balanced, ~monthly updates, production-ready
- **STABLE**: Most stable, ~quarterly updates, conservative

### Maintenance Windows

Maintenance occurs automatically within configured windows:

```hcl
resource "google_container_cluster" "primary" {
  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"  # 3 AM local time
    }
  }
}
```

## Monitoring

### Cloud Logging

All cluster logs sent to Cloud Logging:
- System logs
- Application logs
- Audit logs

### Cloud Monitoring

Metrics automatically exported:
- Node CPU/memory utilization
- Pod resource usage
- Cluster autoscaler events
- Control plane metrics

### Prometheus Integration

Deploy Prometheus for custom metrics:

```bash
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/bundle.yaml
```

## Cost Optimization

### Development Environment
```hcl
# Zonal cluster (single zone)
region = "europe-west2-a"

# Minimal node counts
general_pool_size = { min = 1, max = 3 }
ai_pool_size      = { min = 0, max = 2 }  # Scale to zero when not used
vector_pool_size  = { min = 0, max = 1 }

# Estimated cost: $100-200/month
```

### Production Environment
```hcl
# Regional cluster (3 zones for HA)
region = "europe-west2"

# Higher availability
general_pool_size = { min = 3, max = 10 }
ai_pool_size      = { min = 1, max = 8 }   # Always at least 1 node
vector_pool_size  = { min = 1, max = 5 }

# Estimated cost: $500-1500/month
```

### Cost Reduction Tips

1. **Use Spot VMs** for non-critical workloads (50-80% discount)
2. **Enable cluster autoscaling** - Scale to zero for dev pools
3. **Use zonal clusters** for non-production (no cross-zone costs)
4. **Right-size node pools** - Don't over-provision
5. **Use committed use discounts** for production (57% off)

## Troubleshooting

### Cannot connect to cluster

```bash
# Get credentials
gcloud container clusters get-credentials CLUSTER_NAME \
  --region REGION --project PROJECT_ID

# Verify kubectl config
kubectl config current-context

# Check authorized networks
gcloud container clusters describe CLUSTER_NAME \
  --region REGION --format="value(masterAuthorizedNetworksConfig)"
```

### Nodes not scaling

```bash
# Check autoscaler events
kubectl get events -n kube-system | grep cluster-autoscaler

# Check node pool configuration
gcloud container node-pools describe POOL_NAME \
  --cluster CLUSTER_NAME --region REGION

# View autoscaler logs
kubectl logs -n kube-system -l app=cluster-autoscaler
```

### Workload Identity not working

```bash
# Verify service account annotation
kubectl get serviceaccount SA_NAME -o yaml | grep iam.gke.io

# Check IAM binding
gcloud iam service-accounts get-iam-policy \
  GSA_NAME@PROJECT.iam.gserviceaccount.com

# Test from pod
kubectl run -it test --image=google/cloud-sdk:slim \
  --serviceaccount=SA_NAME -- gcloud auth list
```

## Examples

See [terraform/environments/](../../environments/) for complete environment examples:
- [dev/](../../environments/dev/) - Zonal cluster, minimal config
- [staging/](../../environments/staging/) - Regional cluster, moderate HA
- [prod/](../../environments/prod/) - Regional cluster, full HA

## Testing

```bash
cd terraform/modules/gke
terraform test
```

## Requirements

- Terraform >= 1.11.0
- GCP Provider >= 7.10.0
- `container.googleapis.com` API enabled
- VPC network with secondary IP ranges

## Related Modules

- [vpc](../vpc/) - Network configuration
- [workload_identity](../workload_identity/) - Pod authentication
- [addons](../addons/) - GKE add-ons configuration

## References

- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [GKE Best Practices](https://cloud.google.com/kubernetes-engine/docs/best-practices)
- [Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)
- [GKE Security Hardening](https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster)
