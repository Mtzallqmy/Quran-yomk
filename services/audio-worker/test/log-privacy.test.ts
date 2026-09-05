import test from 'node:test';
import assert from 'node:assert/strict';
import { Logger } from '../src/logger.js';

test('structured logs never include raw exception messages or credential fields', t => {
  const output:string[]=[];
  t.mock.method(process.stdout,'write',(chunk:unknown)=>{output.push(String(chunk));return true;});
  new Logger().error('OPERATION_FAILED',new Error('provider-private-message'),{password:'private-password',api_key:'private-key',nested:{authorization:'private-token'}});
  assert.ok(!output.join('').includes('private'));
  assert.ok(output.join('').includes('OPERATION_FAILED'));
});
