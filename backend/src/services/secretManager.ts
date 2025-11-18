import { SecretManagerServiceClient } from '@google-cloud/secret-manager';
import { config } from '../config';
import { logger } from './logger';

const client = new SecretManagerServiceClient();

const secretCache = new Map<string, { value: string; timestamp: number }>();
const CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes

export async function getSecret(secretName: string): Promise<string> {
  // Check cache
  const cached = secretCache.get(secretName);
  if (cached && Date.now() - cached.timestamp < CACHE_TTL_MS) {
    return cached.value;
  }

  try {
    const name = `projects/${config.projectId}/secrets/${secretName}/versions/latest`;
    const [version] = await client.accessSecretVersion({ name });
    const payload = version.payload?.data?.toString();

    if (!payload) {
      throw new Error(`Secret ${secretName} is empty`);
    }

    // Update cache
    secretCache.set(secretName, { value: payload, timestamp: Date.now() });

    logger.info({ secretName }, 'Secret retrieved successfully');
    return payload;
  } catch (error) {
    logger.error({}, 'Failed to retrieve secret');
    throw error;
  }
}

export async function getAnthropicApiKey(): Promise<string> {
  return getSecret(config.anthropicApiKeySecret);
}

export async function getOpenAIApiKey(): Promise<string> {
  return getSecret(config.openaiApiKeySecret);
}

export async function getVertexAIApiKey(): Promise<string> {
  return getSecret(config.vertexaiApiKeySecret);
}
