import dotenv from 'dotenv';

dotenv.config();

export const awsConfig = {
  // Server
  port: parseInt(process.env.PORT || '8080', 10),
  nodeEnv: process.env.NODE_ENV || 'production',

  // AWS
  region: process.env.AWS_REGION || 'us-east-1',
  accountId: process.env.AWS_ACCOUNT_ID || '',

  // Database - RDS PostgreSQL
  dbHost: process.env.RDS_HOST || '',
  dbPort: parseInt(process.env.RDS_PORT || '5432', 10),
  dbUser: process.env.RDS_USER || 'postgres',
  dbName: process.env.RDS_DATABASE || 'agentdb',
  dbPassword: process.env.RDS_PASSWORD || '', // Use Secrets Manager in production

  // DynamoDB
  dynamodbConversationsTable: process.env.DYNAMODB_CONVERSATIONS_TABLE || 'prod-conversations',
  dynamodbSessionsTable: process.env.DYNAMODB_SESSIONS_TABLE || 'prod-sessions',

  // ElastiCache Redis
  redisHost: process.env.REDIS_HOST || '',
  redisPort: parseInt(process.env.REDIS_PORT || '6379', 10),
  redisAuthToken: process.env.REDIS_AUTH_TOKEN || '',

  // S3
  s3KnowledgeBucket: process.env.S3_KNOWLEDGE_BUCKET || 'servicenow-ai-knowledge-documents-prod',
  s3ChunksBucket: process.env.S3_CHUNKS_BUCKET || 'servicenow-ai-document-chunks-prod',
  s3UploadsBucket: process.env.S3_UPLOADS_BUCKET || 'servicenow-ai-user-uploads-prod',

  // SNS/SQS
  snsTicketEventsArn: process.env.SNS_TICKET_EVENTS_ARN || '',
  sqsTicketEventsUrl: process.env.SQS_TICKET_EVENTS_URL || '',
  snsNotificationArn: process.env.SNS_NOTIFICATION_ARN || '',
  sqsNotificationUrl: process.env.SQS_NOTIFICATION_URL || '',

  // Secrets Manager
  anthropicApiKeySecret: process.env.ANTHROPIC_API_KEY_SECRET || 'prod/anthropic-api-key',
  openaiApiKeySecret: process.env.OPENAI_API_KEY_SECRET || 'prod/openai-api-key',

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
const requiredEnvVars = ['AWS_REGION', 'AWS_ACCOUNT_ID', 'RDS_HOST', 'REDIS_HOST'];
const missingEnvVars = requiredEnvVars.filter((varName) => !process.env[varName]);

if (missingEnvVars.length > 0) {
  throw new Error(`Missing required environment variables: ${missingEnvVars.join(', ')}`);
}
