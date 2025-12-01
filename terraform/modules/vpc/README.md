# VPC (Virtual Private Cloud) Module

Terraform module for creating a secure, production-ready VPC network with private Google access, Cloud NAT, and zero-trust firewall rules.

## Features

- ✅ **Custom VPC network** - Non-default network with custom subnets
- ✅ **Private Google Access** - Access GCP services without external IPs
- ✅ **Cloud NAT** - Outbound internet access for private nodes
- ✅ **VPC Flow Logs** - Network traffic monitoring
- ✅ **Zero-trust firewall** - Default-deny with explicit allow rules
- ✅ **Secondary IP ranges** - For GKE pods and services
- ✅ **Serverless VPC Connector** - Optional Cloud Run integration
- ✅ **Regional routing** - High availability and low latency

## Usage

### Basic Example

```hcl
module "vpc" {
  source = "../../modules/vpc"

  project_id   = "my-project-id"
  region       = "europe-west2"
  network_name = "my-vpc-network"

  subnets = [
    {
      name                    = "gke-subnet"
      ip_cidr_range           = "10.0.0.0/20"
      region                  = "europe-west2"
      private_google_access   = true
      flow_logs               = true
      secondary_ip_range_pods = "10.4.0.0/14"  # 262,144 IPs for pods
      secondary_ip_range_svc  = "10.8.0.0/20"  # 4,096 IPs for services
    }
  ]

  # Cloud NAT for outbound internet
  nat_enabled = true
  router_name = "my-router"
  nat_name    = "my-nat"

  # Zero-trust firewall
  create_fw_default_deny = true
}
```

### Multi-Subnet Example

```hcl
module "vpc" {
  source = "../../modules/vpc"

  project_id   = "my-project-id"
  region       = "europe-west2"
  network_name = "prod-vpc"

  subnets = [
    # GKE subnet
    {
      name                    = "gke-subnet"
      ip_cidr_range           = "10.0.0.0/20"    # 4,096 IPs
      region                  = "europe-west2"
      private_google_access   = true
      flow_logs               = true
      secondary_ip_range_pods = "10.4.0.0/14"    # GKE pods
      secondary_ip_range_svc  = "10.8.0.0/20"    # GKE services
    },
    # CloudSQL / Private Services subnet
    {
      name                    = "private-services"
      ip_cidr_range           = "10.1.0.0/24"    # 256 IPs
      region                  = "europe-west2"
      private_google_access   = true
      flow_logs               = true
      secondary_ip_range_pods = ""               # No secondary ranges
      secondary_ip_range_svc  = ""
    },
    # Management subnet
    {
      name                    = "management"
      ip_cidr_range           = "10.2.0.0/24"    # 256 IPs
      region                  = "europe-west2"
      private_google_access   = true
      flow_logs               = true
      secondary_ip_range_pods = ""
      secondary_ip_range_svc  = ""
    }
  ]

  nat_enabled  = true
  nat_ip_count = 2  # Reserve 2 static NAT IPs

  # Firewall rules
  create_fw_default_deny = true
}
```

### With Serverless VPC Connector

