import {
  GuardDutyClient,
  GetFindingsCommand,
  ArchiveFindingsCommand,
} from '@aws-sdk/client-guardduty';
import {
  EC2Client,
  CreateSnapshotCommand,
  StopInstancesCommand,
  CreateTagsCommand,
  ModifyInstanceAttributeCommand,
} from '@aws-sdk/client-ec2';
import { SNSClient, PublishCommand } from '@aws-sdk/client-sns';
import {
  BedrockAgentClient,
  UpdateAgentCommand,
  GetAgentCommand,
} from '@aws-sdk/client-bedrock-agent';
import {
  LambdaClient,
  UpdateFunctionConfigurationCommand,
  GetFunctionConfigurationCommand,
} from '@aws-sdk/client-lambda';
import { Handler } from 'aws-lambda';
import {
  IncidentEvent,
  IncidentResponse,
  IncidentAction,
  GuardDutyFinding,
  IsolationResult,
} from './types';
import {
  createIncidentTicket,
  notifySecurityTeam,
  isolateResource,
  snapshotResource,
  logger,
  assessSeverity,
} from './utils';

const guarddutyClient = new GuardDutyClient({});
const ec2Client = new EC2Client({});
const snsClient = new SNSClient({});
const bedrockClient = new BedrockAgentClient({});
const lambdaClient = new LambdaClient({});

const SECURITY_TOPIC_ARN = process.env.SECURITY_TOPIC_ARN || '';
const INCIDENT_QUEUE_URL = process.env.INCIDENT_QUEUE_URL || '';
const AUTO_ISOLATE = process.env.AUTO_ISOLATE === 'true';
const DRY_RUN = process.env.DRY_RUN === 'true';

export const handler: Handler<IncidentEvent, IncidentResponse> = async (event) => {
  logger.info('Security incident response triggered', { event });

  const incidentId = `incident-${Date.now()}`;
  const actions: IncidentAction[] = [];
  const startTime = Date.now();

  try {
    // Parse GuardDuty findings
    const findings = await parseGuardDutyFindings(event);

    if (!findings || findings.length === 0) {
      logger.warn('No findings to process');
      return {
        incidentId,
        timestamp: new Date().toISOString(),
        status: 'NO_ACTION_REQUIRED',
        actionsToken: 0,
        findings: [],
        responseTime: Date.now() - startTime,
      };
    }

    logger.info(`Processing ${findings.length} findings`, { incidentId });

    // Process each finding
    for (const finding of findings) {
      const severity = assessSeverity(finding);

      // High and critical findings require immediate action
      if (severity === 'CRITICAL' || severity === 'HIGH') {
        // Isolate compromised resources
        if (AUTO_ISOLATE && !DRY_RUN) {
          const isolationResult = await isolateCompromisedResources(finding);
          actions.push({
            type: 'ISOLATION',
            resourceArn: finding.resourceArn,
            status: isolationResult.success ? 'SUCCESS' : 'FAILED',
            timestamp: new Date().toISOString(),
            details: isolationResult.message,
          });
        }

        // Create snapshots for forensics
        const snapshotResult = await createForensicSnapshots(finding);
        actions.push({
          type: 'SNAPSHOT',
          resourceArn: finding.resourceArn,
          status: snapshotResult.success ? 'SUCCESS' : 'FAILED',
          timestamp: new Date().toISOString(),
          details: snapshotResult.snapshotId,
        });

        // Notify security team
        await notifySecurityTeam({
          incidentId,
          finding,
          severity,
          actions,
          snsTopicArn: SECURITY_TOPIC_ARN,
        });

        actions.push({
          type: 'NOTIFICATION',
          resourceArn: SECURITY_TOPIC_ARN,
          status: 'SUCCESS',
          timestamp: new Date().toISOString(),
          details: 'Security team notified',
        });
      }

      // Create incident ticket for all findings
      const ticketId = await createIncidentTicket({
        incidentId,
        finding,
        severity,
        actions,
        queueUrl: INCIDENT_QUEUE_URL,
      });

      actions.push({
        type: 'TICKET_CREATION',
        resourceArn: finding.resourceArn,
        status: ticketId ? 'SUCCESS' : 'FAILED',
        timestamp: new Date().toISOString(),
        details: ticketId || 'Failed to create ticket',
      });
    }

    // Archive findings in GuardDuty
    if (!DRY_RUN && event.detectorId && findings.length > 0) {
      await archiveGuardDutyFindings(
        event.detectorId,
        findings.map((f) => f.id)
      );
    }

    const response: IncidentResponse = {
      incidentId,
      timestamp: new Date().toISOString(),
      status: actions.some((a) => a.status === 'FAILED') ? 'PARTIAL_SUCCESS' : 'SUCCESS',
      actionsToken: actions.length,
      findings: findings.map((f) => ({
        id: f.id,
        type: f.type,
        severity: assessSeverity(f),
        resourceArn: f.resourceArn,
      })),
      responseTime: Date.now() - startTime,
      dryRun: DRY_RUN,
    };

    logger.info('Incident response completed', { response });
    return response;
  } catch (error) {
    logger.error('Error during incident response', { error, incidentId });

    // Still notify on error
    try {
      await snsClient.send(
        new PublishCommand({
          TopicArn: SECURITY_TOPIC_ARN,
          Subject: `Security Incident Response Error - ${incidentId}`,
          Message: JSON.stringify({
            incidentId,
            error: error instanceof Error ? error.message : 'Unknown error',
            event,
            timestamp: new Date().toISOString(),
          }),
        })
      );
    } catch (notifyError) {
      logger.error('Failed to send error notification', { notifyError });
    }

    throw error;
  }
};

