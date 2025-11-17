import {
  SecurityEvent,
  AnomalousActivity,
  SuspiciousPattern,
  BaselineData,
  Evidence,
  LoggerContext,
} from './types';

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

export async function analyzeCloudTrailLogs(
  startTime: Date,
  endTime: Date
): Promise<SecurityEvent[]> {
  // This function would integrate with CloudTrail
  // Implementation provided in index.ts
  return [];
}

export async function detectSuspiciousAPICalls(
  events: SecurityEvent[],
  customSuspiciousActions?: string[]
): Promise<SuspiciousPattern[]> {
  const patterns: SuspiciousPattern[] = [];

  // Define suspicious API calls
  const suspiciousActions = customSuspiciousActions || [
    'DeleteTrail',
    'StopLogging',
    'DeleteFlowLogs',
    'DeleteDetector',
    'DisassociateFromMasterAccount',
    'DeleteMembers',
    'UpdateTrail',
    'PutEventSelectors',
    'ConsoleLogin',
    'GetSecretValue',
    'GetPasswordData',
    'GetFederationToken',
    'AssumeRole',
    'CreateAccessKey',
    'DeleteAccessKey',
    'UpdateAccessKey',
    'AttachUserPolicy',
    'AttachRolePolicy',
    'PutUserPolicy',
    'PutRolePolicy',
    'CreateUser',
    'CreateRole',
    'UpdateAssumeRolePolicy',
  ];

  const patternMap = new Map<string, SecurityEvent[]>();

  for (const event of events) {
    if (suspiciousActions.includes(event.eventName)) {
      if (!patternMap.has(event.eventName)) {
        patternMap.set(event.eventName, []);
      }
      patternMap.get(event.eventName)!.push(event);
    }
  }

  for (const [action, matchingEvents] of patternMap.entries()) {
    if (matchingEvents.length === 0) continue;

    const severity = determineSeverity(action, matchingEvents.length);

    patterns.push({
      id: `suspicious-api-${action}-${Date.now()}`,
      pattern: action,
      description: `Detected ${matchingEvents.length} occurrences of suspicious API call: ${action}`,
      occurrences: matchingEvents.length,
      firstSeen: matchingEvents[0].timestamp,
      lastSeen: matchingEvents[matchingEvents.length - 1].timestamp,
      severity,
      examples: matchingEvents.slice(0, 5),
    });
  }

  return patterns;
}

export async function detectPrivilegeEscalation(
  events: SecurityEvent[]
): Promise<AnomalousActivity[]> {
  const anomalies: AnomalousActivity[] = [];

  // Privilege escalation indicators
  const escalationActions = [
    'PutUserPolicy',
    'PutRolePolicy',
    'AttachUserPolicy',
    'AttachRolePolicy',
    'CreateAccessKey',
    'UpdateAssumeRolePolicy',
    'CreatePolicyVersion',
    'SetDefaultPolicyVersion',
  ];

  for (const event of events) {
    if (!escalationActions.includes(event.eventName)) continue;

    const indicators: string[] = [];
    const evidence: Evidence[] = [];

    // Check for policy changes that grant admin access
    if (event.requestParameters) {
      const params = JSON.stringify(event.requestParameters);
      if (params.includes('*:*') || params.includes('AdministratorAccess')) {
        indicators.push('Grants administrator access');
        evidence.push({
          type: 'REQUEST_PARAMETERS',
          description: 'Policy grants broad permissions',
          value: event.requestParameters,
          timestamp: event.timestamp,
        });
      }
    }

    // Check for privilege escalation patterns
    if (
      event.eventName === 'AttachUserPolicy' ||
      event.eventName === 'AttachRolePolicy'
    ) {
      indicators.push('IAM policy attachment');
      evidence.push({
        type: 'IAM_CHANGE',
        description: 'Policy attached to principal',
        value: { eventName: event.eventName, parameters: event.requestParameters },
        timestamp: event.timestamp,
      });
    }

    if (indicators.length > 0) {
      anomalies.push({
        id: `priv-esc-${event.id}`,
        type: 'PRIVILEGE_ESCALATION',
        description: `Potential privilege escalation detected: ${event.eventName}`,
        severity: calculateEscalationSeverity(indicators),
        timestamp: event.timestamp,
        eventName: event.eventName,
        userIdentity: event.userIdentity.userName || event.userIdentity.principalId || 'unknown',
        sourceIP: event.sourceIPAddress,
        indicators,
        affectedResources: event.resources?.map((r) => r.arn),
        riskScore: calculateRiskScore(indicators, evidence),
        evidence,
      });
    }
  }

  return anomalies;
}

