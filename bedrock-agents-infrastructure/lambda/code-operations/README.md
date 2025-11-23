# Code Operations Lambda Function

Lambda function for Bedrock Agent code operations action group. Provides file manipulation, code search, and git operations capabilities.

## Features

### 1. Read File (`read-file`)
Read file contents from S3 storage.

**Parameters:**
- `filePath` (required): Path to the file
- `bucket` (optional): S3 bucket name (defaults to CODE_BUCKET env var)
- `encoding` (optional): File encoding (default: utf-8)

**Example:**
```json
{
  "filePath": "src/components/App.tsx",
  "bucket": "my-code-bucket",
  "encoding": "utf-8"
}
```

### 2. Write File (`write-file`)
Write or update file contents in S3 storage.

**Parameters:**
- `filePath` (required): Path to the file
- `content` (required): File content
- `bucket` (optional): S3 bucket name
- `encoding` (optional): File encoding (default: utf-8)

**Example:**
```json
{
  "filePath": "src/utils/helper.ts",
  "content": "export function helper() { return 'hello'; }",
  "bucket": "my-code-bucket"
}
```

### 3. Search Code (`search-code`)
Search for patterns in code files.

**Parameters:**
- `query` (required): Search query
- `bucket` (optional): S3 bucket name
- `pattern` (optional): Regex pattern
- `fileTypes` (optional): Array of file extensions (default: ['.ts', '.js', '.tsx', '.jsx'])
- `maxResults` (optional): Maximum results (default: 50)

**Example:**
```json
{
  "query": "useEffect",
  "fileTypes": [".tsx", ".jsx"],
  "maxResults": 100
}
```

### 4. Git Operations (`git-operations`)
Execute git operations (commit, push, pull, branch, status).

**Parameters:**
- `operation` (required): Git operation type
- `repository` (required): Repository identifier
- `branch` (optional): Branch name (default: main)
- `message` (optional): Commit message
- `files` (optional): Array of file paths

**Example:**
```json
{
  "operation": "commit",
  "repository": "my-repo",
  "branch": "feature/new-feature",
  "message": "Add new component",
  "files": ["src/components/NewComponent.tsx"]
}
```

## Environment Variables

- `AWS_REGION`: AWS region (default: us-east-1)
- `CODE_BUCKET`: Default S3 bucket for code storage

## Deployment

### Build
```bash
npm install
npm run build
```

### Package
```bash
npm run package
```

### Deploy with Terraform
The Lambda function is deployed as part of the Bedrock agents infrastructure:

```hcl
resource "aws_lambda_function" "code_operations" {
  filename      = "code-operations/function.zip"
  function_name = "bedrock-agent-code-operations"
  role          = aws_iam_role.lambda_role.arn
  handler       = "dist/index.handler"
  runtime       = "nodejs20.x"
  timeout       = 60
  memory_size   = 512

  environment {
    variables = {
      CODE_BUCKET = aws_s3_bucket.code_storage.id
    }
  }
}
```

## IAM Permissions Required

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::${CODE_BUCKET}/*",
        "arn:aws:s3:::${CODE_BUCKET}"
      ]
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

## Response Format

All operations return a standardized response:

```json
{
  "success": true,
  "action": "read-file",
  "result": {
    "filePath": "src/App.tsx",
    "content": "...",
    "size": 1234,
    "encoding": "utf-8"
  },
  "timestamp": "2025-11-17T10:30:00.000Z"
}
```

## Error Handling

Errors are caught and returned with appropriate status codes:

```json
{
  "success": false,
  "error": "File not found: src/missing.tsx",
  "timestamp": "2025-11-17T10:30:00.000Z"
}
```

## Testing

```bash
npm test
```

## Integration with Bedrock Agent

This Lambda function is registered as an action group in the Bedrock Agent:

```typescript
const actionGroup = {
  actionGroupName: "CodeOperations",
  actionGroupExecutor: {
    lambda: lambdaArn
  },
  apiSchema: {
    payload: apiSchemaJson
  }
};
```

## Security Considerations

1. **Path Validation**: All file paths are validated to prevent directory traversal
2. **Bucket Access**: S3 bucket access is restricted via IAM policies
3. **Input Sanitization**: All inputs are validated and sanitized
4. **Error Messages**: Error messages don't expose sensitive information

## License

MIT
