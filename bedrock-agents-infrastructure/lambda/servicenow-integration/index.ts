/**
 * ServiceNow Integration Lambda Handler
 * Main entry point for AWS Bedrock Agent integration with ServiceNow
 */

import { Context } from 'aws-lambda';
import { ServiceNowClient } from './servicenow-client';
import {
  ServiceNowLambdaEvent,
  ServiceNowResponse,
  ServiceNowError,
  IncidentActionParams,
  TicketActionParams,
  ChangeActionParams,
  ProblemActionParams,
  KnowledgeActionParams,
  UserGroupActionParams,
  ReportingActionParams,
} from './types';
import { logOperation } from './utils';

// Environment variables
const SECRETS_MANAGER_SECRET_NAME = process.env.SERVICENOW_SECRET_NAME || 'servicenow/credentials';
const RATE_LIMIT_ENABLED = process.env.RATE_LIMIT_ENABLED === 'true';
const MAX_REQUESTS = parseInt(process.env.MAX_REQUESTS || '100', 10);
const WINDOW_MS = parseInt(process.env.WINDOW_MS || '60000', 10);

let serviceNowClient: ServiceNowClient | null = null;

/**
 * Initialize ServiceNow client (singleton pattern)
 */
async function getServiceNowClient(): Promise<ServiceNowClient> {
  if (!serviceNowClient) {
    serviceNowClient = await ServiceNowClient.fromSecretsManager(
      SECRETS_MANAGER_SECRET_NAME,
      {
        rateLimitConfig: {
          maxRequests: MAX_REQUESTS,
          windowMs: WINDOW_MS,
          enabled: RATE_LIMIT_ENABLED,
        },
        timeout: 30000,
        maxRetries: 3,
        retryDelay: 1000,
      }
    );
  }
  return serviceNowClient;
}

/**
 * Main Lambda handler
 */
export async function handler(
  event: ServiceNowLambdaEvent,
  context: Context
): Promise<ServiceNowResponse> {
  const startTime = Date.now();

  try {
    logOperation('lambda-invocation', {
      action: event.action,
      requestId: context.awsRequestId,
    });

    const client = await getServiceNowClient();

    // Route to appropriate action handler
    const result = await routeAction(client, event.action, event.parameters);

    const duration = Date.now() - startTime;
    logOperation('lambda-success', {
      action: event.action,
      duration,
      requestId: context.awsRequestId,
    });

    return {
      success: true,
      data: result,
      statusCode: 200,
      message: 'Operation completed successfully',
    };
  } catch (error) {
    const duration = Date.now() - startTime;

    if (error instanceof ServiceNowError) {
      logOperation('lambda-error', {
        action: event.action,
        error: error.message,
        errorCode: error.errorCode,
        statusCode: error.statusCode,
        duration,
        requestId: context.awsRequestId,
      }, 'error');

      return {
        success: false,
        error: error.message,
        statusCode: error.statusCode,
      };
    }

    // Unknown error
    console.error('Unexpected error:', error);
    logOperation('lambda-error', {
      action: event.action,
      error: error instanceof Error ? error.message : 'Unknown error',
      duration,
      requestId: context.awsRequestId,
    }, 'error');

    return {
      success: false,
      error: 'Internal server error',
      statusCode: 500,
    };
  }
}

/**
 * Route action to appropriate handler
 */
async function routeAction(
  client: ServiceNowClient,
  action: string,
  parameters: Record<string, any>
): Promise<any> {
  // Incident Management Actions
  if (action.startsWith('incident') || action.includes('incident')) {
    return handleIncidentAction(client, action, parameters as IncidentActionParams);
  }

  // Ticket Operations
  if (action.includes('ticket')) {
    return handleTicketAction(client, action, parameters as TicketActionParams);
  }

  // Change Management
  if (action.includes('change')) {
    return handleChangeAction(client, action, parameters as ChangeActionParams);
  }

  // Problem Management
  if (action.includes('problem')) {
    return handleProblemAction(client, action, parameters as ProblemActionParams);
  }

  // Knowledge Base
  if (action.includes('knowledge') || action.includes('kb')) {
    return handleKnowledgeAction(client, action, parameters as KnowledgeActionParams);
  }

  // User/Group Operations
  if (action.includes('user') || action.includes('group')) {
    return handleUserGroupAction(client, action, parameters as UserGroupActionParams);
  }

  // Reporting
  if (action.includes('metrics') || action.includes('sla') || action.includes('report')) {
    return handleReportingAction(client, action, parameters as ReportingActionParams);
  }

  throw new ServiceNowError(`Unknown action: ${action}`, 400, 'UNKNOWN_ACTION');
}

