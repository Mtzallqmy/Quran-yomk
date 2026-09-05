import { ProcessingError } from './errors.js';

export type LogFields = Record<string, unknown>;

export class Logger {
  constructor(private readonly service = 'audio-worker') {}

  info(event: string, fields: LogFields = {}): void { this.write('INFO', event, fields); }
  warn(event: string, fields: LogFields = {}): void { this.write('WARN', event, fields); }
  error(event: string, error: unknown, fields: LogFields = {}): void {
    this.write('ERROR', event, { ...fields, error_code: error instanceof ProcessingError ? error.code : 'WORKER_INTERNAL_ERROR' });
  }

  private write(level: string, event: string, fields: LogFields): void {
    const sanitized = JSON.parse(JSON.stringify(fields, (key, value) =>
      /secret|password|credential|api.?key|token|authorization|signed_?url/i.test(key) ? '[REDACTED]' : value,
    )) as LogFields;
    process.stdout.write(`${JSON.stringify({ timestamp: new Date().toISOString(), service: this.service, level, event, ...sanitized })}\n`);
  }
}
