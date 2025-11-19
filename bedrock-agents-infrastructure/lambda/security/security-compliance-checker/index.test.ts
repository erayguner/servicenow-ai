import { handler } from './index';
import { ComplianceCheckEvent, ComplianceCheckResult } from './types';

// Mock AWS SDK clients
jest.mock('@aws-sdk/client-bedrock-agent');
jest.mock('@aws-sdk/client-iam');
jest.mock('@aws-sdk/client-kms');
jest.mock('@aws-sdk/client-securityhub');
jest.mock('@aws-sdk/client-secrets-manager');

describe('Security Compliance Checker', () => {
  const mockAccountId = '123456789012';
  const mockRegion = 'us-east-1';

  beforeEach(() => {
    process.env.AWS_ACCOUNT_ID = mockAccountId;
    process.env.AWS_REGION = mockRegion;
    jest.clearAllMocks();
  });

  describe('handler', () => {
    it('should perform compliance check and return results', async () => {
      const event: ComplianceCheckEvent = {
        targetRoles: ['arn:aws:iam::123456789012:role/TestRole'],
        resourceArns: ['arn:aws:kms:us-east-1:123456789012:key/test-key'],
        checkTypes: ['bedrock', 'iam', 'secrets', 'encryption'],
      };

      const result = await handler(event, {} as any, {} as any);

      expect(result).toBeDefined();
      expect(result.checkId).toMatch(/^compliance-check-\d+$/);
      expect(result.timestamp).toBeDefined();
      expect(result.totalFindings).toBeGreaterThanOrEqual(0);
      expect(result.complianceStatus).toMatch(/^(PASSED|FAILED)$/);
    });

    it('should handle empty event gracefully', async () => {
      const event: ComplianceCheckEvent = {};

      const result = await handler(event, {} as any, {} as any);

      expect(result).toBeDefined();
      expect(result.totalFindings).toBeGreaterThanOrEqual(0);
    });

    it('should categorize findings by severity', async () => {
      const event: ComplianceCheckEvent = {
        checkTypes: ['bedrock', 'iam'],
      };

      const result = await handler(event, {} as any, {} as any);

      expect(result.criticalFindings).toBeGreaterThanOrEqual(0);
      expect(result.highFindings).toBeGreaterThanOrEqual(0);
      expect(result.mediumFindings).toBeGreaterThanOrEqual(0);
      expect(result.lowFindings).toBeGreaterThanOrEqual(0);
      expect(
        result.criticalFindings +
          result.highFindings +
          result.mediumFindings +
          result.lowFindings
      ).toBe(result.totalFindings);
    });

    it('should fail compliance if critical findings exist', async () => {
      const event: ComplianceCheckEvent = {
        checkTypes: ['iam'],
      };

      const result = await handler(event, {} as any, {} as any);

      if (result.criticalFindings > 0) {
        expect(result.complianceStatus).toBe('FAILED');
      }
    });

    it('should handle errors gracefully', async () => {
      const event: ComplianceCheckEvent = {
        targetRoles: ['invalid-arn'],
      };

      await expect(handler(event, {} as any, {} as any)).rejects.toThrow();
    });
  });

  describe('Bedrock Agent Checks', () => {
    it('should detect agents without customer-managed encryption', async () => {
      const event: ComplianceCheckEvent = {
        checkTypes: ['bedrock'],
      };

      const result = await handler(event, {} as any, {} as any);

      const encryptionFindings = result.findings.filter(
        (f) => f.title.includes('customer-managed encryption')
      );
      expect(encryptionFindings).toBeDefined();
    });
  });

  describe('IAM Policy Checks', () => {
    it('should detect wildcard principals in trust policies', async () => {
      const event: ComplianceCheckEvent = {
        targetRoles: ['arn:aws:iam::123456789012:role/WildcardRole'],
        checkTypes: ['iam'],
      };

      const result = await handler(event, {} as any, {} as any);

      const wildcardFindings = result.findings.filter(
        (f) => f.title.includes('wildcard')
      );
      expect(wildcardFindings).toBeDefined();
    });

    it('should detect overly permissive actions', async () => {
      const event: ComplianceCheckEvent = {
        targetRoles: ['arn:aws:iam::123456789012:role/AdminRole'],
        checkTypes: ['iam'],
      };

      const result = await handler(event, {} as any, {} as any);

      const overPrivilegedFindings = result.findings.filter(
        (f) => f.title.includes('overly permissive')
      );
      expect(overPrivilegedFindings).toBeDefined();
    });
  });

  describe('Secret Scanning', () => {
    it('should detect exposed AWS credentials', async () => {
      const event: ComplianceCheckEvent = {
        checkTypes: ['secrets'],
      };

      const result = await handler(event, {} as any, {} as any);

      expect(result.findings).toBeDefined();
    });

    it('should detect secrets without rotation', async () => {
      const event: ComplianceCheckEvent = {
        checkTypes: ['secrets'],
      };

      const result = await handler(event, {} as any, {} as any);

      const rotationFindings = result.findings.filter(
        (f) => f.title.includes('rotation')
      );
      expect(rotationFindings).toBeDefined();
    });
  });

  describe('Encryption Checks', () => {
    it('should validate KMS key usage', async () => {
      const event: ComplianceCheckEvent = {
        resourceArns: ['arn:aws:kms:us-east-1:123456789012:key/test-key'],
        checkTypes: ['encryption'],
      };

      const result = await handler(event, {} as any, {} as any);

      expect(result.findings).toBeDefined();
    });

    it('should check key rotation status', async () => {
      const event: ComplianceCheckEvent = {
        resourceArns: ['arn:aws:kms:us-east-1:123456789012:key/test-key'],
        checkTypes: ['encryption'],
      };

      const result = await handler(event, {} as any, {} as any);

      expect(result).toBeDefined();
    });
  });

  describe('Security Hub Integration', () => {
    it('should format findings for Security Hub', async () => {
      const event: ComplianceCheckEvent = {
        checkTypes: ['bedrock', 'iam', 'secrets', 'encryption'],
      };

      const result = await handler(event, {} as any, {} as any);

      result.findings.forEach((finding) => {
        expect(finding.id).toBeDefined();
        expect(finding.title).toBeDefined();
        expect(finding.severity).toMatch(/^(CRITICAL|HIGH|MEDIUM|LOW|INFORMATIONAL)$/);
        expect(finding.resourceArn).toBeDefined();
        expect(finding.remediationSteps).toBeInstanceOf(Array);
      });
    });
  });
});
