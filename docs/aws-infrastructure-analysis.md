# AWS Infrastructure Analysis for ServiceNow AI Agent Platform

## 1. OVERVIEW - AWS SERVICES INVENTORY

### Core Infrastructure Services

- **VPC (Virtual Private Cloud)** - Network foundation with multi-AZ support
- **EKS (Elastic Kubernetes Service)** - Container orchestration platform
- **S3 (Simple Storage Service)** - Object storage for documents, uploads,
  backups
- **CloudWatch** - Logging and monitoring across all services

### Database & Caching Services

- **RDS PostgreSQL** - Relational database for structured data
- **DynamoDB** - NoSQL database for conversations and sessions
- **ElastiCache Redis** - In-memory caching for performance

### Security & Encryption

- **KMS (Key Management Service)** - Encryption key management
- **Secrets Manager** - Credential and secret storage
- **WAF (Web Application Firewall)** - Traffic protection and rate limiting
- **IAM (Identity & Access Management)** - Role-based access control

### Messaging & Async Processing

- **SNS (Simple Notification Service)** - Pub/Sub messaging
- **SQS (Simple Queue Service)** - Message queuing (subscribers to SNS)

### Cost Management & Budgets

- **AWS Budgets** - Cost monitoring and alerts

---

## 2. DETAILED MODULE ARCHITECTURE

### 2.1 VPC Module (Network Layer)

**Purpose**: Provides isolated network infrastructure with
public/private/database subnets

**Key Configurations:**

- **3 Availability Zones** for high availability
- **Public Subnets**: Host NAT Gateways and load balancers
- **Private Subnets**: Host EKS worker nodes
- **Database Subnets**: Host RDS and ElastiCache
- **Internet Gateway**: Public internet access
- **NAT Gateway**: Private subnet internet egress
- **VPC Endpoints**: S3, DynamoDB, ECR, STS, Logs, SecretsManager (avoid NAT
  Gateway costs)
- **VPC Flow Logs**: Traffic monitoring (prod only)

**Dev Configuration:**

- Single NAT Gateway (cost optimization)
- Flow logs disabled
- VPC endpoints enabled

**Prod Configuration:**

- Multiple NAT Gateways (HA)
- Flow logs enabled (30-day retention)
- VPC endpoints enabled

---

### 2.2 EKS Module (Kubernetes Orchestration)

**Purpose**: Kubernetes cluster for AI agent workloads

**Architecture:**

- **Control Plane**: AWS-managed Kubernetes API server
- **Node Groups**: EC2 instances running as worker nodes

**Dev Configuration:**

```
General Node Group:
  - Instance: t3a.medium (ARM-based, cheaper)
  - Capacity: SPOT (70% savings)
  - Min: 1, Max: 3, Desired: 1
  - Disabled: AI node group
```

**Prod Configuration:**

```
General Node Group:
  - Instances: t3.xlarge, t3a.xlarge
  - Capacity: ON_DEMAND
  - Min: 3, Max: 20, Desired: 3

AI Node Group:
  - Instances: r6i.2xlarge, r6a.2xlarge (memory optimized)
  - Capacity: ON_DEMAND
  - Min: 2, Max: 10, Desired: 2
  - Taints: workload=ai (prevent general workloads)
```

**Key Add-ons (2025 Best Practices):**

- **vpc-cni**: AWS VPC CNI for pod networking
- **coredns**: DNS resolution
- **kube-proxy**: Network proxy
- **eks-pod-identity-agent**: Pod Identity (replaces IRSA)
- **aws-ebs-csi-driver**: Persistent volume support

**Security:**

- KMS encryption for secrets
- Pod Identity for IAM access
- OIDC provider for IRSA fallback
- Security groups for control plane and nodes

**Logging:**

- CloudWatch logs: api, audit, authenticator, controllerManager, scheduler
- Dev: 7 days retention
- Prod: 30 days retention

---

### 2.3 RDS Module (Relational Database)

