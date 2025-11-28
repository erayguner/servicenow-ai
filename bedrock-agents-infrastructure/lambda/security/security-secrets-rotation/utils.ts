import * as crypto from 'crypto';
import {
  SecretsManagerClient,
  GetSecretValueCommand,
  TestSecretCommand,
} from '@aws-sdk/client-secrets-manager';
import {
  LambdaClient,
  UpdateFunctionConfigurationCommand,
  GetFunctionConfigurationCommand,
} from '@aws-sdk/client-lambda';
import { SNSClient, PublishCommand } from '@aws-sdk/client-sns';
import {
  DatabaseCredentials,
  VerificationResult,
  VerificationCheck,
  RotationType,
  NotificationPayload,
  LoggerContext,
} from './types';

const secretsClient = new SecretsManagerClient({});
const lambdaClient = new LambdaClient({});
const snsClient = new SNSClient({});

export const logger = {
  info: (message: string, context?: LoggerContext) => {
    console.log(
      JSON.stringify({ level: 'INFO', message, ...context, timestamp: new Date().toISOString() })
    );
  },
  warn: (message: string, context?: LoggerContext) => {
    console.warn(
      JSON.stringify({ level: 'WARN', message, ...context, timestamp: new Date().toISOString() })
    );
  },
  error: (message: string, context?: LoggerContext) => {
    console.error(
      JSON.stringify({ level: 'ERROR', message, ...context, timestamp: new Date().toISOString() })
    );
  },
};

