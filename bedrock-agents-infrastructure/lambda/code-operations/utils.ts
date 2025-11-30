import {
  S3Client,
  GetObjectCommand,
  PutObjectCommand,
  ListObjectsV2Command,
} from '@aws-sdk/client-s3';
import { Readable } from 'stream';
import { SearchOptions, SearchResult, GitOperationOptions, GitOperationResult } from './types';

/**
 * Read file content from S3
 */
export async function readFileContent(
  s3Client: S3Client,
  bucket: string,
  key: string,
  encoding: BufferEncoding = 'utf-8'
): Promise<string> {
  try {
    const command = new GetObjectCommand({
      Bucket: bucket,
      Key: key,
    });

    const response = await s3Client.send(command);

    if (!response.Body) {
      throw new Error('Empty response body');
    }

    // Convert stream to string
    const stream = response.Body as Readable;
    const chunks: Buffer[] = [];

    for await (const chunk of stream) {
      chunks.push(chunk);
    }

    return Buffer.concat(chunks).toString(encoding);
  } catch (error) {
    console.error(`Error reading file ${key} from bucket ${bucket}:`, error);
    throw new Error(
      `Failed to read file: ${error instanceof Error ? error.message : 'Unknown error'}`
    );
  }
}

/**
 * Write file content to S3
 */
export async function writeFileContent(
  s3Client: S3Client,
  bucket: string,
  key: string,
  content: string,
  encoding: string = 'utf-8',
  metadata?: Record<string, string>
): Promise<void> {
  try {
    const command = new PutObjectCommand({
      Bucket: bucket,
      Key: key,
      Body: Buffer.from(content, encoding as BufferEncoding),
      ContentType: getContentType(key),
      Metadata: {
        ...metadata,
        lastModified: new Date().toISOString(),
      },
    });

    await s3Client.send(command);
    console.log(`Successfully wrote file ${key} to bucket ${bucket}`);
  } catch (error) {
    console.error(`Error writing file ${key} to bucket ${bucket}:`, error);
    throw new Error(
      `Failed to write file: ${error instanceof Error ? error.message : 'Unknown error'}`
    );
  }
}

/**
 * Search for code patterns in files
 */
export async function searchInCode(
  s3Client: S3Client,
  bucket: string,
  query: string,
  options: SearchOptions = {}
): Promise<SearchResult[]> {
  const {
    pattern,
    fileTypes = ['.ts', '.js', '.tsx', '.jsx', '.py', '.java'],
    maxResults = 50,
    caseSensitive = false,
  } = options;

  const results: SearchResult[] = [];

  try {
    // List all objects in the bucket
    const listCommand = new ListObjectsV2Command({
      Bucket: bucket,
      MaxKeys: 1000,
    });

    const listResponse = await s3Client.send(listCommand);
    const objects = listResponse.Contents || [];

    // Filter by file type
    const relevantFiles = objects.filter((obj) => {
      const key = obj.Key || '';
      return fileTypes.some((ext) => key.endsWith(ext));
    });

    console.log(`Searching in ${relevantFiles.length} files...`);

    // Search in each file
    for (const file of relevantFiles) {
      if (results.length >= maxResults) break;
      if (!file.Key) continue;

      try {
        const content = await readFileContent(s3Client, bucket, file.Key);
        const lines = content.split('\n');

        // Create regex from query
        const searchRegex = pattern
          ? new RegExp(pattern, caseSensitive ? 'g' : 'gi')
          : new RegExp(query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), caseSensitive ? 'g' : 'gi');

        // Search each line
        lines.forEach((line, index) => {
          if (results.length >= maxResults) return;

          const matches = line.match(searchRegex);
          if (matches) {
            results.push({
              filePath: file.Key!,
              line: index + 1,
              content: line.trim(),
              match: matches[0],
              context: {
                before: lines.slice(Math.max(0, index - 2), index),
                after: lines.slice(index + 1, Math.min(lines.length, index + 3)),
              },
            });
          }
        });
      } catch (error) {
        console.error(`Error searching file ${file.Key}:`, error);
        // Continue with next file
      }
    }

    console.log(`Found ${results.length} matches for query: ${query}`);
    return results;
  } catch (error) {
    console.error('Error searching code:', error);
    throw new Error(
      `Failed to search code: ${error instanceof Error ? error.message : 'Unknown error'}`
    );
  }
}

/**
 * Execute git operations (placeholder for integration with CodeCommit or GitHub)
 */
export async function executeGitOperation(
  operation: string,
  options: GitOperationOptions
): Promise<GitOperationResult> {
  console.log(`Executing git operation: ${operation}`, options);

  // This is a placeholder implementation
  // In production, integrate with AWS CodeCommit or GitHub API

  const { repository, branch = 'main', message, files = [] } = options;

  switch (operation) {
    case 'commit':
      return {
        success: true,
        operation: 'commit',
        commitSha: generateMockCommitSha(),
        branch,
        message,
        changedFiles: files.length,
        details: {
          repository,
          timestamp: new Date().toISOString(),
        },
      };

    case 'push':
      return {
        success: true,
        operation: 'push',
        branch,
        details: {
          repository,
          timestamp: new Date().toISOString(),
        },
      };

    case 'pull':
      return {
        success: true,
        operation: 'pull',
        branch,
        details: {
          repository,
          updatedFiles: 0,
          timestamp: new Date().toISOString(),
        },
      };

    case 'branch':
      return {
        success: true,
        operation: 'branch',
        branch,
        details: {
          repository,
          created: true,
          timestamp: new Date().toISOString(),
        },
      };

    case 'status':
      return {
        success: true,
        operation: 'status',
        branch,
        details: {
          repository,
          modifiedFiles: 0,
          untrackedFiles: 0,
          timestamp: new Date().toISOString(),
        },
      };

    default:
      throw new Error(`Unsupported git operation: ${operation}`);
  }
}

/**
 * Get content type based on file extension
 */
function getContentType(filePath: string): string {
  const ext = filePath.split('.').pop()?.toLowerCase();

  const contentTypes: Record<string, string> = {
    ts: 'text/typescript',
    tsx: 'text/typescript',
    js: 'application/javascript',
    jsx: 'application/javascript',
    json: 'application/json',
    py: 'text/x-python',
    java: 'text/x-java',
    md: 'text/markdown',
    txt: 'text/plain',
    html: 'text/html',
    css: 'text/css',
    xml: 'application/xml',
    yaml: 'application/x-yaml',
    yml: 'application/x-yaml',
  };

  return contentTypes[ext || ''] || 'application/octet-stream';
}

/**
 * Generate mock commit SHA (for demonstration)
 */
function generateMockCommitSha(): string {
  return Array.from({ length: 40 }, () => Math.floor(Math.random() * 16).toString(16)).join('');
}

/**
 * Validate file path for security
 */
export function validateFilePath(filePath: string): boolean {
  // Prevent directory traversal
  if (filePath.includes('..') || filePath.includes('//')) {
    return false;
  }

  // Ensure path doesn't start with /
  if (filePath.startsWith('/')) {
    return false;
  }

  return true;
}

/**
 * Format file size for display
 */
export function formatFileSize(bytes: number): string {
  const units = ['B', 'KB', 'MB', 'GB'];
  let size = bytes;
  let unitIndex = 0;

  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex++;
  }

  return `${size.toFixed(2)} ${units[unitIndex]}`;
}
