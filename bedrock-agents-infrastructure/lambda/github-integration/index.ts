import { Handler } from 'aws-lambda';
import { SecretsManagerClient, GetSecretValueCommand } from '@aws-sdk/client-secrets-manager';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { GitHubResponse, GitHubAction } from './types';
import {
  createPullRequest,
  manageIssue,
  performCodeReview,
  getMergeStatus,
  updatePRStatus,
} from './utils';

const secretsClient = new SecretsManagerClient({ region: process.env.AWS_REGION || 'us-east-1' });
const dynamoClient = new DynamoDBClient({ region: process.env.AWS_REGION || 'us-east-1' });

/**
 * Lambda handler for GitHub integration action group
 * Supports: create-pr, manage-issues, code-review
 */
export const handler: Handler = async (event: any): Promise<GitHubResponse> => {
  console.log('GitHub Integration Event:', JSON.stringify(event, null, 2));

  try {
    const actionGroup = event.actionGroup;
    const apiPath = event.apiPath;
    const httpMethod = event.httpMethod;
    const parameters = event.parameters || [];
    const requestBody = event.requestBody;

    // Extract parameters
    const params: Record<string, string> = {};
    parameters.forEach((param: any) => {
      params[param.name] = param.value;
    });

    // Parse request body
    let bodyContent: any = {};
    if (requestBody?.content) {
      const contentType = Object.keys(requestBody.content)[0];
      bodyContent = JSON.parse(requestBody.content[contentType].body);
    }

    // Get GitHub token from Secrets Manager
    const githubToken = await getGitHubToken();

    // Determine action from API path
    const action = apiPath.replace('/github-integration/', '') as GitHubAction;

    let result: any;

    switch (action) {
      case 'create-pr':
        result = await handleCreatePR(params, bodyContent, githubToken);
        break;

      case 'manage-issues':
        result = await handleManageIssues(params, bodyContent, githubToken);
        break;

      case 'code-review':
        result = await handleCodeReview(params, bodyContent, githubToken);
        break;

      case 'merge-status':
        result = await handleMergeStatus(params, bodyContent, githubToken);
        break;

      case 'update-pr':
        result = await handleUpdatePR(params, bodyContent, githubToken);
        break;

      default:
        throw new Error(`Unknown action: ${action}`);
    }

    return {
      messageVersion: '1.0',
      response: {
        actionGroup,
        apiPath,
        httpMethod,
        httpStatusCode: 200,
        responseBody: {
          'application/json': {
            body: JSON.stringify({
              success: true,
              action,
              result,
              timestamp: new Date().toISOString(),
            }),
          },
        },
      },
    };
  } catch (error) {
    console.error('Error in GitHub integration:', error);

    return {
      messageVersion: '1.0',
      response: {
        actionGroup: event.actionGroup,
        apiPath: event.apiPath,
        httpMethod: event.httpMethod,
        httpStatusCode: 500,
        responseBody: {
          'application/json': {
            body: JSON.stringify({
              success: false,
              error: error instanceof Error ? error.message : 'Unknown error',
              timestamp: new Date().toISOString(),
            }),
          },
        },
      },
    };
  }
};

/**
 * Get GitHub token from Secrets Manager
 */
async function getGitHubToken(): Promise<string> {
  const secretName = process.env.GITHUB_TOKEN_SECRET || 'github/token';

  try {
    const command = new GetSecretValueCommand({
      SecretId: secretName,
    });

    const response = await secretsClient.send(command);

    if (response.SecretString) {
      const secret = JSON.parse(response.SecretString);
      return secret.token || secret.GITHUB_TOKEN;
    }

    throw new Error('GitHub token not found in secret');
  } catch (error) {
    console.error('Error retrieving GitHub token:', error);
    throw new Error('Failed to retrieve GitHub token from Secrets Manager');
  }
}

/**
 * Handle create-pr operation
 */
async function handleCreatePR(
  params: Record<string, string>,
  body: any,
  githubToken: string
): Promise<any> {
  const owner = params.owner || body.owner;
  const repo = params.repo || body.repo;
  const title = params.title || body.title;
  const description = params.description || body.description || '';
  const headBranch = params.headBranch || body.headBranch;
  const baseBranch = params.baseBranch || body.baseBranch || 'main';
  const draft = params.draft === 'true' || body.draft === true;
  const labels = params.labels?.split(',') || body.labels || [];
  const reviewers = params.reviewers?.split(',') || body.reviewers || [];

  if (!owner || !repo || !title || !headBranch) {
    throw new Error('owner, repo, title, and headBranch are required');
  }

  console.log(`Creating PR: ${owner}/${repo} - ${title}`);

  const pr = await createPullRequest(githubToken, {
    owner,
    repo,
    title,
    description,
    headBranch,
    baseBranch,
    draft,
    labels,
    reviewers,
  });

  // Store PR metadata in DynamoDB
  await storePRMetadata(dynamoClient, pr);

  return {
    prNumber: pr.number,
    prUrl: pr.url,
    state: pr.state,
    draft: pr.draft,
    headBranch,
    baseBranch,
    createdAt: pr.createdAt,
  };
}

