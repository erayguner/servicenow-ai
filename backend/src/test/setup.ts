/**
 * Jest test setup file
 * Runs before each test suite
 */

// Set test environment variables
process.env.NODE_ENV = 'test';

// Mock environment variables
process.env.PORT = '3001';
process.env.GCP_PROJECT_ID = 'test-project';
process.env.GOOGLE_CLOUD_PROJECT = 'test-project';

// Global test utilities
global.console = {
  ...console,
  // Suppress console.log in tests unless explicitly needed
  log: jest.fn(),
  debug: jest.fn(),
  info: jest.fn(),
  // Keep warn and error for debugging
  warn: console.warn,
  error: console.error,
};

// Increase timeout for integration tests
jest.setTimeout(10000);
