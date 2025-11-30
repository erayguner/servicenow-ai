import { Logging } from '@google-cloud/logging';
import { config } from '../config';

const logging = new Logging({ projectId: config.projectId });
const log = logging.log('ai-research-assistant-backend');

interface LogEntry {
  [key: string]: any;
}

// Sensitive field patterns to redact from console logs
const SENSITIVE_FIELDS = [
  'password',
  'passwd',
  'pwd',
  'secret',
  'token',
  'apikey',
  'api_key',
  'authorization',
  'auth',
  'cookie',
  'session',
  'private',
  'credential',
  'credit_card',
  'ssn',
  'social_security',
];

/**
 * Sanitize log entry by redacting sensitive fields for console output
 * This prevents sensitive data from being exposed in clear text logs
 */
function sanitizeForConsole(entry: LogEntry): LogEntry {
  const sanitized: LogEntry = {};

  for (const [key, value] of Object.entries(entry)) {
    const lowerKey = key.toLowerCase();
    const isSensitive = SENSITIVE_FIELDS.some((field) => lowerKey.includes(field));

    if (isSensitive) {
      sanitized[key] = '[REDACTED]';
    } else if (value && typeof value === 'object' && !Array.isArray(value)) {
      // Recursively sanitize nested objects
      sanitized[key] = sanitizeForConsole(value);
    } else {
      sanitized[key] = value;
    }
  }

  return sanitized;
}

export const logger = {
  info: (entry: LogEntry, message: string) => {
    const metadata = {
      resource: { type: 'cloud_run_revision' },
      severity: 'INFO',
    };
    const logEntry = log.entry(metadata, { message, ...entry });
    log.write(logEntry);

    // Also log to console in development (with sanitization)
    if (config.nodeEnv === 'development') {
      console.log('[INFO]', message, sanitizeForConsole(entry));
    }
  },

  error: (entry: LogEntry, message: string) => {
    const metadata = {
      resource: { type: 'cloud_run_revision' },
      severity: 'ERROR',
    };
    const logEntry = log.entry(metadata, { message, ...entry });
    log.write(logEntry);

    if (config.nodeEnv === 'development') {
      console.error('[ERROR]', message, sanitizeForConsole(entry));
    }
  },

  warn: (entry: LogEntry, message: string) => {
    const metadata = {
      resource: { type: 'cloud_run_revision' },
      severity: 'WARNING',
    };
    const logEntry = log.entry(metadata, { message, ...entry });
    log.write(logEntry);

    if (config.nodeEnv === 'development') {
      console.warn('[WARN]', message, sanitizeForConsole(entry));
    }
  },

  debug: (entry: LogEntry, message: string) => {
    if (config.logLevel === 'debug') {
      const metadata = {
        resource: { type: 'cloud_run_revision' },
        severity: 'DEBUG',
      };
      const logEntry = log.entry(metadata, { message, ...entry });
      log.write(logEntry);

      if (config.nodeEnv === 'development') {
        console.debug('[DEBUG]', message, sanitizeForConsole(entry));
      }
    }
  },
};
