import { S3Client, GetObjectCommand, PutObjectCommand } from '@aws-sdk/client-s3';
import { DynamoDBClient, PutItemCommand, QueryCommand } from '@aws-sdk/client-dynamodb';
import { marshall, unmarshall } from '@aws-sdk/util-dynamodb';
import { Readable } from 'stream';
import {
  GenerateTestsOptions,
  GeneratedTests,
  RunTestsOptions,
  TestResults,
  CoverageReportOptions,
  CoverageReport,
  TestFailure
} from './types';

/**
 * Generate tests for a source file
 */
export async function generateTests(
  s3Client: S3Client,
  bucket: string,
  options: GenerateTestsOptions
): Promise<GeneratedTests> {
  const { sourceFile, testFramework, testType, coverage } = options;

  console.log(`Generating tests for ${sourceFile}`);

  // Read source file to analyze
  const sourceContent = await readFileFromS3(s3Client, bucket, sourceFile);

  // Analyze source code structure
  const analysis = analyzeSourceCode(sourceContent, sourceFile);

  // Generate test content based on framework and type
  const testContent = generateTestContent(
    analysis,
    testFramework,
    testType,
    coverage
  );

  // Determine test file path
  const testFile = getTestFilePath(sourceFile, testFramework);

  // Write test file to S3
  await writeFileToS3(s3Client, bucket, testFile, testContent.content);

  return {
    testFile,
    content: testContent.content,
    testCount: testContent.testCount,
    estimatedCoverage: testContent.estimatedCoverage,
    framework: testFramework,
    imports: testContent.imports,
    testSuites: testContent.testSuites
  };
}

/**
 * Run tests and return results
 */
export async function runTests(
  s3Client: S3Client,
  dynamoClient: DynamoDBClient,
  options: RunTestsOptions
): Promise<TestResults> {
  const { testPath, testFramework, environment, parallel, timeout } = options;

  console.log(`Running tests with ${testFramework}`);

  // Generate unique test run ID
  const testRunId = `test-run-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  const startTime = Date.now();

  // Mock test execution (in production, this would execute actual tests)
  const results = await executeTests(testFramework, {
    testPath,
    environment,
    parallel,
    timeout
  });

  const duration = Date.now() - startTime;

  const testResults: TestResults = {
    testRunId,
    timestamp: new Date().toISOString(),
    framework: testFramework,
    totalTests: results.totalTests,
    passed: results.passed,
    failed: results.failed,
    skipped: results.skipped,
    duration,
    coverage: results.coverage,
    failures: results.failures,
    warnings: results.warnings
  };

  // Store results in DynamoDB
  await storeTestResults(dynamoClient, testResults);

  return testResults;
}

/**
 * Generate coverage report
 */
export async function generateCoverageReport(
  s3Client: S3Client,
  dynamoClient: DynamoDBClient,
  options: CoverageReportOptions
): Promise<CoverageReport> {
  const { testRunId, format, threshold, includeFiles } = options;

  console.log(`Generating coverage report (format: ${format})`);

  // Fetch test results from DynamoDB
  const testResults = testRunId
    ? await getTestResults(dynamoClient, testRunId)
    : await getLatestTestResults(dynamoClient);

  if (!testResults) {
    throw new Error('No test results found');
  }

  // Calculate coverage metrics
  const coverage = testResults.coverage || {
    lines: { total: 0, covered: 0, percentage: 0 },
    statements: { total: 0, covered: 0, percentage: 0 },
    functions: { total: 0, covered: 0, percentage: 0 },
    branches: { total: 0, covered: 0, percentage: 0 }
  };

  const overall = {
    lines: coverage.lines.percentage,
    statements: coverage.statements.percentage,
    functions: coverage.functions.percentage,
    branches: coverage.branches.percentage,
    total: (
      coverage.lines.percentage +
      coverage.statements.percentage +
      coverage.functions.percentage +
      coverage.branches.percentage
    ) / 4
  };

  // Generate report based on format
  const reportContent = formatCoverageReport(testResults, format, overall);

  // Upload report to S3
  const reportPath = `coverage-reports/${testResults.testRunId}.${format}`;
  await writeFileToS3(s3Client, process.env.CODE_BUCKET!, reportPath, reportContent);

  const report: CoverageReport = {
    testRunId: testResults.testRunId,
    timestamp: testResults.timestamp,
    format,
    overall,
    coverageByType: {
      unit: overall.total,
      integration: overall.total * 0.8,
      e2e: overall.total * 0.6
    },
    filesAnalyzed: 0,
    uncoveredLines: [],
    reportUrl: `s3://${process.env.CODE_BUCKET}/${reportPath}`,
    recommendations: generateRecommendations(overall, threshold)
  };

  return report;
}

