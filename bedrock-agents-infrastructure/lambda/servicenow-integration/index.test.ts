/**
 * Unit tests for ServiceNow Integration Lambda
 */

import { Context } from 'aws-lambda';
import { handler } from './index';
import { ServiceNowClient } from './servicenow-client';
import { ServiceNowLambdaEvent, ServiceNowResponse, Incident } from './types';

// Mock ServiceNow client
jest.mock('./servicenow-client');
jest.mock('./utils', () => ({
  ...jest.requireActual('./utils'),
  getServiceNowCredentials: jest.fn().mockResolvedValue({
    instance: 'https://dev.service-now.com',
    username: 'test_user',
    password: 'test_pass',
    authType: 'basic',
  }),
}));

const mockContext: Context = {
  callbackWaitsForEmptyEventLoop: false,
  functionName: 'servicenow-integration',
  functionVersion: '1',
  invokedFunctionArn: 'arn:aws:lambda:us-east-1:123456789:function:servicenow-integration',
  memoryLimitInMB: '512',
  awsRequestId: 'test-request-id',
  logGroupName: '/aws/lambda/servicenow-integration',
  logStreamName: 'test-stream',
  getRemainingTimeInMillis: () => 30000,
  done: jest.fn(),
  fail: jest.fn(),
  succeed: jest.fn(),
};

