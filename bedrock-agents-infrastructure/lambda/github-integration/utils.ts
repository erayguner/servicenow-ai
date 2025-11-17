import {
  CreatePROptions,
  PullRequest,
  ManageIssueOptions,
  Issue,
  CodeReviewOptions,
  Review,
  MergeStatusOptions,
  MergeStatus,
  UpdatePROptions,
  GitHubAPIResponse
} from './types';

const GITHUB_API_BASE = 'https://api.github.com';

/**
 * Create a pull request
 */
export async function createPullRequest(
  token: string,
  options: CreatePROptions
): Promise<PullRequest> {
  const { owner, repo, title, description, headBranch, baseBranch, draft, labels, reviewers } = options;

  console.log(`Creating PR: ${owner}/${repo} from ${headBranch} to ${baseBranch}`);

  // Create the PR
  const prResponse = await makeGitHubRequest(token, 'POST', `/repos/${owner}/${repo}/pulls`, {
    title,
    body: description,
    head: headBranch,
    base: baseBranch,
    draft
  });

  const prNumber = prResponse.data.number;

  // Add labels if provided
  if (labels && labels.length > 0) {
    await makeGitHubRequest(token, 'POST', `/repos/${owner}/${repo}/issues/${prNumber}/labels`, {
      labels
    });
  }

  // Request reviewers if provided
  if (reviewers && reviewers.length > 0) {
    await makeGitHubRequest(
      token,
      'POST',
      `/repos/${owner}/${repo}/pulls/${prNumber}/requested_reviewers`,
      {
        reviewers
      }
    );
  }

  return {
    number: prResponse.data.number,
    url: prResponse.data.url,
    htmlUrl: prResponse.data.html_url,
    state: prResponse.data.state,
    title: prResponse.data.title,
    description: prResponse.data.body || '',
    headBranch: prResponse.data.head.ref,
    baseBranch: prResponse.data.base.ref,
    draft: prResponse.data.draft || false,
    merged: prResponse.data.merged || false,
    createdAt: prResponse.data.created_at,
    updatedAt: prResponse.data.updated_at,
    author: {
      login: prResponse.data.user.login,
      id: prResponse.data.user.id,
      avatarUrl: prResponse.data.user.avatar_url,
      url: prResponse.data.user.url
    },
    reviewers: [],
    labels: []
  };
}

/**
 * Manage issues (create, update, close, comment)
 */
export async function manageIssue(
  token: string,
  options: ManageIssueOptions
): Promise<Issue> {
  const { owner, repo, operation, issueNumber, title, body, labels, assignees, state } = options;

  let response: GitHubAPIResponse<any>;

  switch (operation) {
    case 'create':
      response = await makeGitHubRequest(token, 'POST', `/repos/${owner}/${repo}/issues`, {
        title,
        body,
        labels,
        assignees
      });
      break;

    case 'update':
      if (!issueNumber) throw new Error('issueNumber required for update');
      response = await makeGitHubRequest(
        token,
        'PATCH',
        `/repos/${owner}/${repo}/issues/${issueNumber}`,
        {
          title,
          body,
          labels,
          assignees,
          state
        }
      );
      break;

    case 'close':
      if (!issueNumber) throw new Error('issueNumber required for close');
      response = await makeGitHubRequest(
        token,
        'PATCH',
        `/repos/${owner}/${repo}/issues/${issueNumber}`,
        {
          state: 'closed'
        }
      );
      break;

    case 'comment':
      if (!issueNumber) throw new Error('issueNumber required for comment');
      await makeGitHubRequest(
        token,
        'POST',
        `/repos/${owner}/${repo}/issues/${issueNumber}/comments`,
        {
          body
        }
      );
      // Get the updated issue
      response = await makeGitHubRequest(
        token,
        'GET',
        `/repos/${owner}/${repo}/issues/${issueNumber}`
      );
      break;

    case 'label':
      if (!issueNumber) throw new Error('issueNumber required for label');
      await makeGitHubRequest(
        token,
        'POST',
        `/repos/${owner}/${repo}/issues/${issueNumber}/labels`,
        {
          labels
        }
      );
      response = await makeGitHubRequest(
        token,
        'GET',
        `/repos/${owner}/${repo}/issues/${issueNumber}`
      );
      break;

    default:
      throw new Error(`Unknown operation: ${operation}`);
  }

  return {
    number: response.data.number,
    url: response.data.url,
    htmlUrl: response.data.html_url,
    state: response.data.state,
    title: response.data.title,
    body: response.data.body || '',
    labels: response.data.labels || [],
    assignees: response.data.assignees || [],
    createdAt: response.data.created_at,
    updatedAt: response.data.updated_at,
    closedAt: response.data.closed_at,
    author: {
      login: response.data.user.login,
      id: response.data.user.id,
      avatarUrl: response.data.user.avatar_url,
      url: response.data.user.url
    },
    comments: response.data.comments || 0
  };
}