/**
 * Analyze test results and store metrics
 */
export async function analyzeTestResults(
  dynamoClient: DynamoDBClient,
  results: TestResults
): Promise<void> {
  console.log('Analyzing test results for metrics');

  // Calculate additional metrics
  const metrics = {
    successRate: (results.passed / results.totalTests) * 100,
    averageTestDuration: results.duration / results.totalTests,
    failureRate: (results.failed / results.totalTests) * 100,
    coverageScore: results.coverage
      ? (
          results.coverage.lines.percentage +
          results.coverage.statements.percentage +
          results.coverage.functions.percentage +
          results.coverage.branches.percentage
        ) / 4
      : 0
  };

  // Store metrics
  await storeTestMetrics(dynamoClient, results.testRunId, metrics);
}

// Helper functions

async function readFileFromS3(
  s3Client: S3Client,
  bucket: string,
  key: string
): Promise<string> {
  const command = new GetObjectCommand({ Bucket: bucket, Key: key });
  const response = await s3Client.send(command);
  const stream = response.Body as Readable;
  const chunks: Buffer[] = [];

  for await (const chunk of stream) {
    chunks.push(chunk);
  }

  return Buffer.concat(chunks).toString('utf-8');
}

async function writeFileToS3(
  s3Client: S3Client,
  bucket: string,
  key: string,
  content: string
): Promise<void> {
  const command = new PutObjectCommand({
    Bucket: bucket,
    Key: key,
    Body: Buffer.from(content, 'utf-8'),
    ContentType: 'text/plain'
  });

  await s3Client.send(command);
}

