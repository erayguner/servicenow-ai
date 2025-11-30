import { CloudTrailClient, LookupEventsCommand } from '@aws-sdk/client-cloudtrail';
import { SNSClient, PublishCommand } from '@aws-sdk/client-sns';
import { SecurityHubClient, BatchImportFindingsCommand } from '@aws-sdk/client-securityhub';
import { Handler } from 'aws-lambda';
import {
  LogAnalysisEvent,
  LogAnalysisResult,
  SecurityEvent,
  AnomalousActivity,
  SuspiciousPattern,
} from './types';
import {
  detectSuspiciousAPICalls,
  detectPrivilegeEscalation,
  detectUnauthorizedAccess,
  identifyAnomalies,
  createSecurityHubFinding,
  logger,
} from './utils';

const cloudtrailClient = new CloudTrailClient({});
const snsClient = new SNSClient({});
const securityHubClient = new SecurityHubClient({});

const NOTIFICATION_TOPIC = process.env.NOTIFICATION_TOPIC_ARN || '';
const SECURITY_HUB_ENABLED = process.env.SECURITY_HUB_ENABLED !== 'false';
const LOOKBACK_HOURS = parseInt(process.env.LOOKBACK_HOURS || '24', 10);
const ALERT_THRESHOLD = process.env.ALERT_THRESHOLD || 'MEDIUM';

export const handler: Handler<LogAnalysisEvent, LogAnalysisResult> = async (event) => {
  logger.info('Starting security log analysis', { event });

  const analysisId = `log-analysis-${Date.now()}`;
  const securityEvents: SecurityEvent[] = [];
  const anomalies: AnomalousActivity[] = [];
  const suspiciousPatterns: SuspiciousPattern[] = [];
  const startTime = Date.now();

  try {
    const endTime = new Date();
    const startTimeDate = new Date(endTime.getTime() - LOOKBACK_HOURS * 60 * 60 * 1000);

    // Analyze CloudTrail logs
    if (event.analyzeCloudTrail !== false) {
      const cloudtrailEvents = await analyzeCloudTrailEvents(startTimeDate, endTime);
      securityEvents.push(...cloudtrailEvents);
    }

    // Detect suspicious API calls
    if (event.detectSuspiciousAPI !== false) {
      const suspiciousAPIs = await detectSuspiciousAPICalls(
        securityEvents,
        event.suspiciousActions
      );
      suspiciousPatterns.push(...suspiciousAPIs);
    }

    // Detect privilege escalation attempts
    if (event.detectPrivilegeEscalation !== false) {
      const escalations = await detectPrivilegeEscalation(securityEvents);
      anomalies.push(...escalations);
    }

    // Detect unauthorized access attempts
    if (event.detectUnauthorizedAccess !== false) {
      const unauthorized = await detectUnauthorizedAccess(securityEvents);
      anomalies.push(...unauthorized);
    }

    // Identify anomalous behavior
    if (event.detectAnomalies !== false) {
      const detectedAnomalies = await identifyAnomalies(securityEvents, event.baselineData);
      anomalies.push(...detectedAnomalies);
    }

    // Filter by severity threshold
    const filteredAnomalies = filterBySeverity(anomalies, ALERT_THRESHOLD);

    // Report to Security Hub
    if (SECURITY_HUB_ENABLED && filteredAnomalies.length > 0) {
      await reportToSecurityHub(filteredAnomalies, analysisId);
    }

    // Send alerts for critical anomalies
    const criticalAnomalies = filteredAnomalies.filter(
      (a) => a.severity === 'CRITICAL' || a.severity === 'HIGH'
    );

    if (criticalAnomalies.length > 0 && NOTIFICATION_TOPIC) {
      await sendSecurityAlert(criticalAnomalies, analysisId);
    }

    const result: LogAnalysisResult = {
      analysisId,
      timestamp: new Date().toISOString(),
      timeRange: {
        start: startTimeDate.toISOString(),
        end: endTime.toISOString(),
        hours: LOOKBACK_HOURS,
      },
      totalEvents: securityEvents.length,
      totalAnomalies: filteredAnomalies.length,
      criticalAnomalies: filteredAnomalies.filter((a) => a.severity === 'CRITICAL').length,
      highAnomalies: filteredAnomalies.filter((a) => a.severity === 'HIGH').length,
      mediumAnomalies: filteredAnomalies.filter((a) => a.severity === 'MEDIUM').length,
      lowAnomalies: filteredAnomalies.filter((a) => a.severity === 'LOW').length,
      anomalies: filteredAnomalies,
      suspiciousPatterns,
      duration: Date.now() - startTime,
      alertsSent: criticalAnomalies.length,
    };

    logger.info('Security log analysis completed', { result });
    return result;
  } catch (error) {
    logger.error('Error during log analysis', { error, analysisId });
    throw error;
  }
};

