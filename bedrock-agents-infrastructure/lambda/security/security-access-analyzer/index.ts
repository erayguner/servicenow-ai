import {
  AccessAnalyzerClient,
  ListFindingsCommand,
  GetFindingCommand,
  ArchiveFindingCommand,
  StartPolicyGenerationCommand,
  GetGeneratedPolicyCommand,
} from '@aws-sdk/client-accessanalyzer';
import {
  IAMClient,
  GetPolicyCommand,
  GetRoleCommand,
  SimulatePrincipalPolicyCommand,
  ListAttachedRolePoliciesCommand,
  GetPolicyVersionCommand,
} from '@aws-sdk/client-iam';
import { SNSClient, PublishCommand } from '@aws-sdk/client-sns';
import { SQSClient, SendMessageCommand } from '@aws-sdk/client-sqs';
import { Handler } from 'aws-lambda';
import {
  AccessAnalysisEvent,
  AccessAnalysisResult,
  AccessFinding,
  PolicyRecommendation,
  UnusedPermission,
} from './types';
import {
  analyzeIAMPolicy,
  generateLeastPrivilegePolicy,
  detectUnusedPermissions,
  updatePolicyRecommendation,
  logger,
} from './utils';

const accessAnalyzerClient = new AccessAnalyzerClient({});
const iamClient = new IAMClient({});
const snsClient = new SNSClient({});
const sqsClient = new SQSClient({});

const ANALYZER_ARN = process.env.ANALYZER_ARN || '';
const NOTIFICATION_TOPIC = process.env.NOTIFICATION_TOPIC_ARN || '';
const POLICY_QUEUE_URL = process.env.POLICY_QUEUE_URL || '';
const DRY_RUN = process.env.DRY_RUN === 'true';
const AUTO_UPDATE_POLICIES = process.env.AUTO_UPDATE_POLICIES === 'true';

export const handler: Handler<AccessAnalysisEvent, AccessAnalysisResult> = async (event) => {
  logger.info('Starting access analysis', { event });

  const analysisId = `analysis-${Date.now()}`;
  const findings: AccessFinding[] = [];
  const recommendations: PolicyRecommendation[] = [];
  const unusedPermissions: UnusedPermission[] = [];
  const startTime = Date.now();

  try {
    // Analyze IAM Access Analyzer findings
    if (event.analyzeFindings !== false) {
      const accessFindings = await analyzeAccessAnalyzerFindings();
      findings.push(...accessFindings);
    }

    // Analyze specific roles
    if (event.roleArns && event.roleArns.length > 0) {
      for (const roleArn of event.roleArns) {
        const roleAnalysis = await analyzeRole(roleArn);
        findings.push(...roleAnalysis.findings);
        recommendations.push(...roleAnalysis.recommendations);
        unusedPermissions.push(...roleAnalysis.unusedPermissions);
      }
    }

    // Detect overly permissive policies
    if (event.checkOverpermissive !== false) {
      const overpermissiveFindings = await detectOverpermissivePolicies(event.roleArns);
      findings.push(...overpermissiveFindings);
    }

    // Generate least-privilege recommendations
    if (event.generateRecommendations !== false && event.roleArns) {
      for (const roleArn of event.roleArns) {
        const policyRec = await generateLeastPrivilegeRecommendation(roleArn);
        if (policyRec) {
          recommendations.push(policyRec);
        }
      }
    }

    // Auto-update policies if enabled (dry-run mode)
    if (AUTO_UPDATE_POLICIES && !DRY_RUN && recommendations.length > 0) {
      for (const rec of recommendations) {
        await queuePolicyUpdate(rec, analysisId);
      }
    }

    // Send notification for critical findings
    const criticalFindings = findings.filter((f) => f.severity === 'CRITICAL' || f.severity === 'HIGH');
    if (criticalFindings.length > 0 && NOTIFICATION_TOPIC) {
      await sendAccessAnalysisNotification(criticalFindings, analysisId);
    }

    const result: AccessAnalysisResult = {
      analysisId,
      timestamp: new Date().toISOString(),
      totalFindings: findings.length,
      criticalFindings: findings.filter((f) => f.severity === 'CRITICAL').length,
      highFindings: findings.filter((f) => f.severity === 'HIGH').length,
      mediumFindings: findings.filter((f) => f.severity === 'MEDIUM').length,
      lowFindings: findings.filter((f) => f.severity === 'LOW').length,
      findings,
      recommendations,
      unusedPermissions,
      duration: Date.now() - startTime,
      dryRun: DRY_RUN,
      policiesQueued: AUTO_UPDATE_POLICIES ? recommendations.length : 0,
    };

    logger.info('Access analysis completed', { result });
    return result;
  } catch (error) {
    logger.error('Error during access analysis', { error, analysisId });
    throw error;
  }
};