export async function detectUnauthorizedAccess(
  events: SecurityEvent[]
): Promise<AnomalousActivity[]> {
  const anomalies: AnomalousActivity[] = [];

  // Track failed access attempts
  const failedAttempts = new Map<string, SecurityEvent[]>();

  for (const event of events) {
    if (event.errorCode === 'AccessDenied' || event.errorCode === 'UnauthorizedOperation') {
      const key = `${event.userIdentity.userName}-${event.sourceIPAddress}`;

      if (!failedAttempts.has(key)) {
        failedAttempts.set(key, []);
      }
      failedAttempts.get(key)!.push(event);
    }
  }

  // Detect patterns of repeated failures
  for (const [key, attempts] of failedAttempts.entries()) {
    if (attempts.length < 5) continue; // Threshold: 5+ failed attempts

    const [userName, sourceIP] = key.split('-');

    anomalies.push({
      id: `unauth-access-${Date.now()}-${key}`,
      type: 'UNAUTHORIZED_ACCESS',
      description: `${attempts.length} unauthorized access attempts detected`,
      severity: attempts.length >= 20 ? 'CRITICAL' : attempts.length >= 10 ? 'HIGH' : 'MEDIUM',
      timestamp: attempts[attempts.length - 1].timestamp,
      eventName: 'Multiple Failed Access Attempts',
      userIdentity: userName,
      sourceIP,
      indicators: [
        `${attempts.length} failed attempts`,
        'Repeated access denials',
        'Potential brute force or reconnaissance',
      ],
      riskScore: Math.min(100, attempts.length * 5),
      evidence: attempts.slice(0, 10).map((attempt) => ({
        type: 'FAILED_ACCESS',
        description: `Failed ${attempt.eventName}`,
        value: {
          eventName: attempt.eventName,
          errorCode: attempt.errorCode,
          errorMessage: attempt.errorMessage,
        },
        timestamp: attempt.timestamp,
      })),
    });
  }

  return anomalies;
}

export async function identifyAnomalies(
  events: SecurityEvent[],
  baseline?: BaselineData
): Promise<AnomalousActivity[]> {
  const anomalies: AnomalousActivity[] = [];

  if (!baseline) {
    logger.warn('No baseline data provided, skipping anomaly detection');
    return anomalies;
  }

  // Detect unusual source IPs
  const sourceIPs = new Set(events.map((e) => e.sourceIPAddress));
  for (const ip of sourceIPs) {
    if (baseline.normalSourceIPs && !baseline.normalSourceIPs.includes(ip)) {
      const eventsFromIP = events.filter((e) => e.sourceIPAddress === ip);

      if (eventsFromIP.length >= 5) {
        anomalies.push({
          id: `unusual-ip-${ip}-${Date.now()}`,
          type: 'UNUSUAL_LOCATION',
          description: `Activity from unusual source IP: ${ip}`,
          severity: 'MEDIUM',
          timestamp: eventsFromIP[0].timestamp,
          eventName: 'Unusual Source IP',
          userIdentity: eventsFromIP[0].userIdentity.userName || 'unknown',
          sourceIP: ip,
          indicators: ['New source IP', `${eventsFromIP.length} events from this IP`],
          riskScore: 40,
          evidence: eventsFromIP.slice(0, 5).map((e) => ({
            type: 'UNUSUAL_IP',
            description: `Event from new IP: ${e.eventName}`,
            value: { eventName: e.eventName, ip },
            timestamp: e.timestamp,
          })),
        });
      }
    }
  }

  // Detect off-hours activity
  const currentHour = new Date().getHours();
  if (baseline.typicalActivityHours && !baseline.typicalActivityHours.includes(currentHour)) {
    const recentEvents = events.filter((e) => {
      const eventHour = new Date(e.timestamp).getHours();
      return eventHour === currentHour;
    });

    if (recentEvents.length >= 10) {
      anomalies.push({
        id: `off-hours-${Date.now()}`,
        type: 'ANOMALOUS_BEHAVIOR',
        description: 'Significant activity during off-hours',
        severity: 'MEDIUM',
        timestamp: new Date().toISOString(),
        eventName: 'Off-Hours Activity',
        userIdentity: 'Multiple users',
        sourceIP: 'Various',
        indicators: ['Activity during unusual hours', `Hour: ${currentHour}:00`],
        riskScore: 35,
        evidence: recentEvents.slice(0, 5).map((e) => ({
          type: 'OFF_HOURS',
          description: `Event at unusual time: ${e.eventName}`,
          value: { eventName: e.eventName, hour: currentHour },
          timestamp: e.timestamp,
        })),
      });
    }
  }

  return anomalies;
}