/**
 * Perform code review on a pull request
 */
export async function performCodeReview(
  token: string,
  options: CodeReviewOptions
): Promise<Review> {
  const { owner, repo, prNumber, reviewType, body, comments } = options;

  console.log(`Performing ${reviewType} review on PR #${prNumber}`);

  const reviewData: any = {
    event: reviewType,
    body
  };

  // Add inline comments if provided
  if (comments && comments.length > 0) {
    reviewData.comments = comments.map(comment => ({
      path: comment.path,
      position: comment.position,
      body: comment.body,
      line: comment.line,
      side: comment.side || 'RIGHT',
      start_line: comment.startLine,
      start_side: comment.startSide
    }));
  }

  const response = await makeGitHubRequest(
    token,
    'POST',
    `/repos/${owner}/${repo}/pulls/${prNumber}/reviews`,
    reviewData
  );

  return {
    id: response.data.id,
    prNumber,
    state: response.data.state,
    body: response.data.body || '',
    commentsCount: comments?.length || 0,
    submittedAt: response.data.submitted_at,
    url: response.data.html_url,
    author: {
      login: response.data.user.login,
      id: response.data.user.id,
      avatarUrl: response.data.user.avatar_url,
      url: response.data.user.url
    },
    comments: comments || []
  };
}

/**
 * Get merge status of a pull request
 */
export async function getMergeStatus(
  token: string,
  options: MergeStatusOptions
): Promise<MergeStatus> {
  const { owner, repo, prNumber } = options;

  console.log(`Checking merge status for PR #${prNumber}`);

  // Get PR details
  const prResponse = await makeGitHubRequest(
    token,
    'GET',
    `/repos/${owner}/${repo}/pulls/${prNumber}`
  );

  // Get status checks
  const checksResponse = await makeGitHubRequest(
    token,
    'GET',
    `/repos/${owner}/${repo}/commits/${prResponse.data.head.sha}/check-runs`
  );

  // Get reviews
  const reviewsResponse = await makeGitHubRequest(
    token,
    'GET',
    `/repos/${owner}/${repo}/pulls/${prNumber}/reviews`
  );

  const checks = checksResponse.data.check_runs || [];
  const reviews = reviewsResponse.data || [];

  const checksStatus = {
    total: checks.length,
    passed: checks.filter((c: any) => c.conclusion === 'success').length,
    failed: checks.filter((c: any) => c.conclusion === 'failure').length,
    pending: checks.filter((c: any) => c.status === 'in_progress' || c.status === 'queued').length,
    conclusion: determineChecksConclusion(checks)
  };

  const reviewStatus = {
    total: reviews.length,
    approved: reviews.filter((r: any) => r.state === 'APPROVED').length,
    changesRequested: reviews.filter((r: any) => r.state === 'CHANGES_REQUESTED').length,
    commented: reviews.filter((r: any) => r.state === 'COMMENTED').length,
    requiresReview: true,
    minimumRequired: 1
  };

  return {
    mergeable: prResponse.data.mergeable ?? false,
    mergeableState: prResponse.data.mergeable_state,
    canMerge:
      prResponse.data.mergeable &&
      checksStatus.failed === 0 &&
      reviewStatus.approved >= reviewStatus.minimumRequired,
    conflicts: !prResponse.data.mergeable,
    checksStatus,
    reviewStatus,
    requiredStatusChecks: checks.map((check: any) => ({
      name: check.name,
      status: check.conclusion || check.status,
      required: true,
      description: check.output?.summary
    }))
  };
}

/**
 * Update pull request
 */
