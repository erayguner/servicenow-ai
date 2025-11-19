/**
 * Type definitions for infrastructure Lambda function
 */

export type InfrastructureAction =
  | 'terraform-plan'
  | 'terraform-apply'
  | 'kubernetes-deploy'
  | 'aws-operations'
  | 'infrastructure-state';

export type TerraformAction = 'plan' | 'apply' | 'destroy' | 'import' | 'state';
export type DeploymentStatus = 'pending' | 'in-progress' | 'completed' | 'failed' | 'rolled-back';
export type HealthStatus = 'healthy' | 'degraded' | 'unhealthy';

export interface InfrastructureRequest {
  actionGroup: string;
  apiPath: string;
  httpMethod: string;
  parameters?: Parameter[];
  requestBody?: RequestBody;
}

export interface Parameter {
  name: string;
  value: string;
  type: string;
}

export interface RequestBody {
  content: {
    [contentType: string]: {
      body: string;
    };
  };
}

export interface InfrastructureResponse {
  messageVersion: string;
  response: {
    actionGroup: string;
    apiPath: string;
    httpMethod: string;
    httpStatusCode: number;
    responseBody: {
      [contentType: string]: {
        body: string;
      };
    };
  };
}

export interface TerraformPlanOptions {
  workingDir: string;
  varFile?: string;
  variables?: Record<string, any>;
  target?: string;
  bucket: string;
  environment: string;
}

export interface TerraformPlan {
  planId: string;
  workingDir: string;
  environment: string;
  changes: {
    create: number;
    update: number;
    delete: number;
    total: number;
  };
  resources: TerraformResource[];
  output: string;
  planFileUrl: string;
  executionTime: number;
  createdAt: string;
}

export interface TerraformResource {
  address: string;
  type: string;
  name: string;
  action: 'create' | 'update' | 'delete' | 'no-op';
  provider: string;
  attributes?: Record<string, any>;
}

export interface TerraformApplyOptions {
  planId?: string;
  workingDir: string;
  autoApprove: boolean;
  environment: string;
  bucket: string;
}

export interface TerraformApply {
  applyId: string;
  planId?: string;
  environment: string;
  status: DeploymentStatus;
  resourcesCreated: number;
  resourcesUpdated: number;
  resourcesDeleted: number;
  totalResources: number;
  stateFileUrl: string;
  executionTime: number;
  outputs: Record<string, TerraformOutput>;
  appliedAt: string;
}

export interface TerraformOutput {
  value: any;
  type: string;
  sensitive: boolean;
}

export interface KubernetesDeployOptions {
  clusterName: string;
  namespace: string;
  manifestPath?: string;
  manifestContent?: string;
  deploymentType: string;
  replicas: number;
  image?: string;
  environment: string;
}

export interface KubernetesDeployment {
  deploymentId: string;
  clusterName: string;
  namespace: string;
  deploymentType: string;
  status: DeploymentStatus;
  replicas: number;
  availableReplicas: number;
  images: string[];
  services: KubernetesService[];
  deployedAt: string;
  rolloutStatus: string;
}

export interface KubernetesService {
  name: string;
  type: string;
  ports: ServicePort[];
  selector: Record<string, string>;
}

export interface ServicePort {
  name: string;
  port: number;
  targetPort: number;
  protocol: string;
}

export interface AWSOperationOptions {
  service: string;
  operation: string;
  parameters: Record<string, any>;
  region: string;
}

export interface AWSOperationResult {
  status: 'success' | 'failure';
  data: any;
  metadata: {
    requestId?: string;
    duration: number;
    retries: number;
  };
}

export interface AWSClients {
  s3Client: any;
  ecsClient: any;
  ec2Client: any;
  cfnClient: any;
  dynamoClient: any;
}

export interface InfrastructureStateOptions {
  environment: string;
  stateType: 'all' | 'terraform' | 'kubernetes' | 'aws';
  includeDetails: boolean;
}

export interface InfrastructureState {
  environment: string;
  terraform?: TerraformState;
  kubernetes?: KubernetesState;
  aws?: AWSState;
  lastUpdated: string;
  healthStatus: HealthStatus;
}

export interface TerraformState {
  version: number;
  resources: number;
  outputs: Record<string, any>;
  stateFileUrl: string;
  lastApplied?: string;
  modules: TerraformModule[];
}

export interface TerraformModule {
  path: string[];
  resources: TerraformResource[];
}

export interface KubernetesState {
  clusterName: string;
  namespaces: string[];
  deployments: number;
  services: number;
  pods: number;
  nodes: number;
  version: string;
  details?: KubernetesDetails;
}

export interface KubernetesDetails {
  deployments: KubernetesDeploymentInfo[];
  services: KubernetesService[];
  nodes: KubernetesNode[];
}

export interface KubernetesDeploymentInfo {
  name: string;
  namespace: string;
  replicas: number;
  availableReplicas: number;
  status: string;
}

export interface KubernetesNode {
  name: string;
  status: string;
  capacity: {
    cpu: string;
    memory: string;
  };
  allocatable: {
    cpu: string;
    memory: string;
  };
}

export interface AWSState {
  region: string;
  resources: {
    ec2Instances: number;
    s3Buckets: number;
    lambdaFunctions: number;
    ecsServices: number;
    rdsInstances: number;
  };
  costs?: AWSCosts;
  details?: AWSDetails;
}

export interface AWSCosts {
  current: number;
  forecast: number;
  breakdown: Record<string, number>;
}

export interface AWSDetails {
  ec2Instances: EC2Instance[];
  s3Buckets: S3Bucket[];
  lambdaFunctions: LambdaFunction[];
}

export interface EC2Instance {
  instanceId: string;
  instanceType: string;
  state: string;
  publicIp?: string;
  privateIp?: string;
  tags: Record<string, string>;
}

export interface S3Bucket {
  name: string;
  region: string;
  creationDate: string;
  size: number;
  objectCount: number;
}

export interface LambdaFunction {
  functionName: string;
  runtime: string;
  handler: string;
  memorySize: number;
  timeout: number;
  lastModified: string;
}

export interface DeploymentMetrics {
  deploymentId: string;
  environment: string;
  startTime: string;
  endTime?: string;
  duration?: number;
  status: DeploymentStatus;
  changesApplied: number;
  errors: DeploymentError[];
}

export interface DeploymentError {
  resource: string;
  error: string;
  timestamp: string;
}