// ===========================
// Incident Action Handlers
// ===========================

async function handleIncidentAction(
  client: ServiceNowClient,
  action: string,
  params: IncidentActionParams
): Promise<any> {
  switch (action) {
    case 'create-incident':
      return client.createIncident(params.incident as any);

    case 'update-incident':
      if (!params.sys_id) {
        throw new ServiceNowError('sys_id is required', 400, 'MISSING_PARAMETER');
      }
      return client.updateIncident({ sys_id: params.sys_id, ...params.incident });

    case 'resolve-incident':
      if (!params.sys_id) {
        throw new ServiceNowError('sys_id is required', 400, 'MISSING_PARAMETER');
      }
      return client.resolveIncident(
        params.sys_id,
        params.resolution_notes || 'Issue resolved',
        params.close_code
      );

    case 'get-incident':
      return client.getIncident(params.sys_id, params.number);

    case 'search-incidents':
      if (!params.query) {
        throw new ServiceNowError('query is required', 400, 'MISSING_PARAMETER');
      }
      return client.searchIncidents(params.query);

    case 'assign-incident':
      if (!params.sys_id) {
        throw new ServiceNowError('sys_id is required', 400, 'MISSING_PARAMETER');
      }
      return client.assignIncident(
        params.sys_id,
        params.assigned_to,
        params.assignment_group
      );

    case 'add-comment':
      if (!params.sys_id || !params.comment) {
        throw new ServiceNowError('sys_id and comment are required', 400, 'MISSING_PARAMETER');
      }
      return client.addIncidentComment(params.sys_id, params.comment);

    default:
      throw new ServiceNowError(`Unknown incident action: ${action}`, 400, 'UNKNOWN_ACTION');
  }
}

// ===========================
// Ticket Action Handlers
// ===========================

async function handleTicketAction(
  client: ServiceNowClient,
  action: string,
  params: TicketActionParams
): Promise<any> {
  const table = params.table || 'incident';

  switch (action) {
    case 'create-ticket':
      // Map to appropriate table creation
      if (table === 'incident') {
        return client.createIncident(params.ticket as any);
      }
      throw new ServiceNowError(`Unsupported table: ${table}`, 400, 'UNSUPPORTED_TABLE');

    case 'update-ticket':
      if (!params.sys_id) {
        throw new ServiceNowError('sys_id is required', 400, 'MISSING_PARAMETER');
      }
      if (table === 'incident') {
        return client.updateIncident({ sys_id: params.sys_id, ...params.ticket });
      }
      throw new ServiceNowError(`Unsupported table: ${table}`, 400, 'UNSUPPORTED_TABLE');

    case 'close-ticket':
      if (!params.sys_id) {
        throw new ServiceNowError('sys_id is required', 400, 'MISSING_PARAMETER');
      }
      if (table === 'incident') {
        return client.resolveIncident(params.sys_id, params.close_notes || 'Ticket closed');
      }
      throw new ServiceNowError(`Unsupported table: ${table}`, 400, 'UNSUPPORTED_TABLE');

    case 'get-ticket-status':
      if (!params.sys_id && !params.number) {
        throw new ServiceNowError('sys_id or number is required', 400, 'MISSING_PARAMETER');
      }
      if (table === 'incident') {
        return client.getIncident(params.sys_id, params.number);
      }
      throw new ServiceNowError(`Unsupported table: ${table}`, 400, 'UNSUPPORTED_TABLE');

    case 'add-work-notes':
      if (!params.sys_id || !params.work_notes) {
        throw new ServiceNowError('sys_id and work_notes are required', 400, 'MISSING_PARAMETER');
      }
      if (table === 'incident') {
        return client.addIncidentWorkNotes(params.sys_id, params.work_notes);
      }
      throw new ServiceNowError(`Unsupported table: ${table}`, 400, 'UNSUPPORTED_TABLE');

    default:
      throw new ServiceNowError(`Unknown ticket action: ${action}`, 400, 'UNKNOWN_ACTION');
  }
}

// ===========================
// Change Action Handlers
// ===========================