export async function updatePRStatus(
  token: string,
  options: UpdatePROptions
): Promise<PullRequest> {
  const { owner, repo, prNumber, title, description, state, labels, baseBranch } = options;

  console.log(`Updating PR #${prNumber}`);

  const updateData: any = {};
  if (title) updateData.title = title;
  if (description) updateData.body = description;
  if (state) updateData.state = state;
  if (baseBranch) updateData.base = baseBranch;

  const response = await makeGitHubRequest(
    token,
    'PATCH',
    `/repos/${owner}/${repo}/pulls/${prNumber}`,
    updateData
  );

  // Update labels if provided
  if (labels) {
    await makeGitHubRequest(token, 'PUT', `/repos/${owner}/${repo}/issues/${prNumber}/labels`, {
      labels
    });
  }

  return {
    number: response.data.number,
    url: response.data.url,
    htmlUrl: response.data.html_url,
    state: response.data.state,
    title: response.data.title,
    description: response.data.body || '',
    headBranch: response.data.head.ref,
    baseBranch: response.data.base.ref,
    draft: response.data.draft || false,
    merged: response.data.merged || false,
    createdAt: response.data.created_at,
    updatedAt: response.data.updated_at,
    author: {
      login: response.data.user.login,
      id: response.data.user.id,
      avatarUrl: response.data.user.avatar_url,
      url: response.data.user.url
    },
    reviewers: [],
    labels: []
  };
}

/**
 * Make authenticated GitHub API request
 */
async function makeGitHubRequest(
  token: string,
  method: string,
  path: string,
  body?: any
): Promise<GitHubAPIResponse<any>> {
  const url = `${GITHUB_API_BASE}${path}`;

  const headers: Record<string, string> = {
    'Authorization': `Bearer ${token}`,
    'Accept': 'application/vnd.github.v3+json',
    'Content-Type': 'application/json',
    'User-Agent': 'Bedrock-Agent-GitHub-Integration'
  };

  const options: RequestInit = {
    method,
    headers
  };

  if (body && (method === 'POST' || method === 'PATCH' || method === 'PUT')) {
    options.body = JSON.stringify(body);
  }

  console.log(`GitHub API Request: ${method} ${path}`);

  const response = await fetch(url, options);

  if (!response.ok) {
    const error = await response.json();
    throw new Error(`GitHub API Error: ${error.message || response.statusText}`);
  }

  const data = await response.json();

  // Extract rate limit info from headers
  const rateLimit = {
    limit: parseInt(response.headers.get('X-RateLimit-Limit') || '5000', 10),
    remaining: parseInt(response.headers.get('X-RateLimit-Remaining') || '5000', 10),
    reset: parseInt(response.headers.get('X-RateLimit-Reset') || '0', 10),
    used: parseInt(response.headers.get('X-RateLimit-Used') || '0', 10)
  };

  const responseHeaders: Record<string, string> = {};
  response.headers.forEach((value, key) => {
    responseHeaders[key] = value;
  });

  return {
    data,
    status: response.status,
    headers: responseHeaders,
    rateLimit
  };
}

/**
 * Determine overall checks conclusion
 */
function determineChecksConclusion(checks: any[]): 'success' | 'failure' | 'neutral' | 'pending' {
  if (checks.length === 0) return 'neutral';
  if (checks.some((c: any) => c.conclusion === 'failure')) return 'failure';
  if (checks.some((c: any) => c.status === 'in_progress' || c.status === 'queued')) return 'pending';
  if (checks.every((c: any) => c.conclusion === 'success')) return 'success';
  return 'neutral';
}

/**
 * Format GitHub timestamp
 */
export function formatGitHubDate(dateString: string): string {
  return new Date(dateString).toISOString();
}

/**
 * Parse PR URL to extract owner, repo, and PR number
 */
export function parsePRUrl(url: string): { owner: string; repo: string; prNumber: number } | null {
  const match = url.match(/github\.com\/([^/]+)\/([^/]+)\/pull\/(\d+)/);
  if (!match) return null;

  return {
    owner: match[1],
    repo: match[2],
    prNumber: parseInt(match[3], 10)
  };
}

/**
 * Validate GitHub token format
 */
export function validateGitHubToken(token: string): boolean {
  // GitHub tokens start with ghp_, gho_, ghu_, ghs_, or ghr_
  return /^(ghp|gho|ghu|ghs|ghr)_[a-zA-Z0-9]{36,}$/.test(token);
}
