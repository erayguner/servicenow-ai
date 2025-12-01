# CloudSQL Module

Terraform module for creating a secure, production-ready Cloud SQL PostgreSQL instance with customer-managed encryption, automated backups, and high availability.

## Features

- ✅ **PostgreSQL 17** - Latest stable version
- ✅ **Private IP** - VPC-internal access only
- ✅ **Customer-Managed Encryption** - KMS key encryption
- ✅ **Automated backups** - Point-in-time recovery
- ✅ **High availability** - Regional HA with automatic failover
- ✅ **Auto-resize** - Automatic disk expansion
- ✅ **IAM authentication** - Optional passwordless access
- ✅ **SSL/TLS** - Encrypted connections
- ✅ **Maintenance windows** - Controlled update schedule

## Usage

### Basic Example

```hcl
module "cloudsql" {
  source = "../../modules/cloudsql"

  project_id    = "my-project-id"
  region        = "europe-west2"
  instance_name = "my-postgres-instance"

  # Database configuration
  database_version = "POSTGRES_17"
  tier             = "db-custom-2-7680"  # 2 vCPU, 7.5GB RAM
  disk_size        = 10
  disk_autoresize  = true

  # High availability
  availability_type = "ZONAL"  # ZONAL for dev, REGIONAL for prod

  # Security
  kms_key              = module.kms.database_key_id
  deletion_protection  = false  # Set to true for production

  # Databases and users
  databases = ["app_db", "analytics_db"]
  users = [
    { name = "app_user", password = "CHANGE_ME" }
  ]

  # Network
  network_id = module.vpc.network_id
}
```

### Production Example (High Availability)

```hcl
module "cloudsql_prod" {
  source = "../../modules/cloudsql"

  project_id    = "prod-project-id"
  region        = "europe-west2"
  instance_name = "prod-postgres"

  # Production-grade configuration
  database_version = "POSTGRES_17"
  tier             = "db-custom-8-32768"  # 8 vCPU, 32GB RAM
  disk_size        = 500
  disk_autoresize  = true

  # High availability - CRITICAL
  availability_type = "REGIONAL"  # Multi-zone HA with auto-failover

  # Security
  kms_key             = module.kms.database_key_id
  deletion_protection = true  # Prevent accidental deletion

  # Backups
  backup_enabled         = true
  backup_start_time      = "03:00"  # 3 AM UTC
  point_in_time_recovery = true
  transaction_log_retention_days = 7

  # Maintenance
  maintenance_window_day  = 7  # Sunday
  maintenance_window_hour = 3  # 3 AM UTC

  # Databases
  databases = ["app_db", "analytics_db"]
  users = [
    { name = "app_user", password = var.app_db_password },
    { name = "readonly_user", password = var.readonly_password }
  ]

  # Network
  network_id = module.vpc.network_id

  # Flags for performance tuning
  database_flags = [
    { name = "max_connections", value = "500" },
    { name = "shared_buffers", value = "8GB" },
    { name = "effective_cache_size", value = "24GB" },
    { name = "work_mem", value = "16MB" }
  ]
}
```

### Development Example (Cost-Optimized)