```hcl
module "vpc" {
  source = "../../modules/vpc"

  project_id   = "my-project-id"
  region       = "europe-west2"
  network_name = "vpc-with-serverless"

  subnets = [
    {
      name                    = "gke-subnet"
      ip_cidr_range           = "10.0.0.0/20"
      region                  = "europe-west2"
      private_google_access   = true
      flow_logs               = true
      secondary_ip_range_pods = "10.4.0.0/14"
      secondary_ip_range_svc  = "10.8.0.0/20"
    }
  ]

  nat_enabled = true

  # Enable for Cloud Run
  enable_serverless_connector = true
  serverless_connector_cidr   = "10.8.0.0/28"  # /28 required (16 IPs)
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `project_id` | GCP project ID | `string` | - | yes |
| `region` | Primary GCP region | `string` | - | yes |
| `network_name` | Name of the VPC network | `string` | - | yes |
| `subnets` | List of subnets to create | `list(object)` | - | yes |
| `nat_enabled` | Enable Cloud NAT | `bool` | `true` | no |
| `router_name` | Name of Cloud Router | `string` | `"core-router"` | no |
| `nat_name` | Name of Cloud NAT | `string` | `"core-nat"` | no |
| `nat_ip_count` | Number of static NAT IPs (0 = automatic) | `number` | `0` | no |
| `create_fw_default_deny` | Create default-deny firewall rules | `bool` | `true` | no |
| `enable_serverless_connector` | Enable Serverless VPC Access | `bool` | `false` | no |
| `serverless_connector_cidr` | CIDR for serverless connector (/28) | `string` | `"10.8.0.0/28"` | no |

### Subnet Object Schema

```hcl
{
  name                    = string  # Subnet name
  ip_cidr_range           = string  # Primary CIDR (e.g., "10.0.0.0/20")
  region                  = string  # GCP region
  private_google_access   = bool    # Enable Private Google Access
  flow_logs               = bool    # Enable VPC Flow Logs
  secondary_ip_range_pods = string  # Secondary range for GKE pods (or "" if not needed)
  secondary_ip_range_svc  = string  # Secondary range for GKE services (or "" if not needed)
}
```

## Outputs

| Name | Description |
|------|-------------|
| `network_id` | VPC network ID |
| `network_name` | VPC network name |
| `network_self_link` | VPC network self-link |
| `subnetwork_ids` | Map of subnet names to IDs |
| `subnetwork_self_links` | Map of subnet names to self-links |
| `router_id` | Cloud Router ID |
| `nat_id` | Cloud NAT ID |

## Architecture

### Network Design

```
┌─────────────────────────────────────────────────────────────┐
│                        VPC Network                           │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  GKE Subnet (10.0.0.0/20)                           │  │
│  │  ├─ Primary: Node IPs                               │  │
│  │  ├─ Secondary (pods): 10.4.0.0/14                   │  │
│  │  └─ Secondary (services): 10.8.0.0/20               │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Private Services (10.1.0.0/24)                      │  │
│  │  └─ CloudSQL, Redis, Private Service Connection     │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Cloud Router + Cloud NAT                            │  │
│  │  └─ Outbound internet access for private nodes      │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
         │                                │
         │ Private Google Access          │ Cloud NAT
         ▼                                ▼
    GCP Services                      Internet
```

### IP Address Planning

**Recommended CIDR allocations:**

| Purpose | CIDR | IPs Available | Usage |
|---------|------|---------------|-------|
| GKE Nodes | `10.0.0.0/20` | 4,096 | Node primary IPs |
| GKE Pods | `10.4.0.0/14` | 262,144 | Pod IPs (large!) |
| GKE Services | `10.8.0.0/20` | 4,096 | ClusterIP services |
| Private Services | `10.1.0.0/24` | 256 | CloudSQL, Redis |
| Management | `10.2.0.0/24` | 256 | Bastion, VPN |
| Serverless | `10.8.0.0/28` | 16 | Cloud Run connector |

**Important**: GKE pods consume many IPs! Allocate `/14` or larger for production.

## Security Features

### Zero-Trust Firewall

When `create_fw_default_deny = true`, the module creates:

1. **Default Deny All Ingress** - Block all incoming traffic by default
2. **Default Deny All Egress** - Block all outgoing traffic by default
3. **Allow Internal** - Allow internal VPC communication (10.0.0.0/8)
4. **Allow Health Checks** - Allow Google Cloud health checks

**Then explicitly allow only required traffic:**

```hcl
# Allow SSH from specific CIDR
resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh-from-office"
  network = module.vpc.network_name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["203.0.113.0/24"]  # Office IP
  target_tags   = ["allow-ssh"]
}
```

### Private Google Access

Enabled by default. Allows VMs without external IPs to:
- Access Google APIs (storage, compute, etc.)
- Pull container images from GCR/Artifact Registry
- Use Cloud SQL, Secret Manager, etc.

### VPC Flow Logs

Enabled by default. Captures network traffic for:
- Security analysis
- Troubleshooting
- Cost optimization
- Compliance auditing

Logs available in Cloud Logging for 30 days (configurable).

## Cloud NAT

### How It Works

Cloud NAT provides outbound internet access for private nodes:

```
Private Node → Cloud Router → Cloud NAT → Internet
(no external IP)              (NAT gateway)
```

### NAT IP Allocation

**Automatic (default):**
```hcl
nat_ip_count = 0  # GCP manages NAT IPs
```

**Manual (recommended for production):**
```hcl
nat_ip_count = 2  # Reserve 2 static external IPs

# Benefits:
# - Predictable source IPs for allowlisting
# - Higher bandwidth (1.8 Gbps per IP)
# - Avoid port exhaustion
```

### NAT Configuration Best Practices

```hcl
# Small cluster (dev)
nat_ip_count = 0  # Automatic

# Medium cluster (staging)
nat_ip_count = 2  # ~64K connections per IP

