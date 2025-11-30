# GitHub Integration Lambda Function

Lambda function for Bedrock Agent GitHub integration action group. Provides
comprehensive GitHub operations including PR management, issue tracking, and
code reviews using the GitHub API.

## Features

### 1. Create Pull Request (`create-pr`)

Create pull requests with automatic reviewer assignment and labeling.

**Parameters:**

- `owner` (required): Repository owner/organization
- `repo` (required): Repository name
- `title` (required): PR title
- `description` (optional): PR description/body
- `headBranch` (required): Source branch
- `baseBranch` (optional): Target branch - default: main
- `draft` (optional): Create as draft PR - default: false
- `labels` (optional): Comma-separated labels
- `reviewers` (optional): Comma-separated reviewer usernames

**Example:**

```json
{
  "owner": "myorg",
  "repo": "myproject",
  "title": "Add new feature",
  "description": "## Summary\n- Implemented feature X\n- Added tests\n\n## Test Plan\n- Run `npm test`",
  "headBranch": "feature/new-feature",
  "baseBranch": "main",
  "draft": false,
  "labels": "enhancement,needs-review",
  "reviewers": "reviewer1,reviewer2"
}
```

**Response:**

```json
{
  "prNumber": 123,
  "prUrl": "https://api.github.com/repos/myorg/myproject/pulls/123",
  "state": "open",
  "draft": false,
  "headBranch": "feature/new-feature",
  "baseBranch": "main",
  "createdAt": "2025-11-17T15:00:00Z"
}
```

### 2. Manage Issues (`manage-issues`)

Create, update, close, comment on, and label issues.

**Parameters:**

- `owner` (required): Repository owner
- `repo` (required): Repository name
- `operation` (required): Operation type (create, update, close, comment, label)
- `issueNumber` (conditional): Issue number (required for update, close,
  comment, label)
- `title` (conditional): Issue title (required for create, optional for update)
- `body` (optional): Issue body/comment content
- `labels` (optional): Comma-separated labels
- `assignees` (optional): Comma-separated assignee usernames

**Example (Create):**

```json
{
  "owner": "myorg",
  "repo": "myproject",
  "operation": "create",
  "title": "Bug: Application crashes on startup",
  "body": "## Description\nApplication crashes when...\n\n## Steps to Reproduce\n1. ...",
  "labels": "bug,high-priority",
  "assignees": "developer1"
}
```

**Example (Comment):**

```json
{
  "owner": "myorg",
  "repo": "myproject",
  "operation": "comment",
  "issueNumber": 456,
  "body": "I've started investigating this issue. Will have a fix ready soon."
}
```

### 3. Code Review (`code-review`)

Perform comprehensive code reviews with inline comments.

**Parameters:**

- `owner` (required): Repository owner
- `repo` (required): Repository name
- `prNumber` (required): Pull request number
- `reviewType` (optional): Review type (APPROVE, REQUEST_CHANGES, COMMENT) -
  default: COMMENT
- `body` (optional): Review summary
- `comments` (optional): Array of inline comments

**Example:**

```json
{
  "owner": "myorg",
  "repo": "myproject",
  "prNumber": 123,
  "reviewType": "REQUEST_CHANGES",
  "body": "Please address the following issues before merging:",
  "comments": [
    {
      "path": "src/app.ts",
      "line": 42,
      "body": "This function should handle null values",
      "side": "RIGHT"
    },
    {
      "path": "src/utils.ts",
      "line": 15,
      "body": "Consider extracting this logic into a separate function",
      "side": "RIGHT"
    }
  ]
}
```

### 4. Merge Status (`merge-status`)

Check if a PR is ready to merge with detailed status information.

**Parameters:**

- `owner` (required): Repository owner
- `repo` (required): Repository name
- `prNumber` (required): Pull request number

**Example:**

```json
{
  "owner": "myorg",
  "repo": "myproject",
  "prNumber": 123
}
```

**Response:**