```hcl
module "cloudsql_dev" {
  source = "../../modules/cloudsql"

  project_id    = "dev-project-id"
  region        = "europe-west2"
  instance_name = "dev-postgres"

  # Minimal configuration for dev
  database_version = "POSTGRES_17"
  tier             = "db-custom-1-3840"  # 1 vCPU, 3.75GB RAM
  disk_size        = 10
  disk_autoresize  = true

  # Single zone (cheaper)
  availability_type = "ZONAL"

  # Security (still use KMS)
  kms_key             = module.kms.database_key_id
  deletion_protection = false

  # Minimal backups
  backup_enabled         = true
  backup_start_time      = "03:00"
  point_in_time_recovery = false  # Reduce cost

  databases = ["dev_db"]
  users = [
    { name = "dev_user", password = "dev_password_123" }
  ]

  network_id = module.vpc.network_id
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `project_id` | GCP project ID | `string` | - | yes |
| `region` | GCP region | `string` | - | yes |
| `instance_name` | CloudSQL instance name | `string` | - | yes |
| `database_version` | PostgreSQL version | `string` | `"POSTGRES_17"` | no |
| `tier` | Machine tier (e.g., db-custom-4-16384) | `string` | `"db-custom-4-16384"` | no |
| `disk_size` | Disk size in GB | `number` | `100` | no |
| `disk_autoresize` | Enable automatic disk resize | `bool` | `true` | no |
| `availability_type` | ZONAL or REGIONAL (HA) | `string` | `"REGIONAL"` | no |
| `deletion_protection` | Prevent accidental deletion | `bool` | `false` | no |
| `kms_key` | KMS key for encryption | `string` | - | yes |
| `databases` | List of databases to create | `list(string)` | - | yes |
| `users` | List of users to create | `list(object)` | - | yes |
| `network_id` | VPC network ID for private IP | `string` | - | yes |
| `backup_enabled` | Enable automated backups | `bool` | `true` | no |
| `backup_start_time` | Backup start time (HH:MM) | `string` | `"03:00"` | no |
| `point_in_time_recovery` | Enable PITR | `bool` | `false` | no |
| `maintenance_window_day` | Day of week for maintenance (1-7) | `number` | `7` | no |
| `maintenance_window_hour` | Hour for maintenance (0-23) | `number` | `3` | no |
| `database_flags` | PostgreSQL configuration flags | `list(object)` | `[]` | no |

### Machine Tiers

| Tier | vCPUs | RAM | Use Case | Est. Cost/Month |
|------|-------|-----|----------|-----------------|
| `db-custom-1-3840` | 1 | 3.75GB | Dev/test | ~$40 |
| `db-custom-2-7680` | 2 | 7.5GB | Small prod | ~$80 |
| `db-custom-4-16384` | 4 | 16GB | Medium prod | ~$160 |
| `db-custom-8-32768` | 8 | 32GB | Large prod | ~$320 |
| `db-custom-16-65536` | 16 | 64GB | Very large | ~$640 |

## Outputs

| Name | Description | Sensitive |
|------|-------------|-----------|
| `instance_connection_name` | Connection string for Cloud SQL Proxy | no |
| `private_ip_address` | Private IP address | yes |
| `instance_name` | CloudSQL instance name | no |
| `self_link` | Instance self-link | no |

## Architecture

### High Availability (REGIONAL)

```
┌────────────────────────────────────────────────────┐
│                  CloudSQL Instance                  │
│                    (REGIONAL)                       │
│                                                     │
│  ┌──────────────────┐      ┌──────────────────┐  │
│  │  Primary (Zone A) │◄────►│ Replica (Zone B) │  │
│  │  - Read/Write     │      │  - Read-only     │  │
│  │  - Sync repl.     │      │  - Auto-failover │  │
│  └──────────────────┘      └──────────────────┘  │
│           │                          │             │
│           └──────────┬───────────────┘             │
│                      │                             │
│              ┌───────▼────────┐                    │
│              │  Private IP    │                    │
│              │  (VPC internal)│                    │
│              └────────────────┘                    │
└────────────────────────────────────────────────────┘
                         │
                         ▼
                ┌────────────────┐
                │   Application  │
                │   (GKE Pods)   │
                └────────────────┘
```

### Connection Methods

#### 1. Private IP (Recommended)

```bash
# Direct connection via private IP
psql "host=10.1.0.3 port=5432 dbname=app_db user=app_user sslmode=require"
```

#### 2. Cloud SQL Proxy

```bash
# Start proxy
cloud_sql_proxy -instances=PROJECT:REGION:INSTANCE=tcp:5432 &

# Connect via localhost
psql "host=127.0.0.1 port=5432 dbname=app_db user=app_user"
```

#### 3. IAM Authentication (Passwordless)

```bash
# Get IAM token
gcloud sql generate-login-token