**Purpose**: PostgreSQL database for structured data

**Dev Configuration:**

```
Engine: PostgreSQL 16.1
Instance: db.t4g.micro (smallest Graviton)
Storage: 20 GB initial, 100 GB max
Multi-AZ: No
Backup: 1 day retention
Enhanced Monitoring: Disabled
Performance Insights: Disabled
Read Replica: None
```

**Prod Configuration:**

```
Engine: PostgreSQL 16.1
Instance: db.r6i.xlarge (memory optimized)
Storage: 200 GB initial, 1000 GB max
Multi-AZ: Yes
Backup: 30 day retention
Enhanced Monitoring: 60 second interval
Performance Insights: Enabled (7 day)
Read Replica: db.r6i.large (optional)
```

**Database:**

- Name: agentdb
- Subnet: Database subnets
- Security: Encrypted with KMS
- Access: Only from EKS nodes

**Logging:**

- PostgreSQL error logs
- Upgrade logs
- Parameter group with statement logging

---

### 2.4 DynamoDB Module (NoSQL Database)

**Purpose**: Serverless document storage for conversations and sessions

**Dev Tables:**

```
1. dev-conversations
   - Hash Key: userId (String)
   - Range Key: conversationId (String)
   - TTL: expiresAt
   - Billing: PAY_PER_REQUEST
   - PITR: Disabled
   - Streams: Disabled

2. dev-sessions
   - Hash Key: sessionId (String)
   - TTL: expiresAt
   - Billing: PAY_PER_REQUEST
   - PITR: Disabled
```

**Prod Tables:**

```
1. prod-conversations
   - Hash Key: userId (String)
   - Range Key: conversationId (String)
   - Attributes: userId, conversationId, createdAt
   - GSI: CreatedAtIndex (userId + createdAt)
   - Billing: PAY_PER_REQUEST
   - PITR: Enabled
   - Streams: Enabled (NEW_AND_OLD_IMAGES)

2. prod-sessions
   - Hash Key: sessionId (String)
   - TTL: expiresAt
   - Billing: PAY_PER_REQUEST
   - PITR: Enabled
```

**Features:**

- KMS encryption at rest
- Point-in-time recovery (prod)
- TTL for auto-expiration
- Streams for event processing (prod)
- Auto-scaling for provisioned tables (if used)

---

### 2.5 S3 Module (Object Storage)

**Purpose**: Store documents, uploads, backups, and audit logs

**Dev Buckets:**

```
1. servicenow-ai-knowledge-documents-dev
   - Versioning: Disabled
   - Intelligent Tiering: Disabled
   - EventBridge: Disabled

2. servicenow-ai-user-uploads-dev
   - Lifecycle: Delete after 7 days
```

**Prod Buckets:**

```
1. servicenow-ai-knowledge-documents-prod
   - Versioning: Enabled
   - Intelligent Tiering: Enabled
   - EventBridge: Enabled

2. servicenow-ai-document-chunks-prod
   - Versioning: Enabled

3. servicenow-ai-user-uploads-prod
   - Versioning: Enabled
   - Lifecycle: Delete after 90 days

4. servicenow-ai-backup-prod
   - Versioning: Enabled
   - Lifecycle Transitions:
     * 30 days: STANDARD_IA
     * 90 days: GLACIER_IR
     * 180 days: DEEP_ARCHIVE

5. servicenow-ai-audit-logs-prod
   - Versioning: Enabled
```

**Security Across All Buckets:**

- Server-side encryption with KMS
- Block all public access
- VPC endpoint access

---

### 2.6 SNS-SQS Module (Message Queue)

**Purpose**: Async messaging for event-driven workflows

**Dev Configuration:**

```
Topics:
  - dev-test-events (1 day retention)

Queue per topic:
  - dev-test-events-queue
```

**Prod Configuration:**