```json
{
  "prNumber": 123,
  "mergeable": true,
  "mergeableState": "clean",
  "canMerge": true,
  "conflicts": false,
  "checksStatus": {
    "total": 5,
    "passed": 5,
    "failed": 0,
    "pending": 0,
    "conclusion": "success"
  },
  "reviewStatus": {
    "total": 2,
    "approved": 2,
    "changesRequested": 0,
    "commented": 0,
    "requiresReview": true,
    "minimumRequired": 1
  }
}
```

### 5. Update PR (`update-pr`)

Update pull request metadata and status.

**Parameters:**

- `owner` (required): Repository owner
- `repo` (required): Repository name
- `prNumber` (required): Pull request number
- `title` (optional): New title
- `description` (optional): New description
- `state` (optional): PR state (open, closed)
- `labels` (optional): Updated labels

**Example:**

```json
{
  "owner": "myorg",
  "repo": "myproject",
  "prNumber": 123,
  "title": "feat: Add new feature (updated)",
  "state": "open",
  "labels": "enhancement,ready-for-review"
}
```

## GitHub API Integration

### Authentication

The function retrieves GitHub tokens from AWS Secrets Manager:

```json
{
  "token": "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
}
```

Or:

```json
{
  "GITHUB_TOKEN": "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
}
```

### Rate Limiting

The function tracks GitHub API rate limits and includes them in responses:

```json
{
  "rateLimit": {
    "limit": 5000,
    "remaining": 4987,
    "reset": 1731849600,
    "used": 13
  }
}
```

## Environment Variables

- `AWS_REGION`: AWS region (default: us-east-1)
- `GITHUB_TOKEN_SECRET`: Secrets Manager secret name for GitHub token (default:
  github/token)
- `PR_METADATA_TABLE`: DynamoDB table for PR tracking (optional)

## IAM Permissions Required

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["secretsmanager:GetSecretValue"],
      "Resource": "arn:aws:secretsmanager:*:*:secret:github/*"
    },
    {
      "Effect": "Allow",
      "Action": ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:UpdateItem"],
      "Resource": "arn:aws:dynamodb:*:*:table/${PR_METADATA_TABLE}"
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
resource "aws_lambda_function" "github_integration" {
  filename      = "github-integration/function.zip"
  function_name = "bedrock-agent-github-integration"
  role          = aws_iam_role.lambda_role.arn
  handler       = "dist/index.handler"
  runtime       = "nodejs20.x"
  timeout       = 60
  memory_size   = 512

  environment {
    variables = {
      GITHUB_TOKEN_SECRET = aws_secretsmanager_secret.github_token.name
      PR_METADATA_TABLE   = aws_dynamodb_table.pr_metadata.name
    }
  }
}
```

## Setting Up GitHub Token

### Create GitHub Personal Access Token

1. Go to GitHub Settings → Developer settings → Personal access tokens
2. Generate new token (classic) with these scopes:
   - `repo` (full control)
   - `workflow` (if accessing Actions)
   - `write:discussion` (if managing discussions)

### Store in Secrets Manager

```bash
aws secretsmanager create-secret \
  --name github/token \
  --secret-string '{"token":"ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}'
```

## Supported Operations

### Pull Requests

- Create new PRs
- Update PR metadata
- Add reviewers and labels
- Check merge status
- Review code changes

### Issues

- Create issues
- Update existing issues
- Close issues
- Add comments
- Manage labels and assignees

### Code Reviews

- Submit reviews (approve/request changes/comment)
- Add inline comments
- Review file changes
- Check review status

## Error Handling

The function handles GitHub API errors gracefully:

```json
{
  "success": false,
  "error": "GitHub API Error: Not Found",
  "timestamp": "2025-11-17T15:00:00Z"
}
```

## Best Practices

1. **Token Security**: Always store GitHub tokens in Secrets Manager, never in
   code
2. **Rate Limiting**: Monitor rate limits and implement backoff strategies
3. **Webhooks**: Consider using GitHub webhooks for real-time updates
4. **Permissions**: Use fine-grained PATs with minimal required scopes
5. **Error Handling**: Implement retry logic for transient failures

## License

MIT