# Connect with token
psql "host=10.1.0.3 port=5432 dbname=app_db user=user@project.iam sslmode=require password=TOKEN"
```

## Security Features

### Customer-Managed Encryption (CMEK)

All data encrypted with KMS key:
- Data at rest
- Automated backups
- Replicas
- Snapshots

```hcl
kms_key = "projects/PROJECT/locations/REGION/keyRings/KEYRING/cryptoKeys/KEY"
```

### SSL/TLS Connections

All connections require SSL/TLS:

```bash
# Download server CA
gcloud sql ssl-certs create CLIENT_CERT_NAME \
  --instance=INSTANCE_NAME \
  cert.pem

# Connect with SSL
psql "host=PRIVATE_IP port=5432 dbname=DB sslmode=verify-ca sslrootcert=server-ca.pem"
```

### Private IP Only

No public IP address assigned:
- Access only from VPC
- No internet exposure
- VPC Service Controls compatible

### IAM Authentication

Enable passwordless access:

```sql
-- Create IAM user
CREATE ROLE "user@project-id.iam" WITH LOGIN;
GRANT ALL ON DATABASE app_db TO "user@project-id.iam";
```

## Backup and Recovery

### Automated Backups

- **Frequency**: Daily
- **Retention**: 7 days (configurable up to 365 days)
- **Storage**: Regional
- **Cost**: Included

### Point-in-Time Recovery (PITR)

Enable transaction log retention:

```hcl
point_in_time_recovery = true
transaction_log_retention_days = 7
```

**Recovery:**
```bash
# Restore to specific timestamp
gcloud sql backups create --instance=INSTANCE_NAME --async

gcloud sql instances clone SOURCE_INSTANCE CLONE_INSTANCE \
  --point-in-time '2024-12-01T12:30:00.000Z'
```

### Manual Backups

```bash
# Create on-demand backup
gcloud sql backups create --instance=INSTANCE_NAME

# List backups
gcloud sql backups list --instance=INSTANCE_NAME

# Restore from backup
gcloud sql backups restore BACKUP_ID --backup-instance=SOURCE --target-instance=TARGET
```

## Performance Tuning

### Database Flags

```hcl
database_flags = [
  # Connections
  { name = "max_connections", value = "500" },

  # Memory
  { name = "shared_buffers", value = "4GB" },      # 25% of RAM
  { name = "effective_cache_size", value = "12GB" }, # 75% of RAM
  { name = "work_mem", value = "16MB" },
  { name = "maintenance_work_mem", value = "1GB" },

  # Checkpoints
  { name = "checkpoint_completion_target", value = "0.9" },
  { name = "wal_buffers", value = "16MB" },

  # Query planner
  { name = "random_page_cost", value = "1.1" },  # SSD
  { name = "effective_io_concurrency", value = "200" },

  # Logging
  { name = "log_min_duration_statement", value = "1000" },  # Log slow queries (>1s)
  { name = "log_connections", value = "on" },
  { name = "log_disconnections", value = "on" }
]
```

### Read Replicas

```hcl
resource "google_sql_database_instance" "read_replica" {
  name                 = "replica-1"
  master_instance_name = module.cloudsql.instance_name
  region               = "europe-west2"
  database_version     = "POSTGRES_17"

  settings {
    tier = "db-custom-4-16384"
  }
}
```

**Use cases:**
- Offload read traffic from primary
- Analytics queries
- Reporting
- Geographic distribution

## Monitoring

### Cloud Monitoring Metrics

Key metrics to monitor:

```bash
# CPU utilization
gcloud monitoring time-series list \
  --filter='metric.type="cloudsql.googleapis.com/database/cpu/utilization"'

# Memory utilization
gcloud monitoring time-series list \
  --filter='metric.type="cloudsql.googleapis.com/database/memory/utilization"'

# Disk utilization
gcloud monitoring time-series list \
  --filter='metric.type="cloudsql.googleapis.com/database/disk/utilization"'

# Connections
gcloud monitoring time-series list \
  --filter='metric.type="cloudsql.googleapis.com/database/postgresql/num_backends"'
