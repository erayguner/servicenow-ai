/**
 * LLM Telemetry Module
 *
 * Provides OpenTelemetry instrumentation for AI/LLM operations.
 * Tracks tokens, costs, latency, and errors for all LLM calls.
 */

import { trace, metrics, SpanStatusCode, Span } from '@opentelemetry/api';

// Initialize tracer and meter
const tracer = trace.getTracer('llm-gateway', '1.0.0');
const meter = metrics.getMeter('llm-gateway', '1.0.0');

// Define metrics
const tokenCounter = meter.createCounter('llm.tokens.total', {
  description: 'Total tokens consumed by LLM calls',
  unit: 'tokens',
});

const costCounter = meter.createCounter('llm.cost.usd', {
  description: 'Total cost of LLM calls in USD',
  unit: 'USD',
});

const requestCounter = meter.createCounter('llm.requests.total', {
  description: 'Total number of LLM requests',
  unit: 'requests',
});

const latencyHistogram = meter.createHistogram('llm.latency.ms', {
  description: 'LLM request latency',
  unit: 'ms',
});

const errorCounter = meter.createCounter('llm.errors.total', {
  description: 'Total number of LLM errors',
  unit: 'errors',
});

// Anthropic Claude pricing (per 1M tokens) - as of 2025
const PRICING = {
  'claude-3-5-sonnet-20241022': {
    input: 3.0, // $3 per 1M input tokens
    output: 15.0, // $15 per 1M output tokens
  },
  'claude-3-5-haiku-20241022': {
    input: 0.8, // $0.80 per 1M input tokens
    output: 4.0, // $4 per 1M output tokens
  },
  'claude-3-opus-20240229': {
    input: 15.0,
    output: 75.0,
  },
  default: {
    input: 3.0,
    output: 15.0,
  },
};

/**
 * Calculate cost based on token usage and model
 */
function calculateCost(model: string, inputTokens: number, outputTokens: number): number {
  const pricing = PRICING[model as keyof typeof PRICING] || PRICING.default;
  const inputCost = (inputTokens / 1_000_000) * pricing.input;
  const outputCost = (outputTokens / 1_000_000) * pricing.output;
  return inputCost + outputCost;
}

/**
 * Interface for LLM operation attributes
 */
export interface LLMOperationAttributes {
  model: string;
  operation: 'completion' | 'embedding' | 'function-call';
  userId?: string;
  sessionId?: string;
  temperature?: number;
  maxTokens?: number;
}

/**
 * Interface for LLM response metrics
 */
export interface LLMResponseMetrics {
  inputTokens: number;
  outputTokens: number;
  totalTokens: number;
  latencyMs: number;
  success: boolean;
  error?: string;
}

/**
 * Create a traced LLM operation
 *
 * Example usage:
 * ```typescript
 * const result = await traceLLMOperation(
 *   { model: 'claude-3-5-sonnet-20241022', operation: 'completion' },
 *   async (span) => {
 *     const response = await anthropic.messages.create({...});
 *     return {
 *       data: response,
 *       metrics: {
 *         inputTokens: response.usage.input_tokens,
 *         outputTokens: response.usage.output_tokens,
 *         totalTokens: response.usage.input_tokens + response.usage.output_tokens,
 *         latencyMs: Date.now() - startTime,
 *         success: true,
 *       }
 *     };
 *   }
 * );
 * ```
 */
export async function traceLLMOperation<T>(
  attributes: LLMOperationAttributes,
  fn: (span: Span) => Promise<{ data: T; metrics: LLMResponseMetrics }>
): Promise<T> {
  const startTime = Date.now();

  return tracer.startActiveSpan(
    `llm.${attributes.operation}`,
    {
      attributes: {
        'llm.model': attributes.model,
        'llm.operation': attributes.operation,
        ...(attributes.userId && { 'llm.user_id': attributes.userId }),
        ...(attributes.sessionId && { 'llm.session_id': attributes.sessionId }),
        ...(attributes.temperature && { 'llm.temperature': attributes.temperature }),
        ...(attributes.maxTokens && { 'llm.max_tokens': attributes.maxTokens }),
      },
    },
    async (span) => {
      try {
        const { data, metrics } = await fn(span);

        // Calculate cost
        const cost = calculateCost(attributes.model, metrics.inputTokens, metrics.outputTokens);

        // Add span attributes
        span.setAttributes({
          'llm.tokens.input': metrics.inputTokens,
          'llm.tokens.output': metrics.outputTokens,
          'llm.tokens.total': metrics.totalTokens,
          'llm.cost.usd': cost,
          'llm.latency.ms': metrics.latencyMs,
        });

        // Record metrics
        tokenCounter.add(metrics.inputTokens, {
          model: attributes.model,
          type: 'input',
          operation: attributes.operation,
        });

        tokenCounter.add(metrics.outputTokens, {
          model: attributes.model,
          type: 'output',
          operation: attributes.operation,
        });

        costCounter.add(cost, {
          model: attributes.model,
          operation: attributes.operation,
        });

        requestCounter.add(1, {
          model: attributes.model,
          operation: attributes.operation,
          status: 'success',
        });

        latencyHistogram.record(metrics.latencyMs, {
          model: attributes.model,
          operation: attributes.operation,
        });

        span.setStatus({ code: SpanStatusCode.OK });
        span.end();

        return data;
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : 'Unknown error';

        span.setStatus({
          code: SpanStatusCode.ERROR,
          message: errorMessage,
        });

        span.recordException(error as Error);

        errorCounter.add(1, {
          model: attributes.model,
          operation: attributes.operation,
          error: errorMessage,
        });

        requestCounter.add(1, {
          model: attributes.model,
          operation: attributes.operation,
          status: 'error',
        });

        span.end();
        throw error;
      }
    }
  );
}

/**
 * Record a prompt injection attempt
 */
export function recordPromptInjectionAttempt(
  userId: string,
  sessionId: string,
  severity: 'low' | 'medium' | 'high'
): void {
  const promptInjectionCounter = meter.createCounter('llm.security.prompt_injection', {
    description: 'Prompt injection attempts detected',
    unit: 'attempts',
  });

  promptInjectionCounter.add(1, {
    user_id: userId,
    session_id: sessionId,
    severity,
  });

  // Create a span for the security event
  const span = tracer.startSpan('llm.security.prompt_injection_detected');
  span.setAttributes({
    'security.event': 'prompt_injection',
    'security.severity': severity,
    'user.id': userId,
    'session.id': sessionId,
  });
  span.end();
}

/**
 * Record PII detection in prompts
 */
export function recordPIIDetection(userId: string, sessionId: string, piiTypes: string[]): void {
  const piiCounter = meter.createCounter('llm.security.pii_detected', {
    description: 'PII detected in prompts',
    unit: 'detections',
  });

  piiCounter.add(1, {
    user_id: userId,
    session_id: sessionId,
    pii_types: piiTypes.join(','),
  });

  const span = tracer.startSpan('llm.security.pii_detected');
  span.setAttributes({
    'security.event': 'pii_detected',
    'user.id': userId,
    'session.id': sessionId,
    'pii.types': piiTypes,
  });
  span.end();
}

export { tracer, meter };
