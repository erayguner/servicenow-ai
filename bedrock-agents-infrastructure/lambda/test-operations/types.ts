/**
 * Type definitions for test operations Lambda function
 */

export type TestAction = 'generate-tests' | 'run-tests' | 'coverage-report';
export type TestFramework = 'jest' | 'mocha' | 'vitest' | 'pytest' | 'junit';
export type TestType = 'unit' | 'integration' | 'e2e' | 'performance';
export type CoverageLevel = 'basic' | 'comprehensive' | 'exhaustive';

export interface TestOperationRequest {
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

export interface TestOperationResponse {
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

export interface GenerateTestsOptions {
  sourceFile: string;
  testFramework: string;
  testType: string;
  coverage: string;
  mockDependencies?: boolean;
  includeEdgeCases?: boolean;
}

export interface GeneratedTests {
  testFile: string;
  content: string;
  testCount: number;
  estimatedCoverage: number;
  framework: string;
  imports: string[];
  testSuites: TestSuite[];
}

export interface TestSuite {
  name: string;
  description: string;
  tests: Test[];
}

export interface Test {
  name: string;
  description: string;
  type: 'positive' | 'negative' | 'edge-case';
  assertions: number;
}

export interface RunTestsOptions {
  testPath?: string;
  testFramework: string;
  environment: string;
  parallel: boolean;
  timeout: number;
  coverage?: boolean;
  bail?: boolean;
}

export interface TestResults {
  testRunId: string;
  timestamp: string;
  framework: string;
  totalTests: number;
  passed: number;
  failed: number;
  skipped: number;
  duration: number;
  coverage?: CoverageData;
  failures: TestFailure[];
  warnings: string[];
}

export interface TestFailure {
  testName: string;
  testFile: string;
  error: string;
  stack?: string;
  duration: number;
}

export interface CoverageData {
  lines: CoverageMetric;
  statements: CoverageMetric;
  functions: CoverageMetric;
  branches: CoverageMetric;
}

export interface CoverageMetric {
  total: number;
  covered: number;
  percentage: number;
}

export interface CoverageReportOptions {
  testRunId?: string;
  format: string;
  threshold: number;
  includeFiles?: string[];
  outputPath?: string;
}

export interface CoverageReport {
  testRunId: string;
  timestamp: string;
  format: string;
  overall: {
    lines: number;
    statements: number;
    functions: number;
    branches: number;
    total: number;
  };
  coverageByType: {
    unit: number;
    integration: number;
    e2e: number;
  };
  filesAnalyzed: number;
  uncoveredLines: UncoveredLine[];
  reportUrl: string;
  recommendations: string[];
}

export interface UncoveredLine {
  file: string;
  lines: number[];
  functions: string[];
  branches: string[];
}

export interface TestMetrics {
  totalRuns: number;
  averageDuration: number;
  averageCoverage: number;
  flakyTests: string[];
  slowestTests: Array<{
    name: string;
    duration: number;
  }>;
  coverageTrend: Array<{
    timestamp: string;
    coverage: number;
  }>;
}
