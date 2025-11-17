# AWS Infrastructure Architecture Diagrams

## 1. HIGH-LEVEL SYSTEM ARCHITECTURE

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         INTERNET / USERS                                 │
└────────────────────────────────┬────────────────────────────────────────┘
                                  │
                                  ▼
                        ┌─────────────────────┐
                        │  AWS WAF + CloudFront│
                        │  (DDoS Protection)   │
                        └──────────┬───────────┘
                                   │
                    ┌──────────────┴──────────────┐
                    │ EKS Application Load Balancer
                    │ (Public Subnets)
                    └──────────────┬──────────────┘
                                   │
        ┌──────────────────────────┴──────────────────────────────┐
        │                                                          │
        ▼                                                          ▼
   ┌─────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
   │ General Node│  │ General Node │  │ General Node │  │  AI Node    │
   │ Group       │  │ Group        │  │ Group        │  │  Group (HA) │
   │ (1-3 pods)  │  │ (multiple)   │  │ (multiple)   │  │ (2-10 pods) │
   │ t3a.medium  │  │ t3.xlarge    │  │ t3a.xlarge   │  │ r6i.2xlarge │
   │ SPOT        │  │ ON_DEMAND    │  │ ON_DEMAND    │  │ ON_DEMAND   │
   └──────┬──────┘  └──────┬───────┘  └──────┬───────┘  └──────┬──────┘
          │                │                  │                │
          └────────────────┼──────────────────┼────────────────┘
                           │                  │
                    ┌──────▼──────────────────▼─────────┐
                    │   Private Subnets (3 AZs)         │
                    │   EKS Worker Nodes                │
                    │   Security Group rules allow:      │
                    │   - To RDS (5432)                 │
                    │   - To Redis (6379)                │
                    │   - To S3/DDB/SNS via VPC endpoint│
                    └──────┬─────────────────────────────┘
                           │
        ┌──────────────────┼──────────────────┬────────────────┐
        │                  │                  │                │
        ▼                  ▼                  ▼                ▼
    ┌────────┐         ┌────────┐       ┌──────────┐      ┌─────────┐
    │  RDS   │         │ Redis  │       │ S3       │      │DynamoDB │
    │PostgreSQL        │ElastiC │       │(via VPC  │      │(via VPC │
    │(Port 5432)       │(Port 6379)     │endpoint) │      │endpoint) │
    │Multi-AZ (Prod)   │3 nodes │       │KMS enc.  │      │KMS enc. │
    │Single AZ (Dev)   │1 node  │       │Versioned │      │PITR(Prod)
    │KMS enc.          │KMS enc.        │/Tiered   │      │Streams  │
    │30-day backup     │Snapshots       │7 buckets │      │Tables:  │
    │Monitoring        │                │          │      │Conv/Sess│
    └────────┘         └────────┘       └──────────┘      └─────────┘
        │
        ▼
    ┌──────────────────────────────────────────────────────────────┐
    │              SNS/SQS (via VPC endpoint)                       │
    │  • prod-ticket-events                                        │
    │  • prod-notification-requests                               │
    │  • prod-knowledge-updates                                    │
    │  • prod-action-requests                                      │
    │  (Each has SQS queue subscriber + DLQ)                       │
    │  KMS encryption for all messages                            │
    └──────────────────────────────────────────────────────────────┘
        │
        ▼
    ┌──────────────────────────────────────────────────────────────┐
    │        Secrets Manager (via VPC endpoint)                     │
    │  • Anthropic API Key                                         │
    │  • OpenAI API Key                                            │
    │  • ServiceNow OAuth Credentials                              │
    │  • Slack Bot Tokens                                          │
    │  • RDS Master Password (auto-rotated)                        │
    │  KMS encrypted with separate keys (Prod)                     │
    └──────────────────────────────────────────────────────────────┘
