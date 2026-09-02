import assert from 'node:assert/strict';
import test from 'node:test';
import { rateLimitBucket } from '../lib/distributed-rate-limit.ts';
import { requireSensitiveAdmin, type AdminContext } from '../lib/auth.ts';

function ctx(aal:'aal1'|'aal2'|null):AdminContext{
  return{userId:'00000000-0000-4000-8000-000000000001',email:'admin@example.invalid',displayName:'Admin',roles:['SUPER_ADMIN'],permissions:new Set(['radio.command']),aal,sessionId:'session-test'};
}

test('distributed rate-limit buckets never persist the raw subject',()=>{
  const subject='203.0.113.42';
  const bucket=rateLimitBucket('login',subject);
  assert.match(bucket,/^[a-f0-9]{64}$/);
  assert.equal(bucket.includes(subject),false);
  assert.equal(bucket,rateLimitBucket('login',subject));
  assert.notEqual(bucket,rateLimitBucket('search',subject));
});

test('MFA readiness mode does not break development by default',()=>{
  const previousMode=process.env.TARTEEL_ADMIN_MFA_MODE;
  const previousEnvironment=process.env.TARTEEL_ENVIRONMENT;
  delete process.env.TARTEEL_ADMIN_MFA_MODE;
  process.env.TARTEEL_ENVIRONMENT='development';
  assert.doesNotThrow(()=>requireSensitiveAdmin(ctx('aal1')));
  if(previousMode===undefined)delete process.env.TARTEEL_ADMIN_MFA_MODE;else process.env.TARTEEL_ADMIN_MFA_MODE=previousMode;
  if(previousEnvironment===undefined)delete process.env.TARTEEL_ENVIRONMENT;else process.env.TARTEEL_ENVIRONMENT=previousEnvironment;
});

test('required MFA mode fails closed unless the validated session is aal2',()=>{
  const previous=process.env.TARTEEL_ADMIN_MFA_MODE;
  process.env.TARTEEL_ADMIN_MFA_MODE='required';
  assert.throws(()=>requireSensitiveAdmin(ctx('aal1')),(error:any)=>error?.code==='MFA_REQUIRED');
  assert.throws(()=>requireSensitiveAdmin(ctx(null)),(error:any)=>error?.code==='MFA_REQUIRED');
  assert.doesNotThrow(()=>requireSensitiveAdmin(ctx('aal2')));
  if(previous===undefined)delete process.env.TARTEEL_ADMIN_MFA_MODE;else process.env.TARTEEL_ADMIN_MFA_MODE=previous;
});
