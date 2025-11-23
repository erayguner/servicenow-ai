/**
 * Type definitions for GitHub integration Lambda function
 */

export type GitHubAction =
  | 'create-pr'
  | 'manage-issues'
  | 'code-review'
  | 'merge-status'
  | 'update-pr';

export type IssueOperation = 'create' | 'update' | 'close' | 'comment' | 'label';
export type ReviewType = 'APPROVE' | 'REQUEST_CHANGES' | 'COMMENT';
export type PRState = 'open' | 'closed';
export type IssueState = 'open' | 'closed';

export interface GitHubRequest {
  actionGroup: string;
  apiPath: string;
  httpMethod: string;
  parameters?: Parameter[];
  requestBody?: RequestBody;
}

export interface Parameter {
  name: string;
  value: string;
  type: string;
}

export interface RequestBody {
  content: {
    [contentType: string]: {
      body: string;
    };
  };
}

export interface GitHubResponse {
  messageVersion: string;
  response: {
    actionGroup: string;
    apiPath: string;
    httpMethod: string;
    httpStatusCode: number;
    responseBody: {
      [contentType: string]: {
        body: string;
      };
    };
  };
}

export interface CreatePROptions {
  owner: string;
  repo: string;
  title: string;
  description: string;
  headBranch: string;
  baseBranch: string;
  draft: boolean;
  labels?: string[];
  reviewers?: string[];
}

export interface PullRequest {
  number: number;
  url: string;
  htmlUrl: string;
  state: PRState;
  title: string;
  description: string;
  headBranch: string;
  baseBranch: string;
  draft: boolean;
  mergeable?: boolean;
  merged: boolean;
  createdAt: string;
  updatedAt: string;
  mergedAt?: string;
  author: GitHubUser;
  reviewers: GitHubUser[];
  labels: Label[];
}

export interface ManageIssueOptions {
  owner: string;
  repo: string;
  operation: IssueOperation;
  issueNumber?: number;
  title?: string;
  body?: string;
  labels?: string[];
  assignees?: string[];
  state?: IssueState;
}

export interface Issue {
  number: number;
  url: string;
  htmlUrl: string;
  state: IssueState;
  title: string;
  body: string;
  labels: Label[];
  assignees: GitHubUser[];
  createdAt: string;
  updatedAt: string;
  closedAt?: string;
  author: GitHubUser;
  comments: number;
}

export interface CodeReviewOptions {
  owner: string;
  repo: string;
  prNumber: number;
  reviewType: ReviewType;
  body: string;
  comments?: ReviewComment[];
}

export interface ReviewComment {
  path: string;
  position?: number;
  body: string;
  line?: number;
  side?: 'LEFT' | 'RIGHT';
  startLine?: number;
  startSide?: 'LEFT' | 'RIGHT';
}

export interface Review {
  id: number;
  prNumber: number;
  state: ReviewType;
  body: string;
  commentsCount: number;
  submittedAt: string;
  url: string;
  author: GitHubUser;
  comments: ReviewComment[];
}

export interface MergeStatusOptions {
  owner: string;
  repo: string;
  prNumber: number;
}

export interface MergeStatus {
  mergeable: boolean;
  mergeableState: string;
  canMerge: boolean;
  conflicts: boolean;
  checksStatus: ChecksStatus;
  reviewStatus: ReviewStatus;
  requiredStatusChecks: StatusCheck[];
}

export interface ChecksStatus {
  total: number;
  passed: number;
  failed: number;
  pending: number;
  conclusion: 'success' | 'failure' | 'neutral' | 'pending';
}

export interface ReviewStatus {
  total: number;
  approved: number;
  changesRequested: number;
  commented: number;
  requiresReview: boolean;
  minimumRequired: number;
}

export interface StatusCheck {
  name: string;
  status: 'success' | 'failure' | 'pending' | 'error';
  required: boolean;
  description?: string;
}

export interface UpdatePROptions {
  owner: string;
  repo: string;
  prNumber: number;
  title?: string;
  description?: string;
  state?: PRState;
  labels?: string[];
  baseBranch?: string;
}

export interface GitHubUser {
  login: string;
  id: number;
  avatarUrl: string;
  url: string;
}

export interface Label {
  id: number;
  name: string;
  color: string;
  description?: string;
}

export interface GitHubAPIResponse<T> {
  data: T;
  status: number;
  headers: Record<string, string>;
  rateLimit: RateLimit;
}

export interface RateLimit {
  limit: number;
  remaining: number;
  reset: number;
  used: number;
}

export interface GitHubError {
  message: string;
  documentation_url?: string;
  errors?: Array<{
    resource: string;
    field: string;
    code: string;
    message?: string;
  }>;
}

export interface PRMetadata {
  owner: string;
  repo: string;
  prNumber: number;
  title: string;
  state: PRState;
  createdAt: string;
  updatedAt: string;
  author: string;
  reviewers: string[];
  labels: string[];
  metrics: PRMetrics;
}

export interface PRMetrics {
  filesChanged: number;
  additions: number;
  deletions: number;
  commits: number;
  comments: number;
  reviews: number;
  timeToMerge?: number;
}