```
Topics:
  1. prod-ticket-events
  2. prod-notification-requests
  3. prod-knowledge-updates
  4. prod-action-requests

All with:
  - 7 day retention (604800 seconds)
  - SQS queue subscriber
```

**Architecture:**

- SNS Topics: Publishers
- SQS Queues: Subscribers to SNS
- Dead Letter Queue: Failed message handling
- KMS Encryption: All messages encrypted
- Queue Policy: Allows SNS to send messages

---

### 2.7 ElastiCache Redis Module (Caching Layer)

**Purpose**: In-memory caching for sessions and performance

**Dev Configuration:**

```
Node Type: cache.t4g.micro (Graviton, cheapest)
Nodes: 1 (single node)
Snapshots: None
Failover: Disabled
Multi-AZ: No
```

**Prod Configuration:**

```
Node Type: cache.r7g.xlarge (Graviton, memory optimized)
Nodes: 3 (cluster for HA)
Snapshots: 7 day retention
Failover: Enabled
Multi-AZ: Enabled
```

**Security:**

- KMS encryption at rest
- In-transit encryption enabled
- AUTH token authentication
- Security group: Only from EKS nodes
- CloudWatch slow-log monitoring

---

### 2.8 KMS Module (Key Management)

**Purpose**: Centralized encryption key management

**Dev Configuration:**

```
Single shared key: "Shared encryption key for dev"
  - Used for all services
  - Cost optimization
  - No multi-region replication
```

**Prod Configuration:**

```
Separate keys for each service:
  1. storage - S3 buckets
  2. rds - RDS encryption
  3. dynamodb - DynamoDB encryption
  4. sns-sqs - SNS/SQS encryption
  5. elasticache - Redis encryption
  6. secrets - Secrets Manager encryption
  7. eks - EKS cluster encryption
```

**Common Features:**

- Automatic key rotation enabled
- 7-30 day deletion window
- Aliases for easy reference

---

### 2.9 Secrets Manager Module (Secret Storage)

**Purpose**: Secure credential and API key storage

**Dev Secrets:**

```
1. dev/anthropic-api-key
2. dev/openai-api-key
3. dev/rds-password (immediate deletion)
```

**Prod Secrets:**

```
1. prod/servicenow-oauth-client-id
2. prod/servicenow-oauth-client-secret
3. prod/slack-bot-token
4. prod/slack-signing-secret
5. prod/openai-api-key
6. prod/anthropic-api-key
7. prod/rds-master-password (auto-rotation every 90 days)
```

**Security:**

- KMS encryption
- Recovery window for deletion protection
- Automatic rotation (prod RDS password)

---

### 2.10 WAF Module (Web Application Firewall)

**Purpose**: Protect EKS workloads from attacks

**Dev Configuration:**

- Rate limit: 5000 req/IP
- Scope: REGIONAL

**Prod Configuration:**

- Rate limit: 2000 req/IP
- Scope: REGIONAL

**Security Rules:**

1. **AWSManagedRulesCommonRuleSet** - OWASP top 10
2. **AWSManagedRulesSQLiRuleSet** - SQL injection protection
3. **RateLimitRule** - Throttle excessive traffic

**Monitoring:**

- CloudWatch metrics enabled
- Sampled requests logged

---

## 3. INTERCONNECTION & DATA FLOW

### 3.1 Application Architecture Flow

```
Internet Traffic
    ↓
AWS WAF (Rate limiting, DDoS protection)
    ↓
EKS Cluster (Kubernetes nodes)
    ├─ General Node Group (t3a.medium/xlarge)
    └─ AI Node Group (r6i.2xlarge) [Prod only]

EKS Nodes Access:
├─ PostgreSQL (RDS) via private subnet
│  └─ Port 5432 from EKS security group
│
├─ DynamoDB via VPC endpoint (no data transfer cost)
│  └─ Conversations & sessions NoSQL storage
│
├─ S3 via VPC endpoint
│  └─ Knowledge documents, user uploads
│
├─ ElastiCache Redis via private subnet
│  └─ Port 6379 for session caching
│
├─ SNS/SQS via VPC endpoint
│  └─ Event-driven async processing
│
└─ Secrets Manager via VPC endpoint
   └─ API keys and credentials
```