async function handleChangeAction(
  client: ServiceNowClient,
  action: string,
  params: ChangeActionParams
): Promise<any> {
  switch (action) {
    case 'create-change-request':
      return client.createChangeRequest(params.change as any);

    case 'update-change-request':
      if (!params.sys_id) {
        throw new ServiceNowError('sys_id is required', 400, 'MISSING_PARAMETER');
      }
      return client.updateChangeRequest(params.sys_id, params.change || {});

    case 'assess-change-risk':
      if (!params.sys_id) {
        throw new ServiceNowError('sys_id is required', 400, 'MISSING_PARAMETER');
      }
      return client.assessChangeRisk(params.sys_id, 'Risk assessment performed');

    case 'approve-change':
      if (!params.sys_id) {
        throw new ServiceNowError('sys_id is required', 400, 'MISSING_PARAMETER');
      }
      return client.approveChange(params.sys_id);

    case 'schedule-change':
      if (!params.sys_id || !params.start_date || !params.end_date) {
        throw new ServiceNowError(
          'sys_id, start_date, and end_date are required',
          400,
          'MISSING_PARAMETER'
        );
      }
      return client.scheduleChange(params.sys_id, params.start_date, params.end_date);

    default:
      throw new ServiceNowError(`Unknown change action: ${action}`, 400, 'UNKNOWN_ACTION');
  }
}

// ===========================
// Problem Action Handlers
// ===========================

async function handleProblemAction(
  client: ServiceNowClient,
  action: string,
  params: ProblemActionParams
): Promise<any> {
  switch (action) {
    case 'create-problem':
      return client.createProblem(params.problem || {});

    case 'link-incidents-to-problem':
      if (!params.sys_id || !params.incident_ids) {
        throw new ServiceNowError('sys_id and incident_ids are required', 400, 'MISSING_PARAMETER');
      }
      await client.linkIncidentsToProblem(params.sys_id, params.incident_ids);
      return { message: 'Incidents linked successfully' };

    case 'update-problem':
      if (!params.sys_id) {
        throw new ServiceNowError('sys_id is required', 400, 'MISSING_PARAMETER');
      }
      return client.updateProblem(params.sys_id, params.problem || {});

    case 'resolve-problem':
      if (!params.sys_id || !params.root_cause) {
        throw new ServiceNowError('sys_id and root_cause are required', 400, 'MISSING_PARAMETER');
      }
      return client.resolveProblem(params.sys_id, params.root_cause, params.workaround);

    default:
      throw new ServiceNowError(`Unknown problem action: ${action}`, 400, 'UNKNOWN_ACTION');
  }
}

// ===========================
// Knowledge Action Handlers
// ===========================

async function handleKnowledgeAction(
  client: ServiceNowClient,
  action: string,
  params: KnowledgeActionParams
): Promise<any> {
  switch (action) {
    case 'search-knowledge':
      if (!params.search_query) {
        throw new ServiceNowError('search_query is required', 400, 'MISSING_PARAMETER');
      }
      return client.searchKnowledge(params.search_query);

    case 'create-kb-article':
      return client.createKBArticle(params.article as any);

    case 'update-kb-article':
      if (!params.sys_id) {
        throw new ServiceNowError('sys_id is required', 400, 'MISSING_PARAMETER');
      }
      return client.updateKBArticle(params.sys_id, params.article || {});

    case 'get-kb-article':
      return client.getKBArticle(params.sys_id, params.number);

    default:
      throw new ServiceNowError(`Unknown knowledge action: ${action}`, 400, 'UNKNOWN_ACTION');
  }
}

// ===========================
// User/Group Action Handlers
// ===========================

async function handleUserGroupAction(
  client: ServiceNowClient,
  action: string,
  params: UserGroupActionParams
): Promise<any> {
  switch (action) {
    case 'get-user-info':
      return client.getUserInfo(params.user_id, params.user_name);

    case 'get-group-info':
      return client.getGroupInfo(params.group_id, params.group_name);

    case 'assign-to-group':
      if (!params.task_sys_id || !params.group_id) {
        throw new ServiceNowError('task_sys_id and group_id are required', 400, 'MISSING_PARAMETER');
      }
      await client.assignToGroup(params.task_sys_id, params.group_id);
      return { message: 'Assigned to group successfully' };

    default:
      throw new ServiceNowError(`Unknown user/group action: ${action}`, 400, 'UNKNOWN_ACTION');
  }
}

// ===========================
// Reporting Action Handlers
// ===========================

async function handleReportingAction(
  client: ServiceNowClient,
  action: string,
  params: ReportingActionParams
): Promise<any> {
  switch (action) {
    case 'get-incident-metrics':
      return client.getIncidentMetrics(params.start_date, params.end_date);

    case 'get-sla-status':
      if (!params.task_sys_id) {
        throw new ServiceNowError('task_sys_id is required', 400, 'MISSING_PARAMETER');
      }
      return client.getSLAStatus(params.task_sys_id);

    case 'generate-report':
      if (!params.report_type) {
        throw new ServiceNowError('report_type is required', 400, 'MISSING_PARAMETER');
      }
      return client.generateReport(params.report_type, params.filters);

    default:
      throw new ServiceNowError(`Unknown reporting action: ${action}`, 400, 'UNKNOWN_ACTION');
  }
}
