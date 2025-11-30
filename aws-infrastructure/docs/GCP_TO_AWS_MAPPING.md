# GCP to AWS Service Mapping (2025)

This document provides a comprehensive mapping of Google Cloud Platform (GCP)
services to their AWS equivalents for the ServiceNow AI Research Assistant
project.

## Service Mapping Overview

| GCP Service                        | AWS Equivalent                               | Notes                                  |
| ---------------------------------- | -------------------------------------------- | -------------------------------------- |
| **Google Kubernetes Engine (GKE)** | **Amazon EKS**                               | Managed Kubernetes service             |
| **Cloud Storage**                  | **Amazon S3**                                | Object storage with lifecycle policies |
| **Cloud SQL (PostgreSQL)**         | **Amazon RDS PostgreSQL**                    | Managed relational database            |
| **Firestore**                      | **Amazon DynamoDB**                          | NoSQL document database                |
| **Cloud Pub/Sub**                  | **Amazon SNS + SQS** or **EventBridge**      | Message queue and pub/sub              |
| **Memorystore for Redis**          | **Amazon ElastiCache Redis**                 | In-memory cache                        |
| **Cloud KMS**                      | **AWS KMS**                                  | Key management service                 |
| **VPC**                            | **Amazon VPC**                               | Virtual private cloud                  |
| **Cloud Armor**                    | **AWS WAF**                                  | Web application firewall               |
| **Secret Manager**                 | **AWS Secrets Manager**                      | Secret management                      |
| **Vertex AI**                      | **Amazon Bedrock**                           | AI/ML platform                         |
| **Cloud Run**                      | **AWS App Runner** or **ECS Fargate**        | Serverless containers                  |
| **Workload Identity**              | **IAM Roles for Service Accounts (IRSA)**    | Pod-level IAM roles                    |
| **Identity-Aware Proxy (IAP)**     | **AWS Verified Access** or **ALB + Cognito** | Identity-aware access                  |
| **Cloud Logging**                  | **Amazon CloudWatch Logs**                   | Centralized logging                    |
| **Cloud Monitoring**               | **Amazon CloudWatch**                        | Monitoring and metrics                 |
| **Cloud Billing**                  | **AWS Cost Explorer** + **Budgets**          | Cost management                        |

## Detailed Service Comparisons

### 1. Container Orchestration

#### GKE → Amazon EKS

