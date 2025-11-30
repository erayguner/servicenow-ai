/**
 * ServiceNow REST API v2 Client
 * Comprehensive wrapper for ServiceNow Table API
 */

import { AxiosInstance } from 'axios';
import {
  ServiceNowClientConfig,
  Incident,
  ChangeRequest,
  Problem,
  KnowledgeArticle,
  User,
  Group,
  SLA,
  IncidentMetrics,
  ServiceNowListResponse,
  ServiceNowSingleResponse,
  ServiceNowError,
  CreateIncidentRequest,
  UpdateIncidentRequest,
  CreateChangeRequest,
  CreateKBArticleRequest,
} from './types';
import {
  createHttpClient,
  getServiceNowCredentials,
  OAuthTokenManager,
  RateLimiter,
  withRetry,
  validateRequired,
  logOperation,
} from './utils';

export class ServiceNowClient {
  private httpClient: AxiosInstance;
  private rateLimiter: RateLimiter;
  private oauthManager?: OAuthTokenManager;
  private config: ServiceNowClientConfig;

  constructor(config: ServiceNowClientConfig) {
    this.config = config;
    this.httpClient = createHttpClient(config.credentials, config.timeout);

    this.rateLimiter = new RateLimiter(
      config.rateLimitConfig || {
        maxRequests: 100,
        windowMs: 60000,
        enabled: true,
      }
    );

    if (config.credentials.authType === 'oauth') {
      this.oauthManager = new OAuthTokenManager(config.credentials, this.httpClient);
    }
  }

  /**
   * Initialize client with credentials from Secrets Manager
   */
  static async fromSecretsManager(
    secretName: string,
    config?: Partial<ServiceNowClientConfig>
  ): Promise<ServiceNowClient> {
    const credentials = await getServiceNowCredentials(secretName);

    return new ServiceNowClient({
      credentials,
      ...config,
    });
  }

  /**
   * Make authenticated API request
   */
  private async request<T>(
    method: string,
    path: string,
    data?: any,
    params?: Record<string, any>
  ): Promise<T> {
    await this.rateLimiter.acquire();

    // Add OAuth token if using OAuth
    if (this.oauthManager) {
      const token = await this.oauthManager.getAccessToken();
      this.httpClient.defaults.headers.common['Authorization'] = `Bearer ${token}`;
    }

    const requestFn = async () => {
      const response = await this.httpClient.request<T>({
        method,
        url: path,
        data,
        params,
      });
      return response.data;
    };

    return withRetry(requestFn, this.config.maxRetries || 3, this.config.retryDelay || 1000);
  }

  // ===========================
  // Incident Management
  // ===========================

  async createIncident(incident: CreateIncidentRequest): Promise<Incident> {
    validateRequired(incident, ['short_description', 'caller_id']);

    logOperation('create-incident', { short_description: incident.short_description });

    const response = await this.request<ServiceNowSingleResponse<Incident>>(
      'POST',
      '/api/now/table/incident',
      incident
    );

    return response.result;
  }

  async updateIncident(update: UpdateIncidentRequest): Promise<Incident> {
    validateRequired(update, ['sys_id']);

    logOperation('update-incident', { sys_id: update.sys_id });

    const { sys_id, ...data } = update;
    const response = await this.request<ServiceNowSingleResponse<Incident>>(
      'PATCH',
      `/api/now/table/incident/${sys_id}`,
      data
    );

    return response.result;
  }

  async resolveIncident(
    sys_id: string,
    resolution_notes: string,
    close_code: string = 'Solved (Permanently)'
  ): Promise<Incident> {
    logOperation('resolve-incident', { sys_id, close_code });

    const response = await this.request<ServiceNowSingleResponse<Incident>>(
      'PATCH',
      `/api/now/table/incident/${sys_id}`,
      {
        state: '6', // Resolved
        close_notes: resolution_notes,
        close_code: close_code,
        resolved_at: new Date().toISOString(),
      }
    );

    return response.result;
  }

