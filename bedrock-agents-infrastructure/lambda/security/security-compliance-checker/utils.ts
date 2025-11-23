import { KMSClient, DescribeKeyCommand } from '@aws-sdk/client-kms';
import { IAMClient, SimulatePrincipalPolicyCommand } from '@aws-sdk/client-iam';
import {
  ComplianceFinding,
  EncryptionCheckResult,
  LoggerContext,
  IAMPolicyCheckResult,
} from './types';

const kmsClient = new KMSClient({});
const iamClient = new IAMClient({});

export const logger = {
  info: (message: string, context?: LoggerContext) => {
    console.log(JSON.stringify({ level: 'INFO', message, ...context, timestamp: new Date().toISOString() }));
  },
  warn: (message: string, context?: LoggerContext) => {
    console.warn(JSON.stringify({ level: 'WARN', message, ...context, timestamp: new Date().toISOString() }));
  },
  error: (message: string, context?: LoggerContext) => {
    console.error(JSON.stringify({ level: 'ERROR', message, ...context, timestamp: new Date().toISOString() }));
  },
};

export async function checkEncryption(resourceArn: string): Promise<ComplianceFinding[]> {
  const findings: ComplianceFinding[] = [];

  try {
    // Extract KMS key ID from ARN if present
    const keyIdMatch = resourceArn.match(/key\/([a-f0-9-]+)/);
    if (!keyIdMatch) {
      findings.push({
        id: `${resourceArn}-no-kms-key`,
        title: 'Resource not encrypted with KMS',
        description: `Resource ${resourceArn} does not appear to use KMS encryption`,
        severity: 'HIGH',
        resourceArn,
        resourceType: 'Unknown',
        complianceStatus: 'FAILED',
        remediationSteps: [
          'Enable encryption using a customer-managed KMS key',
          'Configure appropriate key policies',
          'Enable key rotation',
        ],
      });
      return findings;
    }

    const keyId = keyIdMatch[1];
    const keyDetails = await kmsClient.send(new DescribeKeyCommand({ KeyId: keyId }));

    if (keyDetails.KeyMetadata) {
      const keyMetadata = keyDetails.KeyMetadata;

      // Check if key rotation is enabled
      if (!keyMetadata.KeyManager || keyMetadata.KeyManager === 'AWS') {
        findings.push({
          id: `${resourceArn}-aws-managed-key`,
          title: 'Resource using AWS-managed KMS key',
          description: `Resource is encrypted with AWS-managed key instead of customer-managed key`,
          severity: 'MEDIUM',
          resourceArn,
          resourceType: 'KMSKey',
          complianceStatus: 'FAILED',
          remediationSteps: [
            'Create a customer-managed KMS key',
            'Update resource to use the customer-managed key',
            'Enable automatic key rotation',
          ],
        });
      }

      // Check key state
      if (keyMetadata.KeyState !== 'Enabled') {
        findings.push({
          id: `${resourceArn}-key-disabled`,
          title: 'KMS key is not enabled',
          description: `KMS key ${keyId} is in state: ${keyMetadata.KeyState}`,
          severity: 'CRITICAL',
          resourceArn: keyMetadata.Arn || resourceArn,
          resourceType: 'KMSKey',
          complianceStatus: 'FAILED',
          remediationSteps: [
            'Enable the KMS key',
            'Verify resource can access the key',
            'Update IAM policies if needed',
          ],
        });
      }
    }
  } catch (error) {
    logger.error('Error checking encryption', { error, resourceArn });
  }

  return findings;
}

export async function checkIAMPolicy(
  roleArn: string,
  resourceType: string
): Promise<ComplianceFinding[]> {
  const findings: ComplianceFinding[] = [];

  try {
    // Define dangerous actions to check for
    const dangerousActions = [
      's3:*',
      'iam:*',
      'dynamodb:*',
      'bedrock:*',
      '*:*',
      'kms:Decrypt',
      'secretsmanager:GetSecretValue',
    ];

    // Check for overly permissive actions
    const roleName = roleArn.split('/').pop();
    if (!roleName) return findings;

    // Simulate policy to check permissions
    for (const action of dangerousActions) {
      try {
        const result = await iamClient.send(
          new SimulatePrincipalPolicyCommand({
            PolicySourceArn: roleArn,
            ActionNames: [action],
          })
        );

        if (result.EvaluationResults) {
          for (const evaluation of result.EvaluationResults) {
            if (evaluation.EvalDecision === 'allowed') {
              findings.push({
                id: `${roleName}-overprivileged-${action}`,
                title: 'IAM role has overly permissive action',
                description: `Role ${roleName} has permission for dangerous action: ${action}`,
                severity: action.includes('*:*') ? 'CRITICAL' : 'HIGH',
                resourceArn: roleArn,
                resourceType,
                complianceStatus: 'FAILED',
                remediationSteps: [
                  'Review IAM policy and remove wildcard permissions',
                  'Implement principle of least privilege',
                  'Use specific actions instead of wildcards',
                  'Regularly audit IAM policies',
                ],
                metadata: {
                  action,
                  evalDecision: evaluation.EvalDecision,
                },
              });
            }
          }
        }
      } catch (error) {
        // Policy simulation might fail for various reasons, continue checking
        logger.warn(`Could not simulate policy for action ${action}`, { error, roleArn });
      }
    }
  } catch (error) {
    logger.error('Error checking IAM policy', { error, roleArn });
  }

  return findings;
}