async function analyzeCloudTrailEvents(startTime: Date, endTime: Date): Promise<SecurityEvent[]> {
  const events: SecurityEvent[] = [];

  try {
    const response = await cloudtrailClient.send(
      new LookupEventsCommand({
        StartTime: startTime,
        EndTime: endTime,
        MaxResults: 50,
      })
    );

    const cloudtrailEvents = response.Events || [];

    for (const event of cloudtrailEvents) {
      if (!event.EventName || !event.EventTime) continue;

      const securityEvent: SecurityEvent = {
        id: event.EventId || `event-${Date.now()}`,
        timestamp: event.EventTime.toISOString(),
        eventName: event.EventName,
        eventSource: event.EventSource || 'unknown',
        userIdentity: parseUserIdentity(event.Username),
        sourceIPAddress: event.CloudTrailEvent
          ? JSON.parse(event.CloudTrailEvent).sourceIPAddress
          : 'unknown',
        userAgent: event.CloudTrailEvent ? JSON.parse(event.CloudTrailEvent).userAgent : 'unknown',
        errorCode: event.CloudTrailEvent ? JSON.parse(event.CloudTrailEvent).errorCode : undefined,
        errorMessage: event.CloudTrailEvent
          ? JSON.parse(event.CloudTrailEvent).errorMessage
          : undefined,
        requestParameters: event.CloudTrailEvent
          ? JSON.parse(event.CloudTrailEvent).requestParameters
          : undefined,
        responseElements: event.CloudTrailEvent
          ? JSON.parse(event.CloudTrailEvent).responseElements
          : undefined,
        resources: event.Resources?.map((r) => ({
          type: r.ResourceType || 'unknown',
          arn: r.ResourceName || 'unknown',
        })),
      };

      events.push(securityEvent);
    }
  } catch (error) {
    logger.error('Error analyzing CloudTrail events', { error });
  }

  return events;
}

function parseUserIdentity(username?: string): any {
  if (!username) {
    return { type: 'Unknown' };
  }

  return {
    type: username.includes('assumed-role') ? 'AssumedRole' : 'IAMUser',
    principalId: username,
    userName: username,
  };
}

function filterBySeverity(anomalies: AnomalousActivity[], threshold: string): AnomalousActivity[] {
  const severityOrder = ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'];
  const thresholdIndex = severityOrder.indexOf(threshold);

  if (thresholdIndex === -1) {
    return anomalies;
  }

  return anomalies.filter((anomaly) => {
    const anomalyIndex = severityOrder.indexOf(anomaly.severity);
    return anomalyIndex >= thresholdIndex;
  });
}

async function reportToSecurityHub(
  anomalies: AnomalousActivity[],
  analysisId: string
): Promise<void> {
  try {
    const accountId = process.env.AWS_ACCOUNT_ID || '';
    const region = process.env.AWS_REGION || 'us-east-1';

    const findings = anomalies.map((anomaly) =>
      createSecurityHubFinding(anomaly, analysisId, accountId, region)
    );

    // Security Hub accepts max 100 findings per batch
    const batches = [];
    for (let i = 0; i < findings.length; i += 100) {
      batches.push(findings.slice(i, i + 100));
    }

    for (const batch of batches) {
      await securityHubClient.send(
        new BatchImportFindingsCommand({
          Findings: batch,
        })
      );
    }

    logger.info(`Reported ${findings.length} findings to Security Hub`);
  } catch (error) {
    logger.error('Error reporting to Security Hub', { error });
  }
}

async function sendSecurityAlert(
  anomalies: AnomalousActivity[],
  analysisId: string
): Promise<void> {
  try {
    const criticalCount = anomalies.filter((a) => a.severity === 'CRITICAL').length;
    const highCount = anomalies.filter((a) => a.severity === 'HIGH').length;

    const message = {
      analysisId,
      timestamp: new Date().toISOString(),
      summary: {
        total: anomalies.length,
        critical: criticalCount,
        high: highCount,
      },
      topAnomalies: anomalies.slice(0, 10).map((a) => ({
        id: a.id,
        type: a.type,
        description: a.description,
        severity: a.severity,
        sourceIP: a.sourceIP,
        userIdentity: a.userIdentity,
      })),
      actionRequired: criticalCount > 0 ? 'IMMEDIATE' : 'REVIEW',
    };

    await snsClient.send(
      new PublishCommand({
        TopicArn: NOTIFICATION_TOPIC,
        Subject: `🚨 Security Anomalies Detected - ${analysisId}`,
        Message: JSON.stringify(message, null, 2),
      })
    );

    logger.info('Security alert sent', { analysisId, anomalyCount: anomalies.length });
  } catch (error) {
    logger.error('Error sending security alert', { error });
  }
}
