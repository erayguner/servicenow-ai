/**
 * Utility functions for ServiceNow API integration
 * Includes auth, retry logic, rate limiting, and helpers
 */

import { SecretsManagerClient, GetSecretValueCommand } from '@aws-sdk/client-secrets-manager';
import axios, { AxiosInstance, AxiosError } from 'axios';
import {
  ServiceNowCredentials,
  OAuthTokenResponse,
  RateLimitConfig,
  ServiceNowError,
} from './types';

// Secrets Manager Client
const secretsManager = new SecretsManagerClient({});

/**
 * Retrieve ServiceNow credentials from AWS Secrets Manager
 */
export async function getServiceNowCredentials(secretName: string): Promise<ServiceNowCredentials> {
  try {
    const command = new GetSecretValueCommand({ SecretId: secretName });
    const response = await secretsManager.send(command);

    if (!response.SecretString) {
      throw new Error('Secret value is empty');
    }

    const credentials = JSON.parse(response.SecretString) as ServiceNowCredentials;

    // Validate required fields
    if (!credentials.instance) {
      throw new Error('ServiceNow instance URL is required');
    }

    if (credentials.authType === 'basic' && (!credentials.username || !credentials.password)) {
      throw new Error('Username and password are required for basic auth');
    }

    if (credentials.authType === 'oauth' && (!credentials.clientId || !credentials.clientSecret)) {
      throw new Error('Client ID and secret are required for OAuth');
    }

    return credentials;
  } catch (error) {
    console.error('Failed to retrieve ServiceNow credentials:', error);
    throw new ServiceNowError(
      'Failed to retrieve credentials from Secrets Manager',
      500,
      'CREDENTIALS_ERROR',
      error
    );
  }
}

/**
 * OAuth token management
 */
export class OAuthTokenManager {
  private accessToken: string | null = null;
  private refreshToken: string | null = null;
  private tokenExpiry: number = 0;

  constructor(
    private credentials: ServiceNowCredentials,
    private httpClient: AxiosInstance
  ) {
    if (credentials.accessToken) {
      this.accessToken = credentials.accessToken;
    }
    if (credentials.refreshToken) {
      this.refreshToken = credentials.refreshToken;
    }
  }

  async getAccessToken(): Promise<string> {
    // Return cached token if valid
    if (this.accessToken && Date.now() < this.tokenExpiry) {
      return this.accessToken;
    }

    // Refresh token if available
    if (this.refreshToken) {
      await this.refreshAccessToken();
      return this.accessToken!;
    }

    // Otherwise, get new token
    await this.authenticate();
    return this.accessToken!;
  }

  private async authenticate(): Promise<void> {
    try {
      const response = await this.httpClient.post<OAuthTokenResponse>(
        `/oauth_token.do`,
        new URLSearchParams({
          grant_type: 'password',
          client_id: this.credentials.clientId!,
          client_secret: this.credentials.clientSecret!,
          username: this.credentials.username!,
          password: this.credentials.password!,
        }),
        {
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        }
      );

      this.accessToken = response.data.access_token;
      this.refreshToken = response.data.refresh_token;
      this.tokenExpiry = Date.now() + (response.data.expires_in - 60) * 1000; // Subtract 60s buffer

      console.log('OAuth authentication successful');
    } catch (error) {
      console.error('OAuth authentication failed:', error);
      throw new ServiceNowError('OAuth authentication failed', 401, 'AUTH_ERROR', error);
    }
  }

  private async refreshAccessToken(): Promise<void> {
    try {
      const response = await this.httpClient.post<OAuthTokenResponse>(
        `/oauth_token.do`,
        new URLSearchParams({
          grant_type: 'refresh_token',
          client_id: this.credentials.clientId!,
          client_secret: this.credentials.clientSecret!,
          refresh_token: this.refreshToken!,
        }),
        {
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        }
      );

      this.accessToken = response.data.access_token;
      this.refreshToken = response.data.refresh_token;
      this.tokenExpiry = Date.now() + (response.data.expires_in - 60) * 1000;

      console.log('Access token refreshed successfully');
    } catch (error) {
      console.error('Token refresh failed:', error);
      // If refresh fails, try full authentication
      await this.authenticate();
    }
  }
}

/**
 * Rate limiter using token bucket algorithm
 */
export class RateLimiter {
  private tokens: number;
  private lastRefill: number;

  constructor(private config: RateLimitConfig) {
    this.tokens = config.maxRequests;
    this.lastRefill = Date.now();
  }

  async acquire(): Promise<void> {
    if (!this.config.enabled) {
      return;
    }

    this.refillTokens();

    if (this.tokens > 0) {
      this.tokens--;
      return;
    }

    // Wait until tokens are available
    const waitTime = this.config.windowMs - (Date.now() - this.lastRefill);
    if (waitTime > 0) {
      console.log(`Rate limit reached, waiting ${waitTime}ms`);
      await new Promise((resolve) => setTimeout(resolve, waitTime));
      this.refillTokens();
      this.tokens--;
    }
  }

