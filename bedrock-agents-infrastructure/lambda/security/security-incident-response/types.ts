export interface IncidentEvent {
  detectorId?: string;
  findingIds?: string[];
  source?: 'guardduty' | 'securityhub' | 'cloudtrail' | 'manual';
  eventBridge?: any;
  detail?: any;
}

export interface IncidentResponse {
  incidentId: string;
  timestamp: string;
  status: 'SUCCESS' | 'PARTIAL_SUCCESS' | 'FAILED' | 'NO_ACTION_REQUIRED';
  actionsToken: number;
  findings: FindingSummary[];
  responseTime: number;
  dryRun?: boolean;
  errors?: string[];
}

export interface FindingSummary {
  id: string;
  type: string;
  severity: 'CRITICAL' | 'HIGH' | 'MEDIUM' | 'LOW';
  resourceArn: string;
}

export interface GuardDutyFinding {
  id: string;
  type: string;
  severity: number;
  title: string;
  description: string;
  resourceArn: string;
  accountId: string;
  region: string;
  createdAt: string;
  updatedAt: string;
  confidence: number;
  service: string;
  resource?: any;
}

export interface IncidentAction {
  type:
    | 'ISOLATION'
    | 'SNAPSHOT'
    | 'NOTIFICATION'
    | 'TICKET_CREATION'
    | 'REMEDIATION'
    | 'INVESTIGATION';
  resourceArn: string;
  status: 'SUCCESS' | 'FAILED' | 'PENDING';
  timestamp: string;
  details?: string;
  metadata?: Record<string, any>;
}

export interface IsolationResult {
  success: boolean;
  message: string;
  resourceArn: string;
  isolationType?: 'NETWORK' | 'IAM' | 'SHUTDOWN' | 'QUARANTINE';
  rollbackProcedure?: string;
}

export interface SnapshotResult {
  success: boolean;
  snapshotId?: string;
  snapshotArn?: string;
  volumeId?: string;
  timestamp?: string;
}

export interface NotificationPayload {
  incidentId: string;
  finding: GuardDutyFinding;
  severity: 'CRITICAL' | 'HIGH' | 'MEDIUM' | 'LOW';
  actions: IncidentAction[];
  snsTopicArn: string;
}

export interface IncidentTicket {
  incidentId: string;
  finding: GuardDutyFinding;
  severity: 'CRITICAL' | 'HIGH' | 'MEDIUM' | 'LOW';
  actions: IncidentAction[];
  queueUrl: string;
}

export interface LoggerContext {
  [key: string]: any;
}
