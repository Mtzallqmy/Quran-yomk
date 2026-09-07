import test from 'node:test';
import assert from 'node:assert/strict';
import { handleNotifications, notificationPath, validPushRoute } from '../notifications/index.ts';

test('push deep links are an explicit allowlist',()=>{
  for(const route of ['/home','/prayer-times','/adhkar','/radio','/reciters','/quran','/library','/custom-reminders'])assert.equal(validPushRoute(route),true);
  for(const route of ['https://evil.test','javascript:alert(1)','/admin','../quran',null])assert.equal(validPushRoute(route),false);
});

test('deployed function prefix is stripped once for nested notification routes',()=>{
  assert.equal(notificationPath('https://project.supabase.co/functions/v1/notifications/admin/notifications'),'/admin/notifications');
  assert.equal(notificationPath('https://edge.test/notifications/admin/notifications/id/retry'),'/admin/notifications/id/retry');
  assert.equal(notificationPath('https://edge.test/notifications/devices/register'),'/devices/register');
});

test('guest device registration reaches PostgREST and creates preferences',async t=>{
  const installation='00000000-0000-4000-8000-000000000111';
  const device='00000000-0000-4000-8000-000000000112';
  const writes=[];
  t.mock.method(globalThis,'fetch',async(input,init={})=>{
    const url=String(input);
    if(url.endsWith('/rpc/consume_rate_limit'))return Response.json(true);
    if(url.includes('/user_devices?installation_id='))return Response.json([]);
    if(url.includes('/user_devices?fcm_token='))return Response.json([]);
    if(url.includes('/user_devices?on_conflict=')){writes.push(JSON.parse(init.body));return Response.json([{id:device}]);}
    if(url.includes('/notification_preferences?on_conflict='))return Response.json([{device_id:device}]);
    throw new Error(`unexpected ${url}`);
  });
  const result=await handleNotifications(new Request('https://project.supabase.co/functions/v1/notifications/devices/register',{method:'POST',body:JSON.stringify({installation_id:installation,installation_secret:'a'.repeat(64),fcm_token:'actual-shaped-fcm-token-value-123456789',platform:'android',app_version:'1.0.0',locale:'ar',timezone:'Asia/Aden',notifications_enabled:true})}),env({SUPABASE_URL:'https://example.supabase.co',SUPABASE_SERVICE_ROLE_KEY:'server-key'}));
  assert.equal(result.status,200);
  assert.equal((await result.json()).data.device_id,device);
  assert.equal(writes[0].notifications_enabled,true);
});

const env=values=>name=>values[name];
test('cron and malformed device requests fail closed',async t=>{
  const values={SUPABASE_URL:'https://example.supabase.co',SUPABASE_SERVICE_ROLE_KEY:'server-key',NOTIFICATION_CRON_SECRET:'cron-key'};
  t.mock.method(globalThis,'fetch',async input=>String(input).endsWith('/rpc/authorize_notification_dispatch')?Response.json(false):Promise.reject(new Error(`unexpected ${input}`)));
  const forbidden=await handleNotifications(new Request('https://edge.test/notifications/dispatch',{method:'POST',headers:{authorization:'Bearer wrong'}}),env(values));
  assert.equal(forbidden.status,403);
  const malformed=await handleNotifications(new Request('https://edge.test/notifications/devices/register',{method:'POST',body:'{"fcm_token":"short"}'}),env(values));
  assert.equal(malformed.status,422);
});

test('admin session reads RBAC through the bounded server RPC',async t=>{
  const admin='00000000-0000-4000-8000-000000000101';
  t.mock.method(globalThis,'fetch',async input=>{
    const url=String(input);
    if(url.endsWith('/auth/v1/user'))return Response.json({id:admin});
    if(url.endsWith('/rpc/managed_radio_authorized'))return Response.json(true);
    if(url.endsWith('/rpc/admin_session_context'))return Response.json({roles:['SUPER_ADMIN'],permissions:['notifications.read']});
    throw new Error(`unexpected ${url}`);
  });
  const result=await handleNotifications(new Request('https://edge.test/notifications/admin/session',{headers:{authorization:'Bearer user-token'}}),env({SUPABASE_URL:'https://example.supabase.co',SUPABASE_SERVICE_ROLE_KEY:'server-key'}));
  assert.equal(result.status,200);
  const body=await result.json();
  assert.deepEqual(body.data.roles,['SUPER_ADMIN']);
});