```

---

## 2. VPC NETWORK ARCHITECTURE

```
┌──────────────────────────────────────────────────────────────────────────┐
│                         VPC: 10.0.0.0/16 (Prod)                           │
│                         VPC: 10.10.0.0/16 (Dev)                           │
│                                                                            │
│  ┌─────────────────────────────────────────────────────────────────────┐ │
│  │                      Internet Gateway                               │ │
│  └────────────────────────────────┬──────────────────────────────────┘ │ │
│                                   │                                    │ │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐                       │ │
│  │ Public AZ1 │  │ Public AZ2 │  │ Public AZ3 │                       │ │
│  │10.0.0.0/20 │  │10.0.16.0/20│  │10.0.32.0/20│                       │ │
│  │ NAT Gateway│  │ NAT Gateway│  │ NAT Gateway│(only 1 in Dev)         │ │
│  │ EIP        │  │ EIP        │  │ EIP        │                       │ │
│  └────┬───────┘  └────┬───────┘  └────┬───────┘                       │ │
│       │               │               │                               │ │
│       └───────────────┴───────────────┘                               │ │
│                     │ (IGW Route)                                      │ │
│                     ▼                                                  │ │
│            [Internet Traffic]                                         │ │
│                                                                        │ │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐                       │ │
│  │Private AZ1 │  │Private AZ2 │  │Private AZ3 │                       │ │
│  │10.0.64.0/20│  │10.0.80.0/20│  │10.0.96.0/20│                       │ │
│  │EKS Workers │  │EKS Workers │  │EKS Workers │                       │ │
│  │  (0-3 Pods)│  │  (0-20 Pod)│  │  (0-20 Pod)│                       │ │
│  └─────┬──────┘  └──────┬─────┘  └──────┬─────┘                       │ │
│        │                │              │   (NAT Gateway Route)        │ │
│        └────────────────┴──────────────┘                              │ │
│                        │ (Private Route)                              │ │
│                        ▼                                              │ │
│            [AWS Service Routes via VPC Endpoints]                    │ │
│            - S3 (Gateway endpoint)                                    │ │
│            - DynamoDB (Gateway endpoint)                              │ │
│            - ECR.api, ECR.dkr (Interface)                            │ │
│            - STS (Interface)                                          │ │
│            - Logs (Interface)                                         │ │
│            - Secrets Manager (Interface)                              │ │
│                                                                        │ │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐                       │ │
│  │ Database AZ1│  │Database AZ2 │  │Database AZ3│                       │ │
│  │10.0.128.0/20│  │10.0.144.0/20│  │10.0.160.0/20│                       │ │
│  │   RDS      │  │   RDS SB   │  │   RDS SB   │                       │ │
│  │   Redis    │  │   Redis    │  │   Redis    │                       │ │
│  │   SB       │  │   SB       │  │   SB       │                       │ │
│  └────────────┘  └────────────┘  └────────────┘                       │ │
│                        │ (Database Route)                             │ │
│                        ▼                                              │ │
│            [RDS PostgreSQL Primary/Standby]                          │ │
│            [Redis Cluster with Failover]                             │ │
│                                                                        │ │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. SECURITY LAYERS & ENCRYPTION

```
┌──────────────────────────────────────────────────────────────────────┐
│                    ENCRYPTION & SECURITY LAYERS                      │
└──────────────────────────────────────────────────────────────────────┘

                        WAF (Layer 7)
                    ├─ Rate Limiting (2000 req/IP)
                    ├─ SQL Injection Rules
                    └─ OWASP Common Rules
                              │
                              ▼
                    Security Groups (Layer 4)
                    EKS → RDS (5432)
                    EKS → Redis (6379)
                    RDS ↔ Secrets  None (no direct access)
                              │
                              ▼
                    Network ACLs (Layer 3)
                    Subnet-level isolation
                    Public ↔ Private ↔ Database
                              │
                              ▼
                    VPC Endpoints (Layer 3)
                    Encrypted tunnels for:
                    • S3 (Gateway)
                    • DynamoDB (Gateway)
                    • ECR (Interface)
                    • Secrets (Interface)
                              │
                              ▼
┌───────────────────────────────────────────────────────────┐
│              KMS (Key Management Service)                  │
│  Master encryption for all data at rest                   │
│                                                           │
│  DEV (1 shared key):                                      │
│    └─ dev/shared (all services)                          │
│                                                           │
│  PROD (7 separate keys):                                 │
│    ├─ prod/storage (S3)                                  │
│    ├─ prod/rds (RDS)                                     │
│    ├─ prod/dynamodb (DynamoDB)                           │
│    ├─ prod/sns-sqs (SNS/SQS)                            │
│    ├─ prod/elasticache (Redis)                           │
│    ├─ prod/secrets (Secrets Manager)                     │
│    └─ prod/eks (EKS)                                     │
│                                                           │
│  Common: Key rotation enabled, 7-30 day deletion window   │
└───────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────┐
│         ENCRYPTION IN TRANSIT (All Services)               │
│                                                           │
│  RDS:       TLS/SSL connections (port 5432)              │
│  Redis:     Transit encryption enabled + AUTH token       │
│  S3:        HTTPS/TLS for all requests                   │
│  SNS/SQS:   HTTPS for message transport                  │
│  SecretsM:  TLS via VPC endpoint                         │
│  CloudWatch: HTTPS for log upload                        │
└───────────────────────────────────────────────────────────┘
```