  async getIncident(sys_id?: string, number?: string): Promise<Incident> {
    if (!sys_id && !number) {
      throw new ServiceNowError('Either sys_id or number is required', 400, 'MISSING_PARAMETER');
    }

    logOperation('get-incident', { sys_id, number });

    let query = '';
    if (number) {
      query = `?sysparm_query=number=${number}`;
      const response = await this.request<ServiceNowListResponse<Incident>>(
        'GET',
        `/api/now/table/incident${query}`
      );
      if (response.result.length === 0) {
        throw new ServiceNowError('Incident not found', 404, 'NOT_FOUND');
      }
      return response.result[0];
    } else {
      const response = await this.request<ServiceNowSingleResponse<Incident>>(
        'GET',
        `/api/now/table/incident/${sys_id}`
      );
      return response.result;
    }
  }

  async searchIncidents(query: string, limit: number = 100): Promise<Incident[]> {
    logOperation('search-incidents', { query, limit });

    const response = await this.request<ServiceNowListResponse<Incident>>(
      'GET',
      '/api/now/table/incident',
      undefined,
      {
        sysparm_query: query,
        sysparm_limit: limit,
      }
    );

    return response.result;
  }

  async assignIncident(
    sys_id: string,
    assigned_to?: string,
    assignment_group?: string
  ): Promise<Incident> {
    if (!assigned_to && !assignment_group) {
      throw new ServiceNowError(
        'Either assigned_to or assignment_group is required',
        400,
        'MISSING_PARAMETER'
      );
    }

    logOperation('assign-incident', { sys_id, assigned_to, assignment_group });

    const response = await this.request<ServiceNowSingleResponse<Incident>>(
      'PATCH',
      `/api/now/table/incident/${sys_id}`,
      {
        assigned_to,
        assignment_group,
        state: '2', // In Progress
      }
    );

    return response.result;
  }

  async addIncidentComment(sys_id: string, comment: string): Promise<Incident> {
    logOperation('add-incident-comment', { sys_id });

    const response = await this.request<ServiceNowSingleResponse<Incident>>(
      'PATCH',
      `/api/now/table/incident/${sys_id}`,
      {
        comments: comment,
      }
    );

    return response.result;
  }

  async addIncidentWorkNotes(sys_id: string, work_notes: string): Promise<Incident> {
    logOperation('add-incident-work-notes', { sys_id });

    const response = await this.request<ServiceNowSingleResponse<Incident>>(
      'PATCH',
      `/api/now/table/incident/${sys_id}`,
      {
        work_notes,
      }
    );

    return response.result;
  }

  // ===========================
  // Change Management
  // ===========================

  async createChangeRequest(change: CreateChangeRequest): Promise<ChangeRequest> {
    validateRequired(change, ['short_description', 'type', 'requested_by']);

    logOperation('create-change-request', { short_description: change.short_description });

    const response = await this.request<ServiceNowSingleResponse<ChangeRequest>>(
      'POST',
      '/api/now/table/change_request',
      change
    );

    return response.result;
  }

  async updateChangeRequest(sys_id: string, data: Partial<ChangeRequest>): Promise<ChangeRequest> {
    logOperation('update-change-request', { sys_id });

    const response = await this.request<ServiceNowSingleResponse<ChangeRequest>>(
      'PATCH',
      `/api/now/table/change_request/${sys_id}`,
      data
    );

    return response.result;
  }

  async assessChangeRisk(sys_id: string, risk_assessment: string): Promise<ChangeRequest> {
    logOperation('assess-change-risk', { sys_id });

    const response = await this.request<ServiceNowSingleResponse<ChangeRequest>>(
      'PATCH',
      `/api/now/table/change_request/${sys_id}`,
      {
        risk_impact_analysis: risk_assessment,
        state: 'assess',
      }
    );

    return response.result;
  }

  async approveChange(sys_id: string, approver_notes?: string): Promise<ChangeRequest> {
    logOperation('approve-change', { sys_id });

    const response = await this.request<ServiceNowSingleResponse<ChangeRequest>>(
      'PATCH',
      `/api/now/table/change_request/${sys_id}`,
      {
        approval: 'approved',
        state: 'authorize',
        work_notes: approver_notes,
      }
    );

    return response.result;
  }