  private refillTokens(): void {
    const now = Date.now();
    const timePassed = now - this.lastRefill;

    if (timePassed >= this.config.windowMs) {
      this.tokens = this.config.maxRequests;
      this.lastRefill = now;
    }
  }
}

/**
 * Retry logic with exponential backoff
 */
export async function withRetry<T>(
  fn: () => Promise<T>,
  maxRetries: number = 3,
  baseDelay: number = 1000,
  maxDelay: number = 10000
): Promise<T> {
  let lastError: Error;

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error as Error;

      // Don't retry on client errors (4xx)
      if (axios.isAxiosError(error) && error.response?.status && error.response.status < 500) {
        throw error;
      }

      if (attempt < maxRetries) {
        const delay = Math.min(baseDelay * Math.pow(2, attempt), maxDelay);
        const jitter = Math.random() * 0.1 * delay; // Add 10% jitter
        const waitTime = delay + jitter;

        console.log(`Retry attempt ${attempt + 1}/${maxRetries} after ${Math.round(waitTime)}ms`);
        await new Promise((resolve) => setTimeout(resolve, waitTime));
      }
    }
  }

  throw lastError!;
}

/**
 * Create HTTP client with authentication
 */
export function createHttpClient(
  credentials: ServiceNowCredentials,
  timeout: number = 30000
): AxiosInstance {
  const baseURL = credentials.instance.endsWith('/')
    ? credentials.instance.slice(0, -1)
    : credentials.instance;

  const client = axios.create({
    baseURL,
    timeout,
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
    },
  });

  // Add basic auth if configured
  if (credentials.authType === 'basic' && credentials.username && credentials.password) {
    const auth = Buffer.from(`${credentials.username}:${credentials.password}`).toString('base64');
    client.defaults.headers.common['Authorization'] = `Basic ${auth}`;
  }

  // Add request interceptor for logging
  client.interceptors.request.use(
    (config) => {
      console.log(`ServiceNow API Request: ${config.method?.toUpperCase()} ${config.url}`);
      return config;
    },
    (error) => {
      console.error('Request interceptor error:', error);
      return Promise.reject(error);
    }
  );

  // Add response interceptor for error handling
  client.interceptors.response.use(
    (response) => {
      console.log(`ServiceNow API Response: ${response.status} ${response.statusText}`);
      return response;
    },
    (error: AxiosError) => {
      if (error.response) {
        const statusCode = error.response.status;
        const errorData = error.response.data as any;

        console.error(`ServiceNow API Error: ${statusCode}`, errorData);

        throw new ServiceNowError(
          errorData?.error?.message || error.message,
          statusCode,
          errorData?.error?.code,
          errorData
        );
      }

      throw new ServiceNowError(error.message, 500, 'NETWORK_ERROR', error);
    }
  );

  return client;
}

/**
 * Build query string for ServiceNow API
 */
export function buildQuery(params: Record<string, any>): string {
  const queryParts: string[] = [];

  Object.entries(params).forEach(([key, value]) => {
    if (value !== undefined && value !== null) {
      if (Array.isArray(value)) {
        queryParts.push(`${key}IN${value.join(',')}`);
      } else {
        queryParts.push(`${key}=${value}`);
      }
    }
  });

  return queryParts.join('^');
}

/**
 * Parse ServiceNow date format
 */
export function parseServiceNowDate(dateString: string): Date {
  return new Date(dateString);
}

/**
 * Format date for ServiceNow API
 */
export function formatServiceNowDate(date: Date): string {
  return date
    .toISOString()
    .replace('T', ' ')
    .replace(/\.\d{3}Z$/, '');
}

/**
 * Validate required parameters
 */
export function validateRequired(params: Record<string, any>, required: string[]): void {
  const missing = required.filter((key) => !params[key]);

  if (missing.length > 0) {
    throw new ServiceNowError(
      `Missing required parameters: ${missing.join(', ')}`,
      400,
      'MISSING_PARAMETERS'
    );
  }
}

/**
 * Sanitize user input to prevent injection
 */
export function sanitizeInput(input: string): string {
  return input.replace(/[^\w\s\-@.]/gi, '');
}

/**
 * Log operation to CloudWatch
 */
export function logOperation(
  operation: string,
  details: Record<string, any>,
  level: 'info' | 'warn' | 'error' = 'info'
): void {
  const logEntry = {
    timestamp: new Date().toISOString(),
    operation,
    level,
    ...details,
  };

  const logFn = level === 'error' ? console.error : level === 'warn' ? console.warn : console.log;
  logFn(JSON.stringify(logEntry));
}

/**
 * Calculate SLA breach status
 */
export function isSLABreached(slaEndTime: string, currentTime: Date = new Date()): boolean {
  const endTime = parseServiceNowDate(slaEndTime);
  return currentTime > endTime;
}

/**
 * Format duration in human-readable format
 */
export function formatDuration(seconds: number): string {
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const secs = seconds % 60;

  const parts: string[] = [];
  if (hours > 0) parts.push(`${hours}h`);
  if (minutes > 0) parts.push(`${minutes}m`);
  if (secs > 0 || parts.length === 0) parts.push(`${secs}s`);

  return parts.join(' ');
}