---

## 4. MODULE DEPENDENCY GRAPH

```
┌────────────────────────────────────────────────────────────────────────┐
│                      TERRAFORM MODULE DEPENDENCIES                       │
└────────────────────────────────────────────────────────────────────────┘

                              START
                                │
                    ┌───────────┴───────────┐
                    │                       │
                    ▼                       ▼
                  ┌────┐               ┌──────┐
                  │KMS │               │ WAF  │
                  └─┬──┘               └──────┘
                    │              (independent)
                    │
                    ▼
                  ┌────┐
                  │VPC │ (depends on KMS for endpoints)
                  └─┬──┘
                    │
      ┌─────────────┼─────────────┐
      │             │             │
      ▼             ▼             ▼
   ┌─────┐      ┌──────┐      ┌────────┐
   │ EKS │      │Secrets       │Secrets │
   │     │      │Manager       │Manager │
   └─┬───┘      └──────┘       └────────┘
     │          (depends only on KMS)
     │
     ├─────────────────┬────────────────┬────────────────┐
     │                 │                │                │
     ▼                 ▼                ▼                ▼
  ┌─────┐          ┌──────┐        ┌──────────┐    ┌─────────┐
  │ RDS │          │Redis │        │ S3       │    │DynamoDB │
  │     │          │      │        │          │    │         │
  └─────┘          └──────┘        └──────────┘    └─────────┘
  (depends:        (depends:       (depends:       (depends:
   VPC, EKS)       VPC, EKS)       KMS only)       KMS only)
                                                       │
                                                       ▼
                                                   ┌──────────┐
                                                   │ SNS/SQS  │
                                                   │          │
                                                   └──────────┘
                                              (depends: KMS only)

KEY RULES:
  • KMS must be created first (used by all services)
  • VPC must exist before EKS/RDS/Redis
  • EKS must be running before RDS/Redis (for security groups)
  • All others depend on KMS only
```

---

## 5. DATA FLOW DIAGRAMS

### Request Flow (Inbound)

```
┌─────────────────────────────────────────────────────────────────────┐
│                     USER REQUEST FLOW                                │
└─────────────────────────────────────────────────────────────────────┘

External User
     │
     ▼
  [1] AWS WAF
      ├─ Rate limit check (2000/IP in prod)
      ├─ SQL injection filter
      └─ OWASP rules
     │ (Allowed)
     ▼
  [2] EKS ALB (Application Load Balancer)
      ├─ TLS/SSL termination
      └─ Route to service
     │
     ▼
  [3] EKS Pod (AI Agent)
      ├─ Request processing
      └─ Can call:
         │
         ├──→ [4a] Secrets Manager
         │       └─ Get API keys (Anthropic, OpenAI)
         │
         ├──→ [4b] RDS PostgreSQL
         │       ├─ User profiles
         │       ├─ Agent metadata
         │       └─ Session data
         │
         ├──→ [4c] DynamoDB
         │       ├─ Conversations
         │       ├─ Message history
         │       └─ TTL cleanup
         │
         ├──→ [4d] S3
         │       ├─ Knowledge documents
         │       ├─ User uploads
         │       └─ Backups
         │
         ├──→ [4e] ElastiCache Redis
         │       ├─ Session cache
         │       ├─ Response cache
         │       └─ Rate limit tracking
         │
         └──→ [4f] SNS/SQS
                 ├─ Publish events
                 └─ Queue async tasks

ENCRYPTION CHECKPOINT:
  All connections over TLS/HTTPS
  All data at rest encrypted with KMS
  Database connections require security group
```

