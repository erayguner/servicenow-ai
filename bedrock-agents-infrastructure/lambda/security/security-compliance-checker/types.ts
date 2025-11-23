export interface ComplianceCheckEvent {
  targetRoles?: string[];
  resourceArns?: string[];
  checkTypes?: ('bedrock' | 'iam' | 'secrets' | 'encryption')[];
  severity?: 'CRITICAL' | 'HIGH' | 'MEDIUM' | 'LOW';
}

export interface ComplianceCheckResult {
  checkId: string;
  timestamp: string;
  totalFindings: number;
  criticalFindings: number;
  highFindings: number;
  mediumFindings: number;
  lowFindings: number;
  findings: ComplianceFinding[];
  complianceStatus: 'PASSED' | 'FAILED';
}

export interface ComplianceFinding {
  id: string;
  title: string;
  description: string;
  severity: 'CRITICAL' | 'HIGH' | 'MEDIUM' | 'LOW' | 'INFORMATIONAL';
  resourceArn: string;
  resourceType: string;
  complianceStatus: 'PASSED' | 'FAILED' | 'WARNING';
  remediationSteps: string[];
  metadata?: Record<string, any>;
}

export interface EncryptionCheckResult {
  encrypted: boolean;
  keyType?: 'AWS_MANAGED' | 'CUSTOMER_MANAGED';
  keyId?: string;
  keyArn?: string;
  findings: ComplianceFinding[];
}

export interface IAMPolicyCheckResult {
  policyCompliant: boolean;
  findings: ComplianceFinding[];
  overprivilegedActions?: string[];
  unusedPermissions?: string[];
}

export interface SecretScanResult {
  secretsFound: boolean;
  exposedSecrets: ExposedSecret[];
  findings: ComplianceFinding[];
}

export interface ExposedSecret {
  type: 'api_key' | 'password' | 'token' | 'certificate' | 'unknown';
  location: string;
  severity: 'CRITICAL' | 'HIGH' | 'MEDIUM';
  masked: string;
}

export interface LoggerContext {
  [key: string]: any;
}
