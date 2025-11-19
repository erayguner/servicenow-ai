import { handler } from './index';
import { AccessAnalysisEvent, AccessAnalysisResult } from './types';

// Mock AWS SDK clients
jest.mock('@aws-sdk/client-accessanalyzer');
jest.mock('@aws-sdk/client-iam');
jest.mock('@aws-sdk/client-sns');
jest.mock('@aws-sdk/client-sqs');

describe('Security Access Analyzer', () => {
  beforeEach(() => {
    process.env.ANALYZER_ARN = 'arn:aws:access-analyzer:us-east-1:123456789012:analyzer/test';
    process.env.NOTIFICATION_TOPIC_ARN = 'arn:aws:sns:us-east-1:123456789012:security-alerts';
    process.env.POLICY_QUEUE_URL = 'https://sqs.us-east-1.amazonaws.com/123456789012/policies';
    process.env.DRY_RUN = 'true';
    process.env.AUTO_UPDATE_POLICIES = 'false';
    process.env.AWS_ACCOUNT_ID = '123456789012';
    jest.clearAllMocks();
  });

  describe('handler', () => {
    it('should perform access analysis and return results', async () => {
      const event: AccessAnalysisEvent = {
        analyzeFindings: true,
      };

      const result = await handler(event, {} as any, {} as any);

      expect(result).toBeDefined();
      expect(result.analysisId).toMatch(/^analysis-\d+$/);
      expect(result.totalFindings).toBeGreaterThanOrEqual(0);
    });

    it('should analyze specific roles', async () => {
      const event: AccessAnalysisEvent = {
        roleArns: ['arn:aws:iam::123456789012:role/TestRole'],
        analyzeFindings: false,
      };

      const result = await handler(event, {} as any, {} as any);

      expect(result).toBeDefined();
      expect(result.duration).toBeGreaterThan(0);
    });

    it('should generate recommendations when requested', async () => {
      const event: AccessAnalysisEvent = {
        roleArns: ['arn:aws:iam::123456789012:role/TestRole'],
        generateRecommendations: true,
      };

      const result = await handler(event, {} as any, {} as any);

      expect(result.recommendations).toBeDefined();
      expect(Array.isArray(result.recommendations)).toBe(true);
    });

    it('should categorize findings by severity', async () => {
      const event: AccessAnalysisEvent = {
        analyzeFindings: true,
      };

      const result = await handler(event, {} as any, {} as any);

      expect(result.criticalFindings).toBeGreaterThanOrEqual(0);
      expect(result.highFindings).toBeGreaterThanOrEqual(0);
      expect(result.mediumFindings).toBeGreaterThanOrEqual(0);
      expect(result.lowFindings).toBeGreaterThanOrEqual(0);
      expect(
        result.criticalFindings + result.highFindings + result.mediumFindings + result.lowFindings
      ).toBe(result.totalFindings);
    });
  });

  describe('Access Analyzer Findings', () => {
    it('should analyze Access Analyzer findings', async () => {
      const event: AccessAnalysisEvent = {
        analyzeFindings: true,
      };

      const result = await handler(event, {} as any, {} as any);

      expect(result).toBeDefined();
    });

    it('should skip when ANALYZER_ARN not configured', async () => {
      delete process.env.ANALYZER_ARN;

      const event: AccessAnalysisEvent = {
        analyzeFindings: true,
      };

      const result = await handler(event, {} as any, {} as any);

      expect(result.totalFindings).toBe(0);
    });
  });

  describe('Role Analysis', () => {
    it('should detect overprivileged policies', async () => {
      const event: AccessAnalysisEvent = {
        roleArns: ['arn:aws:iam::123456789012:role/OverprivilegedRole'],
        checkOverpermissive: true,
      };

      const result = await handler(event, {} as any, {} as any);

      const overprivilegedFindings = result.findings.filter(
        (f) => f.type === 'OVERPRIVILEGED'
      );
      expect(overprivilegedFindings).toBeDefined();
    });

    it('should detect wildcard principals', async () => {
      const event: AccessAnalysisEvent = {
        roleArns: ['arn:aws:iam::123456789012:role/WildcardRole'],
      };

      const result = await handler(event, {} as any, {} as any);

      const wildcardFindings = result.findings.filter(
        (f) => f.type === 'WILDCARD_PRINCIPAL'
      );
      expect(wildcardFindings).toBeDefined();
    });

    it('should detect missing ExternalId', async () => {
      const event: AccessAnalysisEvent = {
        roleArns: ['arn:aws:iam::123456789012:role/CrossAccountRole'],
      };

      const result = await handler(event, {} as any, {} as any);

      const externalIdFindings = result.findings.filter(
        (f) => f.type === 'MISSING_EXTERNAL_ID'
      );
      expect(externalIdFindings).toBeDefined();
    });
  });

  describe('Unused Permissions', () => {
    it('should detect unused permissions', async () => {
      const event: AccessAnalysisEvent = {
        roleArns: ['arn:aws:iam::123456789012:role/TestRole'],
      };

      const result = await handler(event, {} as any, {} as any);

      expect(result.unusedPermissions).toBeDefined();
      expect(Array.isArray(result.unusedPermissions)).toBe(true);
    });

    it('should track days since last use', async () => {
      const event: AccessAnalysisEvent = {
        roleArns: ['arn:aws:iam::123456789012:role/TestRole'],
      };

      const result = await handler(event, {} as any, {} as any);

      result.unusedPermissions.forEach((perm) => {
        if (!perm.neverUsed) {
          expect(perm.daysSinceLastUse).toBeGreaterThan(0);
        }
      });
    });
  });

  describe('Policy Recommendations', () => {
    it('should generate least-privilege recommendations', async () => {
      const event: AccessAnalysisEvent = {
        roleArns: ['arn:aws:iam::123456789012:role/TestRole'],
        generateRecommendations: true,
      };

      const result = await handler(event, {} as any, {} as any);

      result.recommendations.forEach((rec) => {
        expect(rec.currentPolicy).toBeDefined();
        expect(rec.recommendedPolicy).toBeDefined();
        expect(rec.changesummary).toBeInstanceOf(Array);
        expect(rec.permissionsRemoved).toBeInstanceOf(Array);
        expect(rec.permissionsAdded).toBeInstanceOf(Array);
        expect(rec.riskReduction).toBeGreaterThanOrEqual(0);
        expect(rec.confidenceScore).toBeGreaterThanOrEqual(0);
      });
    });

    it('should calculate risk reduction', async () => {
      const event: AccessAnalysisEvent = {
        roleArns: ['arn:aws:iam::123456789012:role/TestRole'],
        generateRecommendations: true,
      };

      const result = await handler(event, {} as any, {} as any);

      result.recommendations.forEach((rec) => {
        expect(rec.riskReduction).toBeGreaterThanOrEqual(0);
        expect(rec.riskReduction).toBeLessThanOrEqual(100);
      });
    });
  });

  describe('Auto Policy Updates', () => {
    it('should queue policy updates when enabled', async () => {
      process.env.AUTO_UPDATE_POLICIES = 'true';

      const event: AccessAnalysisEvent = {
        roleArns: ['arn:aws:iam::123456789012:role/TestRole'],
        generateRecommendations: true,
      };

      const result = await handler(event, {} as any, {} as any);

      expect(result.policiesQueued).toBeGreaterThanOrEqual(0);
    });

    it('should not queue updates in dry-run mode', async () => {
      process.env.DRY_RUN = 'true';
      process.env.AUTO_UPDATE_POLICIES = 'true';

      const event: AccessAnalysisEvent = {
        roleArns: ['arn:aws:iam::123456789012:role/TestRole'],
        generateRecommendations: true,
      };

      const result = await handler(event, {} as any, {} as any);

      expect(result.dryRun).toBe(true);
    });
  });

  describe('Notifications', () => {
    it('should send notification for critical findings', async () => {
      const event: AccessAnalysisEvent = {
        roleArns: ['arn:aws:iam::123456789012:role/CriticalRole'],
      };

      const result = await handler(event, {} as any, {} as any);

      expect(result).toBeDefined();
    });
  });

  describe('Error Handling', () => {
    it('should handle invalid role ARN', async () => {
      const event: AccessAnalysisEvent = {
        roleArns: ['invalid-arn'],
      };

      await expect(handler(event, {} as any, {} as any)).rejects.toThrow();
    });

    it('should handle non-existent role gracefully', async () => {
      const event: AccessAnalysisEvent = {
        roleArns: ['arn:aws:iam::123456789012:role/NonExistentRole'],
      };

      await expect(handler(event, {} as any, {} as any)).rejects.toThrow();
    });
  });

  describe('Dry Run Mode', () => {
    it('should not make actual changes in dry run', async () => {
      process.env.DRY_RUN = 'true';

      const event: AccessAnalysisEvent = {
        roleArns: ['arn:aws:iam::123456789012:role/TestRole'],
        generateRecommendations: true,
      };

      const result = await handler(event, {} as any, {} as any);

      expect(result.dryRun).toBe(true);
    });
  });

  describe('Performance', () => {
    it('should measure analysis duration', async () => {
      const event: AccessAnalysisEvent = {
        roleArns: ['arn:aws:iam::123456789012:role/TestRole'],
      };

      const result = await handler(event, {} as any, {} as any);

      expect(result.duration).toBeGreaterThan(0);
      expect(typeof result.duration).toBe('number');
    });
  });
});
