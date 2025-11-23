/**
 * Custom Action Group Lambda Handler
 *
 * This example demonstrates a Lambda function that serves as an action group
 * for Bedrock Agents. It handles requests from agents and performs specific
 * business logic.
 */

import {
  APIGatewayProxyEvent,
  APIGatewayProxyResult,
  Context
} from 'aws-lambda';
import * as AWS from 'aws-sdk';
import * as crypto from 'crypto';

// Initialize AWS SDK clients
const dynamodb = new AWS.DynamoDB.DocumentClient();
const s3 = new AWS.S3();
const sns = new AWS.SNS();

/**
 * Request body structure for action group
 */
interface ActionRequest {
  action: string;
  parameters: Record<string, any>;
}

/**
 * Standard response structure
 */
interface ActionResponse {
  statusCode: number;
  body: {
    success: boolean;
    data?: any;
    error?: string;
    message?: string;
  };
}

/**
 * Create task action handler
 */
async function createTask(parameters: Record<string, any>): Promise<any> {
  const {
    title,
    description,
    priority = 'medium',
    assignee,
    dueDate
  } = parameters;

  if (!title || !description) {
    throw new Error('Missing required parameters: title, description');
  }

  const taskId = `TASK-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;

  const task = {
    id: taskId,
    title,
    description,
    priority,
    assignee: assignee || 'unassigned',
    status: 'open',
    createdAt: new Date().toISOString(),
    dueDate: dueDate || null,
    completedAt: null
  };

  try {
    await dynamodb.put({
      TableName: process.env.TASKS_TABLE || 'bedrock-tasks',
      Item: task
    }).promise();

    return {
      taskId,
      message: `Task created successfully`,
      task
    };
  } catch (error) {
    throw new Error(`Failed to create task: ${error}`);
  }
}

/**
 * Get tasks action handler
 */
async function getTasks(parameters: Record<string, any>): Promise<any> {
  const {
    status = 'open',
    assignee,
    limit = 10
  } = parameters;

  try {
    const scanParams: any = {
      TableName: process.env.TASKS_TABLE || 'bedrock-tasks',
      FilterExpression: 'taskStatus = :status',
      ExpressionAttributeValues: {
        ':status': status
      }
    };

    if (assignee) {
      scanParams.FilterExpression += ' AND assignee = :assignee';
      scanParams.ExpressionAttributeValues[':assignee'] = assignee;
    }

    const result = await dynamodb.scan({
      ...scanParams,
      Limit: limit
    }).promise();

    return {
      tasks: result.Items || [],
      count: result.Items?.length || 0,
      message: `Retrieved ${result.Items?.length || 0} tasks`
    };
  } catch (error) {
    throw new Error(`Failed to get tasks: ${error}`);
  }
}

/**
 * Update task action handler
 */
async function updateTask(parameters: Record<string, any>): Promise<any> {
  const {
    taskId,
    status,
    priority,
    assignee,
    notes
  } = parameters;

  if (!taskId) {
    throw new Error('Missing required parameter: taskId');
  }

  // Build update expression
  const updateParts: string[] = [];
  const expressionValues: Record<string, any> = {
    ':updatedAt': new Date().toISOString()
  };

  if (status) {
    updateParts.push('taskStatus = :status');
    expressionValues[':status'] = status;

    if (status === 'completed') {
      updateParts.push('completedAt = :completedAt');
      expressionValues[':completedAt'] = new Date().toISOString();
    }
  }

  if (priority) {
    updateParts.push('priority = :priority');
    expressionValues[':priority'] = priority;
  }

  if (assignee) {
    updateParts.push('assignee = :assignee');
    expressionValues[':assignee'] = assignee;
  }

  if (notes) {
    updateParts.push('notes = :notes');
    expressionValues[':notes'] = notes;
  }

  updateParts.push('updatedAt = :updatedAt');

  try {
    const result = await dynamodb.update({
      TableName: process.env.TASKS_TABLE || 'bedrock-tasks',
      Key: { id: taskId },
      UpdateExpression: `SET ${updateParts.join(', ')}`,
      ExpressionAttributeValues: expressionValues,
      ReturnValues: 'ALL_NEW'
    }).promise();

    return {
      taskId,
      message: 'Task updated successfully',
      task: result.Attributes
    };
  } catch (error) {
    throw new Error(`Failed to update task: ${error}`);
  }
}

/**
 * Send notification action handler
 */
async function sendNotification(parameters: Record<string, any>): Promise<any> {
  const {
    recipientEmail,
    subject,
    message,
    taskId
  } = parameters;

  if (!recipientEmail || !subject || !message) {
    throw new Error('Missing required parameters: recipientEmail, subject, message');
  }

  try {
    // Send via SNS
    const snsTopicArn = process.env.SNS_TOPIC_ARN;

    if (snsTopicArn) {
      await sns.publish({
        TopicArn: snsTopicArn,
        Subject: subject,
        Message: `${message}\n\n${taskId ? `Task ID: ${taskId}` : ''}`
      }).promise();
    }

    // In production, you might also send email via SES
    return {
      notificationId: `NOTIF-${Date.now()}`,
      recipient: recipientEmail,
      status: 'sent',
      message: 'Notification sent successfully'
    };
  } catch (error) {
    throw new Error(`Failed to send notification: ${error}`);
  }
}

/**
 * Store document action handler
 */
async function storeDocument(parameters: Record<string, any>): Promise<any> {
  const {
    filename,
    content,
    contentType = 'text/plain',
    metadata = {}
  } = parameters;

  if (!filename || !content) {
    throw new Error('Missing required parameters: filename, content');
  }

  const bucketName = process.env.DOCUMENTS_BUCKET || 'bedrock-documents';
  const key = `documents/${Date.now()}-${filename}`;

  try {
    await s3.putObject({
      Bucket: bucketName,
      Key: key,
      Body: Buffer.from(content),
      ContentType: contentType,
      Metadata: metadata
    }).promise();

    return {
      documentId: key,
      location: `s3://${bucketName}/${key}`,
      message: 'Document stored successfully'
    };
  } catch (error) {
    throw new Error(`Failed to store document: ${error}`);
  }
}