  async scheduleChange(
    sys_id: string,
    start_date: string,
    end_date: string
  ): Promise<ChangeRequest> {
    logOperation('schedule-change', { sys_id, start_date, end_date });

    const response = await this.request<ServiceNowSingleResponse<ChangeRequest>>(
      'PATCH',
      `/api/now/table/change_request/${sys_id}`,
      {
        start_date,
        end_date,
        state: 'scheduled',
      }
    );

    return response.result;
  }

  // ===========================
  // Problem Management
  // ===========================

  async createProblem(problem: Partial<Problem>): Promise<Problem> {
    validateRequired(problem, ['short_description']);

    logOperation('create-problem', { short_description: problem.short_description });

    const response = await this.request<ServiceNowSingleResponse<Problem>>(
      'POST',
      '/api/now/table/problem',
      problem
    );

    return response.result;
  }

  async linkIncidentsToProblem(problem_sys_id: string, incident_ids: string[]): Promise<void> {
    logOperation('link-incidents-to-problem', {
      problem_sys_id,
      incident_count: incident_ids.length,
    });

    for (const incident_id of incident_ids) {
      await this.request('PATCH', `/api/now/table/incident/${incident_id}`, {
        problem_id: problem_sys_id,
      });
    }
  }

  async updateProblem(sys_id: string, data: Partial<Problem>): Promise<Problem> {
    logOperation('update-problem', { sys_id });

    const response = await this.request<ServiceNowSingleResponse<Problem>>(
      'PATCH',
      `/api/now/table/problem/${sys_id}`,
      data
    );

    return response.result;
  }

  async resolveProblem(sys_id: string, root_cause: string, workaround?: string): Promise<Problem> {
    logOperation('resolve-problem', { sys_id });

    const response = await this.request<ServiceNowSingleResponse<Problem>>(
      'PATCH',
      `/api/now/table/problem/${sys_id}`,
      {
        state: '5', // Resolved
        root_cause,
        workaround,
        resolved_at: new Date().toISOString(),
      }
    );

    return response.result;
  }

  // ===========================
  // Knowledge Base
  // ===========================

  async searchKnowledge(query: string, limit: number = 50): Promise<KnowledgeArticle[]> {
    logOperation('search-knowledge', { query, limit });

    const response = await this.request<ServiceNowListResponse<KnowledgeArticle>>(
      'GET',
      '/api/now/table/kb_knowledge',
      undefined,
      {
        sysparm_query: `short_descriptionLIKE${query}^ORtextLIKE${query}`,
        sysparm_limit: limit,
        sysparm_display_value: 'true',
      }
    );

    return response.result;
  }

  async createKBArticle(article: CreateKBArticleRequest): Promise<KnowledgeArticle> {
    validateRequired(article, ['short_description', 'text', 'kb_knowledge_base', 'author']);

    logOperation('create-kb-article', { short_description: article.short_description });

    const response = await this.request<ServiceNowSingleResponse<KnowledgeArticle>>(
      'POST',
      '/api/now/table/kb_knowledge',
      article
    );

    return response.result;
  }

  async updateKBArticle(
    sys_id: string,
    data: Partial<KnowledgeArticle>
  ): Promise<KnowledgeArticle> {
    logOperation('update-kb-article', { sys_id });

    const response = await this.request<ServiceNowSingleResponse<KnowledgeArticle>>(
      'PATCH',
      `/api/now/table/kb_knowledge/${sys_id}`,
      data
    );

    return response.result;
  }

  async getKBArticle(sys_id?: string, number?: string): Promise<KnowledgeArticle> {
    if (!sys_id && !number) {
      throw new ServiceNowError('Either sys_id or number is required', 400, 'MISSING_PARAMETER');
    }

    logOperation('get-kb-article', { sys_id, number });

    if (number) {
      const response = await this.request<ServiceNowListResponse<KnowledgeArticle>>(
        'GET',
        '/api/now/table/kb_knowledge',
        undefined,
        { sysparm_query: `number=${number}` }
      );
      if (response.result.length === 0) {
        throw new ServiceNowError('Knowledge article not found', 404, 'NOT_FOUND');
      }
      return response.result[0];
    } else {
      const response = await this.request<ServiceNowSingleResponse<KnowledgeArticle>>(
        'GET',
        `/api/now/table/kb_knowledge/${sys_id}`
      );
      return response.result;
    }
  }

  // ===========================
  // User and Group Operations
  // ===========================

