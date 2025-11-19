# Security Architecture Diagrams

## Complete Defense in Depth Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          Internet / External Traffic                         │
│                                                                              │
├─────────────────────────────────────────────────────────────────────────────┤
│ LAYER 1: PERIMETER DEFENSE                                                  │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │ AWS WAF (Web Application Firewall)                                  │   │
│  │ - SQL injection prevention                                         │   │
│  │ - XSS protection                                                   │   │
│  │ - Rate limiting (1000 req/5min)                                    │   │
│  │ - Geo-blocking (if needed)                                         │   │
│  │ - IP reputation blocking                                           │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │ AWS Shield (DDoS Protection)                                        │   │
│  │ - Standard: Automatic protection                                   │   │
│  │ - Advanced: 24/7 DDoS Response Team                               │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                      ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│ LAYER 2: NETWORK SECURITY (AWS VPC)                                         │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │ Public Subnets (Availability Zone A & B)                            │   │
│  │                                                                      │   │
│  │  ┌────────────────────────────────────────────────────────────┐    │   │
│  │  │ Application Load Balancer (ALB)                            │    │   │
│  │  │ - HTTPS/TLS 1.3                                           │    │   │
│  │  │ - Health check on /health endpoint                         │    │   │
│  │  │ - Listener on port 443                                     │    │   │
│  │  │ - Forwarding to private subnets                            │    │   │
│  │  └────────────────────────────────────────────────────────────┘    │   │
│  │                                                                      │   │
│  │  ┌────────────────────────────────────────────────────────────┐    │   │
│  │  │ NAT Gateway (for outbound traffic)                         │    │   │
│  │  │ - Elastic IP address                                       │    │   │
│  │  │ - Handles all private subnet outbound                      │    │   │
│  │  └────────────────────────────────────────────────────────────┘    │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │ Private Subnets (Availability Zone A & B)                           │   │
│  │                                                                      │   │
│  │  ┌─────────────────┐  ┌─────────────────┐                           │   │
│  │  │  Lambda Tier    │  │  ECS Tier       │                           │   │
│  │  │                 │  │                 │                           │   │
│  │  │  - Agent        │  │  - Orchestrator │                           │   │
│  │  │    Coordinator  │  │  - Worker nodes │                           │   │
│  │  │  - Agent        │  │                 │                           │   │
│  │  │    Executor     │  │                 │                           │   │
│  │  │  - Knowledge    │  │                 │                           │   │
│  │  │    Processor    │  │                 │                           │   │
│  │  │                 │  │                 │                           │   │
│  │  │  Security       │  │  Security       │                           │   │
│  │  │  Groups:        │  │  Groups:        │                           │   │
│  │  │  - Ingress:     │  │  - Ingress:     │                           │   │
│  │  │    ALB (443)    │  │    ALB (ports)  │                           │   │
│  │  │  - Egress:      │  │  - Egress:      │                           │   │
│  │  │    Limited      │  │    Limited      │                           │   │
│  │  └─────────────────┘  └─────────────────┘                           │   │
│  │                                                                      │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │ Data Tier Subnets (Availability Zone A & B)                         │   │
│  │                                                                      │   │
│  │  ┌─────────────────────────┐  ┌──────────────────────────┐          │   │
│  │  │ RDS Database Cluster    │  │  DynamoDB                │          │   │
│  │  │ (Multi-AZ Read Replica) │  │  (Global Table)          │          │   │
│  │  │                         │  │                          │          │   │
│  │  │ - Encryption at rest    │  │ - Point-in-time recovery│          │   │
│  │  │ - Automated backups     │  │ - Encryption at rest     │          │   │
│  │  │ - Multi-AZ HA           │  │ - TTL on items           │          │   │
│  │  │ - Read replicas         │  │ - Streams enabled        │          │   │
│  │  │ - Encryption in transit │  │ - Encryption in transit  │          │   │
│  │  │                         │  │                          │          │   │
│  │  │ Security group:         │  │ Resource-based policy:   │          │   │
│  │  │ - Only from app tier    │  │ - Only from app tier     │          │   │
│  │  │ - Port 5432 (Postgres)  │  │ - No public access       │          │   │
│  │  └─────────────────────────┘  └──────────────────────────┘          │   │
│  │                                                                      │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                      ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│ LAYER 3: IDENTITY & ACCESS (IAM)                                            │
│                                                                              │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐          │
│  │ Lambda Execution │  │ ECS Task         │  │ RDS IAM Auth     │          │
│  │ Role             │  │ Execution Role   │  │ Token            │          │
│  │                  │  │                  │  │                  │          │
│  │ Policies:        │  │ Policies:        │  │ TTL: 15 minutes  │          │
│  │ - BedrockAccess  │  │ - BedrockAccess  │  │                  │          │
│  │ - DynamoDB       │  │ - DynamoDB       │  │ No passwords:    │          │
│  │ - S3             │  │ - ECR access     │  │ - Tokens only    │          │
│  │ - Secrets        │  │ - CloudWatch     │  │ - Auto-rotated   │          │
│  │ - CloudWatch     │  │ - Secrets        │  │                  │          │
│  │ - KMS            │  │ - KMS            │  │                  │          │
│  │                  │  │                  │  │                  │          │
│  │ Trust:           │  │ Trust:           │  │ Trust:           │          │
│  │ - Lambda service │  │ - ECS service    │  │ - RDS service    │          │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘          │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                      ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│ LAYER 4: DATA PROTECTION (Encryption)                                       │
│                                                                              │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐          │
│  │ KMS Master Key   │  │ S3 Encryption    │  │ Secrets Manager  │          │
│  │ (Customer        │  │ (KMS AES-256)    │  │ (KMS encrypted)  │          │
│  │  Managed)        │  │                  │  │                  │          │
│  │                  │  │ Objects:         │  │ Secrets:         │          │
│  │ - AWS_KMS        │  │ - Data keys      │  │ - DB passwords   │          │
│  │ - Hardware       │  │ - Encrypted      │  │ - API keys       │          │
│  │   backed         │  │ - Audit logging  │  │ - Tokens         │          │
│  │ - Automatic      │  │                  │  │                  │          │
│  │   rotation       │  │                  │  │ Rotation:        │          │
│  │                  │  │                  │  │ - Auto every 30d │          │
│  │ CloudTrail:      │  │ CloudTrail:      │  │ - Via Lambda     │          │
│  │ - Key usage      │  │ - Encrypt calls  │  │ - Verified       │          │
│  │ - Access denied  │  │ - Object access  │  │                  │          │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘          │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                      ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│ LAYER 5: MONITORING & DETECTION                                             │
│                                                                              │
│  ┌──────────────────────┐  ┌──────────────────────┐  ┌──────────────────┐  │
│  │ CloudWatch Logs      │  │ CloudWatch Metrics   │  │ CloudTrail       │  │
│  │                      │  │                      │  │                  │  │
│  │ - Lambda logs        │  │ - Lambda duration    │  │ - All API calls  │  │
│  │ - Application logs   │  │ - Lambda errors      │  │ - IAM changes    │  │
│  │ - Network logs       │  │ - RDS CPU/memory     │  │ - Resource mods  │  │
│  │ - Access logs        │  │ - API latency        │  │ - 90-day history │  │
│  │ - 90-day retention   │  │ - Error rates        │  │                  │  │
│  │                      │  │                      │  │ S3 Delivery:     │  │
│  │ Alarms:              │  │ Alarms:              │  │ - Encrypted      │  │
│  │ - Error patterns     │  │ - Threshold breaches │  │ - MFA delete     │  │
│  │ - Anomalies          │  │ - Anomaly detection  │  │ - Validation     │  │
│  └──────────────────────┘  └──────────────────────┘  └──────────────────┘  │
│                                                                              │
│  ┌──────────────────────┐  ┌──────────────────────┐  ┌──────────────────┐  │
│  │ GuardDuty            │  │ Security Hub         │  │ VPC Flow Logs    │  │
│  │                      │  │                      │  │                  │  │
│  │ - Threat detection   │  │ - Compliance checks  │  │ - Network traffic│  │
│  │ - Anomalies          │  │ - Findings           │  │ - Connections    │  │
│  │ - Malware detection  │  │ - Standard controls  │  │ - Accepted/denied│  │
│  │ - Real-time findings │  │ - Score/severity     │  │ - Bytes in/out   │  │
│  │                      │  │                      │  │ - 30-day archive │  │
│  └──────────────────────┘  └──────────────────────┘  └──────────────────┘  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                      ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│ LAYER 6: ALERTING & RESPONSE                                                │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │ SNS Topics (Email/SMS)                                              │   │
│  │ - Critical security events                                          │   │
│  │ - High error rates                                                  │   │
│  │ - Unusual API activity                                              │   │
│  │ - GuardDuty findings                                                │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │ PagerDuty Integration                                               │   │
│  │ - Tier 1 incidents                                                  │   │
│  │ - Security findings                                                 │   │
│  │ - Critical system failures                                          │   │
│  │ - On-call escalation                                                │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │ Lambda Automated Response                                           │   │
│  │ - Isolate compromised systems                                       │   │
│  │ - Revoke compromised credentials                                    │   │
│  │ - Enable enhanced logging                                           │   │
│  │ - Trigger incident response                                         │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Data Flow - Bedrock Agent Invocation