/**
 * Handle manage-issues operation
 */
async function handleManageIssues(
  params: Record<string, string>,
  body: any,
  githubToken: string
): Promise<any> {
  const owner = params.owner || body.owner;
  const repo = params.repo || body.repo;
  const operation = params.operation || body.operation; // create, update, close, comment
  const issueNumber = params.issueNumber || body.issueNumber;
  const title = params.title || body.title;
  const issueBody = params.body || body.body;
  const labels = params.labels?.split(',') || body.labels || [];
  const assignees = params.assignees?.split(',') || body.assignees || [];

  if (!owner || !repo || !operation) {
    throw new Error('owner, repo, and operation are required');
  }

  console.log(`Managing issue: ${owner}/${repo} - ${operation}`);

  const issue = await manageIssue(githubToken, {
    owner,
    repo,
    operation,
    issueNumber: issueNumber ? parseInt(issueNumber, 10) : undefined,
    title,
    body: issueBody,
    labels,
    assignees,
  });

  return {
    issueNumber: issue.number,
    issueUrl: issue.url,
    state: issue.state,
    title: issue.title,
    operation,
    updatedAt: issue.updatedAt,
  };
}

/**
 * Handle code-review operation
 */
async function handleCodeReview(
  params: Record<string, string>,
  body: any,
  githubToken: string
): Promise<any> {
  const owner = params.owner || body.owner;
  const repo = params.repo || body.repo;
  const prNumber = parseInt(params.prNumber || body.prNumber, 10);
  const reviewType = params.reviewType || body.reviewType || 'COMMENT'; // APPROVE, REQUEST_CHANGES, COMMENT
  const reviewBody = params.body || body.body || '';
  const comments = body.comments || [];

  if (!owner || !repo || !prNumber) {
    throw new Error('owner, repo, and prNumber are required');
  }

  console.log(`Performing code review: ${owner}/${repo}#${prNumber}`);

  const review = await performCodeReview(githubToken, {
    owner,
    repo,
    prNumber,
    reviewType,
    body: reviewBody,
    comments,
  });

  return {
    reviewId: review.id,
    prNumber,
    reviewType: review.state,
    commentsCount: review.commentsCount,
    submittedAt: review.submittedAt,
    reviewUrl: review.url,
  };
}

/**
 * Handle merge-status operation
 */
async function handleMergeStatus(
  params: Record<string, string>,
  body: any,
  githubToken: string
): Promise<any> {
  const owner = params.owner || body.owner;
  const repo = params.repo || body.repo;
  const prNumber = parseInt(params.prNumber || body.prNumber, 10);

  if (!owner || !repo || !prNumber) {
    throw new Error('owner, repo, and prNumber are required');
  }

  console.log(`Checking merge status: ${owner}/${repo}#${prNumber}`);

  const status = await getMergeStatus(githubToken, {
    owner,
    repo,
    prNumber,
  });

  return {
    prNumber,
    mergeable: status.mergeable,
    mergeableState: status.mergeableState,
    canMerge: status.canMerge,
    conflicts: status.conflicts,
    checksStatus: status.checksStatus,
    reviewStatus: status.reviewStatus,
  };
}

/**
 * Handle update-pr operation
 */
async function handleUpdatePR(
  params: Record<string, string>,
  body: any,
  githubToken: string
): Promise<any> {
  const owner = params.owner || body.owner;
  const repo = params.repo || body.repo;
  const prNumber = parseInt(params.prNumber || body.prNumber, 10);
  const title = params.title || body.title;
  const description = params.description || body.description;
  const state = params.state || body.state; // open, closed
  const labels = params.labels?.split(',') || body.labels;

  if (!owner || !repo || !prNumber) {
    throw new Error('owner, repo, and prNumber are required');
  }

  console.log(`Updating PR: ${owner}/${repo}#${prNumber}`);

  const pr = await updatePRStatus(githubToken, {
    owner,
    repo,
    prNumber,
    title,
    description,
    state,
    labels,
  });

  return {
    prNumber,
    title: pr.title,
    state: pr.state,
    updatedAt: pr.updatedAt,
    prUrl: pr.url,
  };
}

/**
 * Store PR metadata in DynamoDB
 */
async function storePRMetadata(_dynamoClient: DynamoDBClient, pr: any): Promise<void> {
  // Implementation for storing PR metadata
  console.log('Storing PR metadata:', pr.number);
  // This would store PR data in DynamoDB for tracking
}
