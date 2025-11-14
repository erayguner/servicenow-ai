import { Logging } from '@google-cloud/logging';
import { config } from '../config';

const logging = new Logging({ projectId: config.projectId });
const log = logging.log('ai-research-assistant-backend');

interface LogEntry {
  [key: string]: any;
}

export const logger = {
  info: (entry: LogEntry, message: string) => {
    const metadata = {
      resource: { type: 'cloud_run_revision' },
      severity: 'INFO',
    };
    const logEntry = log.entry(metadata, { message, ...entry });
    log.write(logEntry);

    // Also log to console in development
    if (config.nodeEnv === 'development') {
      console.log('[INFO]', message, entry);
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
      console.error('[ERROR]', message, entry);
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
      console.warn('[WARN]', message, entry);
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
        console.debug('[DEBUG]', message, entry);
      }
    }
  },
};