```
User/Client
    │
    ▼
┌─────────────────┐
│   HTTPS (TLS1.3) │ - Encrypted in transit
└─────────────────┘ - Certificate validated
    │
    ▼
┌──────────────────────────────┐
│ AWS WAF & Shield             │
│ - Rate limiting              │
│ - IP reputation              │
│ - Threat pattern detection   │
└──────────────────────────────┘
    │
    ▼
┌──────────────────────────────┐
│ Application Load Balancer    │
│ - TLS termination            │
│ - Listener on 443            │
│ - Health checks              │
└──────────────────────────────┘
    │
    ▼
┌──────────────────────────────┐
│ API Gateway                  │
│ - Request validation         │
│ - API key verification       │
│ - Request logging            │
│ - Rate limiting              │
└──────────────────────────────┘
    │
    ▼
┌──────────────────────────────┐
│ Authorizer Lambda            │
│ - Verify API key/token       │
│ - Validate user identity     │
│ - Check permissions          │
│ - CloudTrail logging         │
└──────────────────────────────┘
    │ (Authorized)
    ▼
┌──────────────────────────────┐
│ Agent Coordinator Lambda     │
│ (Assume IAM role)            │
│ - Temporary credentials      │
│ - CloudTrail logging         │
│ - Request validation         │
│ - Agent selection logic      │
└──────────────────────────────┘
    │
    ├─────────────────────┬──────────────┐
    │                     │              │
    ▼                     ▼              ▼
┌──────────┐      ┌──────────┐      ┌──────────┐
│ Bedrock  │      │ Database │      │ Secrets  │
│ API Call │      │ Query    │      │ Fetch    │
└──────────┘      └──────────┘      └──────────┘
    │                    │              │
    │            ┌────────┴──────────┐  │
    │            │   (Encrypted)     │  │
    │            ▼                   ▼  │
    │        ┌─────────────────────┐   │
    │        │ RDS/DynamoDB        │   │
    │        │ (KMS encrypted)     │   │
    │        │ (Encrypted in transit│  │
    │        └─────────────────────┘   │
    │            │                     │
    └────────────┼─────────────────────┘
                 │
                 ▼
        ┌───────────────────┐
        │ Agent Executor    │
        │ Lambda/ECS        │
        └───────────────────┘
                 │
                 ▼
        ┌───────────────────────┐
        │ Bedrock Model         │
        │ Invocation            │
        │ (Token-based auth)    │
        └───────────────────────┘
                 │
        ┌────────┴────────┐
        │                 │
        ▼                 ▼
    Response          CloudWatch
    (to client)       Logging
                      │
                      ▼
                 ┌─────────────┐
                 │ S3 Logs     │
                 │ (encrypted) │
                 │ (7yr retain)│
                 └─────────────┘
```

## Security Control Layers

```
┌────────────────────────────────────────────────┐
│         Application Layer Security             │
│ - Input validation                             │
│ - Output encoding                              │
│ - Error handling                               │
│ - Security headers                             │
│ - CORS configuration                           │
├────────────────────────────────────────────────┤
│      Infrastructure Layer Security             │
│ - Network segmentation                         │
│ - Encryption at rest                           │
│ - Encryption in transit                        │
│ - IAM role-based access                        │
│ - Key management                               │
├────────────────────────────────────────────────┤
│       Operations Layer Security                │
│ - Monitoring and alerting                      │
│ - Incident response                            │
│ - Access control                               │
│ - Change management                            │
│ - Audit logging                                │
├────────────────────────────────────────────────┤
│       Governance Layer Security                │
│ - Security policies                            │
│ - Compliance standards                         │
│ - Risk management                              │
│ - Vendor management                            │
│ - Training and awareness                       │
└────────────────────────────────────────────────┘
```

---

**Version**: 1.0
**Updated**: November 2024
**Format**: ASCII Diagrams (PlantUML compatible)