async function parseGuardDutyFindings(event: IncidentEvent): Promise<GuardDutyFinding[]> {
  const findings: GuardDutyFinding[] = [];

  try {
    if (event.findingIds && event.findingIds.length > 0 && event.detectorId) {
      const response = await guarddutyClient.send(
        new GetFindingsCommand({
          DetectorId: event.detectorId,
          FindingIds: event.findingIds,
        })
      );

      if (response.Findings) {
        for (const finding of response.Findings) {
          findings.push({
            id: finding.Id || '',
            type: finding.Type || 'Unknown',
            severity: finding.Severity || 0,
            title: finding.Title || '',
            description: finding.Description || '',
            resourceArn: finding.Resource?.InstanceDetails?.InstanceId || '',
            accountId: finding.AccountId || '',
            region: finding.Region || '',
            createdAt: finding.CreatedAt || '',
            updatedAt: finding.UpdatedAt || '',
            confidence: finding.Confidence || 0,
            service: finding.Service?.ServiceName || 'Unknown',
          });
        }
      }
    }
  } catch (error) {
    logger.error('Error parsing GuardDuty findings', { error });
  }

  return findings;
}

async function isolateCompromisedResources(finding: GuardDutyFinding): Promise<IsolationResult> {
  try {
    const result = await isolateResource(finding.resourceArn, finding.type);
    logger.info('Resource isolated', { resourceArn: finding.resourceArn, result });
    return result;
  } catch (error) {
    logger.error('Failed to isolate resource', { error, resourceArn: finding.resourceArn });
    return {
      success: false,
      message: error instanceof Error ? error.message : 'Unknown error',
      resourceArn: finding.resourceArn,
    };
  }
}

async function createForensicSnapshots(
  finding: GuardDutyFinding
): Promise<{ success: boolean; snapshotId?: string }> {
  try {
    const result = await snapshotResource(finding.resourceArn, finding.id);
    logger.info('Forensic snapshot created', { resourceArn: finding.resourceArn, result });
    return { success: true, snapshotId: result.snapshotId };
  } catch (error) {
    logger.error('Failed to create snapshot', { error, resourceArn: finding.resourceArn });
    return { success: false };
  }
}

async function archiveGuardDutyFindings(detectorId: string, findingIds: string[]): Promise<void> {
  try {
    await guarddutyClient.send(
      new ArchiveFindingsCommand({
        DetectorId: detectorId,
        FindingIds: findingIds,
      })
    );
    logger.info('Findings archived in GuardDuty', { count: findingIds.length });
  } catch (error) {
    logger.error('Failed to archive findings', { error, detectorId, findingIds });
  }
}