### Event-Driven Flow (Async)

```
┌─────────────────────────────────────────────────────────────────────┐
│                    EVENT-DRIVEN ARCHITECTURE                         │
└─────────────────────────────────────────────────────────────────────┘

EKS Pod (Agent)
     │
     ├─→ Publishes message to SNS Topic
     │   • prod-ticket-events
     │   • prod-notification-requests
     │   • prod-knowledge-updates
     │   • prod-action-requests
     │
     ▼
  [SNS Topic] (KMS encrypted)
     │
     └──→ Triggers SQS Queue
         (Message stored for 7 days)
         │
         └──→ [Lambda Handler / EKS Consumer]
             ├─ Process message
             ├─ Update database
             └─ Send response
             
         If failed:
         └──→ [Dead Letter Queue] (14 days retention)
             └─ Manual investigation/retry

EXAMPLE: Knowledge Update Flow
  1. User uploads document
  2. EKS pod processes
  3. Publishes "prod-knowledge-updates" to SNS
  4. SQS receives message
  5. Async worker processes:
     ├─ Chunk document
     ├─ Generate embeddings
     ├─ Store in S3
     ├─ Update RDS metadata
     └─ Expire old versions (S3 lifecycle)
```

---

## 6. DATABASE RELATIONSHIPS

```
┌─────────────────────────────────────────────────────────────────────┐
│                   DATA PERSISTENCE LAYER                             │
└─────────────────────────────────────────────────────────────────────┘

PostgreSQL (RDS)                     DynamoDB
  agentdb                            (NoSQL)
  ├─ Users                           ├─ conversations
  │  ├─ id                           │  ├─ PK: userId
  │  ├─ email                        │  ├─ SK: conversationId
  │  └─ org_id                       │  ├─ createdAt (GSI)
  │                                  │  ├─ messages (array)
  ├─ Agents                          │  ├─ ttl (auto-expire)
  │  ├─ id                           │  └─ updated_at
  │  ├─ name                         │
  │  ├─ type                         ├─ sessions
  │  └─ config                       │  ├─ PK: sessionId
  │                                  │  ├─ userId
  ├─ Knowledge Base                  │  ├─ createdAt
  │  ├─ id                           │  ├─ expiresAt (TTL)
  │  ├─ name                         │  └─ metadata
  │  ├─ storage_key (→ S3)           │
  │  └─ chunk_count                  └─ (PITR enabled in Prod)
  │
  ├─ Workflows                     S3 Buckets
  │  ├─ id                           ├─ knowledge-documents
  │  ├─ name                         │  ├─ Original documents
  │  └─ steps                        │  └─ Versioning enabled
  │
  └─ Audit Log                      ├─ document-chunks
     ├─ id                          │  └─ Chunked text
     ├─ user_id                     │
     ├─ action                      ├─ user-uploads
     ├─ timestamp                   │  └─ 90-day lifecycle
     └─ result                      │
                                    ├─ backups
ElastiCache Redis                   │  └─ Multi-tier lifecycle
  ├─ session:{sessionId}            │     (30d IA, 90d IR, 180d Archive)
  │  ├─ user_id                     │
  │  ├─ expires: 24h                └─ audit-logs
  │  └─ metadata                       └─ Immutable records

Cross-references:
  RDS.users.id → DynamoDB.sessions.userId → S3.{path}/user/
  RDS.agents.id → DynamoDB.conversations.context.agentId
  RDS.knowledge.storage_key → S3.knowledge-documents/{key}
```

---

## 7. COST OPTIMIZATION HIERARCHY

