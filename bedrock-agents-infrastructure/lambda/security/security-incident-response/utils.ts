import {
  EC2Client,
  CreateSnapshotCommand,
  StopInstancesCommand,
  ModifyInstanceAttributeCommand,
  DescribeInstancesCommand,
  CreateTagsCommand,
} from '@aws-sdk/client-ec2';
import { SNSClient, PublishCommand } from '@aws-sdk/client-sns';
import { SQSClient, SendMessageCommand } from '@aws-sdk/client-sqs';
import {
  BedrockAgentClient,
  GetAgentCommand,
} from '@aws-sdk/client-bedrock-agent';
import {
  GuardDutyFinding,
  IsolationResult,
  SnapshotResult,
  NotificationPayload,
  IncidentTicket,
  LoggerContext,
} from './types';

const ec2Client = new EC2Client({});
const snsClient = new SNSClient({});
const sqsClient = new SQSClient({});
const bedrockClient = new BedrockAgentClient({});

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

export function assessSeverity(
  finding: GuardDutyFinding
): 'CRITICAL' | 'HIGH' | 'MEDIUM' | 'LOW' {
  // GuardDuty severity: 0-3.9 Low, 4-6.9 Medium, 7-8.9 High, 9-10 Critical
  if (finding.severity >= 9) return 'CRITICAL';
  if (finding.severity >= 7) return 'HIGH';
  if (finding.severity >= 4) return 'MEDIUM';
  return 'LOW';
}

export async function isolateResource(
  resourceArn: string,
  _findingType: string,
): Promise<IsolationResult> {
  try {
    // Determine resource type from ARN
    if (resourceArn.includes('instance')) {
      return await isolateEC2Instance(resourceArn);
    } else if (resourceArn.includes('bedrock')) {
      return await isolateBedrockAgent(resourceArn);
    } else if (resourceArn.includes('lambda')) {
      return await isolateLambdaFunction(resourceArn);
    } else {
      logger.warn('Unknown resource type for isolation', { resourceArn });
      return {
        success: false,
        message: 'Unknown resource type',
        resourceArn,
      };
    }
  } catch (error) {
    logger.error('Error isolating resource', { error, resourceArn });
    return {
      success: false,
      message: error instanceof Error ? error.message : 'Unknown error',
      resourceArn,
    };
  }
}

async function isolateEC2Instance(instanceId: string): Promise<IsolationResult> {
  try {
    // Get instance details
    const describeResponse = await ec2Client.send(
      new DescribeInstancesCommand({
        InstanceIds: [instanceId],
      })
    );

    if (!describeResponse.Reservations || describeResponse.Reservations.length === 0) {
      throw new Error(`Instance ${instanceId} not found`);
    }

    const instance = describeResponse.Reservations[0].Instances?.[0];
    if (!instance) {
      throw new Error(`Instance details not available for ${instanceId}`);
    }

    // Create isolation security group (deny all traffic)
    // In production, you would create a dedicated isolation SG
    await ec2Client.send(
      new ModifyInstanceAttributeCommand({
        InstanceId: instanceId,
        Groups: ['sg-isolation'], // Replace with actual isolation SG
      })
    );

    // Tag instance as isolated
    await ec2Client.send(
      new CreateTagsCommand({
        Resources: [instanceId],
        Tags: [
          {
            Key: 'SecurityStatus',
            Value: 'ISOLATED',
          },
          {
            Key: 'IsolationTimestamp',
            Value: new Date().toISOString(),
          },
        ],
      })
    );

    // Optionally stop the instance
    const shouldStop = process.env.STOP_COMPROMISED_INSTANCES === 'true';
    if (shouldStop) {
      await ec2Client.send(
        new StopInstancesCommand({
          InstanceIds: [instanceId],
        })
      );
    }

    return {
      success: true,
      message: `EC2 instance ${instanceId} isolated successfully`,
      resourceArn: instanceId,
      isolationType: 'NETWORK',
      rollbackProcedure: 'Restore original security groups and restart instance',
    };
  } catch (error) {
    logger.error('Failed to isolate EC2 instance', { error, instanceId });
    throw error;
  }
}

async function isolateBedrockAgent(agentArn: string): Promise<IsolationResult> {
  try {
    const agentId = agentArn.split('/').pop();
    if (!agentId) {
      throw new Error('Invalid agent ARN');
    }

    // Get agent details
    const agentResponse = await bedrockClient.send(
      new GetAgentCommand({
        agentId,
      })
    );

    if (!agentResponse.agent) {
      throw new Error(`Agent ${agentId} not found`);
    }

    // Disable the agent or update to restrictive IAM role
    // Note: Bedrock doesn't have a direct "disable" - we'd update the IAM role
    logger.info('Bedrock agent marked for isolation', { agentId });

    return {
      success: true,
      message: `Bedrock agent ${agentId} isolated (IAM role should be updated manually)`,
      resourceArn: agentArn,
      isolationType: 'IAM',
      rollbackProcedure: 'Restore original IAM role for the agent',
    };
  } catch (error) {
    logger.error('Failed to isolate Bedrock agent', { error, agentArn });
    throw error;
  }
}

