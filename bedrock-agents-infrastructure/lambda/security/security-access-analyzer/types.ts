export interface AccessAnalysisEvent {
  roleArns?: string[];
  analyzeFindings?: boolean;
  checkOverpermissive?: boolean;
  generateRecommendations?: boolean;
  autoArchive?: boolean;
}

export interface AccessAnalysisResult {
  analysisId: string;
  timestamp: string;
  totalFindings: number;
  criticalFindings: number;
  highFindings: number;
  mediumFindings: number;
  lowFindings: number;
  findings: AccessFinding[];
  recommendations: PolicyRecommendation[];
  unusedPermissions: UnusedPermission[];
  duration: number;
  dryRun?: boolean;
  policiesQueued?: number;
}

export interface AccessFinding {
  id: string;
  type: FindingType;
  title: string;
  description: string;
  severity: 'CRITICAL' | 'HIGH' | 'MEDIUM' | 'LOW';
  resourceArn: string;
  resourceType: string;
  principal: string;
  action: string;
  isPublic: boolean;
  analyzedAt: string;
  condition?: Record<string, any>;
  metadata?: Record<string, any>;
}

export type FindingType =
  | 'ACCESS_ANALYZER'
  | 'OVERPRIVILEGED'
  | 'UNUSED_PERMISSIONS'
  | 'WILDCARD_PRINCIPAL'
  | 'MISSING_EXTERNAL_ID'
  | 'PUBLIC_ACCESS'
  | 'CROSS_ACCOUNT';

export interface PolicyRecommendation {
  id: string;
  resourceArn: string;
  resourceType: 'IAMRole' | 'IAMPolicy' | 'IAMUser';
  currentPolicy: PolicyDocument;
  recommendedPolicy: PolicyDocument;
  changesummary: string[];
  permissionsRemoved: string[];
  permissionsAdded: string[];
  riskReduction: number;
  confidenceScore: number;
}

export interface PolicyDocument {
  Version: string;
  Statement: PolicyStatement[];
}

export interface PolicyStatement {
  Sid?: string;
  Effect: 'Allow' | 'Deny';
  Principal?: string | { [key: string]: string | string[] };
  Action: string | string[];
  Resource: string | string[];
  Condition?: Record<string, any>;
}

export interface UnusedPermission {
  roleArn: string;
  roleName: string;
  permission: string;
  service: string;
  lastUsed?: string;
  neverUsed: boolean;
  daysSinceLastUse?: number;
}

export interface PolicyAnalysis {
  policyArn: string;
  policyName: string;
  overprivileged: boolean;
  wildcardActions: string[];
  wildcardResources: string[];
  findings: AccessFinding[];
  riskScore: number;
}

export interface TrustPolicyAnalysis {
  roleArn: string;
  hasWildcardPrincipal: boolean;
  hasCrossAccountAccess: boolean;
  hasExternalId: boolean;
  principals: string[];
  findings: AccessFinding[];
}

export interface PermissionUsage {
  service: string;
  action: string;
  lastUsed?: string;
  accessedResources?: string[];
  frequency: number;
}

export interface LeastPrivilegeAnalysis {
  roleArn: string;
  currentPermissions: string[];
  usedPermissions: string[];
  unusedPermissions: string[];
  recommendedPolicy: PolicyDocument;
  reductionPercentage: number;
}

export interface LoggerContext {
  [key: string]: any;
}