function determineSeverity(
  action: string,
  occurrences: number
): 'CRITICAL' | 'HIGH' | 'MEDIUM' | 'LOW' {
  const criticalActions = [
    'DeleteTrail',
    'StopLogging',
    'DeleteFlowLogs',
    'DeleteDetector',
    'DisassociateFromMasterAccount',
  ];

  if (criticalActions.includes(action)) {
    return 'CRITICAL';
  }

  if (occurrences >= 10) {
    return 'HIGH';
  }

  if (occurrences >= 5) {
    return 'MEDIUM';
  }

  return 'LOW';
}

function calculateEscalationSeverity(
  indicators: string[]
): 'CRITICAL' | 'HIGH' | 'MEDIUM' | 'LOW' {
  const adminIndicators = indicators.filter((i) => i.includes('administrator'));

  if (adminIndicators.length > 0) {
    return 'CRITICAL';
  }

  if (indicators.length >= 3) {
    return 'HIGH';
  }

  if (indicators.length >= 2) {
    return 'MEDIUM';
  }

  return 'LOW';
}

function calculateRiskScore(indicators: string[], evidence: Evidence[]): number {
  let score = 0;

  // Base score from indicators
  score += indicators.length * 15;

  // Additional score from evidence
  score += evidence.length * 10;

  // Check for high-risk indicators
  const highRiskKeywords = ['admin', 'full access', '*:*', 'root'];
  for (const indicator of indicators) {
    for (const keyword of highRiskKeywords) {
      if (indicator.toLowerCase().includes(keyword)) {
        score += 20;
      }
    }
  }

  return Math.min(100, score);
}

export function createSecurityHubFinding(
  anomaly: AnomalousActivity,
  analysisId: string,
  accountId: string,
  region: string
): any {
  const severityMapping = {
    CRITICAL: 90,
    HIGH: 70,
    MEDIUM: 40,
    LOW: 10,
  };

  return {
    SchemaVersion: '2018-10-08',
    Id: `${analysisId}/${anomaly.id}`,
    ProductArn: `arn:aws:securityhub:${region}:${accountId}:product/${accountId}/default`,
    GeneratorId: 'security-log-analyzer',
    AwsAccountId: accountId,
    Types: ['TTPs/Discovery', 'TTPs/Privilege Escalation', 'TTPs/Credential Access'],
    CreatedAt: new Date().toISOString(),
    UpdatedAt: new Date().toISOString(),
    Severity: {
      Label: anomaly.severity,
      Normalized: severityMapping[anomaly.severity],
    },
    Title: `${anomaly.type}: ${anomaly.description}`,
    Description: `${anomaly.description}\n\nIndicators:\n${anomaly.indicators.join('\n')}`,
    Resources: [
      {
        Type: 'AwsAccount',
        Id: accountId,
        Region: region,
      },
    ],
    Network: {
      SourceIpV4: anomaly.sourceIP !== 'Various' ? anomaly.sourceIP : undefined,
    },
    RecordState: 'ACTIVE',
    FindingProviderFields: {
      Severity: {
        Label: anomaly.severity,
      },
      Types: [`${anomaly.type}`],
    },
  };
}
