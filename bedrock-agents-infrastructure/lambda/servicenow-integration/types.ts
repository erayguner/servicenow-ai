/**
 * ServiceNow API Integration Types
 * Comprehensive type definitions for ServiceNow REST API v2
 */

// Base ServiceNow Record
export interface ServiceNowRecord {
  sys_id: string;
  sys_created_on: string;
  sys_updated_on: string;
  sys_created_by: string;
  sys_updated_by: string;
}

// Incident Types
export interface Incident extends ServiceNowRecord {
  number: string;
  short_description: string;
  description?: string;
  impact: '1' | '2' | '3'; // 1-High, 2-Medium, 3-Low
  urgency: '1' | '2' | '3';
  priority: '1' | '2' | '3' | '4' | '5';
  state: '1' | '2' | '3' | '6' | '7' | '8'; // 1-New, 2-In Progress, 3-On Hold, 6-Resolved, 7-Closed, 8-Canceled
  assigned_to?: string;
  assignment_group?: string;
  caller_id: string;
  category?: string;
  subcategory?: string;
  contact_type?: string;
  comments?: string;
  work_notes?: string;
  close_notes?: string;
  close_code?: string;
  resolved_at?: string;
  closed_at?: string;
}

export interface CreateIncidentRequest {
  short_description: string;
  description?: string;
  caller_id: string;
  impact?: '1' | '2' | '3';
  urgency?: '1' | '2' | '3';
  category?: string;
  subcategory?: string;
  assignment_group?: string;
  assigned_to?: string;
}

export interface UpdateIncidentRequest {
  sys_id: string;
  short_description?: string;
  description?: string;
  state?: string;
  assigned_to?: string;
  assignment_group?: string;
  work_notes?: string;
  comments?: string;
}

// Ticket Types (Generic)
export interface Ticket extends ServiceNowRecord {
  number: string;
  short_description: string;
  description?: string;
  state: string;
  assigned_to?: string;
  assignment_group?: string;
  priority: string;
}

// Change Request Types
export interface ChangeRequest extends ServiceNowRecord {
  number: string;
  short_description: string;
  description?: string;
  type: 'standard' | 'normal' | 'emergency';
  risk: '1' | '2' | '3' | '4'; // 1-High, 2-Medium, 3-Low, 4-Planning
  impact: '1' | '2' | '3';
  state: 'new' | 'assess' | 'authorize' | 'scheduled' | 'implement' | 'review' | 'closed';
  approval: 'not requested' | 'requested' | 'approved' | 'rejected';
  assignment_group?: string;
  assigned_to?: string;
  start_date?: string;
  end_date?: string;
  implementation_plan?: string;
  backout_plan?: string;
  test_plan?: string;
}

export interface CreateChangeRequest {
  short_description: string;
  description?: string;
  type: 'standard' | 'normal' | 'emergency';
  risk?: string;
  impact?: string;
  assignment_group?: string;
  requested_by: string;
  start_date?: string;
  end_date?: string;
}

// Problem Types
export interface Problem extends ServiceNowRecord {
  number: string;
  short_description: string;
  description?: string;
  state: '1' | '2' | '3' | '4' | '5'; // 1-New, 2-Assess, 3-RCA, 4-Fix in Progress, 5-Resolved
  impact: '1' | '2' | '3';
  urgency: '1' | '2' | '3';
  priority: '1' | '2' | '3' | '4' | '5';
  assigned_to?: string;
  assignment_group?: string;
  root_cause?: string;
  workaround?: string;
  related_incidents?: string[];
}

// Knowledge Base Types
export interface KnowledgeArticle extends ServiceNowRecord {
  number: string;
  short_description: string;
  text: string;
  kb_knowledge_base: string;
  kb_category?: string;
  workflow_state: 'draft' | 'published' | 'retired';
  author: string;
  valid_to?: string;
  rating?: number;
  views?: number;
}

export interface CreateKBArticleRequest {
  short_description: string;
  text: string;
  kb_knowledge_base: string;
  kb_category?: string;
  author: string;
}

// User and Group Types
export interface User extends ServiceNowRecord {
  user_name: string;
  first_name: string;
  last_name: string;
  email: string;
  phone?: string;
  title?: string;
  department?: string;
  location?: string;
  active: boolean;
}

export interface Group extends ServiceNowRecord {
  name: string;
  description?: string;
  type?: string;
  active: boolean;
  manager?: string;
}

// SLA Types
export interface SLA {
  sys_id: string;
  task: string;
  sla_definition: string;
  start_time: string;
  end_time?: string;
  duration: string;
  percentage: number;
  business_percentage: number;
  has_breached: boolean;
  schedule?: string;
}

