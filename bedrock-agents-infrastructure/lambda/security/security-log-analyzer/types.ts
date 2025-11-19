export interface LogAnalysisEvent {
  analyzeCloudTrail?: boolean;
  detectSuspiciousAPI?: boolean;
  detectPrivilegeEscalation?: boolean;
  detectUnauthorizedAccess?: boolean;
  detectAnomalies?: boolean;
  suspiciousActions?: string[];
  baselineData?: BaselineData;
  lookbackHours?: number;
}

export interface LogAnalysisResult {
  analysisId: string;
  timestamp: string;
  timeRange: TimeRange;
  totalEvents: number;
  totalAnomalies: number;
  criticalAnomalies: number;
  highAnomalies: number;
  mediumAnomalies: number;
  lowAnomalies: number;
  anomalies: AnomalousActivity[];
  suspiciousPatterns: SuspiciousPattern[];
  duration: number;
  alertsSent: number;
}

export interface TimeRange {
  start: string;
  end: string;
  hours: number;
}

export interface SecurityEvent {
  id: string;
  timestamp: string;
  eventName: string;
  eventSource: string;
  userIdentity: UserIdentity;
  sourceIPAddress: string;
  userAgent: string;
  errorCode?: string;
  errorMessage?: string;
  requestParameters?: any;
  responseElements?: any;
  resources?: Resource[];
}

export interface UserIdentity {
  type: string;
  principalId?: string;
  arn?: string;
  accountId?: string;
  userName?: string;
  sessionContext?: any;
}

export interface Resource {
  type: string;
  arn: string;
}

export interface AnomalousActivity {
  id: string;
  type: AnomalyType;
  description: string;
  severity: 'CRITICAL' | 'HIGH' | 'MEDIUM' | 'LOW';
  timestamp: string;
  eventName: string;
  userIdentity: string;
  sourceIP: string;
  indicators: string[];
  affectedResources?: string[];
  riskScore: number;
  evidence: Evidence[];
}

export type AnomalyType =
  | 'PRIVILEGE_ESCALATION'
  | 'UNAUTHORIZED_ACCESS'
  | 'SUSPICIOUS_API_CALL'
  | 'UNUSUAL_LOCATION'
  | 'ANOMALOUS_BEHAVIOR'
  | 'DATA_EXFILTRATION'
  | 'CREDENTIAL_ACCESS'
  | 'LATERAL_MOVEMENT';

export interface Evidence {
  type: string;
  description: string;
  value: any;
  timestamp: string;
}

export interface SuspiciousPattern {
  id: string;
  pattern: string;
  description: string;
  occurrences: number;
  firstSeen: string;
  lastSeen: string;
  severity: 'CRITICAL' | 'HIGH' | 'MEDIUM' | 'LOW';
  examples: SecurityEvent[];
}

export interface BaselineData {
  normalAPICallPatterns?: Record<string, number>;
  normalSourceIPs?: string[];
  normalUserAgents?: string[];
  typicalActivityHours?: number[];
  averageAPICallsPerHour?: number;
}

export interface PrivilegeEscalationIndicators {
  iamPolicyChanges: boolean;
  roleAssumption: boolean;
  permissionBoundaryChanges: boolean;
  trustPolicyChanges: boolean;
  newUserCreation: boolean;
}

export interface UnauthorizedAccessIndicators {
  accessDeniedErrors: number;
  unusualSourceIP: boolean;
  unusualUserAgent: boolean;
  offHoursAccess: boolean;
  unexpectedGeolocation: boolean;
}

export interface LoggerContext {
  [key: string]: any;
}