export async function scanForSecrets(content: string, source: string): Promise<ComplianceFinding[]> {
  const findings: ComplianceFinding[] = [];

  // Regex patterns for common secrets
  const patterns = [
    {
      name: 'AWS Access Key',
      pattern: /AKIA[0-9A-Z]{16}/g,
      severity: 'CRITICAL' as const,
    },
    {
      name: 'AWS Secret Key',
      pattern: /[0-9a-zA-Z/+]{40}/g,
      severity: 'CRITICAL' as const,
    },
    {
      name: 'Generic API Key',
      pattern: /api[_-]?key[_-]?=?['\"]?[0-9a-zA-Z]{32,}/gi,
      severity: 'HIGH' as const,
    },
    {
      name: 'Password in Code',
      pattern: /password[_-]?=?['\"]?[^\s'\"]{8,}/gi,
      severity: 'HIGH' as const,
    },
    {
      name: 'Private Key',
      pattern: /-----BEGIN (?:RSA |EC )?PRIVATE KEY-----/g,
      severity: 'CRITICAL' as const,
    },
    {
      name: 'JWT Token',
      pattern: /eyJ[a-zA-Z0-9_-]*\.eyJ[a-zA-Z0-9_-]*\.[a-zA-Z0-9_-]*/g,
      severity: 'HIGH' as const,
    },
  ];

  for (const { name, pattern, severity } of patterns) {
    const matches = content.match(pattern);
    if (matches) {
      for (const match of matches) {
        findings.push({
          id: `secret-exposed-${source}-${name.replace(/\s/g, '-').toLowerCase()}`,
          title: `Exposed ${name} detected`,
          description: `Found potential ${name} in ${source}`,
          severity,
          resourceArn: source,
          resourceType: 'Code',
          complianceStatus: 'FAILED',
          remediationSteps: [
            'Remove hardcoded secrets from code',
            'Store secrets in AWS Secrets Manager',
            'Update code to retrieve secrets at runtime',
            'Rotate the exposed credentials immediately',
            'Review git history and remove secrets',
          ],
          metadata: {
            secretType: name,
            maskedValue: `${match.substring(0, 4)}****${match.substring(match.length - 4)}`,
          },
        });
      }
    }
  }

  return findings;
}

export function createSecurityHubFinding(
  finding: ComplianceFinding,
  accountId: string,
  region: string
): any {
  const severityMapping = {
    CRITICAL: 90,
    HIGH: 70,
    MEDIUM: 40,
    LOW: 10,
    INFORMATIONAL: 0,
  };

  return {
    SchemaVersion: '2018-10-08',
    Id: finding.id,
    ProductArn: `arn:aws:securityhub:${region}:${accountId}:product/${accountId}/default`,
    GeneratorId: 'security-compliance-checker',
    AwsAccountId: accountId,
    Types: ['Software and Configuration Checks/AWS Security Best Practices'],
    CreatedAt: new Date().toISOString(),
    UpdatedAt: new Date().toISOString(),
    Severity: {
      Label: finding.severity,
      Normalized: severityMapping[finding.severity],
    },
    Title: finding.title,
    Description: finding.description,
    Resources: [
      {
        Type: finding.resourceType,
        Id: finding.resourceArn,
        Region: region,
      },
    ],
    Compliance: {
      Status: finding.complianceStatus,
    },
    Remediation: {
      Recommendation: {
        Text: finding.remediationSteps.join('; '),
      },
    },
  };
}

export function maskSensitiveData(data: string): string {
  if (!data || data.length < 8) return '****';
  return `${data.substring(0, 4)}****${data.substring(data.length - 4)}`;
}
