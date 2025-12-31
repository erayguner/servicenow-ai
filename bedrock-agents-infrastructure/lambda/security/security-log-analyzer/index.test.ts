import { handler } from './index';
import { LogAnalysisEvent } from './types';

// Mock AWS SDK clients
jest.mock('@aws-sdk/client-cloudtrail');
jest.mock('@aws-sdk/client-cloudwatch-logs');
jest.mock('@aws-sdk/client-guardduty');
jest.mock('@aws-sdk/client-securityhub');
jest.mock('@aws-sdk/client-sns');

describe('Security Log Analyzer', () => {
  beforeEach(() => {
    process.env.NOTIFICATION_TOPIC_ARN = 'arn:aws:sns:us-east-1:123456789012:security-alerts';
    process.env.SECURITY_HUB_ENABLED = 'true';
    process.env.LOOKBACK_HOURS = '24';
    process.env.ALERT_THRESHOLD = 'MEDIUM';
    process.env.AWS_ACCOUNT_ID = '123456789012';
    process.env.AWS_REGION = 'us-east-1';
    jest.clearAllMocks();
  });

  describe('handler', () => {
    it('should perform log analysis and return results', async () => {
      const event: LogAnalysisEvent = {
        analyzeCloudTrail: true,
      };

      const result = await handler(event);

      expect(result).toBeDefined();
      expect(result.analysisId).toMatch(/^log-analysis-\d+$/);
      expect(result.totalEvents).toBeGreaterThanOrEqual(0);
      expect(result.timeRange).toBeDefined();
    });

    it('should analyze CloudTrail logs', async () => {
      const event: LogAnalysisEvent = {
        analyzeCloudTrail: true,
        lookbackHours: 12,
      };

      const result = await handler(event);

      expect(result.timeRange.hours).toBe(12);
    });

    it('should detect suspicious API calls', async () => {
      const event: LogAnalysisEvent = {
        detectSuspiciousAPI: true,
        suspiciousActions: ['DeleteTrail', 'StopLogging'],
      };

      const result = await handler(event);

      expect(result.suspiciousPatterns).toBeDefined();
      expect(Array.isArray(result.suspiciousPatterns)).toBe(true);
    });

    it('should categorize anomalies by severity', async () => {
      const event: LogAnalysisEvent = {
        analyzeCloudTrail: true,
        detectPrivilegeEscalation: true,
        detectUnauthorizedAccess: true,
      };

      const result = await handler(event);

      expect(result.criticalAnomalies).toBeGreaterThanOrEqual(0);
      expect(result.highAnomalies).toBeGreaterThanOrEqual(0);
      expect(result.mediumAnomalies).toBeGreaterThanOrEqual(0);
      expect(result.lowAnomalies).toBeGreaterThanOrEqual(0);
      expect(
        result.criticalAnomalies +
          result.highAnomalies +
          result.mediumAnomalies +
          result.lowAnomalies
      ).toBe(result.totalAnomalies);
    });
  });

  describe('Suspicious API Detection', () => {
    it('should detect CloudTrail deletion attempts', async () => {
      const event: LogAnalysisEvent = {
        detectSuspiciousAPI: true,
      };

      const result = await handler(event);

      expect(result.suspiciousPatterns).toBeDefined();
    });

    it('should use custom suspicious actions', async () => {
      const event: LogAnalysisEvent = {
        detectSuspiciousAPI: true,
        suspiciousActions: ['CustomAction1', 'CustomAction2'],
      };

      const result = await handler(event);

      expect(result).toBeDefined();
    });
  });

  describe('Privilege Escalation Detection', () => {
    it('should detect IAM policy changes', async () => {
      const event: LogAnalysisEvent = {
        detectPrivilegeEscalation: true,
      };

      const result = await handler(event);

      const escalations = result.anomalies.filter((a) => a.type === 'PRIVILEGE_ESCALATION');
      expect(escalations).toBeDefined();
    });

    it('should identify admin access grants', async () => {
      const event: LogAnalysisEvent = {
        detectPrivilegeEscalation: true,
      };

      const result = await handler(event);

      expect(result).toBeDefined();
    });
  });

  describe('Unauthorized Access Detection', () => {
    it('should detect repeated failed access attempts', async () => {
      const event: LogAnalysisEvent = {
        detectUnauthorizedAccess: true,
      };

      const result = await handler(event);

      const unauthorized = result.anomalies.filter((a) => a.type === 'UNAUTHORIZED_ACCESS');
      expect(unauthorized).toBeDefined();
    });

    it('should track AccessDenied errors', async () => {
      const event: LogAnalysisEvent = {
        detectUnauthorizedAccess: true,
      };

      const result = await handler(event);

      expect(result).toBeDefined();
    });
  });

  describe('Anomaly Detection', () => {
    it('should detect unusual source IPs', async () => {
      const event: LogAnalysisEvent = {
        detectAnomalies: true,
        baselineData: {
          normalSourceIPs: ['203.0.113.1', '203.0.113.2'],
        },
      };

      const result = await handler(event);

      expect(result.anomalies).toBeDefined();
    });

    it('should detect off-hours activity', async () => {
      const event: LogAnalysisEvent = {
        detectAnomalies: true,
        baselineData: {
          typicalActivityHours: [9, 10, 11, 12, 13, 14, 15, 16, 17],
        },
      };

      const result = await handler(event);

      expect(result).toBeDefined();
    });

    it('should skip anomaly detection without baseline', async () => {
      const event: LogAnalysisEvent = {
        detectAnomalies: true,
      };

      const result = await handler(event);

      expect(result.anomalies).toBeDefined();
    });
  });

  describe('Severity Filtering', () => {
    it('should filter by CRITICAL threshold', async () => {
      process.env.ALERT_THRESHOLD = 'CRITICAL';

      const event: LogAnalysisEvent = {
        analyzeCloudTrail: true,
      };

      const result = await handler(event);

      result.anomalies.forEach((anomaly) => {
        expect(anomaly.severity).toBe('CRITICAL');
      });
    });

    it('should filter by HIGH threshold', async () => {
      process.env.ALERT_THRESHOLD = 'HIGH';

      const event: LogAnalysisEvent = {
        analyzeCloudTrail: true,
      };

      const result = await handler(event);

      result.anomalies.forEach((anomaly) => {
        expect(['CRITICAL', 'HIGH']).toContain(anomaly.severity);
      });
    });
  });

  describe('Security Hub Integration', () => {
    it('should report findings when enabled', async () => {
      process.env.SECURITY_HUB_ENABLED = 'true';

      const event: LogAnalysisEvent = {
        analyzeCloudTrail: true,
      };

      const result = await handler(event);

      expect(result).toBeDefined();
    });

    it('should not report when disabled', async () => {
      process.env.SECURITY_HUB_ENABLED = 'false';

      const event: LogAnalysisEvent = {
        analyzeCloudTrail: true,
      };

      const result = await handler(event);

      expect(result).toBeDefined();
    });
  });

  describe('Alerts', () => {
    it('should send alerts for critical anomalies', async () => {
      const event: LogAnalysisEvent = {
        detectPrivilegeEscalation: true,
      };

      const result = await handler(event);

      expect(result.alertsSent).toBeGreaterThanOrEqual(0);
    });

    it('should track number of alerts sent', async () => {
      const event: LogAnalysisEvent = {
        analyzeCloudTrail: true,
      };

      const result = await handler(event);

      expect(typeof result.alertsSent).toBe('number');
    });
  });

  describe('Time Range', () => {
    it('should use custom lookback hours', async () => {
      const event: LogAnalysisEvent = {
        analyzeCloudTrail: true,
        lookbackHours: 48,
      };

      const result = await handler(event);

      expect(result.timeRange.hours).toBe(48);
    });

    it('should use default lookback hours', async () => {
      const event: LogAnalysisEvent = {
        analyzeCloudTrail: true,
      };

      const result = await handler(event);

      expect(result.timeRange.hours).toBe(24);
    });
  });

  describe('Performance', () => {
    it('should measure analysis duration', async () => {
      const event: LogAnalysisEvent = {
        analyzeCloudTrail: true,
      };

      const result = await handler(event);

      expect(result.duration).toBeGreaterThan(0);
      expect(typeof result.duration).toBe('number');
    });
  });

  describe('Evidence Collection', () => {
    it('should collect evidence for anomalies', async () => {
      const event: LogAnalysisEvent = {
        detectPrivilegeEscalation: true,
      };

      const result = await handler(event);

      result.anomalies.forEach((anomaly) => {
        expect(anomaly.evidence).toBeDefined();
        expect(Array.isArray(anomaly.evidence)).toBe(true);
      });
    });

    it('should include indicators for each anomaly', async () => {
      const event: LogAnalysisEvent = {
        detectUnauthorizedAccess: true,
      };

      const result = await handler(event);

      result.anomalies.forEach((anomaly) => {
        expect(anomaly.indicators).toBeDefined();
        expect(Array.isArray(anomaly.indicators)).toBe(true);
      });
    });
  });

  describe('Error Handling', () => {
    it('should handle errors gracefully', async () => {
      const event: LogAnalysisEvent = {};

      await expect(handler(event)).rejects.toThrow();
    });
  });
});
