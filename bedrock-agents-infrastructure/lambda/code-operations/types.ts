/**
 * Type definitions for code operations Lambda function
 */

export type ActionType = 'read-file' | 'write-file' | 'search-code' | 'git-operations';

export interface CodeOperationRequest {
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

export interface CodeOperationResponse {
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

export interface FileReadOptions {
  encoding?: string;
  bucket?: string;
}

export interface FileWriteOptions {
  encoding?: string;
  bucket?: string;
  metadata?: Record<string, string>;
}

export interface SearchOptions {
  pattern?: string;
  fileTypes?: string[];
  maxResults?: number;
  caseSensitive?: boolean;
}

export interface SearchResult {
  filePath: string;
  line: number;
  content: string;
  match: string;
  context?: {
    before: string[];
    after: string[];
  };
}

export interface GitOperationOptions {
  repository: string;
  branch?: string;
  message?: string;
  author?: {
    name: string;
    email: string;
  };
  files?: string[];
  commitSha?: string;
}

export interface GitOperationResult {
  success: boolean;
  operation: string;
  commitSha?: string;
  branch?: string;
  message?: string;
  changedFiles?: number;
  details?: any;
}

export interface S3FileMetadata {
  bucket: string;
  key: string;
  size: number;
  lastModified: Date;
  contentType: string;
  etag: string;
}
