/**
 * OpenTelemetry Instrumentation
 *
 * This module initializes OpenTelemetry for distributed tracing and metrics.
 * Must be imported BEFORE any other modules to ensure auto-instrumentation works.
 *
 * Features:
 * - Auto-instrumentation for Express.js, HTTP, PostgreSQL, etc.
 * - OTLP gRPC exporters for traces and metrics
 * - Resource attributes (service name, version, environment)
 * - Batch span processor for performance
 */

import { NodeSDK } from '@opentelemetry/sdk-node';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-grpc';
import { OTLPMetricExporter } from '@opentelemetry/exporter-metrics-otlp-grpc';
import { PeriodicExportingMetricReader } from '@opentelemetry/sdk-metrics';
import { Resource } from '@opentelemetry/resources';
import {
  ATTR_SERVICE_NAME,
  ATTR_SERVICE_VERSION,
  ATTR_DEPLOYMENT_ENVIRONMENT,
} from '@opentelemetry/semantic-conventions';

// Environment configuration
const OTEL_COLLECTOR_URL =
  process.env.OTEL_COLLECTOR_URL || 'http://opentelemetry-collector.observability:4317';
const SERVICE_NAME = process.env.SERVICE_NAME || 'ai-backend';
const SERVICE_VERSION = process.env.SERVICE_VERSION || '1.0.0';
const ENVIRONMENT = process.env.NODE_ENV || 'development';

// Create resource with service information
const resource = new Resource({
  [ATTR_SERVICE_NAME]: SERVICE_NAME,
  [ATTR_SERVICE_VERSION]: SERVICE_VERSION,
  [ATTR_DEPLOYMENT_ENVIRONMENT]: ENVIRONMENT,
});

// Configure trace exporter
const traceExporter = new OTLPTraceExporter({
  url: OTEL_COLLECTOR_URL,
});

// Configure metric exporter
const metricReader = new PeriodicExportingMetricReader({
  exporter: new OTLPMetricExporter({
    url: OTEL_COLLECTOR_URL,
  }),
  exportIntervalMillis: 60000, // Export every 60 seconds
});

// Initialize OpenTelemetry SDK
const sdk = new NodeSDK({
  resource,
  traceExporter,
  metricReader,
  instrumentations: [
    getNodeAutoInstrumentations({
      // Configure auto-instrumentation
      '@opentelemetry/instrumentation-http': {
        // Capture HTTP headers
        requestHook: (span, request) => {
          span.setAttribute('http.request.user_agent', request.headers['user-agent'] || 'unknown');
        },
      },
      '@opentelemetry/instrumentation-express': {
        // Express-specific instrumentation
        requestHook: (span, requestInfo) => {
          span.setAttribute('express.route', requestInfo.route || 'unknown');
        },
      },
      '@opentelemetry/instrumentation-pg': {
        // PostgreSQL instrumentation
        enhancedDatabaseReporting: true,
      },
      // Disable DNS instrumentation (can be noisy)
      '@opentelemetry/instrumentation-dns': {
        enabled: false,
      },
    }),
  ],
});

// Graceful shutdown
process.on('SIGTERM', () => {
  sdk
    .shutdown()
    .then(() => console.log('OpenTelemetry shut down successfully'))
    .catch((error) => console.error('Error shutting down OpenTelemetry', error))
    .finally(() => process.exit(0));
});

// Start the SDK
void sdk.start().catch((error) =>
  console.error('OpenTelemetry failed to start', error)
);
console.log(`OpenTelemetry initialized for ${SERVICE_NAME} (${ENVIRONMENT})`);
console.log(`Exporting to: ${OTEL_COLLECTOR_URL}`);

export default sdk;
