import {
  BedrockAgentClient,
  GetAgentCommand,
  ListAgentsCommand,
} from '@aws-sdk/client-bedrock-agent';
import { IAMClient, GetPolicyCommand, GetRoleCommand } from '@aws-sdk/client-iam';
import { KMSClient, DescribeKeyCommand } from '@aws-sdk/client-kms';
import {
  SecurityHubClient,
  BatchImportFindingsCommand,
} from '@aws-sdk/client-securityhub';
import { SecretsManagerClient, ListSecretsCommand } from '@aws-sdk/client-secrets-manager';
import { Handler } from 'aws-lambda';
import { ComplianceCheckEvent, ComplianceCheckResult, ComplianceFinding } from './types';
import {
  checkEncryption,
  checkIAMPolicy,
  scanForSecrets,
  createSecurityHubFinding,
  logger,
} from './utils';

const bedrockClient = new BedrockAgentClient({});
const iamClient = new IAMClient({});
const kmsClient = new KMSClient({});
const securityHubClient = new SecurityHubClient({});
const secretsClient = new SecretsManagerClient({});

export const handler: Handler<ComplianceCheckEvent, ComplianceCheckResult> = async (event) => {
  logger.info('Starting security compliance check', { event });

  const findings: ComplianceFinding[] = [];
  const accountId = process.env.AWS_ACCOUNT_ID || '';
  const region = process.env.AWS_REGION || 'us-east-1';

  try {
    // Check Bedrock agent configurations
    const agentFindings = await checkBedrockAgents(accountId, region);
    findings.push(...agentFindings);

    // Validate IAM policies
    const iamFindings = await checkIAMPolicies(event.targetRoles || []);
    findings.push(...iamFindings);

    // Scan for exposed secrets
    const secretFindings = await checkSecretsExposure(accountId, region);
    findings.push(...secretFindings);

    // Check encryption settings
    const encryptionFindings = await checkEncryptionSettings(event.resourceArns || []);
    findings.push(...encryptionFindings);

    // Report findings to Security Hub
    if (findings.length > 0) {
      await reportToSecurityHub(findings, accountId, region);
    }

    const result: ComplianceCheckResult = {
      checkId: `compliance-check-${Date.now()}`,
      timestamp: new Date().toISOString(),
      totalFindings: findings.length,
      criticalFindings: findings.filter((f) => f.severity === 'CRITICAL').length,
      highFindings: findings.filter((f) => f.severity === 'HIGH').length,
      mediumFindings: findings.filter((f) => f.severity === 'MEDIUM').length,
      lowFindings: findings.filter((f) => f.severity === 'LOW').length,
      findings,
      complianceStatus: findings.some((f) => f.severity === 'CRITICAL') ? 'FAILED' : 'PASSED',
    };

    logger.info('Compliance check completed', { result });
    return result;
  } catch (error) {
    logger.error('Error during compliance check', { error });
    throw error;
  }
};

async function checkBedrockAgents(
  accountId: string,
  region: string
): Promise<ComplianceFinding[]> {
  const findings: ComplianceFinding[] = [];

  try {
    const listResponse = await bedrockClient.send(new ListAgentsCommand({}));
    const agents = listResponse.agentSummaries || [];

    for (const agentSummary of agents) {
      if (!agentSummary.agentId) continue;

      try {
        const agentDetails = await bedrockClient.send(
          new GetAgentCommand({ agentId: agentSummary.agentId })
        );

        const agent = agentDetails.agent;
        if (!agent) continue;

        // Check for encryption
        if (!agent.customerEncryptionKeyArn) {
          findings.push({
            id: `bedrock-agent-${agent.agentId}-no-cmk`,
            title: 'Bedrock Agent not using customer-managed encryption',
            description: `Agent ${agent.agentName} is not configured with a customer-managed KMS key`,
            severity: 'HIGH',
            resourceArn: agent.agentArn || '',
            resourceType: 'BedrockAgent',
            complianceStatus: 'FAILED',
            remediationSteps: [
              'Configure a customer-managed KMS key for the Bedrock agent',
              'Update agent configuration to use the CMK',
              'Ensure proper key policies are in place',
            ],
          });
        }

        // Check IAM role
        if (agent.agentResourceRoleArn) {
          const roleFindings = await checkIAMPolicy(agent.agentResourceRoleArn, 'BedrockAgent');
          findings.push(...roleFindings);
        }
      } catch (error) {
        logger.error(`Error checking agent ${agentSummary.agentId}`, { error });
      }
    }
  } catch (error) {
    logger.error('Error listing Bedrock agents', { error });
  }

  return findings;
}

