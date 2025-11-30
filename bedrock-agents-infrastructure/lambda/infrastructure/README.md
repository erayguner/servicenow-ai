# Infrastructure Operations Lambda Function

Lambda function for Bedrock Agent infrastructure operations action group.
Provides Terraform automation, Kubernetes deployment, and AWS resource
management capabilities.

## Features

### 1. Terraform Plan (`terraform-plan`)

Generate and analyze Terraform execution plans.

**Parameters:**

- `workingDir` (required): Terraform working directory path
- `varFile` (optional): Variables file path
- `variables` (optional): Variable overrides as JSON object
- `target` (optional): Specific resource to target
- `bucket` (optional): S3 bucket for plan storage - defaults to
  TERRAFORM_STATE_BUCKET
- `environment` (required): Environment name (dev, staging, prod)

**Example:**

```json
{
  "workingDir": "terraform/environments/dev",
  "environment": "dev",
  "variables": {
    "instance_type": "t3.micro",
    "region": "us-east-1"
  },
  "bucket": "my-terraform-states"
}
```

**Response:**

```json
{
  "planId": "plan-1731843000-abc123",
  "workingDir": "terraform/environments/dev",
  "environment": "dev",
  "changes": {
    "create": 5,
    "update": 2,
    "delete": 0,
    "total": 7
  },
  "resources": [
    {
      "address": "aws_instance.web",
      "type": "aws_instance",
      "name": "web",
      "action": "create",
      "provider": "aws"
    }
  ],
  "planFileUrl": "s3://my-terraform-states/terraform/plans/dev/plan-1731843000-abc123.tfplan",
  "executionTime": 5432,
  "requiresApproval": true
}
```

### 2. Terraform Apply (`terraform-apply`)

Apply Terraform changes with safety checks.

**Parameters:**

- `planId` (optional): Plan ID to apply
- `workingDir` (conditional): Required if planId not provided
- `autoApprove` (optional): Auto-approve changes - default: false
- `environment` (required): Environment name
- `bucket` (optional): S3 bucket for state storage

**Example:**

```json
{
  "planId": "plan-1731843000-abc123",
  "environment": "dev",
  "autoApprove": true
}
```

**Response:**

```json
{
  "applyId": "apply-1731843100-xyz789",
  "planId": "plan-1731843000-abc123",
  "environment": "dev",
  "status": "completed",
  "resourcesCreated": 5,
  "resourcesUpdated": 2,
  "resourcesDeleted": 0,
  "totalResources": 7,
  "stateFileUrl": "s3://my-terraform-states/terraform/states/dev/dev.tfstate",
  "executionTime": 15432,
  "outputs": {
    "instance_id": {
      "value": "i-1234567890abcdef0",
      "type": "string",
      "sensitive": false
    }
  }
}
```

### 3. Kubernetes Deploy (`kubernetes-deploy`)

Deploy applications to Kubernetes clusters.

**Parameters:**

- `clusterName` (required): EKS cluster name
- `namespace` (optional): Kubernetes namespace - default: default
- `manifestPath` (optional): Path to manifest file in S3
- `manifestContent` (optional): Inline manifest YAML
- `deploymentType` (optional): Deployment type - default: deployment
- `replicas` (optional): Number of replicas - default: 1
- `image` (optional): Container image
- `environment` (optional): Environment label - default: dev

**Example:**

```json
{
  "clusterName": "production-eks-cluster",
  "namespace": "production",
  "image": "nginx:1.21",
  "replicas": 3,
  "deploymentType": "deployment",
  "environment": "prod"
}
```

**Response:**

```json
{
  "deploymentId": "k8s-deploy-1731843200-def456",
  "clusterName": "production-eks-cluster",
  "namespace": "production",
  "deploymentType": "deployment",
  "status": "completed",
  "replicas": 3,
  "availableReplicas": 3,
  "images": ["nginx:1.21"],
  "services": [
    {
      "name": "deployment-service",
      "type": "LoadBalancer",
      "ports": [
        {
          "name": "http",
          "port": 80,
          "targetPort": 8080,
          "protocol": "TCP"
        }
      ]
    }
  ],
  "deployedAt": "2025-11-17T15:30:00Z",
  "rolloutStatus": "complete"
}
```

### 4. AWS Operations (`aws-operations`)

Execute AWS service operations.

**Parameters:**

- `service` (required): AWS service name (ec2, ecs, s3, cloudformation,
  dynamodb)
- `operation` (required): Operation name
- `parameters` (required): Operation-specific parameters
- `region` (optional): AWS region - defaults to AWS_REGION

**Example (EC2):**

```json
{
  "service": "ec2",
  "operation": "describe-instances",
  "parameters": {
    "Filters": [
      {
        "Name": "tag:Environment",
        "Values": ["production"]
      }
    ]
  }
}
```

**Example (ECS):**

```json
{
  "service": "ecs",
  "operation": "list-services",
  "parameters": {
    "cluster": "production-cluster"
  }
}
```

### 5. Infrastructure State (`infrastructure-state`)

Get comprehensive infrastructure state and health.