- **GCP**: Google Kubernetes Engine with managed control plane
- **AWS**: Amazon Elastic Kubernetes Service with managed control plane
- **Key Differences**:
  - EKS uses VPC CNI for networking (vs GKE's Kubenet/Calico)
  - EKS node groups managed via Auto Scaling Groups
  - EKS add-ons for core components (CoreDNS, kube-proxy, VPC CNI)
- **2025 Best Practices**:
  - Use EKS 1.28+ with extended support
  - Enable EKS Pod Identity for IRSA (replaces Workload Identity)
  - Use Karpenter for autoscaling (more efficient than Cluster Autoscaler)
  - Enable EKS control plane logging to CloudWatch

### 2. Object Storage

#### Cloud Storage → Amazon S3

- **GCP**: Cloud Storage with buckets and lifecycle management
- **AWS**: Amazon S3 with buckets and lifecycle policies
- **Key Features**:
  - S3 Standard → Standard-IA → Glacier Instant → Glacier Deep Archive
  - S3 Intelligent-Tiering for automatic cost optimization
  - S3 Object Lock for WORM (Write Once Read Many)
  - Server-side encryption with KMS (SSE-KMS)
- **2025 Best Practices**:
  - Enable S3 versioning for critical data
  - Use S3 Intelligent-Tiering for cost optimization
  - Implement S3 Block Public Access at account level
  - Use S3 Event Notifications → EventBridge for event-driven workflows

### 3. Relational Database

#### Cloud SQL → Amazon RDS PostgreSQL

- **GCP**: Cloud SQL with automated backups and read replicas
- **AWS**: Amazon RDS with Multi-AZ and read replicas
- **Key Features**:
  - RDS Multi-AZ for high availability (vs Cloud SQL HA)
  - RDS Proxy for connection pooling
  - Performance Insights for query analysis
  - Automated backups with point-in-time recovery
- **2025 Best Practices**:
  - Use RDS PostgreSQL 16+ (latest stable)
  - Enable Performance Insights and Enhanced Monitoring
  - Use RDS Proxy for serverless/Lambda connections
  - Enable encryption at rest with KMS
  - Use AWS Secrets Manager for credential rotation

### 4. NoSQL Database

#### Firestore → Amazon DynamoDB

- **GCP**: Firestore with document-based data model
- **AWS**: DynamoDB with key-value and document store
- **Key Differences**:
  - DynamoDB uses partition/sort keys (vs Firestore collections)
  - DynamoDB supports both On-Demand and Provisioned capacity
  - DynamoDB Streams for change data capture
- **2025 Best Practices**:
  - Use DynamoDB On-Demand for unpredictable workloads
  - Enable Point-in-Time Recovery (PITR)
  - Use DynamoDB Streams → Lambda for event processing
  - Implement Global Tables for multi-region replication
  - Use DynamoDB Encryption at rest (KMS)

### 5. Messaging & Event Streaming

#### Cloud Pub/Sub → Amazon SNS + SQS / EventBridge

- **GCP**: Cloud Pub/Sub for pub/sub messaging
- **AWS**: SNS for pub/sub + SQS for queuing, or EventBridge for event routing
- **Mapping**:
  - Pub/Sub topics → SNS topics + SQS queues
  - Pub/Sub subscriptions → SQS queues subscribed to SNS
  - For event-driven architectures, use EventBridge for advanced routing
- **2025 Best Practices**:
  - Use Amazon EventBridge for event-driven architectures
  - Enable SNS FIFO for ordered message delivery
  - Use SQS Dead Letter Queues (DLQ) for failed messages
  - Implement SQS visibility timeout and message retention
  - Use EventBridge Schema Registry for event contracts

### 6. In-Memory Cache

#### Memorystore for Redis → Amazon ElastiCache Redis

- **GCP**: Memorystore for Redis with managed scaling
- **AWS**: ElastiCache for Redis with cluster mode
- **Key Features**:
  - Redis 7.0+ with enhanced I/O multiplexing
  - Cluster mode for horizontal scaling
  - Multi-AZ with automatic failover
  - Redis AUTH for authentication
- **2025 Best Practices**:
  - Use Redis 7.x with enhanced features
  - Enable encryption in-transit and at-rest
  - Use Redis Cluster mode for high availability
  - Implement connection pooling in application layer

### 7. Key Management

#### Cloud KMS → AWS KMS

- **GCP**: Cloud KMS with regional keyrings
- **AWS**: AWS KMS with multi-region keys
- **Key Features**:
  - Customer managed keys (CMKs)
  - Automatic key rotation
  - Multi-region keys for global applications
  - Key policies for fine-grained access control
- **2025 Best Practices**:
  - Use AWS KMS multi-region keys for global replication
  - Enable automatic key rotation (365 days)
  - Use key aliases for flexibility
  - Implement least privilege access via key policies
  - Enable CloudTrail logging for key usage

### 8. Networking

#### VPC → Amazon VPC

- **GCP**: VPC with subnets and Cloud NAT
- **AWS**: Amazon VPC with subnets and NAT Gateway
- **Key Features**:
  - VPC with public/private subnets
  - NAT Gateway for outbound internet access
  - Internet Gateway for public resources
  - VPC Flow Logs for traffic analysis
- **2025 Best Practices**:
  - Use at least 3 AZs for high availability
  - Implement private subnets for workloads
  - Use VPC Endpoints for AWS services (S3, DynamoDB, etc.)
  - Enable VPC Flow Logs → CloudWatch Logs
  - Use Network Firewall for advanced filtering

### 9. Web Application Firewall

#### Cloud Armor → AWS WAF

- **GCP**: Cloud Armor with preconfigured rules
- **AWS**: AWS WAF with managed rule groups
- **Key Features**:
  - Managed rule groups (OWASP Top 10, Bot Control, etc.)
  - Rate-based rules for DDoS protection
  - Custom rules with IPSet and RegexPatternSet
  - Integration with ALB, API Gateway, CloudFront
- **2025 Best Practices**:
  - Use AWS Managed Rules (Core, Known Bad Inputs, SQL Injection)
  - Implement rate limiting per IP/region
  - Use AWS Shield Standard (free) + Shield Advanced for critical apps
  - Enable WAF logging → CloudWatch Logs or S3
  - Use AWS Firewall Manager for multi-account WAF management

### 10. Secret Management

#### Secret Manager → AWS Secrets Manager

- **GCP**: Secret Manager with versioning
- **AWS**: AWS Secrets Manager with automatic rotation
- **Key Features**:
  - Automatic rotation for RDS/DocumentDB/Redshift
  - Lambda-based rotation for custom secrets
  - Cross-account access via resource policies
  - Integration with IAM for access control
- **2025 Best Practices**:
  - Enable automatic rotation for database credentials
  - Use Secrets Manager instead of Systems Manager Parameter Store for secrets
  - Implement least privilege access via IAM policies
  - Use VPC Endpoints for Secrets Manager access from private subnets
  - Enable encryption with KMS

### 11. AI/ML Platform

#### Vertex AI → Amazon Bedrock

- **GCP**: Vertex AI with Matching Engine for vector search
- **AWS**: Amazon Bedrock for foundation models + OpenSearch for vector search
- **Mapping**:
  - Vertex AI Matching Engine → Amazon OpenSearch Service (with k-NN plugin)
  - Vertex AI Embeddings → Amazon Bedrock Embeddings (Titan, Cohere)
  - Vertex AI Model Garden → Amazon Bedrock (Claude, Llama, etc.)
- **2025 Best Practices**:
  - Use Amazon Bedrock for foundation models (Claude 3.5, Llama 3.1)
  - Use Amazon OpenSearch Service with k-NN for vector search
  - Alternatively, use Amazon MemoryDB for Redis (vector search)
  - Enable Bedrock Guardrails for responsible AI
  - Use Bedrock Agents for agentic workflows

### 12. Serverless Containers

#### Cloud Run → AWS App Runner / ECS Fargate

- **GCP**: Cloud Run for serverless containers
- **AWS**: AWS App Runner (simpler) or ECS Fargate (more control)
- **Mapping**:
  - Cloud Run services → App Runner services (automatic scaling, HTTPS)
  - For more control: ECS Fargate with ALB
- **2025 Best Practices**:
  - Use App Runner for simple HTTP services (auto-scaling, auto-HTTPS)
  - Use ECS Fargate for complex microservices with ECS Service Connect
  - Enable container insights for monitoring
  - Use AWS Copilot CLI for easy deployment
  - Implement health checks and graceful shutdowns

### 13. Workload Identity

#### Workload Identity → IAM Roles for Service Accounts (IRSA)

- **GCP**: Workload Identity binds K8s SA to GCP SA
- **AWS**: IRSA binds K8s SA to IAM Role
- **2025 Best Practices**:
  - Use EKS Pod Identity (2024+) for simpler configuration
  - Implement least privilege IAM policies per pod
  - Use IAM role session tags for fine-grained access
  - Enable IAM Access Analyzer to validate permissions

### 14. Identity-Aware Proxy

#### IAP → AWS Verified Access / ALB + Cognito

- **GCP**: Identity-Aware Proxy for BeyondCorp
- **AWS**: AWS Verified Access (2024+) or ALB with Cognito
- **Mapping**:
  - IAP → AWS Verified Access (zero-trust access)
  - IAP → ALB + Cognito (OAuth 2.0, SAML)
- **2025 Best Practices**:
  - Use AWS Verified Access for zero-trust network access
  - Alternatively, use ALB with Cognito for OIDC/SAML
  - Implement MFA with Cognito advanced security
  - Use AWS IAM Identity Center (SSO) for workforce access

## Infrastructure as Code

### Terraform Providers

- **GCP**: `google` and `google-beta` providers
- **AWS**: `aws` provider (v5.x recommended)

### State Management

- **GCP**: Terraform state in Cloud Storage
- **AWS**: Terraform state in S3 with DynamoDB for locking

## Cost Optimization

### 2025 Best Practices

1. **Compute**:

   - Use EKS with Karpenter for efficient autoscaling
   - Use Spot Instances for non-critical workloads (70-90% savings)
   - Use Graviton3 instances (ARM) for 40% better price/performance

2. **Storage**:

   - Use S3 Intelligent-Tiering for automatic cost optimization
   - Enable S3 Storage Lens for usage analytics
   - Use EBS gp3 volumes (20% cheaper than gp2)

3. **Networking**:

   - Use VPC Endpoints to avoid NAT Gateway costs
   - Use CloudFront for edge caching (reduce origin traffic)

4. **Monitoring**:
   - Use AWS Cost Explorer for cost analysis
   - Enable AWS Budgets with alerts
   - Use AWS Compute Optimizer for rightsizing recommendations

## Migration Strategy

### Phase 1: Planning (Week 1-2)

1. Review GCP resource inventory
2. Map all services to AWS equivalents
3. Create AWS accounts and organization structure
4. Set up Terraform state backend (S3 + DynamoDB)

### Phase 2: Infrastructure (Week 3-4)

1. Deploy VPC and networking
2. Deploy EKS cluster with node groups
3. Deploy RDS PostgreSQL (Multi-AZ)
4. Deploy ElastiCache Redis
5. Deploy DynamoDB tables
6. Deploy S3 buckets with lifecycle policies

### Phase 3: Application (Week 5-6)

1. Update application configuration for AWS SDKs
2. Deploy Kubernetes workloads to EKS
3. Configure SNS/SQS for messaging
4. Set up AWS Secrets Manager
5. Configure AWS WAF rules

### Phase 4: Testing & Cutover (Week 7-8)

1. Run integration tests on AWS
2. Perform load testing
3. Set up monitoring and alerting
4. Plan cutover window
5. Execute cutover and validate

## Security Considerations

### 2025 Security Best Practices

1. **Identity & Access**:

   - Enable AWS IAM Identity Center for workforce access
   - Use IAM roles everywhere (no long-term credentials)
   - Enable MFA for privileged accounts
   - Use AWS CloudTrail for audit logging

2. **Network Security**:

   - Use Security Groups and NACLs for defense in depth
   - Enable VPC Flow Logs
   - Use AWS Network Firewall for advanced filtering
   - Implement zero-trust with AWS Verified Access

3. **Data Protection**:

   - Enable encryption at rest for all services (KMS)
   - Enable encryption in transit (TLS 1.3)
   - Use S3 Block Public Access
   - Enable RDS encryption and automated backups

4. **Compliance**:
   - Use AWS Config for compliance monitoring
   - Enable AWS Security Hub for centralized security findings
   - Use AWS GuardDuty for threat detection
   - Implement AWS Organizations SCPs for preventive controls

## Monitoring & Observability

### AWS Observability Stack

1. **Metrics**: Amazon CloudWatch Metrics
2. **Logs**: Amazon CloudWatch Logs with Logs Insights
3. **Traces**: AWS X-Ray for distributed tracing
4. **Dashboards**: CloudWatch Dashboards
5. **Alerts**: CloudWatch Alarms → SNS → Lambda/Email

### OpenTelemetry Integration

- Use AWS Distro for OpenTelemetry (ADOT)
- Export to CloudWatch, X-Ray, or third-party (Prometheus, Grafana)

## Additional Resources

- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [AWS EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [AWS Security Best Practices](https://docs.aws.amazon.com/security/)
- [AWS Prescriptive Guidance](https://aws.amazon.com/prescriptive-guidance/)

## Conclusion

This mapping provides a comprehensive guide for migrating from GCP to AWS using
2025 best practices. The AWS implementation maintains feature parity while
leveraging AWS-native services for optimal performance, security, and cost
efficiency.
