export interface RotationEvent {
  SecretId?: string;
  secretArn?: string;
  ClientRequestToken?: string;
  Step?: 'createSecret' | 'setSecret' | 'testSecret' | 'finishSecret';
  rotationType?: RotationType;
  lambdaFunctions?: string[];
  databaseInstances?: string[];
}

export interface RotationResult {
  rotationId: string;
  secretArn: string;
  status: 'SUCCESS' | 'FAILED' | 'PARTIAL_SUCCESS';
  rotationType: RotationType;
  steps: SecretRotationStep[];
  duration: number;
  verificationResult?: VerificationResult;
  dryRun?: boolean;
  errors?: string[];
}

export type RotationType =
  | 'BEDROCK_API_KEY'
  | 'DATABASE_CREDENTIALS'
  | 'LAMBDA_ENVIRONMENT'
  | 'GENERIC_SECRET';

export interface SecretRotationStep {
  step: 'CREATE_SECRET' | 'SET_SECRET' | 'TEST_SECRET' | 'FINISH_SECRET' | 'VERIFICATION' | 'ERROR';
  status: 'IN_PROGRESS' | 'SUCCESS' | 'FAILED';
  timestamp: string;
  message: string;
  metadata?: Record<string, any>;
}

export interface VerificationResult {
  success: boolean;
  message: string;
  checks: VerificationCheck[];
  timestamp: string;
}

export interface VerificationCheck {
  checkName: string;
  passed: boolean;
  details: string;
}

export interface DatabaseCredentials {
  host: string;
  port: number;
  username: string;
  currentPassword: string;
  newPassword: string;
  database: string;
  engine?: 'mysql' | 'postgres' | 'oracle' | 'sqlserver';
}

export interface LambdaEnvironmentUpdate {
  functionName: string;
  environmentVariables: Record<string, string>;
  dryRun: boolean;
}

export interface NotificationPayload {
  rotationId: string;
  secretArn: string;
  status: 'SUCCESS' | 'FAILED' | 'IN_PROGRESS';
  steps: SecretRotationStep[];
  topicArn: string;
  error?: string;
}

export interface SecretMetadata {
  secretArn: string;
  secretName: string;
  rotationType: RotationType;
  lastRotated?: string;
  nextRotation?: string;
  rotationEnabled: boolean;
}

export interface LoggerContext {
  [key: string]: any;
}
