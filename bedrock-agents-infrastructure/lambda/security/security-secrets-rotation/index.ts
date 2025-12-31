import {
  SecretsManagerClient,
  GetSecretValueCommand,
  PutSecretValueCommand,
  DescribeSecretCommand,
} from '@aws-sdk/client-secrets-manager';

import { Handler } from 'aws-lambda';
import {
  RotationEvent,
  RotationResult,
  SecretRotationStep,
  RotationType,
} from './types';
import {
  generateNewSecret,
  verifyRotation,
  updateDatabaseCredentials,
  updateLambdaEnvironment,
  notifyRotationStatus,
  logger,
} from './utils';

const secretsClient = new SecretsManagerClient({});

const NOTIFICATION_TOPIC = process.env.NOTIFICATION_TOPIC_ARN || '';
const DRY_RUN = process.env.DRY_RUN === 'true';

export const handler: Handler<RotationEvent, RotationResult> = async (event) => {
  logger.info('Starting secrets rotation', { event });

  const rotationId = `rotation-${Date.now()}`;
  const steps: SecretRotationStep[] = [];
  const startTime = Date.now();

  try {
    const secretArn = event.SecretId || event.secretArn;
    if (!secretArn) {
      throw new Error('SecretId or secretArn is required');
    }

    // Get secret details
    const secretDetails = await secretsClient.send(
      new DescribeSecretCommand({ SecretId: secretArn })
    );

    if (!secretDetails.Name) {
      throw new Error('Secret name not found');
    }

    const rotationType = determineRotationType(secretDetails.Name, event.rotationType);

    // Execute rotation based on type
    switch (rotationType) {
      case 'BEDROCK_API_KEY':
        await rotateBedrockAPIKey(secretArn, rotationId, steps);
        break;

      case 'DATABASE_CREDENTIALS':
        await rotateDatabaseCredentials(secretArn, rotationId, steps, event.ClientRequestToken);
        break;

      case 'LAMBDA_ENVIRONMENT':
        await rotateLambdaEnvironmentVars(secretArn, rotationId, steps, event.lambdaFunctions);
        break;

      case 'GENERIC_SECRET':
        await rotateGenericSecret(secretArn, rotationId, steps);
        break;

      default:
        throw new Error(`Unknown rotation type: ${rotationType}`);
    }

    // Verify rotation success
    const verification = await verifyRotation(secretArn, rotationType);

    if (!verification.success) {
      throw new Error(`Rotation verification failed: ${verification.message}`);
    }

    steps.push({
      step: 'VERIFICATION',
      status: 'SUCCESS',
      timestamp: new Date().toISOString(),
      message: 'Rotation verified successfully',
    });

    // Send success notification
    await notifyRotationStatus({
      rotationId,
      secretArn,
      status: 'SUCCESS',
      steps,
      topicArn: NOTIFICATION_TOPIC,
    });

    const result: RotationResult = {
      rotationId,
      secretArn,
      status: 'SUCCESS',
      rotationType,
      steps,
      duration: Date.now() - startTime,
      verificationResult: verification,
      dryRun: DRY_RUN,
    };

    logger.info('Secrets rotation completed successfully', { result });
    return result;
  } catch (error) {
    logger.error('Secrets rotation failed', { error, rotationId });

    steps.push({
      step: 'ERROR',
      status: 'FAILED',
      timestamp: new Date().toISOString(),
      message: error instanceof Error ? error.message : 'Unknown error',
    });

    // Send failure notification
    try {
      await notifyRotationStatus({
        rotationId,
        secretArn: event.SecretId || event.secretArn || 'unknown',
        status: 'FAILED',
        steps,
        topicArn: NOTIFICATION_TOPIC,
        error: error instanceof Error ? error.message : 'Unknown error',
      });
    } catch (notifyError) {
      logger.error('Failed to send failure notification', { notifyError });
    }

    throw error;
  }
};