```
┌─────────────────────────────────────────────────────────────────────┐
│              COST OPTIMIZATION STRATEGIES BY TIER                    │
└─────────────────────────────────────────────────────────────────────┘

TIER 1: Compute Optimization
  EKS Nodes:
    ├─ ARM-based (Graviton): 20% cheaper than x86
    ├─ SPOT instances (Dev): 70% cheaper (fault-tolerant)
    └─ Right-sized: t3a.medium (dev), r6i.2xlarge (prod)

TIER 2: Data Transfer Optimization
  VPC Endpoints:
    ├─ S3 Gateway endpoint: $0.01/GB saved vs NAT
    ├─ DynamoDB endpoint: No NAT data charges
    ├─ Interface endpoints: $0.007/hour each
    └─ Reduces NAT bandwidth by 60-80%

TIER 3: Storage Optimization
  S3 Lifecycle (Prod):
    ├─ 0-30 days:   STANDARD ($0.023/GB)
    ├─ 30-90 days:  STANDARD_IA ($0.0125/GB)
    ├─ 90-180 days: GLACIER_IR ($0.004/GB)
    └─ 180+ days:   DEEP_ARCHIVE ($0.00099/GB)
  
  DynamoDB:
    ├─ PAY_PER_REQUEST: Good for variable workloads
    └─ Avoid provisioned capacity waste

TIER 4: Database Optimization
  RDS:
    ├─ Single-AZ (dev): No standby cost
    ├─ Multi-AZ (prod): 100% premium for HA
    ├─ No read replicas unless needed
    └─ Graviton instances: 20% cheaper

  Redis:
    ├─ Single node (dev): No failover overhead
    └─ 3-node cluster (prod): HA requirement

TIER 5: Encryption Overhead
  KMS:
    ├─ DEV: 1 key (shared) = $1/month
    ├─ PROD: 7 keys = $7/month
    └─ Negligible vs security benefit

MONTHLY COST ESTIMATE:
  DEV:   ~$200  (SPOT compute, single-AZ, minimal services)
  PROD: ~$15,000 (ON_DEMAND, multi-AZ, full HA/DR)
```

---

## 8. HORIZONTAL SCALING ARCHITECTURE

```
┌─────────────────────────────────────────────────────────────────────┐
│           AUTO-SCALING & HORIZONTAL SCALING CAPABILITY               │
└─────────────────────────────────────────────────────────────────────┘

EKS Node Groups (Horizontal Pod Autoscaler)
  ┌─────────────────────────────────────────────┐
  │ General Node Group                          │
  │ ├─ Min: 3 nodes                             │
  │ ├─ Max: 20 nodes                            │
  │ ├─ Desired: 3-20 (auto-scales)              │
  │ ├─ Metric: CPU/Memory utilization           │
  │ └─ Scale-up: +1-2 nodes (33% max churn)     │
  └─────────────────────────────────────────────┘

  ┌─────────────────────────────────────────────┐
  │ AI Node Group                               │
  │ ├─ Min: 2 nodes                             │
  │ ├─ Max: 10 nodes                            │
  │ ├─ Desired: 2-10 (auto-scales)              │
  │ ├─ Metric: AI model serving demand          │
  │ └─ Taints: workload=ai (only AI pods)       │
  └─────────────────────────────────────────────┘

DynamoDB Auto-Scaling (for Provisioned mode)
  ├─ Read capacity: Target 70% utilization
  ├─ Write capacity: Target 70% utilization
  ├─ Scale-up: Immediate
  └─ Scale-down: 15 minutes cooldown

RDS Auto-Scaling (Multi-AZ)
  ├─ Storage: Auto-grows up to max_allocated
  ├─ Failover: <2 minutes to standby
  └─ Read replica: For read-heavy workloads

ElastiCache Auto-Failover
  ├─ Primary node fails → Replica promotes
  ├─ RTO: <30 seconds
  └─ No application code changes needed

SNS/SQS Scaling
  ├─ Automatic (no configuration needed)
  ├─ Unlimited message throughput
  └─ 7-day retention (Prod) vs 1-day (Dev)
```

