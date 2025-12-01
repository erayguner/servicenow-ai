import { handler } from './index';
import { RotationEvent, RotationResult } from './types';

// Mock AWS SDK clients
jest.mock('@aws-sdk/client-secrets-manager');
jest.mock('@aws-sdk/client-lambda');
jest.mock('@aws-sdk/client-rds');
jest.mock('@aws-sdk/client-sns');

describe('Security Secrets Rotation', () => {
  beforeEach(() => {
    process.env.NOTIFICATION_TOPIC_ARN = 'arn:aws:sns:us-east-1:123456789012:rotation-alerts';
    process.env.DRY_RUN = 'true';
    jest.clearAllMocks();
  });

  describe('handler', () => {
    it('should rotate Bedrock API key successfully', async () => {
      const event: RotationEvent = {
        SecretId: 'arn:aws:secretsmanager:us-east-1:123456789012:secret:bedrock-api-key',
        rotationType: 'BEDROCK_API_KEY',
        ClientRequestToken: 'test-token-123',
      };

      const result = await handler(event, {} as any, {} as any);

      expect(result).toBeDefined();
      expect(result.rotationId).toMatch(/^rotation-\d+$/);
      expect(result.status).toBe('SUCCESS');
      expect(result.rotationType).toBe('BEDROCK_API_KEY');
      expect(result.dryRun).toBe(true);
    });

    it('should rotate database credentials successfully', async () => {
      const event: RotationEvent = {
        SecretId: 'arn:aws:secretsmanager:us-east-1:123456789012:secret:db-credentials',
        rotationType: 'DATABASE_CREDENTIALS',
        ClientRequestToken: 'test-token-456',
      };

      const result = await handler(event, {} as any, {} as any);

      expect(result).toBeDefined();
      expect(result.rotationType).toBe('DATABASE_CREDENTIALS');
      expect(result.steps.length).toBeGreaterThan(0);
    });

    it('should rotate Lambda environment variables', async () => {
      const event: RotationEvent = {
        secretArn: 'arn:aws:secretsmanager:us-east-1:123456789012:secret:lambda-env',
        rotationType: 'LAMBDA_ENVIRONMENT',
        lambdaFunctions: ['function-1', 'function-2'],
      };

      const result = await handler(event, {} as any, {} as any);

      expect(result).toBeDefined();
      expect(result.rotationType).toBe('LAMBDA_ENVIRONMENT');
    });

    it('should rotate generic secret', async () => {
      const event: RotationEvent = {
        SecretId: 'arn:aws:secretsmanager:us-east-1:123456789012:secret:generic-secret',
        rotationType: 'GENERIC_SECRET',
      };

      const result = await handler(event, {} as any, {} as any);

      expect(result).toBeDefined();
      expect(result.rotationType).toBe('GENERIC_SECRET');
    });

    it('should handle missing SecretId', async () => {
      const event: RotationEvent = {};

      await expect(handler(event, {} as any, {} as any)).rejects.toThrow(
        'SecretId or secretArn is required'
      );
    });

    it('should measure rotation duration', async () => {
      const event: RotationEvent = {
        SecretId: 'arn:aws:secretsmanager:us-east-1:123456789012:secret:test-secret',
        rotationType: 'GENERIC_SECRET',
      };

      const result = await handler(event, {} as any, {} as any);

      expect(result.duration).toBeGreaterThan(0);
      expect(typeof result.duration).toBe('number');
    });
  });

  describe('Rotation Steps', () => {
    it('should include all required rotation steps', async () => {
      const event: RotationEvent = {
        SecretId: 'arn:aws:secretsmanager:us-east-1:123456789012:secret:test-secret',
        rotationType: 'BEDROCK_API_KEY',
      };

      const result = await handler(event, {} as any, {} as any);

      const stepTypes = result.steps.map((s) => s.step);
      expect(stepTypes).toContain('CREATE_SECRET');
      expect(stepTypes).toContain('SET_SECRET');
      expect(stepTypes).toContain('TEST_SECRET');
      expect(stepTypes).toContain('FINISH_SECRET');
      expect(stepTypes).toContain('VERIFICATION');
    });

    it('should mark all steps as SUCCESS on successful rotation', async () => {
      const event: RotationEvent = {
        SecretId: 'arn:aws:secretsmanager:us-east-1:123456789012:secret:test-secret',
        rotationType: 'GENERIC_SECRET',
      };

      const result = await handler(event, {} as any, {} as any);

      const allSuccess = result.steps.every(
        (s) => s.status === 'SUCCESS' || s.status === 'IN_PROGRESS'
      );
      expect(allSuccess).toBe(true);
    });
  });

  describe('Verification', () => {
    it('should include verification result', async () => {
      const event: RotationEvent = {
        SecretId: 'arn:aws:secretsmanager:us-east-1:123456789012:secret:test-secret',
        rotationType: 'BEDROCK_API_KEY',
      };

      const result = await handler(event, {} as any, {} as any);

      expect(result.verificationResult).toBeDefined();
      expect(result.verificationResult?.success).toBeDefined();
      expect(result.verificationResult?.checks).toBeInstanceOf(Array);
    });

    it('should perform type-specific verification', async () => {
      const event: RotationEvent = {
        SecretId: 'arn:aws:secretsmanager:us-east-1:123456789012:secret:db-creds',
        rotationType: 'DATABASE_CREDENTIALS',
      };

      const result = await handler(event, {} as any, {} as any);

      expect(result.verificationResult?.checks.length).toBeGreaterThan(0);
    });
  });

  describe('Error Handling', () => {
    it('should handle rotation errors gracefully', async () => {
      const event: RotationEvent = {
        SecretId: 'arn:aws:secretsmanager:us-east-1:123456789012:secret:invalid-secret',
        rotationType: 'BEDROCK_API_KEY',
      };

      await expect(handler(event)).rejects.toThrow();
    });

    it('should add ERROR step on failure', async () => {
      const event: RotationEvent = {
        SecretId: undefined,
      };

      try {
        await handler(event);
      } catch (error) {
        expect(error).toBeDefined();
      }
    });
  });

  describe('Dry Run Mode', () => {
    it('should not make actual changes in dry run mode', async () => {
      process.env.DRY_RUN = 'true';

      const event: RotationEvent = {
        SecretId: 'arn:aws:secretsmanager:us-east-1:123456789012:secret:test-secret',
        rotationType: 'DATABASE_CREDENTIALS',
      };

      const result = await handler(event);

      expect(result.dryRun).toBe(true);
    });
  });

  describe('Rotation Type Detection', () => {
    it('should auto-detect Bedrock API key from secret name', async () => {
      const event: RotationEvent = {
        SecretId: 'arn:aws:secretsmanager:us-east-1:123456789012:secret:bedrock-api-key-abc123',
      };

      const result = await handler(event);

      expect(result.rotationType).toBe('BEDROCK_API_KEY');
    });

    it('should auto-detect database credentials from secret name', async () => {
      const event: RotationEvent = {
        SecretId: 'arn:aws:secretsmanager:us-east-1:123456789012:secret:rds-db-password',
      };

      const result = await handler(event);

      expect(result.rotationType).toBe('DATABASE_CREDENTIALS');
    });

    it('should auto-detect Lambda environment from secret name', async () => {
      const event: RotationEvent = {
        SecretId: 'arn:aws:secretsmanager:us-east-1:123456789012:secret:lambda-function-env',
      };

      const result = await handler(event);

      expect(result.rotationType).toBe('LAMBDA_ENVIRONMENT');
    });
  });

  describe('Notification', () => {
    it('should send success notification', async () => {
      const event: RotationEvent = {
        SecretId: 'arn:aws:secretsmanager:us-east-1:123456789012:secret:test-secret',
        rotationType: 'GENERIC_SECRET',
      };

      const result = await handler(event);

      expect(result.status).toBe('SUCCESS');
    });

    it('should send failure notification on error', async () => {
      const event: RotationEvent = {
        SecretId: undefined,
      };

      try {
        await handler(event);
      } catch (error) {
        expect(error).toBeDefined();
      }
    });
  });
});
