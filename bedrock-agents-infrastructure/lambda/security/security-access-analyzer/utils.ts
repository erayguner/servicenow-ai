import {
  IAMClient,
  GetPolicyCommand,
  GetPolicyVersionCommand,
  SimulatePrincipalPolicyCommand,
  GetServiceLastAccessedDetailsCommand,
  GenerateServiceLastAccessedDetailsCommand,
} from '@aws-sdk/client-iam';
import {
  AccessAnalyzerClient,
  StartPolicyGenerationCommand,
  GetGeneratedPolicyCommand,
} from '@aws-sdk/client-accessanalyzer';
import {
  PolicyAnalysis,
  PolicyRecommendation,
  UnusedPermission,
  AccessFinding,
  PolicyDocument,
  LoggerContext,
} from './types';

const iamClient = new IAMClient({});
const accessAnalyzerClient = new AccessAnalyzerClient({});

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

export async function analyzeIAMPolicy(policyArn: string): Promise<PolicyAnalysis> {
  const analysis: PolicyAnalysis = {
    policyArn,
    policyName: policyArn.split('/').pop() || 'unknown',
    overprivileged: false,
    wildcardActions: [],
    wildcardResources: [],
    findings: [],
    riskScore: 0,
  };

  try {
    // Get policy details
    const policyResponse = await iamClient.send(
      new GetPolicyCommand({ PolicyArn: policyArn })
    );

    const policy = policyResponse.Policy;
    if (!policy || !policy.DefaultVersionId) {
      return analysis;
    }

    // Get policy version (actual policy document)
    const versionResponse = await iamClient.send(
      new GetPolicyVersionCommand({
        PolicyArn: policyArn,
        VersionId: policy.DefaultVersionId,
      })
    );

    const policyDocument = versionResponse.PolicyVersion?.Document;
    if (!policyDocument) {
      return analysis;
    }

    const parsedPolicy = JSON.parse(decodeURIComponent(policyDocument));

    // Analyze statements
    for (const statement of parsedPolicy.Statement || []) {
      if (statement.Effect !== 'Allow') continue;

      // Check for wildcard actions
      const actions = Array.isArray(statement.Action) ? statement.Action : [statement.Action];
      for (const action of actions) {
        if (action === '*' || action.includes('*')) {
          analysis.wildcardActions.push(action);
          analysis.overprivileged = true;
        }
      }

      // Check for wildcard resources
      const resources = Array.isArray(statement.Resource)
        ? statement.Resource
        : [statement.Resource];
      for (const resource of resources) {
        if (resource === '*') {
          analysis.wildcardResources.push(resource);
          analysis.overprivileged = true;
        }
      }

      // Check for dangerous action combinations
      const dangerousActions = ['iam:*', 's3:*', 'ec2:*', '*:*'];
      for (const action of actions) {
        if (dangerousActions.includes(action)) {
          analysis.findings.push({
            id: `${policyArn}-dangerous-action-${action}`,
            type: 'OVERPRIVILEGED',
            title: `Dangerous action in policy: ${action}`,
            description: `Policy contains overly permissive action: ${action}`,
            severity: action === '*:*' ? 'CRITICAL' : 'HIGH',
            resourceArn: policyArn,
            resourceType: 'IAMPolicy',
            principal: 'N/A',
            action,
            isPublic: false,
            analyzedAt: new Date().toISOString(),
          });
        }
      }
    }

    // Calculate risk score
    analysis.riskScore = calculatePolicyRiskScore(analysis);
  } catch (error) {
    logger.error(`Error analyzing policy ${policyArn}`, { error });
  }

  return analysis;
}

function calculatePolicyRiskScore(analysis: PolicyAnalysis): number {
  let score = 0;

  // Wildcard actions
  score += analysis.wildcardActions.length * 20;

  // Wildcard resources
  score += analysis.wildcardResources.length * 15;

  // Findings
  score += analysis.findings.filter((f) => f.severity === 'CRITICAL').length * 30;
  score += analysis.findings.filter((f) => f.severity === 'HIGH').length * 20;
  score += analysis.findings.filter((f) => f.severity === 'MEDIUM').length * 10;

  return Math.min(score, 100);
}