**Parameters:**

- `environment` (optional): Environment filter - default: dev
- `stateType` (optional): State type (all, terraform, kubernetes, aws) -
  default: all
- `includeDetails` (optional): Include detailed information - default: false

**Example:**

```json
{
  "environment": "prod",
  "stateType": "all",
  "includeDetails": true
}
```

**Response:**

```json
{
  "environment": "prod",
  "stateType": "all",
  "terraform": {
    "version": 4,
    "resources": 45,
    "outputs": {
      "vpc_id": "vpc-12345",
      "subnet_ids": ["subnet-1", "subnet-2"]
    },
    "stateFileUrl": "s3://terraform-states/prod.tfstate",
    "lastApplied": "2025-11-17T14:00:00Z"
  },
  "kubernetes": {
    "clusterName": "production-cluster",
    "namespaces": ["default", "kube-system", "production"],
    "deployments": 15,
    "services": 20,
    "pods": 45,
    "nodes": 5,
    "version": "v1.27.0"
  },
  "aws": {
    "region": "us-east-1",
    "resources": {
      "ec2Instances": 10,
      "s3Buckets": 5,
      "lambdaFunctions": 20,
      "ecsServices": 8,
      "rdsInstances": 3
    }
  },
  "lastUpdated": "2025-11-17T15:30:00Z",
  "healthStatus": "healthy"
}
```

## Environment Variables

- `AWS_REGION`: AWS region (default: us-east-1)
- `TERRAFORM_STATE_BUCKET`: S3 bucket for Terraform state files
- `TERRAFORM_TABLE`: DynamoDB table for Terraform metadata
- `KUBERNETES_CONFIG`: Kubernetes configuration

## IAM Permissions Required

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::${TERRAFORM_STATE_BUCKET}/*",
        "arn:aws:s3:::${TERRAFORM_STATE_BUCKET}"
      ]
    },
    {
      "Effect": "Allow",
      "Action": ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:Query"],
      "Resource": "arn:aws:dynamodb:*:*:table/${TERRAFORM_TABLE}"
    },
    {
      "Effect": "Allow",
      "Action": ["ec2:Describe*", "ec2:StartInstances", "ec2:StopInstances"],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": ["ecs:Describe*", "ecs:List*", "ecs:UpdateService"],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": ["eks:DescribeCluster", "eks:ListClusters"],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": ["cloudformation:DescribeStacks", "cloudformation:ListStacks"],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
```

## Deployment

```bash
npm install
npm run build
npm run package
```

Deploy with Terraform:

```hcl
resource "aws_lambda_function" "infrastructure" {
  filename      = "infrastructure/function.zip"
  function_name = "bedrock-agent-infrastructure"
  role          = aws_iam_role.lambda_role.arn
  handler       = "dist/index.handler"
  runtime       = "nodejs20.x"
  timeout       = 300
  memory_size   = 1024

  environment {
    variables = {
      TERRAFORM_STATE_BUCKET = aws_s3_bucket.terraform_states.id
      TERRAFORM_TABLE        = aws_dynamodb_table.terraform_metadata.name
    }
  }
}
```

## Safety Features

### Production Protection

- Production deployments require explicit `autoApprove=true`
- Plans are stored and versioned in S3
- All operations are logged to CloudWatch
- DynamoDB tracks deployment history

### Rollback Capability

- Terraform state files are versioned in S3
- Kubernetes deployments support rollback
- CloudFormation stacks maintain rollback capability

## Best Practices

1. **Always Plan First**: Run `terraform-plan` before `terraform-apply`
2. **Review Changes**: Check the plan output before applying
3. **Use Environments**: Separate dev, staging, and production
4. **State Locking**: Enable DynamoDB state locking for Terraform
5. **Backup States**: Enable S3 versioning for state files
6. **Monitor Deployments**: Check logs and metrics after deployments
7. **Gradual Rollouts**: Use canary deployments for Kubernetes

## Integration with CI/CD

```yaml
# GitHub Actions example
- name: Plan Infrastructure Changes
  run: |
    aws bedrock-agent invoke \
      --action-group "Infrastructure" \
      --action "terraform-plan" \
      --parameters '{"workingDir": "terraform/", "environment": "dev"}'

- name: Apply Infrastructure Changes
  run: |
    aws bedrock-agent invoke \
      --action-group "Infrastructure" \
      --action "terraform-apply" \
      --parameters '{"planId": "${{ steps.plan.outputs.planId }}", "environment": "dev"}'
```

## Supported Operations

### Terraform

- Plan generation and analysis
- Apply with approval workflow
- State management
- Output retrieval

### Kubernetes

- Deployment creation
- Service configuration
- Rollout management
- Health checking

### AWS Services

- EC2 instance management
- ECS service updates
- S3 operations
- CloudFormation stack operations
- DynamoDB table operations

## Error Handling

The function implements comprehensive error handling:

```json
{
  "success": false,
  "error": "Production deployments require explicit approval. Set autoApprove=true",
  "timestamp": "2025-11-17T15:00:00Z"
}
```

## License

MIT
