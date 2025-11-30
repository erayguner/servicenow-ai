# Reusable Instruction Templates for Bedrock Agents

This document contains reusable instruction templates that can be incorporated
into agent configurations.

## Table of Contents

1. [Code Quality Template](#code-quality-template)
2. [Testing Template](#testing-template)
3. [Security Template](#security-template)
4. [Documentation Template](#documentation-template)
5. [Error Handling Template](#error-handling-template)
6. [Performance Template](#performance-template)
7. [AWS Best Practices Template](#aws-best-practices-template)

---

## Code Quality Template

```yaml
code_quality_instructions: |
  ## Code Quality Standards

  ### SOLID Principles
  - **Single Responsibility**: Each class/function should have one reason to change
  - **Open/Closed**: Open for extension, closed for modification
  - **Liskov Substitution**: Subtypes must be substitutable for their base types
  - **Interface Segregation**: Clients shouldn't depend on interfaces they don't use
  - **Dependency Inversion**: Depend on abstractions, not concretions

  ### Clean Code Practices
  - Use meaningful, descriptive names for variables, functions, and classes
  - Keep functions small and focused (< 50 lines)
  - Avoid deep nesting (max 3 levels)
  - DRY (Don't Repeat Yourself) - extract common code
  - Comment WHY, not WHAT (code should be self-documenting)
  - Use consistent formatting and style

  ### Code Organization
  - Logical file and folder structure
  - Group related functionality
  - Separate concerns (presentation, business logic, data access)
  - Use dependency injection
  - Avoid circular dependencies

  ### Code Review Checklist
  - [ ] Code is readable and understandable
  - [ ] Functions are focused and cohesive
  - [ ] No code duplication
  - [ ] Naming is clear and consistent
  - [ ] Edge cases are handled
  - [ ] Error handling is comprehensive
  - [ ] Code is testable
  - [ ] Documentation is adequate
```

---

## Testing Template

```yaml
testing_instructions: |
  ## Testing Standards

  ### Test Coverage Requirements
  - Overall code coverage: 80%+
  - Critical business logic: 100%
  - Error handling paths: 100%
  - Public API surface: 90%+

  ### Testing Pyramid
```

E2E Tests (10%) ↑ Integration Tests (30%) ↑ Unit Tests (60%)

```

### Unit Testing
- Test one thing per test
- Follow AAA pattern (Arrange, Act, Assert)
- Use descriptive test names: `test_methodName_whenCondition_thenExpectedBehavior`
- Mock external dependencies
- Test edge cases and error conditions
- Keep tests independent and repeatable

### Integration Testing
- Test component interactions
- Use real dependencies when possible
- Test data flow between modules
- Validate API contracts
- Test database operations

### Test Quality
- Tests should be fast (< 1s for unit tests)
- Tests should be deterministic (no flaky tests)
- Tests should be isolated (no shared state)
- Tests should be maintainable
- Use test factories/fixtures for test data

### TDD Process (When Applicable)
1. Write failing test (Red)
2. Write minimal code to pass (Green)
3. Refactor while keeping tests green (Refactor)
4. Repeat
```

---

## Security Template

```yaml
security_instructions: |
  ## Security Best Practices

  ### Input Validation
  - Validate all inputs (type, format, range, length)
  - Whitelist validation (allow known good) over blacklist (block known bad)
  - Sanitize inputs to prevent injection attacks
  - Validate on both client and server side

  ### Authentication & Authorization
  - Never store passwords in plain text (use bcrypt, Argon2)
  - Implement secure session management
  - Use strong password policies (12+ chars, complexity)
  - Implement MFA where applicable
  - Follow principle of least privilege
  - Validate authorization on every request

  ### Data Protection
  - Encrypt sensitive data at rest (AES-256)
  - Encrypt data in transit (TLS 1.2+)
  - Never log sensitive data (passwords, tokens, PII)
  - Use parameterized queries (prevent SQL injection)
  - Implement proper key management
  - Follow data minimization principles

  ### API Security
  - Rate limiting per IP/user
  - Request size limits
  - CORS configuration (whitelist origins)
  - API authentication (JWT, API keys)
  - Input validation on all endpoints
  - Output encoding to prevent XSS

  ### Secrets Management
  - Use AWS Secrets Manager or Parameter Store
  - Never hardcode secrets in code
  - Rotate secrets regularly
  - Use different secrets per environment
  - Audit secret access

  ### Security Headers
```

Strict-Transport-Security: max-age=31536000; includeSubDomains
Content-Security-Policy: default-src 'self' X-Content-Type-Options: nosniff
X-Frame-Options: DENY X-XSS-Protection: 1; mode=block

```

### Dependency Security
- Regularly update dependencies
- Scan for known vulnerabilities (npm audit, Snyk)
- Use lock files (package-lock.json, Pipfile.lock)
- Review dependency licenses
```

---

## Documentation Template

````yaml
documentation_instructions: |
  ## Documentation Standards

  ### Code Documentation

  #### Function/Method Documentation
  ```python
  def function_name(param1: str, param2: int) -> dict:
      """
      Brief description of what the function does.

      Args:
          param1: Description of param1
          param2: Description of param2

      Returns:
          Description of return value

      Raises:
          ValueError: When invalid input is provided
          RuntimeError: When operation fails

      Examples:
          >>> function_name("test", 42)
          {'result': 'success'}
      """
````

#### Class Documentation

```python
class ClassName:
    """
    Brief description of the class purpose.

    Attributes:
        attribute1 (str): Description of attribute1
        attribute2 (int): Description of attribute2

    Example:
        >>> obj = ClassName()
        >>> obj.method()
    """
```

### API Documentation

- Use OpenAPI/Swagger for REST APIs
- Document all endpoints, parameters, responses
- Include example requests and responses
- Document authentication requirements
- Document rate limits and quotas
- Provide error code reference

### README Documentation

```markdown
# Project Name

## Overview

Brief description of the project

## Features

- Feature 1
- Feature 2

## Installation

Step-by-step installation instructions

## Usage

Basic usage examples

## API Reference

Link to API documentation

## Configuration

Environment variables and configuration options

## Contributing

How to contribute to the project

## License

License information
```

### Architecture Decision Records (ADRs)

Document important decisions:

```markdown
# ADR-001: [Decision Title]

Date: YYYY-MM-DD Status: [Accepted/Rejected/Superseded]

## Context

What is the issue we're facing?

## Decision

What decision did we make?

## Consequences

- Positive consequences
- Negative consequences
- Trade-offs

## Alternatives Considered

- Alternative 1: [Why rejected]
- Alternative 2: [Why rejected]
```

````

---

## Error Handling Template

```yaml
error_handling_instructions: |
  ## Error Handling Standards

  ### Error Handling Principles
  - Fail fast: Detect errors early
  - Fail safe: Degrade gracefully when possible
  - Provide meaningful error messages
  - Log errors with context
  - Don't expose internal details to users
  - Clean up resources in error cases

  ### Error Types

  #### Custom Error Classes
  ```python
  class ApplicationError(Exception):
      """Base class for application errors"""
      def __init__(self, message: str, code: str, details: dict = None):
          self.message = message
          self.code = code
          self.details = details or {}
          super().__init__(self.message)

  class ValidationError(ApplicationError):
      """Raised when input validation fails"""
      pass

  class NotFoundError(ApplicationError):
      """Raised when resource is not found"""
      pass

  class UnauthorizedError(ApplicationError):
      """Raised when user is not authorized"""
      pass
````

### Error Responses (API)

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid input provided",
    "details": {
      "field": "email",
      "reason": "Invalid email format"
    },
    "timestamp": "2024-01-01T00:00:00Z",
    "requestId": "uuid"
  }
}
```

### Try-Catch Best Practices

```python
try:
    # Attempt operation
    result = risky_operation()
except SpecificError as e:
    # Handle specific error
    logger.error(f"Specific error: {e}", exc_info=True)
    # Take corrective action
except Exception as e:
    # Catch unexpected errors
    logger.error(f"Unexpected error: {e}", exc_info=True)
    # Rethrow or handle gracefully
    raise
finally:
    # Always cleanup resources
    cleanup_resources()
```

### Retry Logic

```python
from tenacity import retry, stop_after_attempt, wait_exponential

@retry(
    stop=stop_after_attempt(3),
    wait=wait_exponential(multiplier=1, min=2, max=10)
)
def operation_with_retry():
    # Operation that might fail transiently
    pass
```

### Circuit Breaker Pattern

- Open circuit after N failures
- Half-open state for testing recovery
- Close circuit when service recovers
- Prevent cascading failures

### Logging Best Practices

```python
# Log with context
logger.error(
    "Failed to process user request",
    extra={
        "user_id": user_id,
        "operation": "update_profile",
        "error_code": "DATABASE_ERROR",
        "request_id": request_id
    },
    exc_info=True
)
```

````

---

## Performance Template

```yaml
performance_instructions: |
  ## Performance Best Practices

  ### Performance Goals
  - API response time: < 200ms (p95)
  - Database queries: < 100ms (p95)
  - Page load time: < 2s (LCP)
  - Time to Interactive: < 3.5s
  - Memory usage: Stable, no leaks

  ### Database Optimization

  #### Query Optimization
  - Use appropriate indexes
  - Avoid N+1 queries (use joins or batch loading)
  - Use database connection pooling
  - Implement query result caching
  - Use pagination for large result sets
  - Avoid SELECT * (specify needed columns)

  #### Indexing Strategy
  ```sql
  -- Index frequently queried columns
  CREATE INDEX idx_users_email ON users(email);

  -- Composite index for multi-column queries
  CREATE INDEX idx_orders_user_date ON orders(user_id, created_at);

  -- Partial index for filtered queries
  CREATE INDEX idx_active_users ON users(email) WHERE active = true;
````

### Caching Strategy

#### Cache Layers

```
Client Cache (Browser)
    ↓
CDN Cache
    ↓
Application Cache (Redis)
    ↓
Database Query Cache
    ↓
Database
```

#### Cache Patterns

- **Cache-Aside**: App checks cache, loads from DB if miss
- **Write-Through**: Write to cache and DB simultaneously
- **Write-Behind**: Write to cache, async write to DB
- **Refresh-Ahead**: Proactively refresh before expiration

#### TTL Guidelines

```yaml
Static Content: 1 year
User Session: 1 hour
API Responses: 5-15 minutes
Database Queries: 1-5 minutes
Real-time Data: 10-30 seconds
```

### Code-Level Optimization

#### Algorithm Complexity

- Prefer O(1) or O(log n) over O(n) when possible
- Avoid O(n²) or higher for large datasets
- Use appropriate data structures
  - Hash maps for O(1) lookup
  - Binary search trees for sorted data
  - Heaps for priority queues

#### Async/Parallel Processing

```python
# Use async for I/O-bound operations
async def fetch_data():
    results = await asyncio.gather(
        fetch_from_api1(),
        fetch_from_api2(),
        fetch_from_api3()
    )
    return results

# Use multiprocessing for CPU-bound operations
from multiprocessing import Pool
with Pool(4) as p:
    results = p.map(cpu_intensive_function, data)
```

### Resource Management

- Connection pooling (database, HTTP)
- Lazy loading for heavy resources
- Proper resource cleanup (close files, connections)
- Memory profiling to detect leaks
- Limit concurrent operations

### API Performance

- Implement pagination (limit, offset or cursor-based)
- Support field filtering (GraphQL-style)
- Compress responses (gzip, brotli)
- Use HTTP/2 or HTTP/3
- Implement rate limiting

### Monitoring & Profiling

- Track key metrics (response time, throughput, errors)
- Set up alerts for performance degradation
- Profile code to find bottlenecks
- Use APM tools (DataDog, New Relic)
- Implement distributed tracing

````

---

## AWS Best Practices Template

```yaml
aws_best_practices_instructions: |
  ## AWS Best Practices

  ### Well-Architected Framework

  #### 1. Operational Excellence
  - Infrastructure as Code (Terraform, CloudFormation)
  - Automated testing and deployment (CI/CD)
  - Monitoring and logging (CloudWatch, X-Ray)
  - Runbooks for common operations
  - Regular review and improvement

  #### 2. Security
  - Implement least privilege (IAM)
  - Enable MFA for root and IAM users
  - Use IAM roles instead of access keys
  - Encrypt data at rest and in transit
  - Enable CloudTrail for audit logging
  - Regular security assessments

  #### 3. Reliability
  - Design for failure (assume everything fails)
  - Multi-AZ deployments
  - Auto-scaling policies
  - Health checks and monitoring
  - Disaster recovery planning
  - Regular backup and testing

  #### 4. Performance Efficiency
  - Right-size resources
  - Use managed services when appropriate
  - Implement caching (CloudFront, ElastiCache)
  - Use serverless for variable workloads
  - Regular performance testing

  #### 5. Cost Optimization
  - Use Reserved Instances or Savings Plans
  - Right-size and scale resources
  - Use Spot Instances for fault-tolerant workloads
  - Implement auto-scaling
  - Regular cost reviews and optimization

  #### 6. Sustainability
  - Use managed services (better efficiency)
  - Right-size workloads
  - Use ARM-based instances (Graviton)
  - Implement auto-scaling
  - Choose optimal regions

  ### Service-Specific Best Practices

  #### Lambda
  - Keep functions small and focused
  - Use environment variables for configuration
  - Implement proper error handling
  - Use layers for shared dependencies
  - Monitor cold start times
  - Set appropriate memory and timeout

  #### DynamoDB
  - Design for uniform data access
  - Use partition keys effectively
  - Implement caching (DAX)
  - Use auto-scaling
  - Monitor capacity metrics
  - Use global tables for multi-region

  #### S3
  - Enable versioning for critical data
  - Use lifecycle policies
  - Enable encryption (SSE-S3, SSE-KMS)
  - Implement bucket policies
  - Use CloudFront for distribution
  - Monitor access patterns

  #### RDS/Aurora
  - Use Multi-AZ for production
  - Enable automated backups
  - Use read replicas for scaling
  - Implement connection pooling
  - Monitor performance metrics
  - Regular maintenance windows

  ### Tagging Strategy
  ```yaml
  Required Tags:
    Environment: [dev, staging, prod]
    Project: [project-name]
    ManagedBy: [terraform, cloudformation, manual]
    Owner: [team-name]
    CostCenter: [cost-center-id]

  Optional Tags:
    Application: [app-name]
    Version: [version]
    Backup: [true, false]
````

### Security Best Practices

- Enable AWS Config for compliance
- Use AWS Security Hub
- Implement AWS WAF for web applications
- Use Secrets Manager for credentials
- Enable GuardDuty for threat detection
- Regular security audits

````

---

## Usage Instructions

To use these templates in your agent configuration:

1. **Copy relevant sections** into your agent's `instruction` field
2. **Customize** the content to match your agent's specific needs
3. **Combine multiple templates** for comprehensive instructions
4. **Add agent-specific guidance** on top of these foundations

Example:
```yaml
instruction: |
  You are a backend development specialist.

  # Include the Code Quality Template
  ## Code Quality Standards
  [Copy from Code Quality Template]

  # Include the Testing Template
  ## Testing Standards
  [Copy from Testing Template]

  # Include the Security Template
  ## Security Best Practices
  [Copy from Security Template]

  # Include the Error Handling Template
  ## Error Handling Standards
  [Copy from Error Handling Template]

  # Include the AWS Best Practices Template
  ## AWS Best Practices
  [Copy from AWS Best Practices Template]

  # Add agent-specific instructions
  ## Backend-Specific Guidelines
  [Your custom content]
````

This modular approach allows you to:

- Maintain consistency across agents
- Reuse proven instruction patterns
- Easily update common guidelines
- Customize per agent while keeping standards
