import dotenv from 'dotenv';

dotenv.config();

export const config = {
  // Server
  port: parseInt(process.env.PORT || '8080', 10),
  nodeEnv: process.env.NODE_ENV || 'production',

  // GCP
  projectId: process.env.GCP_PROJECT_ID || '',
  region: process.env.GCP_REGION || 'us-central1',

  // Database
  firestoreDatabase: process.env.FIRESTORE_DATABASE_ID || '(default)',
  cloudSqlConnectionName: process.env.CLOUD_SQL_CONNECTION_NAME || '',
  dbUser: process.env.DB_USER || '',
  dbName: process.env.DB_NAME || 'agentdb',

  // Secrets
  anthropicApiKeySecret: process.env.ANTHROPIC_API_KEY_SECRET || 'anthropic-api-key',
  openaiApiKeySecret: process.env.OPENAI_API_KEY_SECRET || 'openai-api-key',
  vertexaiApiKeySecret: process.env.VERTEXAI_API_KEY_SECRET || 'vertexai-api-key',

  // Application
  maxConversationHistory: parseInt(process.env.MAX_CONVERSATION_HISTORY || '50', 10),
  defaultModel: process.env.DEFAULT_MODEL || 'claude-3-5-sonnet-20241022',
  sessionTimeoutMinutes: parseInt(process.env.SESSION_TIMEOUT_MINUTES || '60', 10),

  // Logging
  logLevel: process.env.LOG_LEVEL || 'info',

  // Rate limiting
  rateLimitWindowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS || '900000', 10),
  rateLimitMaxRequests: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS || '100', 10),

  // CORS
  corsOrigins: process.env.CORS_ORIGINS?.split(',') || ['http://localhost:3000'],
};

// Validate required config
const requiredEnvVars = ['GCP_PROJECT_ID'];
const missingEnvVars = requiredEnvVars.filter((varName) => !process.env[varName]);

if (missingEnvVars.length > 0) {
  throw new Error(`Missing required environment variables: ${missingEnvVars.join(', ')}`);
}