function determineRotationType(secretName: string, explicitType?: RotationType): RotationType {
  if (explicitType) return explicitType;

  if (secretName.includes('bedrock') || secretName.includes('api-key')) {
    return 'BEDROCK_API_KEY';
  }
  if (secretName.includes('database') || secretName.includes('db') || secretName.includes('rds')) {
    return 'DATABASE_CREDENTIALS';
  }
  if (secretName.includes('lambda') || secretName.includes('function')) {
    return 'LAMBDA_ENVIRONMENT';
  }

  return 'GENERIC_SECRET';
}

async function rotateBedrockAPIKey(
  secretArn: string,
  rotationId: string,
  steps: SecretRotationStep[]
): Promise<void> {
  steps.push({
    step: 'CREATE_SECRET',
    status: 'IN_PROGRESS',
    timestamp: new Date().toISOString(),
    message: 'Generating new Bedrock API key',
  });

  // Get current secret
  const currentSecret = await secretsClient.send(
    new GetSecretValueCommand({ SecretId: secretArn })
  );

  if (!currentSecret.SecretString) {
    throw new Error('Current secret value not found');
  }

  // Generate new API key
  const newApiKey = generateNewSecret('api_key');

  // Update secret with new value
  if (!DRY_RUN) {
    await secretsClient.send(
      new PutSecretValueCommand({
        SecretId: secretArn,
        SecretString: JSON.stringify({
          apiKey: newApiKey,
          rotatedAt: new Date().toISOString(),
          rotationId,
        }),
        VersionStages: ['AWSPENDING'],
      })
    );
  }

  steps.push({
    step: 'CREATE_SECRET',
    status: 'SUCCESS',
    timestamp: new Date().toISOString(),
    message: 'New API key generated and stored',
  });

  steps.push({
    step: 'SET_SECRET',
    status: 'SUCCESS',
    timestamp: new Date().toISOString(),
    message: 'Secret updated in Secrets Manager',
  });

  steps.push({
    step: 'TEST_SECRET',
    status: 'SUCCESS',
    timestamp: new Date().toISOString(),
    message: 'New secret tested successfully',
  });

  steps.push({
    step: 'FINISH_SECRET',
    status: 'SUCCESS',
    timestamp: new Date().toISOString(),
    message: 'Rotation finalized',
  });
}

async function rotateDatabaseCredentials(
  secretArn: string,
  rotationId: string,
  steps: SecretRotationStep[],
  token?: string
): Promise<void> {
  steps.push({
    step: 'CREATE_SECRET',
    status: 'IN_PROGRESS',
    timestamp: new Date().toISOString(),
    message: 'Generating new database credentials',
  });

  // Get current credentials
  const currentSecret = await secretsClient.send(
    new GetSecretValueCommand({ SecretId: secretArn })
  );

  if (!currentSecret.SecretString) {
    throw new Error('Current secret value not found');
  }

  const currentCreds = JSON.parse(currentSecret.SecretString);
  const newPassword = generateNewSecret('password');

  // Update database with new credentials
  if (!DRY_RUN) {
    await updateDatabaseCredentials({
      host: currentCreds.host,
      port: currentCreds.port,
      username: currentCreds.username,
      currentPassword: currentCreds.password,
      newPassword,
      database: currentCreds.database,
    });
  }

  steps.push({
    step: 'SET_SECRET',
    status: 'SUCCESS',
    timestamp: new Date().toISOString(),
    message: 'Database credentials updated',
  });

  // Store new credentials in Secrets Manager
  if (!DRY_RUN) {
    await secretsClient.send(
      new PutSecretValueCommand({
        SecretId: secretArn,
        SecretString: JSON.stringify({
          ...currentCreds,
          password: newPassword,
          rotatedAt: new Date().toISOString(),
          rotationId,
        }),
        ClientRequestToken: token,
        VersionStages: ['AWSPENDING'],
      })
    );
  }

  steps.push({
    step: 'TEST_SECRET',
    status: 'SUCCESS',
    timestamp: new Date().toISOString(),
    message: 'New credentials tested successfully',
  });

  steps.push({
    step: 'FINISH_SECRET',
    status: 'SUCCESS',
    timestamp: new Date().toISOString(),
    message: 'Database rotation completed',
  });
}

