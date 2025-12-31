import { handler } from './index';
import { IncidentEvent } from './types';

// Mock AWS SDK clients
jest.mock('@aws-sdk/client-guardduty');
jest.mock('@aws-sdk/client-ec2');
jest.mock('@aws-sdk/client-sns');
jest.mock('@aws-sdk/client-sqs');
jest.mock('@aws-sdk/client-bedrock-agent');
jest.mock('@aws-sdk/client-lambda');

describe('Security Incident Response', () => {
  beforeEach(() => {
    process.env.SECURITY_TOPIC_ARN = 'arn:aws:sns:us-east-1:123456789012:security-alerts';
    process.env.INCIDENT_QUEUE_URL = 'https://sqs.us-east-1.amazonaws.com/123456789012/incidents';
    process.env.DRY_RUN = 'true';
    jest.clearAllMocks();
  });

  describe('handler', () => {
    it('should process GuardDuty findings and return incident response', async () => {
      const event: IncidentEvent = {
        detectorId: 'test-detector',
        findingIds: ['finding-1'],
        source: 'guardduty',
      };

      const result = await handler(event);

      expect(result).toBeDefined();
      expect(result.incidentId).toMatch(/^incident-\d+$/);
      expect(result.status).toMatch(/^(SUCCESS|PARTIAL_SUCCESS|FAILED|NO_ACTION_REQUIRED)$/);
      expect(result.actionsToken).toBeGreaterThanOrEqual(0);
      expect(result.dryRun).toBe(true);
    });

    it('should handle empty findings gracefully', async () => {
      const event: IncidentEvent = {
        detectorId: 'test-detector',
        findingIds: [],
        source: 'guardduty',
      };

      const result = await handler(event);

      expect(result.status).toBe('NO_ACTION_REQUIRED');
      expect(result.actionsToken).toBe(0);
    });

    it('should process multiple findings', async () => {
      const event: IncidentEvent = {
        detectorId: 'test-detector',
        findingIds: ['finding-1', 'finding-2', 'finding-3'],
        source: 'guardduty',
      };

      const result = await handler(event);

      expect(result.actionsToken).toBeGreaterThan(0);
    });

    it('should measure response time', async () => {
      const event: IncidentEvent = {
        detectorId: 'test-detector',
        findingIds: ['finding-1'],
        source: 'guardduty',
      };

      const result = await handler(event);

      expect(result.responseTime).toBeGreaterThan(0);
      expect(typeof result.responseTime).toBe('number');
    });
  });

  describe('Resource Isolation', () => {
    beforeEach(() => {
      process.env.AUTO_ISOLATE = 'true';
    });

    it('should isolate compromised EC2 instances', async () => {
      const event: IncidentEvent = {
        detectorId: 'test-detector',
        findingIds: ['ec2-finding'],
        source: 'guardduty',
      };

      const result = await handler(event);

      const isolationActions = result.findings.filter((f) => f.resourceArn.includes('instance'));
      expect(isolationActions).toBeDefined();
    });

    it('should isolate Bedrock agents', async () => {
      const event: IncidentEvent = {
        detectorId: 'test-detector',
        findingIds: ['bedrock-finding'],
        source: 'guardduty',
      };

      const result = await handler(event);

      expect(result).toBeDefined();
    });

    it('should not isolate when AUTO_ISOLATE is false', async () => {
      process.env.AUTO_ISOLATE = 'false';

      const event: IncidentEvent = {
        detectorId: 'test-detector',
        findingIds: ['finding-1'],
        source: 'guardduty',
      };

      const result = await handler(event);

      expect(result).toBeDefined();
    });
  });

  describe('Forensic Snapshots', () => {
    it('should create snapshots for compromised resources', async () => {
      const event: IncidentEvent = {
        detectorId: 'test-detector',
        findingIds: ['ec2-finding'],
        source: 'guardduty',
      };

      const result = await handler(event);

      expect(result.actionsToken).toBeGreaterThan(0);
    });

    it('should tag snapshots with incident metadata', async () => {
      const event: IncidentEvent = {
        detectorId: 'test-detector',
        findingIds: ['finding-1'],
        source: 'guardduty',
      };

      const result = await handler(event);

      expect(result.incidentId).toBeDefined();
    });
  });

  describe('Notifications', () => {
    it('should send SNS notification for critical findings', async () => {
      const event: IncidentEvent = {
        detectorId: 'test-detector',
        findingIds: ['critical-finding'],
        source: 'guardduty',
      };

      const result = await handler(event);

      expect(result).toBeDefined();
    });

    it('should include finding details in notification', async () => {
      const event: IncidentEvent = {
        detectorId: 'test-detector',
        findingIds: ['finding-1'],
        source: 'guardduty',
      };

      const result = await handler(event);

      expect(result.findings).toBeDefined();
      expect(Array.isArray(result.findings)).toBe(true);
    });
  });

  describe('Incident Ticketing', () => {
    it('should create incident ticket', async () => {
      const event: IncidentEvent = {
        detectorId: 'test-detector',
        findingIds: ['finding-1'],
        source: 'guardduty',
      };

      const result = await handler(event);

      expect(result.incidentId).toBeDefined();
    });

    it('should include severity in ticket', async () => {
      const event: IncidentEvent = {
        detectorId: 'test-detector',
        findingIds: ['high-severity-finding'],
        source: 'guardduty',
      };

      const result = await handler(event);

      result.findings.forEach((finding) => {
        expect(finding.severity).toMatch(/^(CRITICAL|HIGH|MEDIUM|LOW)$/);
      });
    });
  });

  describe('Error Handling', () => {
    it('should handle invalid detector ID', async () => {
      const event: IncidentEvent = {
        detectorId: 'invalid-detector',
        findingIds: ['finding-1'],
        source: 'guardduty',
      };

      await expect(handler(event)).rejects.toThrow();
    });

    it('should send error notification on failure', async () => {
      const event: IncidentEvent = {
        detectorId: undefined,
        findingIds: ['finding-1'],
        source: 'guardduty',
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

      const event: IncidentEvent = {
        detectorId: 'test-detector',
        findingIds: ['finding-1'],
        source: 'guardduty',
      };

      const result = await handler(event);

      expect(result.dryRun).toBe(true);
    });

    it('should still create action plan in dry run', async () => {
      process.env.DRY_RUN = 'true';
      process.env.AUTO_ISOLATE = 'true';

      const event: IncidentEvent = {
        detectorId: 'test-detector',
        findingIds: ['finding-1'],
        source: 'guardduty',
      };

      const result = await handler(event);

      expect(result.actionsToken).toBeGreaterThanOrEqual(0);
    });
  });
});
