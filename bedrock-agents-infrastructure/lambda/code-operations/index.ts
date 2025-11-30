import { Handler } from 'aws-lambda';
import { S3Client } from '@aws-sdk/client-s3';
import { CodeOperationResponse, ActionType } from './types';
import { readFileContent, writeFileContent, searchInCode, executeGitOperation } from './utils';

const s3Client = new S3Client({ region: process.env.AWS_REGION || 'us-east-1' });

/**
 * Lambda handler for code operations action group
 * Supports: read-file, write-file, search-code, git-operations
 */
export const handler: Handler = async (event: any): Promise<CodeOperationResponse> => {
  console.log('Code Operations Event:', JSON.stringify(event, null, 2));

  try {
    // Parse the Bedrock agent event
    const actionGroup = event.actionGroup;
    const apiPath = event.apiPath;
    const httpMethod = event.httpMethod;
    const parameters = event.parameters || [];
    const requestBody = event.requestBody;

    // Extract parameters into a more usable format
    const params: Record<string, string> = {};
    parameters.forEach((param: any) => {
      params[param.name] = param.value;
    });

    // Parse request body if present
    let bodyContent: any = {};
    if (requestBody?.content) {
      const contentType = Object.keys(requestBody.content)[0];
      bodyContent = JSON.parse(requestBody.content[contentType].body);
    }

    // Determine action type from API path
    const action = apiPath.replace('/code-operations/', '') as ActionType;

    let result: any;

    switch (action) {
      case 'read-file':
        result = await handleReadFile(params, bodyContent);
        break;

      case 'write-file':
        result = await handleWriteFile(params, bodyContent);
        break;

      case 'search-code':
        result = await handleSearchCode(params, bodyContent);
        break;

      case 'git-operations':
        result = await handleGitOperations(params, bodyContent);
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
    console.error('Error in code operations:', error);

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
 * Handle read-file operation
 */
async function handleReadFile(params: Record<string, string>, body: any): Promise<any> {
  const filePath = params.filePath || body.filePath;
  const bucket = params.bucket || body.bucket || process.env.CODE_BUCKET;
  const encoding = params.encoding || body.encoding || 'utf-8';

  if (!filePath) {
    throw new Error('filePath is required');
  }

  console.log(`Reading file: ${filePath} from bucket: ${bucket}`);

  const content = await readFileContent(s3Client, bucket!, filePath, encoding);

  return {
    filePath,
    content,
    size: content.length,
    encoding,
  };
}

/**
 * Handle write-file operation
 */
async function handleWriteFile(params: Record<string, string>, body: any): Promise<any> {
  const filePath = params.filePath || body.filePath;
  const content = params.content || body.content;
  const bucket = params.bucket || body.bucket || process.env.CODE_BUCKET;
  const encoding = params.encoding || body.encoding || 'utf-8';

  if (!filePath || content === undefined) {
    throw new Error('filePath and content are required');
  }

  console.log(`Writing file: ${filePath} to bucket: ${bucket}`);

  await writeFileContent(s3Client, bucket!, filePath, content, encoding);

  return {
    filePath,
    size: content.length,
    success: true,
    bucket,
  };
}

/**
 * Handle search-code operation
 */
async function handleSearchCode(params: Record<string, string>, body: any): Promise<any> {
  const query = params.query || body.query;
  const bucket = params.bucket || body.bucket || process.env.CODE_BUCKET;
  const pattern = params.pattern || body.pattern;
  const fileTypes = params.fileTypes || body.fileTypes || ['.ts', '.js', '.tsx', '.jsx'];
  const maxResults = parseInt(params.maxResults || body.maxResults || '50', 10);

  if (!query) {
    throw new Error('query is required');
  }

  console.log(`Searching code for: ${query} in bucket: ${bucket}`);

  const results = await searchInCode(s3Client, bucket!, query, {
    pattern,
    fileTypes: Array.isArray(fileTypes) ? fileTypes : fileTypes.split(','),
    maxResults,
  });

  return {
    query,
    resultsCount: results.length,
    results: results.slice(0, maxResults),
    bucket,
  };
}

/**
 * Handle git-operations
 */
async function handleGitOperations(params: Record<string, string>, body: any): Promise<any> {
  const operation = params.operation || body.operation;
  const repository = params.repository || body.repository;
  const branch = params.branch || body.branch || 'main';
  const message = params.message || body.message;
  const data = body.data || {};

  if (!operation || !repository) {
    throw new Error('operation and repository are required');
  }

  console.log(`Executing git operation: ${operation} on repository: ${repository}`);

  const result = await executeGitOperation(operation, {
    repository,
    branch,
    message,
    ...data,
  });

  return {
    operation,
    repository,
    branch,
    result,
    success: true,
  };
}