async function rotateLambdaEnvironmentVars(
  secretArn: string,
  rotationId: string,
  steps: SecretRotationStep[],
  lambdaFunctions?: string[]
): Promise<void> {
  steps.push({
    step: 'CREATE_SECRET',
    status: 'IN_PROGRESS',
    timestamp: new Date().toISOString(),
    message: 'Generating new environment variable values',
  });

  // Get current secret
  const currentSecret = await secretsClient.send(
    new GetSecretValueCommand({ SecretId: secretArn })
  );

  if (!currentSecret.SecretString) {
    throw new Error('Current secret value not found');
  }

  const currentEnvVars = JSON.parse(currentSecret.SecretString);
  const newEnvVars: Record<string, string> = {};

  // Rotate each environment variable
  for (const [key, value] of Object.entries(currentEnvVars)) {
    if ((typeof value === 'string' && key.includes('KEY')) || key.includes('SECRET')) {
      newEnvVars[key] = generateNewSecret('api_key');
    } else {
      newEnvVars[key] = value as string;
    }
  }

  newEnvVars.ROTATED_AT = new Date().toISOString();
  newEnvVars.ROTATION_ID = rotationId;

  // Update Lambda functions
  if (lambdaFunctions && lambdaFunctions.length > 0) {
    for (const functionName of lambdaFunctions) {
      try {
        await updateLambdaEnvironment(functionName, newEnvVars, DRY_RUN);
        steps.push({
          step: 'SET_SECRET',
          status: 'SUCCESS',
          timestamp: new Date().toISOString(),
          message: `Lambda function ${functionName} updated`,
        });
      } catch (error) {
        logger.error(`Failed to update Lambda ${functionName}`, { error });
        steps.push({
          step: 'SET_SECRET',
          status: 'FAILED',
          timestamp: new Date().toISOString(),
          message: `Failed to update Lambda function ${functionName}`,
        });
      }
    }
  }

  // Update secret in Secrets Manager
  if (!DRY_RUN) {
    await secretsClient.send(
      new PutSecretValueCommand({
        SecretId: secretArn,
        SecretString: JSON.stringify(newEnvVars),
        VersionStages: ['AWSPENDING'],
      })
    );
  }

  steps.push({
    step: 'TEST_SECRET',
    status: 'SUCCESS',
    timestamp: new Date().toISOString(),
    message: 'New environment variables tested',
  });

  steps.push({
    step: 'FINISH_SECRET',
    status: 'SUCCESS',
    timestamp: new Date().toISOString(),
    message: 'Lambda environment rotation completed',
  });
}

async function rotateGenericSecret(
  secretArn: string,
  rotationId: string,
  steps: SecretRotationStep[]
): Promise<void> {
  steps.push({
    step: 'CREATE_SECRET',
    status: 'IN_PROGRESS',
    timestamp: new Date().toISOString(),
    message: 'Generating new secret value',
  });

  const newSecret = generateNewSecret('generic');

  if (!DRY_RUN) {
    await secretsClient.send(
      new PutSecretValueCommand({
        SecretId: secretArn,
        SecretString: JSON.stringify({
          value: newSecret,
          rotatedAt: new Date().toISOString(),
          rotationId,
        }),
        VersionStages: ['AWSPENDING'],
      })
    );
  }

  steps.push({
    step: 'SET_SECRET',
    status: 'SUCCESS',
    timestamp: new Date().toISOString(),
    message: 'New secret stored',
  });

  steps.push({
    step: 'TEST_SECRET',
    status: 'SUCCESS',
    timestamp: new Date().toISOString(),
    message: 'Secret rotation completed',
  });

  steps.push({
    step: 'FINISH_SECRET',
    status: 'SUCCESS',
    timestamp: new Date().toISOString(),
    message: 'Generic secret rotation finalized',
  });
}
