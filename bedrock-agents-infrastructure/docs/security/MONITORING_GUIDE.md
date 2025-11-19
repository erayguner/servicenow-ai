# Monitoring Guide

## Table of Contents

1. [Monitoring Architecture](#monitoring-architecture)
2. [CloudWatch Setup](#cloudwatch-setup)
3. [Dashboards Configuration](#dashboards-configuration)
4. [Alarm Configuration](#alarm-configuration)
5. [Log Analysis](#log-analysis)
6. [Performance Tuning](#performance-tuning)
7. [Troubleshooting](#troubleshooting)
8. [Metrics Reference](#metrics-reference)
9. [Alert Response Procedures](#alert-response-procedures)
10. [Log Retention and Archival](#log-retention-and-archival)

## Monitoring Architecture

### Overview

The monitoring architecture provides comprehensive visibility into Bedrock Agents Infrastructure across application, infrastructure, and security domains.

```
┌──────────────────────────────────────────────────────────────┐
│                    Data Collection Layer                      │
├──────────────────────────────────────────────────────────────┤
│                                                                │
│  ┌─────────────────┐  ┌─────────────────┐  ┌────────────────┐
│  │   Lambda Logs   │  │  Container Logs │  │  API Gateway   │
│  │   CloudTrail    │  │  RDS Logs       │  │  ALB Logs      │
│  │  VPC Flow Logs  │  │  DynamoDB Logs  │  │  WAF Logs      │
│  └─────────────────┘  └─────────────────┘  └────────────────┘
│           │                    │                     │
└───────────┼────────────────────┼─────────────────────┼────────┘
            │                    │                     │
            ▼                    ▼                     ▼
┌──────────────────────────────────────────────────────────────┐
│              CloudWatch Aggregation Layer                     │
├──────────────────────────────────────────────────────────────┤
│                                                                │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  Log Groups (organized by service/component)        │    │
│  │  - /aws/lambda/bedrock-agent-*                      │    │
│  │  - /aws/ecs/bedrock-cluster                         │    │
│  │  - /aws/rds/bedrock-database                        │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                                │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  Custom Metrics                                      │    │
│  │  - Agent execution time                             │    │
│  │  - Model invocation count                           │    │
│  │  - Error rates by type                              │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                                │
└──────────────────────────────────────────────────────────────┘
            │                    │                     │
            ▼                    ▼                     ▼
┌──────────────────────────────────────────────────────────────┐
│           Analysis & Detection Layer                         │
├──────────────────────────────────────────────────────────────┤
│                                                                │
│  ┌──────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │  CloudWatch      │  │  GuardDuty      │  │ Security Hub │ │
│  │  Alarms          │  │  Threat         │  │ Compliance   │ │
│  │  Anomalies       │  │  Detection      │  │ Monitoring   │ │
│  └──────────────────┘  └─────────────────┘  └──────────────┘ │
│                                                                │
└──────────────────────────────────────────────────────────────┘
            │                    │                     │
            ▼                    ▼                     ▼
┌──────────────────────────────────────────────────────────────┐
│             Notification & Response Layer                    │
├──────────────────────────────────────────────────────────────┤
│                                                                │
│  ┌──────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │  SNS Topics      │  │  Email Alerts   │  │  PagerDuty   │ │
│  │  Slack Webhooks  │  │  SMS Alerts     │  │  Opsgenie    │ │
│  └──────────────────┘  └─────────────────┘  └──────────────┘ │
│                                                                │
└──────────────────────────────────────────────────────────────┘
            │
            ▼
┌──────────────────────────────────────────────────────────────┐
│                  Response & Investigation                    │
├──────────────────────────────────────────────────────────────┤
│  - Review alert details                                      │
│  - Investigate using logs and metrics                        │
│  - Execute response procedures                               │
│  - Document findings and actions                             │
└──────────────────────────────────────────────────────────────┘
```

### Key Components

#### CloudWatch Logs
- Centralized log aggregation
- Log groups for each service
- Metric filters for extraction
- Long-term retention in S3

#### CloudWatch Metrics
- AWS service metrics (Lambda, RDS, DynamoDB)
- Custom application metrics
- Business metrics (agent performance)
- Infrastructure metrics (CPU, memory)

#### CloudWatch Dashboards
- Real-time visualization
- Multi-service views
- Operational status
- Performance trends

#### CloudWatch Alarms
- Automated alerting on thresholds
- Multi-metric conditions
- Action triggers (SNS, Lambda)
- Composite alarms

#### GuardDuty
- Threat detection analysis
- Anomalous behavior detection
- Machine learning-based findings
- Integration with Security Hub

#### Security Hub
- Compliance standard aggregation
- Automated remediation
- Finding prioritization
- Cross-service visibility

## CloudWatch Setup

### Log Groups Organization

```
Organizational Structure:
/bedrock-agents-infrastructure/
├── /aws/lambda/
│   ├── agent-coordinator
│   ├── agent-executor
│   └── knowledge-processor
├── /aws/ecs/
│   ├── orchestrator
│   └── worker
├── /aws/rds/
│   └── bedrock-database
├── /aws/dynamodb/
│   └── agent-state
├── /aws/apigateway/
│   └── bedrock-api
├── /aws/waf/
│   └── api-protection
└── /security/
    ├── cloudtrail
    ├── guardduty
    └── access-logs
```

### Log Group Configuration

#### Retention Policies
```
Policy Schedule:
- CloudTrail logs: 7 years (compliance requirement)
- Security logs: 2 years (audit trail)
- Application logs: 90 days (troubleshooting)
- Performance logs: 30 days (capacity planning)
- Access logs: 1 year (forensics)
```

#### Retention Implementation
```bash
# CloudTrail log group - 7 years retention
aws logs put-retention-policy \
  --log-group-name /aws/cloudtrail/bedrock-agents \
  --retention-in-days 2555

# Security log group - 2 years retention
aws logs put-retention-policy \
  --log-group-name /bedrock-agents-infrastructure/security \
  --retention-in-days 730

# Application log group - 90 days retention
aws logs put-retention-policy \
  --log-group-name /aws/lambda/agent-coordinator \
  --retention-in-days 90
```

### Log Filtering and Parsing

#### Metric Filters
Create filters to extract key metrics from logs:

```
Filter Pattern Examples:

1. Lambda errors:
   "[timestamp, request_id, ERROR...]"
   Metric: LambdaErrors

2. API latency:
   "[..., response_time > 1000, ...]"
   Metric: SlowAPICalls

3. Authentication failures:
   "[..., auth_status = FAILED, ...]"
   Metric: AuthenticationFailures

4. Database connection errors:
   "[..., error_type = DatabaseConnection, ...]"
   Metric: DBConnectionErrors
```

## Dashboards Configuration

### Executive Dashboard

**Purpose**: High-level operational status for stakeholders

**Metrics**:
- System availability (%)
- Error rate (%)
- Average response time (ms)
- Active agents count
- Cost per agent execution
- Incident count (24h)

**Refresh Rate**: 5 minutes

### Operational Dashboard

**Purpose**: Real-time operational monitoring for engineers

**Metrics**:
- Lambda invocations and duration
- Error rates by service
- Database connections and queries
- API request rates and latency
- Memory usage and limits
- Container CPU and memory
- Queue depths (SQS/SNS)

**Refresh Rate**: 1 minute

### Security Dashboard

**Purpose**: Security posture and threat monitoring

**Metrics**:
- Failed authentication attempts
- Unauthorized API calls
- Security Hub findings by severity
- GuardDuty detections
- Network anomalies
- Suspicious IAM activity
- Policy violations

**Refresh Rate**: Real-time

### Performance Dashboard

**Purpose**: Application and infrastructure performance

**Metrics**:
- Agent execution time (p50, p95, p99)
- Model inference latency
- Database query performance
- Cache hit rates
- API response times by endpoint
- Throughput (requests/sec)
- Resource utilization

**Refresh Rate**: 1 minute

### Financial Dashboard

**Purpose**: Cost monitoring and optimization

**Metrics**:
- Daily spending by service
- Cost per agent execution
- Cost trends (daily, weekly, monthly)
- Reserved capacity utilization
- Spot instance savings
- Data transfer costs
- Forecast vs. actual

**Refresh Rate**: Hourly

## Alarm Configuration

### Alarm Severity Levels

```
Severity Levels:

1. CRITICAL - Immediate action required
   - Service down or unavailable
   - Security breach detected
   - Data loss or corruption
   - Major security finding
   Response Time: Immediate (within 5 minutes)

2. HIGH - Urgent but not service-down
   - Elevated error rates (>5%)
   - Performance degradation
   - Unusual network traffic
   - Security policy violation
   Response Time: 15 minutes

3. MEDIUM - Should be addressed soon
   - Moderate error rates (2-5%)
   - Approaching resource limits
   - Configuration drift
   - Suspicious but not confirmed activity
   Response Time: 1 hour

4. LOW - Monitor and schedule
   - Minor errors (<2%)
   - Informational findings
   - Optimization opportunities
   - Best practice deviations
   Response Time: Next business day
```

### Core Alarms

#### Lambda Alarms
```
Alarm: High Error Rate
- Metric: LambdaErrors / LambdaInvocations
- Threshold: > 5% for 2 minutes
- Severity: HIGH
- Action: SNS notification, PagerDuty alert

Alarm: Function Duration Spike
- Metric: Duration (p99)
- Threshold: > 25 seconds for 5 minutes
- Severity: MEDIUM
- Action: SNS notification, CloudWatch alarm

Alarm: Function Throttling
- Metric: Throttles
- Threshold: > 0 (any throttles)
- Severity: CRITICAL
- Action: Immediate SNS, PagerDuty, auto-scaling trigger
```

#### RDS Alarms
```
Alarm: High CPU Utilization
- Metric: CPUUtilization
- Threshold: > 80% for 5 minutes
- Severity: HIGH
- Action: SNS notification, investigation trigger

Alarm: Database Connections High
- Metric: DatabaseConnections
- Threshold: > 80% of max_connections
- Severity: MEDIUM
- Action: SNS notification

Alarm: Replication Lag
- Metric: AuroraBinlogReplicaLag
- Threshold: > 1 second
- Severity: HIGH
- Action: SNS, automated failover check

Alarm: Storage Space Low
- Metric: FreeStorageSpace
- Threshold: < 10% for 5 minutes
- Severity: CRITICAL
- Action: Immediate SNS, PagerDuty, auto-expansion
```

#### API Alarms
```
Alarm: High API Error Rate
- Metric: 4XX + 5XX / Total requests
- Threshold: > 1% for 2 minutes
- Severity: HIGH
- Action: SNS notification, logging trigger

Alarm: API Latency High
- Metric: Latency (p99)
- Threshold: > 2 seconds
- Severity: MEDIUM
- Action: SNS notification

Alarm: API Rate Limited
- Metric: 429 responses
- Threshold: > 10 per minute
- Severity: MEDIUM
- Action: SNS notification
```

#### Security Alarms
```
Alarm: Failed Authentication Spike
- Metric: Authentication failures
- Threshold: > 10 in 5 minutes
- Severity: HIGH
- Action: SNS, PagerDuty, investigation

Alarm: Unauthorized API Calls
- Metric: Unauthorized errors
- Threshold: > 5 per minute
- Severity: HIGH
- Action: SNS, PagerDuty, access review

Alarm: GuardDuty High Finding
- Finding Type: Any HIGH/CRITICAL
- Severity: CRITICAL
- Action: Immediate SNS, PagerDuty, page on-call

Alarm: Security Group Change
- Event: AuthorizeSecurityGroupIngress/Egress
- Severity: HIGH
- Action: SNS notification, approval check
```

#### Cost Alarms
```
Alarm: Daily Spending Spike
- Metric: EstimatedCharges
- Threshold: > 30% increase from baseline
- Severity: MEDIUM
- Action: SNS notification, cost review

Alarm: Monthly Forecast Exceeded
- Metric: Forecasted cost
- Threshold: > Budget + 10%
- Severity: MEDIUM
- Action: SNS notification, optimization review
```

## Log Analysis

### Query Examples

#### Application Logs
```sql
-- High error rate analysis
fields @timestamp, @message, error_code, request_id
| filter error_code like /ERROR|FATAL/
| stats count() as error_count by error_code
| sort error_count desc

-- Slow request analysis
fields @timestamp, request_id, duration_ms, endpoint
| filter duration_ms > 1000
| stats pct(@duration_ms, 50) as p50,
        pct(@duration_ms, 95) as p95,
        pct(@duration_ms, 99) as p99
  by endpoint
| sort p99 desc

-- Agent execution analysis
fields @timestamp, agent_id, status, duration_ms
| filter status = "COMPLETED"
| stats count() as executions,
        pct(@duration_ms, 50) as p50,
        pct(@duration_ms, 95) as p95
  by agent_id
```

#### Security Logs
```sql
-- Failed authentication attempts
fields @timestamp, user, status, source_ip
| filter status = "FAILED"
| stats count() as attempts by user, source_ip
| filter attempts > 5

-- Unauthorized API calls
fields @timestamp, principal_id, action, resource, status
| filter status = "UNAUTHORIZED"
| stats count() by principal_id, action
| sort count() desc

-- IAM policy changes
fields @timestamp, event_name, principal_id, change_details
| filter event_name like /PutUserPolicy|AttachUserPolicy|CreateAccessKey/
| sort @timestamp desc
```

#### Infrastructure Logs
```sql
-- Database connection issues
fields @timestamp, connection_status, error_message
| filter connection_status = "FAILED"
| stats count() as failures by error_message
| sort failures desc

-- Memory allocation failures
fields @timestamp, component, requested_memory, available_memory
| filter available_memory < requested_memory
| stats count() as allocation_failures by component

-- Network timeout analysis
fields @timestamp, service_from, service_to, timeout_duration
| filter timeout_duration > 30000
| stats count() as timeouts by service_from, service_to
```

## Performance Tuning

### Lambda Performance

#### Cold Start Optimization
- Use provisioned concurrency for critical functions
- Minimize deployment package size
- Use Lambda Layers for shared libraries
- Consider ARM-based Graviton processors

#### Memory and CPU Tuning
```
Memory vs Performance Tradeoff:
- 128 MB: Minimal workloads (1 vCPU)
- 256 MB: Lightweight operations (0.5 vCPU)
- 512 MB: Standard workloads (1 vCPU)
- 1024 MB: Heavy processing (2 vCPU)
- 3008 MB: Maximum vCPU, best performance (6 vCPU)

Recommendation: Choose based on:
1. Test function duration at different memory levels
2. Calculate cost per execution
3. Find sweet spot for performance/cost
```

#### Timeout Configuration
```
Timeout Guidelines:
- API endpoints: 30 seconds
- Batch processing: 15 minutes (max 900 sec)
- Async operations: 30 seconds (trigger async job)
- Model inference: 60 seconds (model dependent)

Configuration:
- Set based on p99 latency + buffer
- Monitor timeouts as sign of issues
- Increase timeout only after optimization
```

### Database Performance

#### Connection Pooling
```
Configuration:
- RDS Proxy for connection pooling
- Pool size: CPU count * 2
- Max connections: (available_memory / 2GB)
- Idle timeout: 15 minutes
```

#### Query Optimization
```
Best Practices:
1. Use indexes on frequently filtered columns
2. Analyze query execution plans
3. Avoid N+1 queries (use joins)
4. Cache results when appropriate
5. Partition large tables by date/region
6. Regular vacuum and analyze
```

#### Read Replicas
```
Strategy:
- Use read replicas for reporting
- Async replication for analytics
- Route read queries to replicas
- Monitor replication lag
```

### API Gateway Performance

#### Request/Response Optimization
```
Techniques:
1. Enable gzip compression
2. Minimize response payload size
3. Use pagination for large results
4. Cache responses (CloudFront)
5. Implement request coalescing
```

#### Caching Strategy
```
Cache Levels:
1. CloudFront (edge locations) - 24 hour TTL
2. API Gateway (regional) - 1 hour TTL
3. Application cache (Lambda) - 5 minute TTL
4. Database cache (RDS Query Cache) - automatic
```

## Troubleshooting

### High Error Rates

#### Investigation Steps
```
1. Check CloudWatch dashboards for affected service
2. Query logs for error patterns:
   fields error_code, @message
   | stats count() by error_code
3. Check CloudTrail for recent changes
4. Review GuardDuty findings for security issues
5. Check resource limits and quotas
```

#### Common Causes and Fixes
```
Cause: Lambda timeout
Fix: Increase timeout or optimize code

Cause: Database connection limit exceeded
Fix: Increase RDS max_connections or use RDS Proxy

Cause: Unhandled exception
Fix: Review error logs, add proper error handling

Cause: Policy permission issue
Fix: Check IAM logs, verify role permissions

Cause: Resource throttling
Fix: Check quotas, request limit increase
```

### High Latency

#### Diagnosis
```
1. Identify slowest service using dashboards
2. Check if issue is consistent or intermittent
3. Correlate with:
   - Resource utilization (CPU, memory)
   - Database query time
   - Network latency
   - External service latency
```

#### Optimization Steps
```
1. For Lambda: Increase memory (more CPU)
2. For Database: Check slow query log
3. For Network: Analyze VPC Flow Logs
4. For External calls: Check service status
5. For Cache misses: Increase cache TTL
```

### Memory Issues

#### Investigation
```
1. Check Lambda memory CloudWatch metric
2. Review heap size allocation
3. Check for memory leaks in logs
4. Monitor over time for trends
```

#### Resolution
```
1. Increase Lambda memory allocation
2. Optimize code to reduce memory usage
3. Use object pooling for frequently allocated objects
4. Monitor garbage collection
5. Consider function splitting
```

### Database Issues

#### Connection Problems
```
Diagnosis:
- Check RDS Proxy metrics for connection pool status
- Verify security group rules
- Check VPC routing and subnet configuration

Resolution:
- Increase max_connections if appropriate
- Use RDS Proxy for connection pooling
- Close idle connections
- Review for connection leaks
```

#### Performance Degradation
```
Diagnosis:
- Check CPU and memory utilization
- Review slow query log
- Analyze lock waits
- Check replication lag

Resolution:
- Add missing indexes
- Optimize slow queries
- Increase instance size
- Check for long-running transactions
```

## Metrics Reference

### Application Metrics
| Metric | Unit | Good Range | Action Threshold |
|--------|------|-----------|-----------------|
| Error Rate | % | < 1% | > 5% |
| P50 Latency | ms | < 200 | > 500 |
| P95 Latency | ms | < 500 | > 2000 |
| P99 Latency | ms | < 1000 | > 5000 |
| Throughput | req/s | Baseline | -20% decline |
| Cache Hit Rate | % | > 80% | < 50% |

### Infrastructure Metrics
| Metric | Unit | Good Range | Action Threshold |
|--------|------|-----------|-----------------|
| CPU Utilization | % | 30-70% | > 80% |
| Memory Utilization | % | 50-80% | > 90% |
| Disk Utilization | % | < 70% | > 80% |
| Network In | Mbps | Baseline | 2x baseline |
| Network Out | Mbps | Baseline | 2x baseline |
| Connections | count | < 80% max | > 90% max |

### Security Metrics
| Metric | Unit | Target | Alert Threshold |
|--------|------|--------|-----------------|
| Auth Failures | count/min | < 2 | > 10 |
| Unauthorized Calls | count/min | 0 | > 5 |
| Policy Changes | count/day | Approved only | Any unapproved |
| Security Findings | count | 0 Critical/High | > 0 Critical |
| Access Anomalies | count/day | Baseline | > 2x baseline |

## Alert Response Procedures

### Incident Triage

When an alert fires:
```
1. Immediate Assessment (within 5 min)
   - Is service down? (Severity 1)
   - Is data compromised? (Severity 1)
   - Is performance severely impacted? (Severity 2)
   - Is there potential security issue? (Severity 1-2)

2. Context Gathering (within 10 min)
   - Related alerts from multiple sources
   - Recent changes (CloudTrail)
   - Current resource metrics
   - Previous similar incidents

3. Initial Response (within 15 min)
   - Isolate if necessary (Severity 1)
   - Scale up resources (Severity 2)
   - Enable debug logging (all)
   - Notify stakeholders (Severity 1-2)
```

### Response Workflows

#### High Error Rate Alert
```
1. Check affected service status
2. Review error logs for error type
3. Check recent deployments or changes
4. If new code: Rollback or fix forward
5. If database: Check connection issues
6. If external service: Wait or implement fallback
7. Document findings
8. Monitor for resolution
```

#### Database Alert
```
1. Check RDS metrics (CPU, connections, IOPS)
2. Review slow query log
3. Check replication status if applicable
4. If CPU high: Scale up instance or optimize
5. If connections high: Check for connection leak
6. If storage: Expand storage or clean up
7. Monitor recovery
```

#### Security Alert
```
1. Review alert details in GuardDuty/Security Hub
2. Investigate related CloudTrail events
3. Check affected resource/user/IP
4. If compromise: Begin incident response
5. If false positive: Whitelist if appropriate
6. Document investigation findings
7. Implement remediation
8. Update alert rules if needed
```

## Log Retention and Archival

### Retention Strategy

```
Retention Policy by Log Type:

1. CloudTrail (Compliance) - 7 years
   - Stored in S3 with versioning
   - MFA delete protection
   - Quarterly verification

2. Security logs - 2 years
   - GuardDuty findings
   - Security Hub findings
   - Access logs
   - Encryption key usage

3. Operational logs - 90 days
   - Application logs
   - Error logs
   - Performance logs
   - Debug logs

4. Archive logs - 3-7 years (S3 Glacier)
   - Historical data for trend analysis
   - Compliance archive
   - Forensics support
```

### Archival Process

#### Automated Archival
```
Daily Process:
1. Logs > 90 days old → S3 Standard-IA
2. Logs > 1 year old → S3 Glacier
3. Logs > 3 years old (non-critical) → Delete
4. Compliance logs (CloudTrail) → 7-year retention
```

#### S3 Lifecycle Policies
```json
{
  "Rules": [
    {
      "Id": "ArchiveOldLogs",
      "Status": "Enabled",
      "Transitions": [
        {
          "Days": 90,
          "StorageClass": "STANDARD_IA"
        },
        {
          "Days": 365,
          "StorageClass": "GLACIER"
        }
      ],
      "Expiration": {
        "Days": 2555
      }
    }
  ]
}
```

---

**Document Version**: 1.0
**Last Updated**: November 2024
**Next Review**: May 2025