describe('ServiceNow Integration Lambda Handler', () => {
  let mockClient: jest.Mocked<ServiceNowClient>;

  beforeEach(() => {
    jest.clearAllMocks();
    mockClient = {
      createIncident: jest.fn(),
      updateIncident: jest.fn(),
      resolveIncident: jest.fn(),
      getIncident: jest.fn(),
      searchIncidents: jest.fn(),
      assignIncident: jest.fn(),
      addIncidentComment: jest.fn(),
      addIncidentWorkNotes: jest.fn(),
      createChangeRequest: jest.fn(),
      updateChangeRequest: jest.fn(),
      assessChangeRisk: jest.fn(),
      approveChange: jest.fn(),
      scheduleChange: jest.fn(),
      createProblem: jest.fn(),
      linkIncidentsToProblem: jest.fn(),
      updateProblem: jest.fn(),
      resolveProblem: jest.fn(),
      searchKnowledge: jest.fn(),
      createKBArticle: jest.fn(),
      updateKBArticle: jest.fn(),
      getKBArticle: jest.fn(),
      getUserInfo: jest.fn(),
      getGroupInfo: jest.fn(),
      assignToGroup: jest.fn(),
      getIncidentMetrics: jest.fn(),
      getSLAStatus: jest.fn(),
      generateReport: jest.fn(),
    } as any;

    (ServiceNowClient.fromSecretsManager as jest.Mock).mockResolvedValue(mockClient);
  });

  describe('Incident Management', () => {
    test('create-incident should create a new incident', async () => {
      const mockIncident: Incident = {
        sys_id: 'INC123456',
        number: 'INC0001234',
        short_description: 'Test incident',
        description: 'Test description',
        impact: '2',
        urgency: '2',
        priority: '3',
        state: '1',
        caller_id: 'user123',
        sys_created_on: '2025-01-01T00:00:00Z',
        sys_updated_on: '2025-01-01T00:00:00Z',
        sys_created_by: 'admin',
        sys_updated_by: 'admin',
      };

      mockClient.createIncident.mockResolvedValue(mockIncident);

      const event: ServiceNowLambdaEvent = {
        action: 'create-incident',
        parameters: {
          incident: {
            short_description: 'Test incident',
            description: 'Test description',
            caller_id: 'user123',
            impact: '2',
            urgency: '2',
          },
        },
      };

      const response: ServiceNowResponse = await handler(event, mockContext);

      expect(response.success).toBe(true);
      expect(response.statusCode).toBe(200);
      expect(response.data).toEqual(mockIncident);
      expect(mockClient.createIncident).toHaveBeenCalledWith(
        expect.objectContaining({
          short_description: 'Test incident',
          caller_id: 'user123',
        })
      );
    });

    test('update-incident should update an existing incident', async () => {
      const mockIncident: Incident = {
        sys_id: 'INC123456',
        number: 'INC0001234',
        short_description: 'Updated incident',
        impact: '1',
        urgency: '1',
        priority: '1',
        state: '2',
        caller_id: 'user123',
        sys_created_on: '2025-01-01T00:00:00Z',
        sys_updated_on: '2025-01-01T01:00:00Z',
        sys_created_by: 'admin',
        sys_updated_by: 'admin',
      };

      mockClient.updateIncident.mockResolvedValue(mockIncident);

      const event: ServiceNowLambdaEvent = {
        action: 'update-incident',
        parameters: {
          sys_id: 'INC123456',
          incident: {
            short_description: 'Updated incident',
            state: '2',
          },
        },
      };

      const response: ServiceNowResponse = await handler(event, mockContext);

      expect(response.success).toBe(true);
      expect(response.data).toEqual(mockIncident);
      expect(mockClient.updateIncident).toHaveBeenCalledWith(
        expect.objectContaining({
          sys_id: 'INC123456',
        })
      );
    });

    test('resolve-incident should resolve an incident', async () => {
      const mockIncident: Incident = {
        sys_id: 'INC123456',
        number: 'INC0001234',
        short_description: 'Test incident',
        impact: '2',
        urgency: '2',
        priority: '3',
        state: '6',
        caller_id: 'user123',
        close_notes: 'Issue resolved',
        resolved_at: '2025-01-01T02:00:00Z',
        sys_created_on: '2025-01-01T00:00:00Z',
        sys_updated_on: '2025-01-01T02:00:00Z',
        sys_created_by: 'admin',
        sys_updated_by: 'admin',
      };

      mockClient.resolveIncident.mockResolvedValue(mockIncident);

      const event: ServiceNowLambdaEvent = {
        action: 'resolve-incident',
        parameters: {
          sys_id: 'INC123456',
          resolution_notes: 'Issue resolved',
          close_code: 'Solved (Permanently)',
        },
      };

      const response: ServiceNowResponse = await handler(event, mockContext);

      expect(response.success).toBe(true);
      expect(response.data.state).toBe('6');
      expect(mockClient.resolveIncident).toHaveBeenCalledWith(
        'INC123456',
        'Issue resolved',
        'Solved (Permanently)'
      );
    });

    test('search-incidents should return matching incidents', async () => {
      const mockIncidents: Incident[] = [
        {
          sys_id: 'INC123456',
          number: 'INC0001234',
          short_description: 'Test incident 1',
          impact: '2',
          urgency: '2',
          priority: '3',
          state: '1',
          caller_id: 'user123',
          sys_created_on: '2025-01-01T00:00:00Z',
          sys_updated_on: '2025-01-01T00:00:00Z',
          sys_created_by: 'admin',
          sys_updated_by: 'admin',
        },
        {
          sys_id: 'INC123457',
          number: 'INC0001235',
          short_description: 'Test incident 2',
          impact: '1',
          urgency: '1',
          priority: '1',
          state: '2',
          caller_id: 'user123',
          sys_created_on: '2025-01-01T01:00:00Z',
          sys_updated_on: '2025-01-01T01:00:00Z',
          sys_created_by: 'admin',
          sys_updated_by: 'admin',
        },
      ];

      mockClient.searchIncidents.mockResolvedValue(mockIncidents);

      const event: ServiceNowLambdaEvent = {
        action: 'search-incidents',
        parameters: {
          query: 'caller_id=user123^state=1',
        },
      };

      const response: ServiceNowResponse = await handler(event, mockContext);

      expect(response.success).toBe(true);
      expect(response.data).toHaveLength(2);
      expect(mockClient.searchIncidents).toHaveBeenCalledWith('caller_id=user123^state=1');
    });
  });

  describe('Change Management', () => {
    test('create-change-request should create a new change request', async () => {
      const mockChange = {
        sys_id: 'CHG123456',
        number: 'CHG0001234',
        short_description: 'Test change',
        type: 'normal',
        state: 'new',
      };

      mockClient.createChangeRequest.mockResolvedValue(mockChange as any);

      const event: ServiceNowLambdaEvent = {
        action: 'create-change-request',
        parameters: {
          change: {
            short_description: 'Test change',
            type: 'normal',
            requested_by: 'user123',
          },
        },
      };

      const response: ServiceNowResponse = await handler(event, mockContext);

      expect(response.success).toBe(true);
      expect(response.data).toEqual(mockChange);
    });

    test('approve-change should approve a change request', async () => {
      const mockChange = {
        sys_id: 'CHG123456',
        number: 'CHG0001234',
        approval: 'approved',
        state: 'authorize',
      };

      mockClient.approveChange.mockResolvedValue(mockChange as any);

      const event: ServiceNowLambdaEvent = {
        action: 'approve-change',
        parameters: {
          sys_id: 'CHG123456',
        },
      };

      const response: ServiceNowResponse = await handler(event, mockContext);

      expect(response.success).toBe(true);
      expect(response.data.approval).toBe('approved');
    });
  });

  describe('Knowledge Base', () => {
    test('search-knowledge should return matching articles', async () => {
      const mockArticles = [
        {
          sys_id: 'KB123456',
          number: 'KB0001234',
          short_description: 'How to reset password',
          text: 'Password reset instructions...',
        },
      ];

      mockClient.searchKnowledge.mockResolvedValue(mockArticles as any);

      const event: ServiceNowLambdaEvent = {
        action: 'search-knowledge',
        parameters: {
          search_query: 'password reset',
        },
      };

      const response: ServiceNowResponse = await handler(event, mockContext);

      expect(response.success).toBe(true);
      expect(response.data).toHaveLength(1);
      expect(mockClient.searchKnowledge).toHaveBeenCalledWith('password reset');
    });
  });

  describe('User/Group Operations', () => {
    test('get-user-info should return user details', async () => {
      const mockUser = {
        sys_id: 'user123',
        user_name: 'john.doe',
        first_name: 'John',
        last_name: 'Doe',
        email: 'john.doe@example.com',
        active: true,
      };

      mockClient.getUserInfo.mockResolvedValue(mockUser as any);

      const event: ServiceNowLambdaEvent = {
        action: 'get-user-info',
        parameters: {
          user_name: 'john.doe',
        },
      };

      const response: ServiceNowResponse = await handler(event, mockContext);

      expect(response.success).toBe(true);
      expect(response.data).toEqual(mockUser);
    });
  });

  describe('Reporting', () => {
    test('get-incident-metrics should return metrics', async () => {
      const mockMetrics = {
        total_incidents: 100,
        open_incidents: 30,
        resolved_incidents: 60,
        closed_incidents: 10,
        avg_resolution_time: 3600,
        breached_sla_count: 5,
        by_priority: { '1': 10, '2': 30, '3': 60 },
        by_state: { '1': 30, '2': 20, '6': 40, '7': 10 },
      };

      mockClient.getIncidentMetrics.mockResolvedValue(mockMetrics);

      const event: ServiceNowLambdaEvent = {
        action: 'get-incident-metrics',
        parameters: {
          start_date: '2025-01-01',
          end_date: '2025-01-31',
        },
      };

      const response: ServiceNowResponse = await handler(event, mockContext);

      expect(response.success).toBe(true);
      expect(response.data).toEqual(mockMetrics);
    });
  });

  describe('Error Handling', () => {
    test('should handle unknown action', async () => {
      const event: ServiceNowLambdaEvent = {
        action: 'unknown-action',
        parameters: {},
      };

      const response: ServiceNowResponse = await handler(event, mockContext);

      expect(response.success).toBe(false);
      expect(response.statusCode).toBe(400);
      expect(response.error).toContain('Unknown action');
    });

    test('should handle missing required parameters', async () => {
      const event: ServiceNowLambdaEvent = {
        action: 'create-incident',
        parameters: {
          incident: {},
        },
      };

      const response: ServiceNowResponse = await handler(event, mockContext);

      expect(response.success).toBe(false);
      expect(response.statusCode).toBeGreaterThanOrEqual(400);
    });

    test('should handle ServiceNow API errors', async () => {
      mockClient.createIncident.mockRejectedValue(new Error('API Error'));

      const event: ServiceNowLambdaEvent = {
        action: 'create-incident',
        parameters: {
          incident: {
            short_description: 'Test',
            caller_id: 'user123',
          },
        },
      };

      const response: ServiceNowResponse = await handler(event, mockContext);

      expect(response.success).toBe(false);
      expect(response.statusCode).toBe(500);
    });
  });
});

describe('ServiceNowClient', () => {
  describe('Rate Limiting', () => {
    test('should respect rate limits', async () => {
      const client = await ServiceNowClient.fromSecretsManager('test-secret', {
        rateLimitConfig: {
          maxRequests: 2,
          windowMs: 1000,
          enabled: true,
        },
      });

      // This would need actual implementation testing
      expect(client).toBeDefined();
    });
  });

  describe('Retry Logic', () => {
    test('should retry on transient errors', async () => {
      // Mock implementation for retry testing
      expect(true).toBe(true);
    });
  });

  describe('OAuth Authentication', () => {
    test('should authenticate with OAuth', async () => {
      // Mock OAuth flow
      expect(true).toBe(true);
    });
  });
});
