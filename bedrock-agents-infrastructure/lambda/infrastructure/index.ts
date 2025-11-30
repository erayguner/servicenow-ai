import { Handler } from 'aws-lambda';
import { S3Client } from '@aws-sdk/client-s3';
import { ECSClient } from '@aws-sdk/client-ecs';
import { EC2Client } from '@aws-sdk/client-ec2';
import { CloudFormationClient } from '@aws-sdk/client-cloudformation';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { InfrastructureResponse, InfrastructureAction } from './types';
import {
  executeTerraformPlan,
  executeTerraformApply,
  deployToKubernetes,
  executeAWSOperation,
  getInfrastructureState,
} from './utils';

const s3Client = new S3Client({ region: process.env.AWS_REGION || 'us-east-1' });
const ecsClient = new ECSClient({ region: process.env.AWS_REGION || 'us-east-1' });
const ec2Client = new EC2Client({ region: process.env.AWS_REGION || 'us-east-1' });
const cfnClient = new CloudFormationClient({ region: process.env.AWS_REGION || 'us-east-1' });
const dynamoClient = new DynamoDBClient({ region: process.env.AWS_REGION || 'us-east-1' });

/**
 * Lambda handler for infrastructure action group
 * Supports: terraform-plan, terraform-apply, kubernetes-deploy, aws-operations
 */
export const handler: Handler = async (event: any): Promise<InfrastructureResponse> => {
  console.log('Infrastructure Event:', JSON.stringify(event, null, 2));

  try {
    const actionGroup = event.actionGroup;
    const apiPath = event.apiPath;
    const httpMethod = event.httpMethod;
    const parameters = event.parameters || [];
    const requestBody = event.requestBody;

    // Extract parameters
    const params: Record<string, string> = {};
    parameters.forEach((param: any) => {
      params[param.name] = param.value;
    });

    // Parse request body
    let bodyContent: any = {};
    if (requestBody?.content) {
      const contentType = Object.keys(requestBody.content)[0];
      bodyContent = JSON.parse(requestBody.content[contentType].body);
    }

    // Determine action from API path
    const action = apiPath.replace('/infrastructure/', '') as InfrastructureAction;

    let result: any;

    switch (action) {
      case 'terraform-plan':
        result = await handleTerraformPlan(params, bodyContent);
        break;

      case 'terraform-apply':
        result = await handleTerraformApply(params, bodyContent);
        break;

      case 'kubernetes-deploy':
        result = await handleKubernetesDeploy(params, bodyContent);
        break;

      case 'aws-operations':
        result = await handleAWSOperations(params, bodyContent);
        break;

      case 'infrastructure-state':
        result = await handleInfrastructureState(params, bodyContent);
        break;

      default:
        throw new Error(`Unknown action: ${action}`);
    }

    return {
      messageVersion: '1.0',
      response: {
        actionGroup,
        apiPath,
        httpMethod,
        httpStatusCode: 200,
        responseBody: {
          'application/json': {
            body: JSON.stringify({
              success: true,
              action,
              result,
              timestamp: new Date().toISOString(),
            }),
          },
        },
      },
    };
  } catch (error) {
    console.error('Error in infrastructure operations:', error);

    return {
      messageVersion: '1.0',
      response: {
        actionGroup: event.actionGroup,
        apiPath: event.apiPath,
        httpMethod: event.httpMethod,
        httpStatusCode: 500,
        responseBody: {
          'application/json': {
            body: JSON.stringify({
              success: false,
              error: error instanceof Error ? error.message : 'Unknown error',
              timestamp: new Date().toISOString(),
            }),
          },
        },
      },
    };
  }
};

/**
 * Handle terraform-plan operation
 */
async function handleTerraformPlan(params: Record<string, string>, body: any): Promise<any> {
  const workingDir = params.workingDir || body.workingDir;
  const varFile = params.varFile || body.varFile;
  const variables = body.variables || {};
  const target = params.target || body.target;
  const bucket = params.bucket || body.bucket || process.env.TERRAFORM_STATE_BUCKET;
  const environment = params.environment || body.environment || 'dev';

  if (!workingDir) {
    throw new Error('workingDir is required');
  }

  console.log(`Running Terraform plan in: ${workingDir} for environment: ${environment}`);

  const plan = await executeTerraformPlan(s3Client, dynamoClient, {
    workingDir,
    varFile,
    variables,
    target,
    bucket: bucket!,
    environment,
  });

  return {
    planId: plan.planId,
    workingDir,
    environment,
    changes: {
      create: plan.changes.create,
      update: plan.changes.update,
      delete: plan.changes.delete,
      total: plan.changes.total,
    },
    resources: plan.resources,
    planOutput: plan.output,
    planFileUrl: plan.planFileUrl,
    executionTime: plan.executionTime,
    requiresApproval: plan.changes.total > 0,
  };
}