/**
 * Retrieve document action handler
 */
async function retrieveDocument(parameters: Record<string, any>): Promise<any> {
  const { documentId } = parameters;

  if (!documentId) {
    throw new Error('Missing required parameter: documentId');
  }

  const bucketName = process.env.DOCUMENTS_BUCKET || 'bedrock-documents';

  try {
    const object = await s3.getObject({
      Bucket: bucketName,
      Key: documentId
    }).promise();

    return {
      documentId,
      content: object.Body?.toString('utf-8'),
      contentType: object.ContentType,
      size: object.ContentLength,
      metadata: object.Metadata
    };
  } catch (error) {
    throw new Error(`Failed to retrieve document: ${error}`);
  }
}

/**
 * Search documents action handler
 */
async function searchDocuments(parameters: Record<string, any>): Promise<any> {
  const {
    query,
    limit = 10
  } = parameters;

  if (!query) {
    throw new Error('Missing required parameter: query');
  }

  const bucketName = process.env.DOCUMENTS_BUCKET || 'bedrock-documents';

  try {
    const objects = await s3.listObjectsV2({
      Bucket: bucketName,
      Prefix: 'documents/',
      MaxKeys: limit
    }).promise();

    const results = (objects.Contents || [])
      .filter(obj => {
        const key = obj.Key || '';
        return key.toLowerCase().includes(query.toLowerCase());
      })
      .map(obj => ({
        key: obj.Key,
        size: obj.Size,
        modified: obj.LastModified,
        url: `s3://${bucketName}/${obj.Key}`
      }));

    return {
      query,
      results,
      count: results.length
    };
  } catch (error) {
    throw new Error(`Failed to search documents: ${error}`);
  }
}

/**
 * Main Lambda handler
 */
export const handler = async (
  event: APIGatewayProxyEvent,
  context: Context
): Promise<APIGatewayProxyResult> => {
  console.log('Received event:', JSON.stringify(event, null, 2));

  try {
    // Parse request body
    const body = typeof event.body === 'string'
      ? JSON.parse(event.body)
      : event.body;

    const request: ActionRequest = body;

    if (!request.action) {
      return formatResponse(400, {
        success: false,
        error: 'Missing required field: action'
      });
    }

    let result;

    // Route to appropriate handler
    switch (request.action.toLowerCase()) {
      case 'create-task':
        result = await createTask(request.parameters);
        break;

      case 'get-tasks':
        result = await getTasks(request.parameters);
        break;

      case 'update-task':
        result = await updateTask(request.parameters);
        break;

      case 'send-notification':
        result = await sendNotification(request.parameters);
        break;

      case 'store-document':
        result = await storeDocument(request.parameters);
        break;

      case 'retrieve-document':
        result = await retrieveDocument(request.parameters);
        break;

      case 'search-documents':
        result = await searchDocuments(request.parameters);
        break;

      default:
        return formatResponse(400, {
          success: false,
          error: `Unknown action: ${request.action}`
        });
    }

    return formatResponse(200, {
      success: true,
      data: result,
      message: `Action '${request.action}' completed successfully`
    });

  } catch (error) {
    console.error('Error:', error);

    const message = error instanceof Error ? error.message : String(error);

    return formatResponse(500, {
      success: false,
      error: message
    });
  }
};

/**
 * Format response in standard structure
 */
function formatResponse(
  statusCode: number,
  body: any
): APIGatewayProxyResult {
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*'
    },
    body: JSON.stringify(body)
  };
}

/**
 * Health check handler (optional, for testing)
 */
export const healthCheck = async (
  event: APIGatewayProxyEvent
): Promise<APIGatewayProxyResult> => {
  return formatResponse(200, {
    success: true,
    message: 'Action group Lambda is healthy',
    timestamp: new Date().toISOString()
  });
};