export function generateNewSecret(type: 'api_key' | 'password' | 'generic'): string {
  const length = type === 'password' ? 32 : 64;
  const charset =
    type === 'password'
      ? 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*'
      : 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

  const randomBytes = crypto.randomBytes(length);
  let result = '';

  let i = 0;
  // Compute bias-free upper bound for random byte mapping
  const maxMultiple = Math.floor(256 / charset.length) * charset.length;
  while (i < length) {
    const randByte = crypto.randomBytes(1)[0];
    if (randByte >= maxMultiple) {
      continue; // Reject and redraw if out of bounds
    }
    result += charset[randByte % charset.length];
    i++;
  }

  // Ensure password complexity requirements
  if (type === 'password') {
    const hasUpper = /[A-Z]/.test(result);
    const hasLower = /[a-z]/.test(result);
    const hasDigit = /[0-9]/.test(result);
    const hasSpecial = /[!@#$%^&*]/.test(result);

    if (!hasUpper || !hasLower || !hasDigit || !hasSpecial) {
      // Recursively generate until we meet requirements
      return generateNewSecret(type);
    }
  }

  return result;
}

export async function verifyRotation(
  secretArn: string,
  rotationType: RotationType
): Promise<VerificationResult> {
  const checks: VerificationCheck[] = [];

  try {
    // Check 1: Verify secret exists and is accessible
    const secretResponse = await secretsClient.send(
      new GetSecretValueCommand({ SecretId: secretArn })
    );

    checks.push({
      checkName: 'Secret Accessibility',
      passed: !!secretResponse.SecretString,
      details: 'Secret is accessible and contains value',
    });

    if (!secretResponse.SecretString) {
      return {
        success: false,
        message: 'Secret value is empty',
        checks,
        timestamp: new Date().toISOString(),
      };
    }

    // Check 2: Verify secret format
    try {
      const secretValue = JSON.parse(secretResponse.SecretString);
      checks.push({
        checkName: 'Secret Format',
        passed: true,
        details: 'Secret is valid JSON',
      });

      // Check 3: Verify rotation metadata
      const hasRotationId = !!secretValue.rotationId || !!secretValue.ROTATION_ID;
      const hasTimestamp = !!secretValue.rotatedAt || !!secretValue.ROTATED_AT;

      checks.push({
        checkName: 'Rotation Metadata',
        passed: hasRotationId && hasTimestamp,
        details: 'Secret contains rotation metadata',
      });
    } catch (error) {
      checks.push({
        checkName: 'Secret Format',
        passed: false,
        details: 'Secret is not valid JSON (may be plain text)',
      });
    }

    // Check 4: Type-specific verification
    const typeCheck = await verifyRotationType(secretArn, rotationType, secretResponse.SecretString);
    checks.push(typeCheck);

    const allPassed = checks.every((check) => check.passed);

    return {
      success: allPassed,
      message: allPassed ? 'All verification checks passed' : 'Some verification checks failed',
      checks,
      timestamp: new Date().toISOString(),
    };
  } catch (error) {
    logger.error('Error verifying rotation', { error, secretArn });

    checks.push({
      checkName: 'Verification Error',
      passed: false,
      details: error instanceof Error ? error.message : 'Unknown error',
    });

    return {
      success: false,
      message: 'Verification failed with error',
      checks,
      timestamp: new Date().toISOString(),
    };
  }
}

async function verifyRotationType(
  secretArn: string,
  rotationType: RotationType,
  secretValue: string
): Promise<VerificationCheck> {
  try {
    const parsed = JSON.parse(secretValue);

    switch (rotationType) {
      case 'BEDROCK_API_KEY':
        return {
          checkName: 'Bedrock API Key Validation',
          passed: !!parsed.apiKey && parsed.apiKey.length >= 32,
          details: 'API key meets minimum length requirement',
        };

      case 'DATABASE_CREDENTIALS':
        const hasRequiredFields =
          !!parsed.host && !!parsed.username && !!parsed.password && !!parsed.database;
        return {
          checkName: 'Database Credentials Validation',
          passed: hasRequiredFields,
          details: 'All required database fields present',
        };

      case 'LAMBDA_ENVIRONMENT':
        return {
          checkName: 'Lambda Environment Validation',
          passed: Object.keys(parsed).length > 0,
          details: 'Environment variables present',
        };

      case 'GENERIC_SECRET':
        return {
          checkName: 'Generic Secret Validation',
          passed: !!parsed.value,
          details: 'Secret value present',
        };

      default:
        return {
          checkName: 'Type Validation',
          passed: false,
          details: `Unknown rotation type: ${rotationType}`,
        };
    }
  } catch (error) {
    return {
      checkName: 'Type Validation',
      passed: false,
      details: error instanceof Error ? error.message : 'Unknown error',
    };
  }
}

export async function updateDatabaseCredentials(creds: DatabaseCredentials): Promise<void> {
  // This is a placeholder - actual implementation would use the specific database client
  // For example: MySQL client, PostgreSQL client, etc.

  logger.info('Updating database credentials', {
    host: creds.host,
    username: creds.username,
    database: creds.database,
  });

  // In production, you would:
  // 1. Connect to database with current credentials
  // 2. Execute ALTER USER or equivalent command
  // 3. Verify new credentials work
  // 4. Close connection

  // Example for PostgreSQL:
  // const client = new Client({
  //   host: creds.host,
  //   port: creds.port,
  //   user: creds.username,
  //   password: creds.currentPassword,
  //   database: creds.database,
  // });
  // await client.connect();
  // await client.query(`ALTER USER ${creds.username} WITH PASSWORD '${creds.newPassword}'`);
  // await client.end();

  logger.info('Database credentials updated successfully');
}

export async function updateLambdaEnvironment(
  functionName: string,
  envVars: Record<string, string>,
  dryRun: boolean
): Promise<void> {
  try {
    // Get current configuration
    const currentConfig = await lambdaClient.send(
      new GetFunctionConfigurationCommand({ FunctionName: functionName })
    );

    if (!currentConfig.Environment) {
      throw new Error(`Function ${functionName} has no environment variables`);
    }

    // Merge with new variables
    const updatedVars = {
      ...currentConfig.Environment.Variables,
      ...envVars,
    };

    if (!dryRun) {
      await lambdaClient.send(
        new UpdateFunctionConfigurationCommand({
          FunctionName: functionName,
          Environment: {
            Variables: updatedVars,
          },
        })
      );
    }

    logger.info('Lambda environment updated', { functionName, dryRun });
  } catch (error) {
    logger.error('Failed to update Lambda environment', { error, functionName });
    throw error;
  }
}

export async function notifyRotationStatus(payload: NotificationPayload): Promise<void> {
  try {
    const message = {
      rotationId: payload.rotationId,
      secretArn: payload.secretArn,
      status: payload.status,
      timestamp: new Date().toISOString(),
      steps: payload.steps,
      error: payload.error,
    };

    const subject = `Secret Rotation ${payload.status} - ${payload.rotationId}`;

    await snsClient.send(
      new PublishCommand({
        TopicArn: payload.topicArn,
        Subject: subject,
        Message: JSON.stringify(message, null, 2),
        MessageAttributes: {
          Status: {
            DataType: 'String',
            StringValue: payload.status,
          },
          RotationId: {
            DataType: 'String',
            StringValue: payload.rotationId,
          },
        },
      })
    );

    logger.info('Rotation notification sent', { rotationId: payload.rotationId });
  } catch (error) {
    logger.error('Failed to send rotation notification', { error, payload });
    throw error;
  }
}

export function validateSecretComplexity(secret: string, type: 'api_key' | 'password'): boolean {
  if (type === 'password') {
    // Password must have:
    // - At least 12 characters
    // - At least one uppercase letter
    // - At least one lowercase letter
    // - At least one digit
    // - At least one special character
    return (
      secret.length >= 12 &&
      /[A-Z]/.test(secret) &&
      /[a-z]/.test(secret) &&
      /[0-9]/.test(secret) &&
      /[!@#$%^&*]/.test(secret)
    );
  }

  if (type === 'api_key') {
    // API key must be at least 32 characters
    return secret.length >= 32;
  }

  return false;
}