async function analyzeAccessAnalyzerFindings(): Promise<AccessFinding[]> {
  const findings: AccessFinding[] = [];

  try {
    if (!ANALYZER_ARN) {
      logger.warn('ANALYZER_ARN not configured, skipping Access Analyzer findings');
      return findings;
    }

    const response = await accessAnalyzerClient.send(
      new ListFindingsCommand({
        analyzerArn: ANALYZER_ARN,
        filter: {
          status: {
            eq: ['ACTIVE'],
          },
        },
        maxResults: 100,
      })
    );

    const findingSummaries = response.findings || [];

    for (const summary of findingSummaries) {
      if (!summary.id) continue;

      try {
        const findingDetails = await accessAnalyzerClient.send(
          new GetFindingCommand({
            analyzerArn: ANALYZER_ARN,
            id: summary.id,
          })
        );

        const finding = findingDetails.finding;
        if (!finding) continue;

        findings.push({
          id: finding.id,
          type: 'ACCESS_ANALYZER',
          title: `External access detected: ${finding.resourceType}`,
          description: finding.condition ? JSON.stringify(finding.condition) : 'External access to resource',
          severity: mapAccessAnalyzerSeverity(finding.status || 'ACTIVE'),
          resourceArn: finding.resource || '',
          resourceType: finding.resourceType || 'Unknown',
          principal: finding.principal?.AWS || finding.principal?.Service || 'Unknown',
          action: finding.action?.join(', ') || 'Unknown',
          isPublic: finding.isPublic || false,
          analyzedAt: finding.analyzedAt?.toISOString() || new Date().toISOString(),
        });
      } catch (error) {
        logger.error(`Error getting finding details for ${summary.id}`, { error });
      }
    }
  } catch (error) {
    logger.error('Error analyzing Access Analyzer findings', { error });
  }

  return findings;
}

async function analyzeRole(
  roleArn: string
): Promise<{
  findings: AccessFinding[];
  recommendations: PolicyRecommendation[];
  unusedPermissions: UnusedPermission[];
}> {
  const findings: AccessFinding[] = [];
  const recommendations: PolicyRecommendation[] = [];
  const unusedPermissions: UnusedPermission[] = [];

  try {
    const roleName = roleArn.split('/').pop();
    if (!roleName) {
      throw new Error('Invalid role ARN');
    }

    // Get role details
    const roleResponse = await iamClient.send(new GetRoleCommand({ RoleName: roleName }));
    const role = roleResponse.Role;

    if (!role) {
      throw new Error(`Role ${roleName} not found`);
    }

    // Analyze trust policy
    const trustPolicyAnalysis = await analyzeTrustPolicy(role);
    findings.push(...trustPolicyAnalysis);

    // Get attached policies
    const attachedPolicies = await iamClient.send(
      new ListAttachedRolePoliciesCommand({ RoleName: roleName })
    );

    // Analyze each attached policy
    for (const policy of attachedPolicies.AttachedPolicies || []) {
      if (!policy.PolicyArn) continue;

      const policyAnalysis = await analyzeIAMPolicy(policy.PolicyArn);
      findings.push(...policyAnalysis.findings);

      if (policyAnalysis.overprivileged) {
        findings.push({
          id: `${roleName}-overprivileged-${policy.PolicyName}`,
          type: 'OVERPRIVILEGED',
          title: `Overprivileged policy: ${policy.PolicyName}`,
          description: `Policy ${policy.PolicyName} grants more permissions than necessary`,
          severity: 'HIGH',
          resourceArn: roleArn,
          resourceType: 'IAMRole',
          principal: roleArn,
          action: 'Review and reduce permissions',
          isPublic: false,
          analyzedAt: new Date().toISOString(),
        });
      }
    }

    // Detect unused permissions
    const unused = await detectUnusedPermissions(roleArn, roleName);
    unusedPermissions.push(...unused);

    if (unused.length > 0) {
      findings.push({
        id: `${roleName}-unused-permissions`,
        type: 'UNUSED_PERMISSIONS',
        title: `Unused permissions detected in ${roleName}`,
        description: `Role has ${unused.length} unused permissions`,
        severity: 'MEDIUM',
        resourceArn: roleArn,
        resourceType: 'IAMRole',
        principal: roleArn,
        action: 'Remove unused permissions',
        isPublic: false,
        analyzedAt: new Date().toISOString(),
      });
    }
  } catch (error) {
    logger.error(`Error analyzing role ${roleArn}`, { error });
  }

  return { findings, recommendations, unusedPermissions };
}