```

### Alerts

Recommended alerts:
- CPU > 80% for 5 minutes
- Memory > 90% for 5 minutes
- Disk > 85% (auto-resize may be slow)
- Connection count approaching `max_connections`
- Replication lag > 60 seconds (HA only)

## Cost Optimization

### Development Environment

```hcl
# Minimal config: ~$40-60/month
tier              = "db-custom-1-3840"   # 1 vCPU, 3.75GB
disk_size         = 10                    # 10GB SSD
availability_type = "ZONAL"              # Single zone
point_in_time_recovery = false           # Disable PITR
```

### Production Environment

```hcl
# Balanced config: ~$200-300/month
tier              = "db-custom-4-16384"  # 4 vCPU, 16GB
disk_size         = 100                   # 100GB SSD
availability_type = "REGIONAL"           # Multi-zone HA
point_in_time_recovery = true            # Enable PITR
```

### Cost Reduction Tips

1. **Right-size instances** - Monitor CPU/memory, downsize if underutilized
2. **Use committed use discounts** - 37-57% off for 1-3 year commit
3. **Delete unused instances** - Don't forget dev/test databases
4. **Optimize disk size** - Start small, auto-resize handles growth
5. **Use zonal for non-production** - REGIONAL costs ~2x more
6. **Disable PITR for dev** - Saves on backup storage
7. **Consider shared tenancy** - Multiple apps, one database

## Troubleshooting

### Cannot connect to instance

```bash
# Check instance status
gcloud sql instances describe INSTANCE_NAME --format="value(state)"
# Should return: RUNNABLE

# Verify private IP
gcloud sql instances describe INSTANCE_NAME --format="value(ipAddresses[0].ipAddress)"

# Test connectivity from VM in same VPC
ping PRIVATE_IP
telnet PRIVATE_IP 5432
```

### Connection limit reached

```bash
# Check current connections
psql -c "SELECT count(*) FROM pg_stat_activity;"

# Check max_connections setting
psql -c "SHOW max_connections;"

# Terminate idle connections
psql -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE state = 'idle' AND state_change < now() - interval '1 hour';"

# Increase max_connections (requires restart)
# Add to database_flags:
{ name = "max_connections", value = "1000" }
```

### Slow queries

```bash
# Enable query logging
# Add to database_flags:
{ name = "log_min_duration_statement", value = "1000" }  # Log >1s

# View slow query log
gcloud logging read "resource.type=cloudsql_database AND jsonPayload.message:duration" \
  --limit=50 --format=json

# Analyze with pg_stat_statements
psql -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"
psql -c "SELECT query, calls, mean_exec_time FROM pg_stat_statements ORDER BY mean_exec_time DESC LIMIT 10;"
```

### High memory usage

```bash
# Check shared_buffers setting
psql -c "SHOW shared_buffers;"

# Recommended: 25% of RAM
# For db-custom-4-16384 (16GB RAM): shared_buffers = 4GB

# Check for memory leaks
psql -c "SELECT * FROM pg_stat_database;"
```

## Examples

See [terraform/environments/](../../environments/) for complete examples:
- [dev/](../../environments/dev/) - Zonal, minimal config
- [staging/](../../environments/staging/) - Regional HA, moderate
- [prod/](../../environments/prod/) - Regional HA, full featured

## Testing

```bash
cd terraform/modules/cloudsql
terraform test
```

## Requirements

- Terraform >= 1.11.0
- GCP Provider >= 7.10.0
- `sqladmin.googleapis.com` API enabled
- `servicenetworking.googleapis.com` API enabled
- KMS key created
- VPC network with Service Networking connection

## Related Modules

- [kms](../kms/) - Encryption keys for CloudSQL
- [vpc](../vpc/) - Network configuration
- [secret_manager](../secret_manager/) - Store database passwords

## References

- [CloudSQL Documentation](https://cloud.google.com/sql/docs/postgres)
- [CloudSQL Best Practices](https://cloud.google.com/sql/docs/postgres/best-practices)
- [PostgreSQL Performance](https://www.postgresql.org/docs/current/performance-tips.html)
- [CloudSQL Pricing](https://cloud.google.com/sql/pricing)