// Metrics and Reporting Types
export interface IncidentMetrics {
  total_incidents: number;
  open_incidents: number;
  resolved_incidents: number;
  closed_incidents: number;
  avg_resolution_time: number;
  breached_sla_count: number;
  by_priority: {
    [key: string]: number;
  };
  by_state: {
    [key: string]: number;
  };
}

export interface ReportRequest {
  report_type: 'incident_summary' | 'sla_compliance' | 'change_success_rate' | 'problem_analysis';
  start_date: string;
  end_date: string;
  filters?: Record<string, any>;
}

// Lambda Event Types
export interface ServiceNowLambdaEvent {
  action: string;
  parameters: Record<string, any>;
  requestId?: string;
  timestamp?: string;
}

// Action-specific parameter types
export interface IncidentActionParams {
  action:
    | 'create-incident'
    | 'update-incident'
    | 'resolve-incident'
    | 'get-incident'
    | 'search-incidents'
    | 'assign-incident'
    | 'add-comment';
  sys_id?: string;
  number?: string;
  incident?: Partial<Incident>;
  query?: string;
  assigned_to?: string;
  assignment_group?: string;
  comment?: string;
  work_notes?: string;
  resolution_notes?: string;
  close_code?: string;
}

export interface TicketActionParams {
  action:
    | 'create-ticket'
    | 'update-ticket'
    | 'close-ticket'
    | 'get-ticket-status'
    | 'add-work-notes';
  table?: string; // incident, problem, change_request, etc.
  sys_id?: string;
  number?: string;
  ticket?: Partial<Ticket>;
  work_notes?: string;
  close_notes?: string;
}

export interface ChangeActionParams {
  action:
    | 'create-change-request'
    | 'update-change-request'
    | 'assess-change-risk'
    | 'approve-change'
    | 'schedule-change';
  sys_id?: string;
  number?: string;
  change?: Partial<ChangeRequest>;
  approval_state?: string;
  start_date?: string;
  end_date?: string;
}

export interface ProblemActionParams {
  action: 'create-problem' | 'link-incidents-to-problem' | 'update-problem' | 'resolve-problem';
  sys_id?: string;
  number?: string;
  problem?: Partial<Problem>;
  incident_ids?: string[];
  root_cause?: string;
  workaround?: string;
}

export interface KnowledgeActionParams {
  action: 'search-knowledge' | 'create-kb-article' | 'update-kb-article' | 'get-kb-article';
  sys_id?: string;
  number?: string;
  article?: Partial<KnowledgeArticle>;
  search_query?: string;
}

export interface UserGroupActionParams {
  action: 'get-user-info' | 'get-group-info' | 'assign-to-group';
  user_id?: string;
  user_name?: string;
  group_id?: string;
  group_name?: string;
  task_sys_id?: string;
}

export interface ReportingActionParams {
  action: 'get-incident-metrics' | 'get-sla-status' | 'generate-report';
  start_date?: string;
  end_date?: string;
  task_sys_id?: string;
  report_type?: string;
  filters?: Record<string, any>;
}

// Response Types
export interface ServiceNowResponse<T = any> {
  success: boolean;
  data?: T;
  error?: string;
  statusCode: number;
  message?: string;
}

export interface ServiceNowListResponse<T> {
  result: T[];
}

export interface ServiceNowSingleResponse<T> {
  result: T;
}

// Authentication Types
export interface ServiceNowCredentials {
  instance: string;
  username?: string;
  password?: string;
  clientId?: string;
  clientSecret?: string;
  accessToken?: string;
  refreshToken?: string;
  authType: 'basic' | 'oauth';
}

export interface OAuthTokenResponse {
  access_token: string;
  refresh_token: string;
  scope: string;
  token_type: string;
  expires_in: number;
}

// Rate Limiting Types
export interface RateLimitConfig {
  maxRequests: number;
  windowMs: number;
  enabled: boolean;
}

// Error Types
export class ServiceNowError extends Error {
  constructor(
    message: string,
    public statusCode: number,
    public errorCode?: string,
    public details?: any
  ) {
    super(message);
    this.name = 'ServiceNowError';
  }
}

// API Client Configuration
export interface ServiceNowClientConfig {
  credentials: ServiceNowCredentials;
  rateLimitConfig?: RateLimitConfig;
  timeout?: number;
  maxRetries?: number;
  retryDelay?: number;
  logLevel?: 'debug' | 'info' | 'warn' | 'error';
}