# Large cluster (prod)
nat_ip_count = 4  # High throughput + redundancy
```

## Serverless VPC Connector

Enable for Cloud Run, Cloud Functions, App Engine:

```hcl
enable_serverless_connector = true
serverless_connector_cidr   = "10.8.0.0/28"  # Must be /28 (16 IPs)
```

**Use cases:**
- Cloud Run accessing private CloudSQL
- Cloud Functions calling internal APIs
- App Engine connecting to Redis

**Requirements:**
- CIDR must be `/28` (exactly 16 IPs)
- Must not overlap with existing subnets
- Enable `vpcaccess.googleapis.com` API

## Network Performance

### MTU Settings

Default MTU: **1460 bytes** (GCP standard)

For higher performance (internal traffic only):
```hcl
# In main.tf, modify:
mtu = 1500  # Requires testing, not all services support
```

### Regional vs Global Routing

This module uses **REGIONAL** routing mode:
- Lower latency within region
- Better cost optimization
- Prevents cross-region hairpinning

For multi-region, use global routing:
```hcl
# In main.tf:
routing_mode = "GLOBAL"
```

## Cost Optimization

### VPC Costs

**Free:**
- VPC network itself
- Subnets
- Static routes
- Firewall rules
- VPC Flow Logs (first 1GB/month)

**Paid:**
- Cloud NAT: $0.044/hour + $0.045/GB processed
- NAT static IPs: $0.004/hour per IP
- VPC Flow Logs: $0.50/GB (after free tier)
- VPC peering data transfer: $0.01/GB (egress)
- Serverless VPC connector: $0.028/hour + $0.028/GB

**Optimization tips:**
1. Use automatic NAT IPs for dev/test
2. Disable flow logs in non-production
3. Use regional routing (not global)
4. Share VPC across projects with Shared VPC

### Example Monthly Costs

**Development:**
- Cloud NAT: ~$32/month (auto IPs)
- Flow logs: ~$10/month (limited traffic)
- **Total: ~$42/month**

**Production:**
- Cloud NAT: ~$32/month + 4 static IPs ($12)
- Flow logs: ~$100/month (higher traffic)
- VPC peering: ~$50/month (cross-project)
- **Total: ~$194/month**

## Troubleshooting

### Private nodes cannot access internet

```bash
# Check Cloud NAT status
gcloud compute routers nats describe NAT_NAME \
  --router=ROUTER_NAME --region=REGION

# Verify NAT is configured
gcloud compute routers describe ROUTER_NAME --region=REGION

# Check NAT logs
gcloud logging read "resource.type=nat_gateway" --limit=50
```

### Private Google Access not working

```bash
# Verify subnet configuration
gcloud compute networks subnets describe SUBNET_NAME \
  --region=REGION --format="value(privateIpGoogleAccess)"

# Should return: True

# Test from VM
gcloud compute ssh VM_NAME --zone=ZONE --command="curl -I https://www.googleapis.com"
```

### Cannot create GKE cluster - IP range exhausted

```bash
# Check current usage
gcloud compute networks subnets describe SUBNET_NAME \
  --region=REGION --format="value(secondaryIpRanges)"

# Solution: Expand secondary ranges
# Pods need /14 or larger for production (262,144 IPs)
```

### Firewall rules not working

```bash
# List all firewall rules
gcloud compute firewall-rules list --filter="network:NETWORK_NAME"

# Check rule priority (lower = higher priority)
# Default deny rules should have priority 65534

# Test connectivity
gcloud compute firewall-rules list --filter="network:NETWORK_NAME" --format=table
```

## Examples

See [terraform/environments/](../../environments/) for complete examples:
- [dev/](../../environments/dev/) - Single subnet, auto NAT
- [staging/](../../environments/staging/) - Multi-subnet, static NAT IPs
- [prod/](../../environments/prod/) - Multi-region, Shared VPC

## Testing

```bash
cd terraform/modules/vpc
terraform test
```

## Requirements

- Terraform >= 1.11.0
- GCP Provider >= 7.10.0
- `compute.googleapis.com` API enabled
- `servicenetworking.googleapis.com` API enabled (for CloudSQL)
- `vpcaccess.googleapis.com` API enabled (for serverless connector)

## Related Modules

- [gke](../gke/) - GKE cluster (requires VPC with secondary ranges)
- [cloudsql](../cloudsql/) - CloudSQL (requires VPC peering)
- [cloud_run](../cloud_run/) - Cloud Run (optionally uses VPC connector)

## References

- [VPC Documentation](https://cloud.google.com/vpc/docs)
- [Cloud NAT Documentation](https://cloud.google.com/nat/docs)
- [VPC Best Practices](https://cloud.google.com/vpc/docs/best-practices)
- [Private Google Access](https://cloud.google.com/vpc/docs/private-google-access)
- [VPC Flow Logs](https://cloud.google.com/vpc/docs/using-flow-logs)