async function checkIAMPolicies(targetRoles: string[]): Promise<ComplianceFinding[]> {
  const findings: ComplianceFinding[] = [];

  for (const roleArn of targetRoles) {
    try {
      const roleName = roleArn.split('/').pop();
      if (!roleName) continue;

      const roleResponse = await iamClient.send(new GetRoleCommand({ RoleName: roleName }));
      const role = roleResponse.Role;

      if (!role) continue;

      // Check for overly permissive policies
      const assumeRolePolicy = JSON.parse(
        decodeURIComponent(role.AssumeRolePolicyDocument || '{}')
      );

      if (assumeRolePolicy.Statement) {
        for (const statement of assumeRolePolicy.Statement) {
          if (statement.Principal === '*' || statement.Principal?.AWS === '*') {
            findings.push({
              id: `iam-role-${roleName}-wildcard-principal`,
              title: 'IAM Role allows wildcard principal',
              description: `Role ${roleName} has a trust policy allowing any principal`,
              severity: 'CRITICAL',
              resourceArn: role.Arn,
              resourceType: 'IAMRole',
              complianceStatus: 'FAILED',
              remediationSteps: [
                'Update the trust policy to specify explicit principals',
                'Remove wildcard (*) from Principal field',
                'Implement principle of least privilege',
              ],
            });
          }
        }
      }
    } catch (error) {
      logger.error(`Error checking IAM role ${roleArn}`, { error });
    }
  }

  return findings;
}

async function checkSecretsExposure(
  accountId: string,
  region: string
): Promise<ComplianceFinding[]> {
  const findings: ComplianceFinding[] = [];

  try {
    const secretsResponse = await secretsClient.send(new ListSecretsCommand({}));
    const secrets = secretsResponse.SecretList || [];

    for (const secret of secrets) {
      if (!secret.ARN || !secret.Name) continue;

      // Check if secret has rotation enabled
      if (!secret.RotationEnabled) {
        findings.push({
          id: `secret-${secret.Name}-no-rotation`,
          title: 'Secret rotation not enabled',
          description: `Secret ${secret.Name} does not have automatic rotation enabled`,
          severity: 'MEDIUM',
          resourceArn: secret.ARN,
          resourceType: 'Secret',
          complianceStatus: 'FAILED',
          remediationSteps: [
            'Enable automatic rotation for the secret',
            'Configure rotation Lambda function',
            'Set appropriate rotation schedule',
          ],
        });
      }

      // Check if secret has KMS encryption
      if (!secret.KmsKeyId) {
        findings.push({
          id: `secret-${secret.Name}-no-cmk`,
          title: 'Secret not using customer-managed encryption',
          description: `Secret ${secret.Name} is using AWS-managed encryption key`,
          severity: 'MEDIUM',
          resourceArn: secret.ARN,
          resourceType: 'Secret',
          complianceStatus: 'FAILED',
          remediationSteps: [
            'Create a customer-managed KMS key',
            'Update secret to use the CMK',
            'Ensure proper key policies and rotation',
          ],
        });
      }
    }
  } catch (error) {
    logger.error('Error checking secrets', { error });
  }

  return findings;
}

async function checkEncryptionSettings(resourceArns: string[]): Promise<ComplianceFinding[]> {
  const findings: ComplianceFinding[] = [];

  for (const arn of resourceArns) {
    try {
      const encryptionFindings = await checkEncryption(arn);
      findings.push(...encryptionFindings);
    } catch (error) {
      logger.error(`Error checking encryption for ${arn}`, { error });
    }
  }

  return findings;
}

async function reportToSecurityHub(
  findings: ComplianceFinding[],
  accountId: string,
  region: string
): Promise<void> {
  try {
    const securityHubFindings = findings.map((finding) =>
      createSecurityHubFinding(finding, accountId, region)
    );

    // Security Hub accepts max 100 findings per batch
    const batches = [];
    for (let i = 0; i < securityHubFindings.length; i += 100) {
      batches.push(securityHubFindings.slice(i, i + 100));
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
    throw error;
  }
}