### 3.2 Encryption & Security Layer

**All data encrypted at rest with KMS:**

- RDS: Encrypted with KMS key
- DynamoDB: Encrypted with KMS key
- S3: Server-side encryption with KMS
- Redis: At-rest encryption with KMS
- SNS/SQS: Message encryption with KMS
- Secrets Manager: Encrypted with KMS

**In-transit encryption:**

- Redis: Transit encryption enabled + AUTH token
- RDS: TLS/SSL connections
- S3: HTTPS only
- CloudWatch: HTTPS

### 3.3 High Availability Pattern

**Dev (Single Availability Zone):**

```
Single AZ
├─ 1 NAT Gateway
├─ 1-3 EKS nodes
├─ 1 RDS instance (single AZ)
└─ 1 Redis node
```

**Prod (Multi-AZ):**

```
3 Availability Zones
├─ NAT Gateway per AZ
├─ 3-20 EKS general nodes distributed
├─ 2-10 EKS AI nodes distributed
├─ RDS primary + standby in different AZ
└─ Redis cluster: 3 nodes with failover
```

### 3.4 Backup & Recovery Strategy

**RDS:**

- Dev: 1 day retention (minimal backups)
- Prod: 30 day retention + optional read replica

**S3:**

- Dev: Minimal (7 day delete for uploads)
- Prod: Versioning + lifecycle rules (30/90/180 day transitions)

**DynamoDB:**

- Dev: No PITR
- Prod: PITR enabled, Streams enabled

**Redis:**

- Dev: No snapshots
- Prod: 7 day snapshot retention

---

## 4. DEPENDENCIES & ORCHESTRATION

### Module Dependencies (Terraform)

```
1. KMS (no dependencies)
   ↓
2. VPC (depends on KMS for endpoints)
   ↓
3. EKS (depends on VPC)
   ↓
4. RDS (depends on VPC, EKS for security group)
   ├─ ElastiCache (depends on VPC, EKS for security group)
   ├─ DynamoDB (depends on KMS only)
   ├─ S3 (depends on KMS only)
   ├─ SNS-SQS (depends on KMS only)
   ├─ Secrets Manager (depends on KMS only)
   └─ WAF (independent)
```

### Service Communication Paths

**Allowed:**

- EKS → RDS (via security group rule)
- EKS → ElastiCache (via security group rule)
- EKS → S3 (via VPC endpoint)
- EKS → DynamoDB (via VPC endpoint)
- EKS → SNS/SQS (via VPC endpoint)
- EKS → Secrets Manager (via VPC endpoint)
- SNS → SQS (queue policy)

**Blocked:**

- RDS ↔ DynamoDB (different subnets, no direct access)
- Public ↔ Private subnets (NAT Gateway required)
- Private ↔ Database subnet (no direct route)

---

## 5. COST OPTIMIZATION PATTERNS

### Dev Environment Cost Reductions

- Single NAT Gateway (not HA)
- SPOT instances (70% cheaper)
- Smallest instance types (t3a.micro/medium)
- Disabled: Flow logs, Performance Insights, Read replicas
- Single Redis node (no HA)
- PAY_PER_REQUEST DynamoDB (not provisioned)
- Short TTLs for object deletion (7 days)
- No PITR for DynamoDB/RDS

### Prod Environment Cost Optimization

- VPC endpoints for S3/DynamoDB (avoid NAT data transfer)
- Intelligent tiering for old S3 objects
- ON_DEMAND capacity for reliability
- Graviton instances (ARM-based, 20% cheaper than x86)
- Shared KMS keys strategy (could be further optimized)

---

## 6. MONITORING & OBSERVABILITY

### CloudWatch Integration

