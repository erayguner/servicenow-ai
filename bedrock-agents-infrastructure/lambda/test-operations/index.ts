import { Handler } from 'aws-lambda';
import { S3Client } from '@aws-sdk/client-s3';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { TestOperationResponse, TestAction } from './types';
import { generateTests, runTests, generateCoverageReport, analyzeTestResults } from './utils';

const s3Client = new S3Client({ region: process.env.AWS_REGION || 'us-east-1' });
const dynamoClient = new DynamoDBClient({ region: process.env.AWS_REGION || 'us-east-1' });

/**
 * Lambda handler for test operations action group
 * Supports: generate-tests, run-tests, coverage-report
 */
export const handler: Handler = async (event: any): Promise<TestOperationResponse> => {
  console.log('Test Operations Event:', JSON.stringify(event, null, 2));

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

    // Determine action from API path
    const action = apiPath.replace('/test-operations/', '') as TestAction;

    let result: any;

    switch (action) {
      case 'generate-tests':
        result = await handleGenerateTests(params, bodyContent);
        break;

      case 'run-tests':
        result = await handleRunTests(params, bodyContent);
        break;

      case 'coverage-report':
        result = await handleCoverageReport(params, bodyContent);
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
    console.error('Error in test operations:', error);

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
 * Handle generate-tests operation
 */
async function handleGenerateTests(params: Record<string, string>, body: any): Promise<any> {
  const sourceFile = params.sourceFile || body.sourceFile;
  const testFramework = params.testFramework || body.testFramework || 'jest';
  const testType = params.testType || body.testType || 'unit';
  const coverage = params.coverage || body.coverage || 'comprehensive';
  const bucket = params.bucket || body.bucket || process.env.CODE_BUCKET;

  if (!sourceFile) {
    throw new Error('sourceFile is required');
  }

  console.log(`Generating ${testType} tests for: ${sourceFile} using ${testFramework}`);

  const tests = await generateTests(s3Client, bucket!, {
    sourceFile,
    testFramework,
    testType,
    coverage,
  });

  return {
    sourceFile,
    testFile: tests.testFile,
    testFramework,
    testType,
    testsGenerated: tests.testCount,
    coverage: tests.estimatedCoverage,
    content: tests.content,
  };
}

/**
 * Handle run-tests operation
 */
async function handleRunTests(params: Record<string, string>, body: any): Promise<any> {
  const testPath = params.testPath || body.testPath;
  const testFramework = params.testFramework || body.testFramework || 'jest';
  const environment = params.environment || body.environment || 'test';
  const parallel = params.parallel === 'true' || body.parallel === true;
  const timeout = parseInt(params.timeout || body.timeout || '300000', 10);

  console.log(`Running tests: ${testPath || 'all'} with ${testFramework}`);

  const results = await runTests(s3Client, dynamoClient, {
    testPath,
    testFramework,
    environment,
    parallel,
    timeout,
  });

  // Store results in DynamoDB for historical tracking
  await analyzeTestResults(dynamoClient, results);

  return {
    testFramework,
    testPath: testPath || 'all tests',
    totalTests: results.totalTests,
    passed: results.passed,
    failed: results.failed,
    skipped: results.skipped,
    duration: results.duration,
    coverage: results.coverage,
    failures: results.failures,
    success: results.failed === 0,
  };
}

/**
 * Handle coverage-report operation
 */
async function handleCoverageReport(params: Record<string, string>, body: any): Promise<any> {
  const testRunId = params.testRunId || body.testRunId;
  const format = params.format || body.format || 'json';
  const threshold = parseFloat(params.threshold || body.threshold || '80');
  const includeFiles = params.includeFiles || body.includeFiles;

  console.log(`Generating coverage report for test run: ${testRunId || 'latest'}`);

  const report = await generateCoverageReport(s3Client, dynamoClient, {
    testRunId,
    format,
    threshold,
    includeFiles: includeFiles ? includeFiles.split(',') : undefined,
  });

  return {
    testRunId: report.testRunId,
    timestamp: report.timestamp,
    format,
    overallCoverage: report.overall,
    coverageByType: report.coverageByType,
    filesAnalyzed: report.filesAnalyzed,
    meetsThreshold: report.overall.total >= threshold,
    threshold,
    uncoveredLines: report.uncoveredLines,
    reportUrl: report.reportUrl,
  };
}