  async getUserInfo(user_id?: string, user_name?: string): Promise<User> {
    if (!user_id && !user_name) {
      throw new ServiceNowError(
        'Either user_id or user_name is required',
        400,
        'MISSING_PARAMETER'
      );
    }

    logOperation('get-user-info', { user_id, user_name });

    if (user_name) {
      const response = await this.request<ServiceNowListResponse<User>>(
        'GET',
        '/api/now/table/sys_user',
        undefined,
        { sysparm_query: `user_name=${user_name}` }
      );
      if (response.result.length === 0) {
        throw new ServiceNowError('User not found', 404, 'NOT_FOUND');
      }
      return response.result[0];
    } else {
      const response = await this.request<ServiceNowSingleResponse<User>>(
        'GET',
        `/api/now/table/sys_user/${user_id}`
      );
      return response.result;
    }
  }

  async getGroupInfo(group_id?: string, group_name?: string): Promise<Group> {
    if (!group_id && !group_name) {
      throw new ServiceNowError(
        'Either group_id or group_name is required',
        400,
        'MISSING_PARAMETER'
      );
    }

    logOperation('get-group-info', { group_id, group_name });

    if (group_name) {
      const response = await this.request<ServiceNowListResponse<Group>>(
        'GET',
        '/api/now/table/sys_user_group',
        undefined,
        { sysparm_query: `name=${group_name}` }
      );
      if (response.result.length === 0) {
        throw new ServiceNowError('Group not found', 404, 'NOT_FOUND');
      }
      return response.result[0];
    } else {
      const response = await this.request<ServiceNowSingleResponse<Group>>(
        'GET',
        `/api/now/table/sys_user_group/${group_id}`
      );
      return response.result;
    }
  }

  async assignToGroup(
    task_sys_id: string,
    group_id: string,
    table: string = 'incident'
  ): Promise<void> {
    logOperation('assign-to-group', { task_sys_id, group_id, table });

    await this.request('PATCH', `/api/now/table/${table}/${task_sys_id}`, {
      assignment_group: group_id,
    });
  }

  // ===========================
  // Reporting and Metrics
  // ===========================

  async getIncidentMetrics(start_date?: string, end_date?: string): Promise<IncidentMetrics> {
    logOperation('get-incident-metrics', { start_date, end_date });

    let query = '';
    if (start_date && end_date) {
      query = `sys_created_onBETWEEN${start_date}@${end_date}`;
    }

    const response = await this.request<ServiceNowListResponse<Incident>>(
      'GET',
      '/api/now/table/incident',
      undefined,
      {
        sysparm_query: query,
        sysparm_display_value: 'true',
      }
    );

    const incidents = response.result;

    // Calculate metrics
    const metrics: IncidentMetrics = {
      total_incidents: incidents.length,
      open_incidents: incidents.filter((i) => ['1', '2', '3'].includes(i.state)).length,
      resolved_incidents: incidents.filter((i) => i.state === '6').length,
      closed_incidents: incidents.filter((i) => i.state === '7').length,
      avg_resolution_time: 0,
      breached_sla_count: 0,
      by_priority: {},
      by_state: {},
    };

    // Group by priority and state
    incidents.forEach((incident) => {
      metrics.by_priority[incident.priority] = (metrics.by_priority[incident.priority] || 0) + 1;
      metrics.by_state[incident.state] = (metrics.by_state[incident.state] || 0) + 1;
    });

    return metrics;
  }

  async getSLAStatus(task_sys_id: string): Promise<SLA[]> {
    logOperation('get-sla-status', { task_sys_id });

    const response = await this.request<ServiceNowListResponse<SLA>>(
      'GET',
      '/api/now/table/task_sla',
      undefined,
      {
        sysparm_query: `task=${task_sys_id}`,
        sysparm_display_value: 'true',
      }
    );

    return response.result;
  }

  async generateReport(report_type: string, filters?: Record<string, any>): Promise<any> {
    logOperation('generate-report', { report_type, filters });

    // This would integrate with ServiceNow's reporting API
    // Implementation depends on specific report requirements
    throw new ServiceNowError('Report generation not yet implemented', 501, 'NOT_IMPLEMENTED');
  }
}