- **EKS Logs**: /aws/eks/{cluster-name}/cluster
- **RDS Logs**: PostgreSQL error logs, upgrade logs
- **Redis Logs**: Slow-log to CloudWatch
- **Application Logs**: /aws/eks/{cluster-name}/application
- **VPC Flow Logs**: Network traffic (prod only)

### Metrics Collected

- EKS cluster health
- RDS CPU, memory, connections
- DynamoDB capacity utilization
- ElastiCache evictions, connections
- S3 request rates
- SNS/SQS message counts
- WAF blocked requests

### Budgets & Alerts

- Dev: $200/month budget with 80% and 100% alerts
- Prod: $15,000/month budget with 50%, 80%, 100% alerts

---

## 7. ENVIRONMENT COMPARISON MATRIX

| Feature                  | Dev                              | Prod                                |
| ------------------------ | -------------------------------- | ----------------------------------- |
| **VPC**                  | Single NAT, No flow logs         | Multi-AZ NAT, Flow logs 30d         |
| **EKS Nodes**            | t3a.medium SPOT (1-3)            | t3.xlarge/a ON_DEMAND (3-20)        |
| **AI Nodes**             | Disabled                         | r6i.2xlarge (2-10)                  |
| **RDS**                  | db.t4g.micro, 20GB, 1-day backup | db.r6i.xlarge, 200GB, 30-day backup |
| **RDS HA**               | No (single AZ)                   | Yes (Multi-AZ)                      |
| **DynamoDB PITR**        | No                               | Yes                                 |
| **Redis**                | cache.t4g.micro, 1 node          | cache.r7g.xlarge, 3 nodes           |
| **S3 Versioning**        | Disabled                         | Enabled                             |
| **S3 Lifecycle**         | 7-day delete                     | 30/90/180-day transitions           |
| **KMS Keys**             | 1 shared                         | 7 separate keys                     |
| **CloudWatch Retention** | 3 days                           | 30 days                             |
| **WAF Rate Limit**       | 5000 req/IP                      | 2000 req/IP                         |
| **Estimated Cost**       | $200/month                       | $15,000/month                       |

---

## 8. BEDROCK EQUIVALENT MAPPING

When migrating to Bedrock-based equivalent:

| AWS Service         | Bedrock/Alternative          | Notes                                |
| ------------------- | ---------------------------- | ------------------------------------ |
| **EKS**             | Bedrock Agents + Lambda      | Serverless alternative to Kubernetes |
| **RDS**             | DynamoDB + Aurora Serverless | Better for serverless pattern        |
| **ElastiCache**     | DAX (DynamoDB Accelerator)   | Native DynamoDB caching              |
| **SNS/SQS**         | EventBridge + Lambda         | Event-driven without message queues  |
| **S3**              | S3 (keep)                    | Object storage remains same          |
| **DynamoDB**        | DynamoDB (keep)              | NoSQL layer remains same             |
| **KMS**             | KMS (keep)                   | Encryption layer remains same        |
| **Secrets Manager** | Secrets Manager (keep)       | Secret storage remains same          |
| **WAF**             | WAF (keep) + API Gateway     | Add API Gateway for REST endpoints   |
| **CloudWatch**      | CloudWatch (keep)            | Logging/monitoring remains same      |

---

## 9. KEY CONFIGURATION FILES

**Environment Variables Required:**

```
- AWS Region: us-east-1 (configurable)
- db_master_password: RDS password
- redis_auth_token: Redis authentication token
- budget_alert_emails: Email list for alerts
- eks_public_access_cidrs: Public CIDR access
- create_rds_read_replica: Boolean (prod option)
- rds_rotation_lambda_arn: Lambda for secret rotation
```

**Terraform State Management:**

```
Backend: S3
  - Bucket: servicenow-ai-terraform-state
  - DynamoDB Lock Table: terraform-state-lock
  - KMS Encryption: alias/terraform-state
  - Separate keys per environment (dev/, prod/)
```