test('test-to-my-device dispatches now and exposes a bounded provider code',async t=>{
  const admin='00000000-0000-4000-8000-000000000101';
  const device='00000000-0000-4000-8000-000000000102';
  const notification='00000000-0000-4000-8000-000000000103';
  t.mock.method(globalThis,'fetch',async(input,init={})=>{
    const url=String(input);
    if(url.endsWith('/auth/v1/user'))return Response.json({id:admin});
    if(url.endsWith('/rpc/managed_radio_authorized')||url.endsWith('/rpc/consume_rate_limit'))return Response.json(true);
    if(url.includes('/user_devices?user_id='))return Response.json([{id:device}]);
    if(url.endsWith('/admin_notifications'))return Response.json([{id:notification,scheduled_at:new Date(0).toISOString(),title:'T',body:'B',payload:{route:'/home'}}]);
    if(url.endsWith('/audit_logs'))return Response.json([]);
    if(url.endsWith('/rpc/claim_notification'))return Response.json([{id:notification,title:'T',body:'B',payload:{route:'/home'}}]);
    if(url.endsWith('/rpc/prepare_notification_deliveries'))return Response.json(1);
    if(url.includes('/notification_deliveries?'))return Response.json([{id:1,device_id:device,user_devices:{fcm_token:'device-token-that-is-long-enough'}}]);
    if(url.includes('/admin_notifications?')&&init.method==='PATCH')return Response.json([]);
    throw new Error(`unexpected ${url}`);
  });
  const result=await handleNotifications(new Request('https://edge.test/notifications/admin/test',{method:'POST',headers:{authorization:'Bearer user-token','idempotency-key':'test-device-once'},body:JSON.stringify({title:'T',body:'B',type:'admin_announcements',payload:{route:'/home'}})}),env({SUPABASE_URL:'https://example.supabase.co',SUPABASE_SERVICE_ROLE_KEY:'server-key'}));
  assert.equal(result.status,503);
  assert.equal((await result.json()).error.code,'FIREBASE_CREDENTIAL_MISSING');
});

test('missing Firebase server credential records failure without leaking device tokens',async t=>{
  const token='device-token-that-must-never-be-logged';
  const patches=[];const logs=[];
  t.mock.method(console,'error',value=>logs.push(String(value)));
  t.mock.method(globalThis,'fetch',async(input,init={})=>{
    const url=String(input);
    if(url.endsWith('/rpc/authorize_notification_dispatch'))return Response.json(true);
    if(url.endsWith('/rpc/claim_due_notifications'))return Response.json([{id:'00000000-0000-4000-8000-000000000101',title:'T',body:'B',payload:{route:'/home'}}]);
    if(url.endsWith('/rpc/prepare_notification_deliveries'))return Response.json(1);
    if(url.includes('/notification_deliveries?'))return Response.json([{id:1,device_id:'00000000-0000-4000-8000-000000000102',user_devices:{fcm_token:token}}]);
    if(url.includes('/admin_notifications?')){patches.push(JSON.parse(init.body));return Response.json([]);}
    throw new Error(`unexpected ${url}`);
  });
  const result=await handleNotifications(new Request('https://edge.test/notifications/dispatch',{method:'POST',headers:{authorization:'Bearer cron-key'}}),env({SUPABASE_URL:'https://example.supabase.co',SUPABASE_SERVICE_ROLE_KEY:'server-key',NOTIFICATION_CRON_SECRET:'cron-key'}));
  assert.equal(result.status,200);
  assert.ok(patches.some(value=>value.status==='failed'));
  assert.ok(!logs.join('').includes(token));
});