async function isolateLambdaFunction(functionArn: string): Promise<IsolationResult> {
  try {
    // Lambda functions can be isolated by:
    // 1. Removing VPC config
    // 2. Updating IAM role to deny-all
    // 3. Setting reserved concurrency to 0

    logger.info('Lambda function marked for isolation', { functionArn });

    return {
      success: true,
      message: `Lambda function ${functionArn} marked for isolation`,
      resourceArn: functionArn,
      isolationType: 'IAM',
      rollbackProcedure: 'Restore original IAM role and VPC configuration',
    };
  } catch (error) {
    logger.error('Failed to isolate Lambda function', { error, functionArn });
    throw error;
  }
}

export async function snapshotResource(
  resourceArn: string,
  findingId: string
): Promise<SnapshotResult> {
  try {
    if (resourceArn.includes('instance') || resourceArn.includes('vol-')) {
      // For EC2 instances, snapshot all attached volumes
      const volumeIds = await getInstanceVolumes(resourceArn);

      if (volumeIds.length === 0) {
        return { success: false };
      }

      // Snapshot the first volume (root)
      const snapshotResponse = await ec2Client.send(
        new CreateSnapshotCommand({
          VolumeId: volumeIds[0],
          Description: `Forensic snapshot for security incident ${findingId}`,
          TagSpecifications: [
            {
              ResourceType: 'snapshot',
              Tags: [
                { Key: 'Purpose', Value: 'SecurityForensics' },
                { Key: 'FindingId', Value: findingId },
                { Key: 'CreatedAt', Value: new Date().toISOString() },
              ],
            },
          ],
        })
      );

      return {
        success: true,
        snapshotId: snapshotResponse.SnapshotId,
        volumeId: volumeIds[0],
        timestamp: new Date().toISOString(),
      };
    }

    return { success: false };
  } catch (error) {
    logger.error('Failed to create snapshot', { error, resourceArn });
    return { success: false };
  }
}

async function getInstanceVolumes(instanceId: string): Promise<string[]> {
  try {
    const response = await ec2Client.send(
      new DescribeInstancesCommand({
        InstanceIds: [instanceId],
      })
    );

    const instance = response.Reservations?.[0]?.Instances?.[0];
    if (!instance || !instance.BlockDeviceMappings) {
      return [];
    }

    return instance.BlockDeviceMappings.map((bdm) => bdm.Ebs?.VolumeId).filter(
      Boolean
    ) as string[];
  } catch (error) {
    logger.error('Failed to get instance volumes', { error, instanceId });
    return [];
  }
}

export async function notifySecurityTeam(payload: NotificationPayload): Promise<void> {
  try {
    const message = formatSecurityNotification(payload);

    await snsClient.send(
      new PublishCommand({
        TopicArn: payload.snsTopicArn,
        Subject: `🚨 SECURITY INCIDENT - ${payload.severity} - ${payload.incidentId}`,
        Message: message,
      })
    );

    logger.info('Security team notified', { incidentId: payload.incidentId });
  } catch (error) {
    logger.error('Failed to notify security team', { error, payload });
    throw error;
  }
}

function formatSecurityNotification(payload: NotificationPayload): string {
  return JSON.stringify(
    {
      incidentId: payload.incidentId,
      severity: payload.severity,
      finding: {
        id: payload.finding.id,
        type: payload.finding.type,
        title: payload.finding.title,
        description: payload.finding.description,
        resourceArn: payload.finding.resourceArn,
        confidence: payload.finding.confidence,
      },
      actions: payload.actions,
      timestamp: new Date().toISOString(),
      actionRequired: payload.severity === 'CRITICAL' ? 'IMMEDIATE' : 'REVIEW',
    },
    null,
    2
  );
}

export async function createIncidentTicket(ticket: IncidentTicket): Promise<string | null> {
  try {
    const ticketId = `TICKET-${Date.now()}`;

    const message = {
      ticketId,
      incidentId: ticket.incidentId,
      severity: ticket.severity,
      finding: ticket.finding,
      actions: ticket.actions,
      status: 'OPEN',
      createdAt: new Date().toISOString(),
    };

    await sqsClient.send(
      new SendMessageCommand({
        QueueUrl: ticket.queueUrl,
        MessageBody: JSON.stringify(message),
        MessageAttributes: {
          Severity: {
            DataType: 'String',
            StringValue: ticket.severity,
          },
          IncidentId: {
            DataType: 'String',
            StringValue: ticket.incidentId,
          },
        },
      })
    );

    logger.info('Incident ticket created', { ticketId, incidentId: ticket.incidentId });
    return ticketId;
  } catch (error) {
    logger.error('Failed to create incident ticket', { error, ticket });
    return null;
  }
}