/**
 * Handle terraform-apply operation
 */
async function handleTerraformApply(params: Record<string, string>, body: any): Promise<any> {
  const planId = params.planId || body.planId;
  const workingDir = params.workingDir || body.workingDir;
  const autoApprove = params.autoApprove === 'true' || body.autoApprove === true;
  const environment = params.environment || body.environment || 'dev';
  const bucket = params.bucket || body.bucket || process.env.TERRAFORM_STATE_BUCKET;

  if (!planId && !workingDir) {
    throw new Error('Either planId or workingDir is required');
  }

  // Require manual approval for production
  if (environment === 'prod' && !autoApprove) {
    throw new Error('Production deployments require explicit approval. Set autoApprove=true');
  }

  console.log(
    `Applying Terraform changes for plan: ${planId || 'new'} in environment: ${environment}`
  );

  const apply = await executeTerraformApply(s3Client, dynamoClient, {
    planId,
    workingDir: workingDir!,
    autoApprove,
    environment,
    bucket: bucket!,
  });

  return {
    applyId: apply.applyId,
    planId,
    environment,
    status: apply.status,
    resourcesCreated: apply.resourcesCreated,
    resourcesUpdated: apply.resourcesUpdated,
    resourcesDeleted: apply.resourcesDeleted,
    totalResources: apply.totalResources,
    stateFileUrl: apply.stateFileUrl,
    executionTime: apply.executionTime,
    outputs: apply.outputs,
  };
}

/**
 * Handle kubernetes-deploy operation
 */
async function handleKubernetesDeploy(params: Record<string, string>, body: any): Promise<any> {
  const clusterName = params.clusterName || body.clusterName;
  const namespace = params.namespace || body.namespace || 'default';
  const manifestPath = params.manifestPath || body.manifestPath;
  const manifestContent = body.manifestContent;
  const deploymentType = params.deploymentType || body.deploymentType || 'deployment';
  const replicas = parseInt(params.replicas || body.replicas || '1', 10);
  const image = params.image || body.image;
  const environment = params.environment || body.environment || 'dev';

  if (!clusterName) {
    throw new Error('clusterName is required');
  }

  if (!manifestPath && !manifestContent && !image) {
    throw new Error('Either manifestPath, manifestContent, or image is required');
  }

  console.log(`Deploying to Kubernetes cluster: ${clusterName} in namespace: ${namespace}`);

  const deployment = await deployToKubernetes(s3Client, ecsClient, {
    clusterName,
    namespace,
    manifestPath,
    manifestContent,
    deploymentType,
    replicas,
    image,
    environment,
  });

  return {
    deploymentId: deployment.deploymentId,
    clusterName,
    namespace,
    deploymentType,
    status: deployment.status,
    replicas: deployment.replicas,
    availableReplicas: deployment.availableReplicas,
    images: deployment.images,
    services: deployment.services,
    deployedAt: deployment.deployedAt,
    rolloutStatus: deployment.rolloutStatus,
  };
}

/**
 * Handle aws-operations
 */
async function handleAWSOperations(params: Record<string, string>, body: any): Promise<any> {
  const operation = params.operation || body.operation;
  const service = params.service || body.service;
  const parameters = body.parameters || {};
  const region = params.region || body.region || process.env.AWS_REGION;

  if (!operation || !service) {
    throw new Error('operation and service are required');
  }

  console.log(`Executing AWS operation: ${service}.${operation}`);

  const result = await executeAWSOperation(
    {
      s3Client,
      ecsClient,
      ec2Client,
      cfnClient,
      dynamoClient,
    },
    {
      service,
      operation,
      parameters,
      region: region!,
    }
  );

  return {
    service,
    operation,
    status: result.status,
    data: result.data,
    metadata: result.metadata,
    executedAt: new Date().toISOString(),
  };
}

/**
 * Handle infrastructure-state operation
 */
async function handleInfrastructureState(params: Record<string, string>, body: any): Promise<any> {
  const environment = params.environment || body.environment || 'dev';
  const stateType = params.stateType || body.stateType || 'all'; // all, terraform, kubernetes, aws
  const includeDetails = params.includeDetails === 'true' || body.includeDetails === true;

  console.log(`Getting infrastructure state for environment: ${environment}`);

  const state = await getInfrastructureState(
    s3Client,
    ecsClient,
    ec2Client,
    cfnClient,
    dynamoClient,
    {
      environment,
      stateType,
      includeDetails,
    }
  );

  return {
    environment,
    stateType,
    terraform: state.terraform,
    kubernetes: state.kubernetes,
    aws: state.aws,
    lastUpdated: state.lastUpdated,
    healthStatus: state.healthStatus,
  };
}