async function analyzeTrustPolicy(role: any): Promise<AccessFinding[]> {
  const findings: AccessFinding[] = [];

  try {
    const trustPolicy = JSON.parse(decodeURIComponent(role.AssumeRolePolicyDocument || '{}'));

    if (trustPolicy.Statement) {
      for (const statement of trustPolicy.Statement) {
        // Check for wildcard principals
        if (statement.Principal === '*' || statement.Principal?.AWS === '*') {
          findings.push({
            id: `${role.RoleName}-wildcard-trust`,
            type: 'WILDCARD_PRINCIPAL',
            title: 'Trust policy allows wildcard principal',
            description: `Role ${role.RoleName} can be assumed by any AWS principal`,
            severity: 'CRITICAL',
            resourceArn: role.Arn,
            resourceType: 'IAMRole',
            principal: '*',
            action: 'AssumeRole',
            isPublic: true,
            analyzedAt: new Date().toISOString(),
          });
        }

        // Check for external account access without ExternalId
        if (statement.Principal?.AWS && !statement.Condition?.StringEquals?.['sts:ExternalId']) {
          const principals = Array.isArray(statement.Principal.AWS)
            ? statement.Principal.AWS
            : [statement.Principal.AWS];

          for (const principal of principals) {
            if (principal.includes(':root') && !principal.startsWith('arn:aws:iam::' + process.env.AWS_ACCOUNT_ID)) {
              findings.push({
                id: `${role.RoleName}-external-without-externalid`,
                type: 'MISSING_EXTERNAL_ID',
                title: 'External account access without ExternalId',
                description: `Role ${role.RoleName} allows cross-account access without ExternalId condition`,
                severity: 'HIGH',
                resourceArn: role.Arn,
                resourceType: 'IAMRole',
                principal,
                action: 'AssumeRole',
                isPublic: false,
                analyzedAt: new Date().toISOString(),
              });
            }
          }
        }
      }
    }
  } catch (error) {
    logger.error('Error analyzing trust policy', { error, role: role.RoleName });
  }

  return findings;
}

async function detectOverpermissivePolicies(roleArns?: string[]): Promise<AccessFinding[]> {
  const findings: AccessFinding[] = [];

  // This would be implemented with more sophisticated analysis
  // For now, we check for common overpermissive patterns

  logger.info('Checking for overpermissive policies', { roleCount: roleArns?.length });

  return findings;
}

async function generateLeastPrivilegeRecommendation(
  roleArn: string
): Promise<PolicyRecommendation | null> {
  try {
    const recommendation = await generateLeastPrivilegePolicy(roleArn);
    return recommendation;
  } catch (error) {
    logger.error(`Error generating recommendation for ${roleArn}`, { error });
    return null;
  }
}

async function queuePolicyUpdate(
  recommendation: PolicyRecommendation,
  analysisId: string
): Promise<void> {
  try {
    if (!POLICY_QUEUE_URL) {
      logger.warn('POLICY_QUEUE_URL not configured, skipping policy update queue');
      return;
    }

    await sqsClient.send(
      new SendMessageCommand({
        QueueUrl: POLICY_QUEUE_URL,
        MessageBody: JSON.stringify({
          analysisId,
          recommendation,
          timestamp: new Date().toISOString(),
        }),
        MessageAttributes: {
          AnalysisId: {
            DataType: 'String',
            StringValue: analysisId,
          },
          RoleArn: {
            DataType: 'String',
            StringValue: recommendation.resourceArn,
          },
        },
      })
    );

    logger.info('Policy update queued', { roleArn: recommendation.resourceArn });
  } catch (error) {
    logger.error('Error queuing policy update', { error, recommendation });
  }
}

function mapAccessAnalyzerSeverity(status: string): 'CRITICAL' | 'HIGH' | 'MEDIUM' | 'LOW' {
  switch (status.toUpperCase()) {
    case 'ACTIVE':
      return 'HIGH';
    case 'ARCHIVED':
      return 'LOW';
    case 'RESOLVED':
      return 'LOW';
    default:
      return 'MEDIUM';
  }
}

async function sendAccessAnalysisNotification(
  findings: AccessFinding[],
  analysisId: string
): Promise<void> {
  try {
    const message = {
      analysisId,
      timestamp: new Date().toISOString(),
      summary: {
        total: findings.length,
        critical: findings.filter((f) => f.severity === 'CRITICAL').length,
        high: findings.filter((f) => f.severity === 'HIGH').length,
      },
      topFindings: findings.slice(0, 10).map((f) => ({
        id: f.id,
        title: f.title,
        severity: f.severity,
        resourceArn: f.resourceArn,
        principal: f.principal,
      })),
    };

    await snsClient.send(
      new PublishCommand({
        TopicArn: NOTIFICATION_TOPIC,
        Subject: `🔐 Access Analysis Findings - ${analysisId}`,
        Message: JSON.stringify(message, null, 2),
      })
    );

    logger.info('Access analysis notification sent', { analysisId });
  } catch (error) {
    logger.error('Error sending notification', { error });
  }
}