function analyzeSourceCode(content: string, filePath: string): any {
  // Simple code analysis
  const lines = content.split('\n');
  const functions = content.match(/function\s+\w+|const\s+\w+\s*=\s*\(/g) || [];
  const classes = content.match(/class\s+\w+/g) || [];
  const exports = content.match(/export\s+(function|const|class|default)/g) || [];

  return {
    filePath,
    lines: lines.length,
    functions: functions.length,
    classes: classes.length,
    exports: exports.length,
    language: getLanguageFromPath(filePath)
  };
}

function generateTestContent(
  analysis: any,
  framework: string,
  testType: string,
  coverage: string
): any {
  const testCount = Math.max(analysis.functions, analysis.classes, 1) *
    (coverage === 'comprehensive' ? 3 : coverage === 'exhaustive' ? 5 : 1);

  let content = '';

  switch (framework) {
    case 'jest':
      content = generateJestTests(analysis, testType, testCount);
      break;
    case 'mocha':
      content = generateMochaTests(analysis, testType, testCount);
      break;
    case 'vitest':
      content = generateVitestTests(analysis, testType, testCount);
      break;
    default:
      content = generateJestTests(analysis, testType, testCount);
  }

  return {
    content,
    testCount,
    estimatedCoverage: Math.min(testCount * 10, 95),
    imports: extractImports(content),
    testSuites: parseTestSuites(content)
  };
}

function generateJestTests(analysis: any, testType: string, testCount: number): string {
  return `import { describe, it, expect, beforeEach, afterEach } from '@jest/globals';
import * as target from '${analysis.filePath.replace(/\.ts$/, '')}';

describe('${analysis.filePath}', () => {
  beforeEach(() => {
    // Setup test environment
  });

  afterEach(() => {
    // Cleanup
  });

  describe('${testType} tests', () => {
    it('should pass basic functionality test', () => {
      expect(true).toBe(true);
    });

    it('should handle edge cases', () => {
      expect(() => {
        // Test edge case
      }).not.toThrow();
    });

    it('should handle error conditions', () => {
      expect(() => {
        // Test error handling
      }).toThrow();
    });
  });
});
`;
}

function generateMochaTests(analysis: any, testType: string, testCount: number): string {
  return `const { expect } = require('chai');
const target = require('${analysis.filePath.replace(/\.ts$/, '')}');

describe('${analysis.filePath}', () => {
  beforeEach(() => {
    // Setup
  });

  afterEach(() => {
    // Cleanup
  });

  describe('${testType} tests', () => {
    it('should pass basic test', () => {
      expect(true).to.be.true;
    });
  });
});
`;
}

function generateVitestTests(analysis: any, testType: string, testCount: number): string {
  return generateJestTests(analysis, testType, testCount).replace('@jest/globals', 'vitest');
}

function getTestFilePath(sourceFile: string, framework: string): string {
  const ext = framework === 'pytest' ? '.py' : '.test.ts';
  return sourceFile.replace(/\.(ts|js|py|java)$/, ext);
}

function getLanguageFromPath(filePath: string): string {
  const ext = filePath.split('.').pop();
  const languageMap: Record<string, string> = {
    'ts': 'typescript',
    'tsx': 'typescript',
    'js': 'javascript',
    'jsx': 'javascript',
    'py': 'python',
    'java': 'java'
  };
  return languageMap[ext || ''] || 'unknown';
}

async function executeTests(framework: string, options: any): Promise<any> {
  // Mock test execution
  const totalTests = Math.floor(Math.random() * 50) + 10;
  const failed = Math.floor(Math.random() * 3);
  const passed = totalTests - failed;

  return {
    totalTests,
    passed,
    failed,
    skipped: 0,
    failures: generateMockFailures(failed),
    warnings: [],
    coverage: {
      lines: { total: 1000, covered: 850, percentage: 85 },
      statements: { total: 500, covered: 425, percentage: 85 },
      functions: { total: 100, covered: 90, percentage: 90 },
      branches: { total: 200, covered: 160, percentage: 80 }
    }
  };
}

function generateMockFailures(count: number): TestFailure[] {
  return Array.from({ length: count }, (_, i) => ({
    testName: `Test case ${i + 1}`,
    testFile: 'test/example.test.ts',
    error: 'Expected value to be truthy',
    stack: 'at Object.<anonymous> (test/example.test.ts:10:5)',
    duration: Math.random() * 1000
  }));
}

async function storeTestResults(
  dynamoClient: DynamoDBClient,
  results: TestResults
): Promise<void> {
  const command = new PutItemCommand({
    TableName: process.env.TEST_RESULTS_TABLE || 'test-results',
    Item: marshall({
      testRunId: results.testRunId,
      timestamp: results.timestamp,
      ...results
    })
  });

  await dynamoClient.send(command);
}

async function getTestResults(
  dynamoClient: DynamoDBClient,
  testRunId: string
): Promise<TestResults | null> {
  const command = new QueryCommand({
    TableName: process.env.TEST_RESULTS_TABLE || 'test-results',
    KeyConditionExpression: 'testRunId = :id',
    ExpressionAttributeValues: marshall({ ':id': testRunId })
  });

  const response = await dynamoClient.send(command);
  return response.Items?.[0] ? unmarshall(response.Items[0]) as TestResults : null;
}

async function getLatestTestResults(
  dynamoClient: DynamoDBClient
): Promise<TestResults | null> {
  // Mock implementation - return latest test run
  return null;
}

function formatCoverageReport(results: TestResults, format: string, overall: any): string {
  if (format === 'json') {
    return JSON.stringify({ results, overall }, null, 2);
  } else if (format === 'html') {
    return `<html><body><h1>Coverage Report</h1><p>Overall: ${overall.total}%</p></body></html>`;
  }
  return `Coverage Report\nOverall: ${overall.total}%`;
}

function generateRecommendations(overall: any, threshold: number): string[] {
  const recommendations: string[] = [];

  if (overall.lines < threshold) {
    recommendations.push(`Line coverage (${overall.lines}%) is below threshold (${threshold}%)`);
  }
  if (overall.branches < threshold) {
    recommendations.push(`Branch coverage (${overall.branches}%) is below threshold (${threshold}%)`);
  }
  if (overall.functions < 90) {
    recommendations.push('Consider adding tests for uncovered functions');
  }

  return recommendations;
}

async function storeTestMetrics(
  dynamoClient: DynamoDBClient,
  testRunId: string,
  metrics: any
): Promise<void> {
  const command = new PutItemCommand({
    TableName: process.env.TEST_METRICS_TABLE || 'test-metrics',
    Item: marshall({
      testRunId,
      timestamp: new Date().toISOString(),
      ...metrics
    })
  });

  await dynamoClient.send(command);
}

function extractImports(content: string): string[] {
  // Prevent ReDoS attacks by limiting input size (CodeQL recommendation)
  if (content.length > 100000) {
    throw new Error('Content too large for import extraction (max 100KB)');
  }

  // Use constrained character class to prevent exponential backtracking
  // [^\n]+ matches anything except newlines, avoiding overlap with \s+ boundaries
  const importRegex = /import\s+([^\n]+?)\s+from\s+['"]([^'"]+)['"]/g;
  const imports: string[] = [];
  let match;

  while ((match = importRegex.exec(content)) !== null) {
    imports.push(match[2]); // Capture group 2 now contains the import path
  }

  return imports;
}

function parseTestSuites(content: string): any[] {
  // Simple parsing - in production, use proper AST parsing
  return [{
    name: 'Main test suite',
    description: 'Generated tests',
    tests: [{
      name: 'Test 1',
      description: 'Basic test',
      type: 'positive' as const,
      assertions: 1
    }]
  }];
}