export async function detectUnusedPermissions(
  roleArn: string,
  roleName: string
): Promise<UnusedPermission[]> {
  const unusedPermissions: UnusedPermission[] = [];

  try {
    // Generate service last accessed details
    const generateResponse = await iamClient.send(
      new GenerateServiceLastAccessedDetailsCommand({
        Arn: roleArn,
      })
    );

    const jobId = generateResponse.JobId;
    if (!jobId) {
      logger.warn('Failed to generate service last accessed details');
      return unusedPermissions;
    }

    // Wait a bit for the job to complete (in production, use polling)
    await new Promise((resolve) => setTimeout(resolve, 2000));

    // Get the details
    const detailsResponse = await iamClient.send(
      new GetServiceLastAccessedDetailsCommand({
        JobId: jobId,
      })
    );

    const services = detailsResponse.ServicesLastAccessed || [];

    for (const service of services) {
      if (!service.ServiceName) continue;

      const daysSinceLastUse = service.LastAuthenticated
        ? Math.floor(
            (Date.now() - new Date(service.LastAuthenticated).getTime()) / (1000 * 60 * 60 * 24)
          )
        : undefined;

      // Consider unused if not accessed in 90+ days or never accessed
      if (!service.LastAuthenticated || (daysSinceLastUse && daysSinceLastUse > 90)) {
        unusedPermissions.push({
          roleArn,
          roleName,
          permission: `${service.ServiceNamespace}:*`,
          service: service.ServiceName,
          lastUsed: service.LastAuthenticated?.toISOString(),
          neverUsed: !service.LastAuthenticated,
          daysSinceLastUse,
        });
      }
    }
  } catch (error) {
    logger.error(`Error detecting unused permissions for ${roleArn}`, { error });
  }

  return unusedPermissions;
}

export async function generateLeastPrivilegePolicy(
  roleArn: string
): Promise<PolicyRecommendation | null> {
  try {
    // In production, you would use IAM Access Analyzer policy generation
    // This requires CloudTrail data and can take time to generate

    // For now, we'll create a mock recommendation based on analysis
    const currentPolicy = await getCurrentRolePolicy(roleArn);
    if (!currentPolicy) {
      return null;
    }

    // Simulate policy generation
    // In production: use AccessAnalyzerClient.StartPolicyGenerationCommand
    // and poll with GetGeneratedPolicyCommand

    const recommendedPolicy = await createLeastPrivilegePolicy(currentPolicy);

    const changesummary = generateChangeSummary(currentPolicy, recommendedPolicy);
    const { removed, added } = comparePermissions(currentPolicy, recommendedPolicy);

    return {
      id: `policy-rec-${Date.now()}`,
      resourceArn: roleArn,
      resourceType: 'IAMRole',
      currentPolicy,
      recommendedPolicy,
      changesummary,
      permissionsRemoved: removed,
      permissionsAdded: added,
      riskReduction: calculateRiskReduction(removed, added),
      confidenceScore: 85, // This would be calculated based on CloudTrail data
    };
  } catch (error) {
    logger.error(`Error generating least-privilege policy for ${roleArn}`, { error });
    return null;
  }
}

async function getCurrentRolePolicy(roleArn: string): Promise<PolicyDocument | null> {
  try {
    // This is a simplified version
    // In production, you'd get all attached and inline policies

    return {
      Version: '2012-10-17',
      Statement: [
        {
          Effect: 'Allow',
          Action: ['s3:*', 'dynamodb:*'],
          Resource: '*',
        },
      ],
    };
  } catch (error) {
    logger.error(`Error getting current policy for ${roleArn}`, { error });
    return null;
  }
}

async function createLeastPrivilegePolicy(
  currentPolicy: PolicyDocument
): Promise<PolicyDocument> {
  // This is a mock implementation
  // In production, use IAM Access Analyzer's policy generation based on CloudTrail

  const optimizedStatements = currentPolicy.Statement.map((statement) => {
    const optimized = { ...statement };

    // Replace wildcards with specific actions (mock)
    if (Array.isArray(optimized.Action)) {
      optimized.Action = optimized.Action.map((action) => {
        if (action.includes('*')) {
          // In production, this would be based on actual usage
          return action.replace(/\*/g, 'GetObject'); // Example - replaces all occurrences
        }
        return action;
      });
    }

    // Replace wildcard resources with specific resources (mock)
    if (optimized.Resource === '*') {
      optimized.Resource = 'arn:aws:s3:::specific-bucket/*'; // Example
    }

    return optimized;
  });

  return {
    Version: '2012-10-17',
    Statement: optimizedStatements,
  };
}

function generateChangeSummary(
  current: PolicyDocument,
  recommended: PolicyDocument
): string[] {
  const summary: string[] = [];

  // Count wildcard reductions
  const currentWildcards = countWildcards(current);
  const recommendedWildcards = countWildcards(recommended);

  if (currentWildcards.actions > recommendedWildcards.actions) {
    summary.push(
      `Reduced wildcard actions from ${currentWildcards.actions} to ${recommendedWildcards.actions}`
    );
  }

  if (currentWildcards.resources > recommendedWildcards.resources) {
    summary.push(
      `Reduced wildcard resources from ${currentWildcards.resources} to ${recommendedWildcards.resources}`
    );
  }

  // Statement count changes
  if (current.Statement.length !== recommended.Statement.length) {
    summary.push(`Statements changed from ${current.Statement.length} to ${recommended.Statement.length}`);
  }

  return summary;
}

function countWildcards(policy: PolicyDocument): { actions: number; resources: number } {
  let actions = 0;
  let resources = 0;

  for (const statement of policy.Statement) {
    const actionList = Array.isArray(statement.Action) ? statement.Action : [statement.Action];
    actions += actionList.filter((a) => a.includes('*')).length;

    const resourceList = Array.isArray(statement.Resource)
      ? statement.Resource
      : [statement.Resource];
    resources += resourceList.filter((r) => r === '*').length;
  }

  return { actions, resources };
}

function comparePermissions(
  current: PolicyDocument,
  recommended: PolicyDocument
): { removed: string[]; added: string[] } {
  const currentPerms = extractPermissions(current);
  const recommendedPerms = extractPermissions(recommended);

  const removed = currentPerms.filter((p) => !recommendedPerms.includes(p));
  const added = recommendedPerms.filter((p) => !currentPerms.includes(p));

  return { removed, added };
}

function extractPermissions(policy: PolicyDocument): string[] {
  const permissions: string[] = [];

  for (const statement of policy.Statement) {
    if (statement.Effect !== 'Allow') continue;

    const actions = Array.isArray(statement.Action) ? statement.Action : [statement.Action];
    permissions.push(...actions);
  }

  return permissions;
}

function calculateRiskReduction(removed: string[], added: string[]): number {
  // Calculate risk reduction percentage
  const removedWildcards = removed.filter((p) => p.includes('*')).length;
  const addedWildcards = added.filter((p) => p.includes('*')).length;

  const wildcardReduction = removedWildcards - addedWildcards;
  const totalReduction = removed.length - added.length;

  // Weight wildcard reduction higher
  const riskReduction = (wildcardReduction * 20 + totalReduction * 5);

  return Math.max(0, Math.min(100, riskReduction));
}

export async function updatePolicyRecommendation(
  recommendation: PolicyRecommendation,
  dryRun: boolean
): Promise<boolean> {
  try {
    if (dryRun) {
      logger.info('Dry run mode: would update policy', {
        roleArn: recommendation.resourceArn,
      });
      return true;
    }

    // In production, you would:
    // 1. Create a new policy version
    // 2. Test with IAM policy simulator
    // 3. Apply the policy
    // 4. Monitor for errors
    // 5. Rollback if needed

    logger.info('Policy update would be applied', {
      roleArn: recommendation.resourceArn,
      removedCount: recommendation.permissionsRemoved.length,
      addedCount: recommendation.permissionsAdded.length,
    });

    return true;
  } catch (error) {
    logger.error('Error updating policy', { error, recommendation });
    return false;
  }
}
