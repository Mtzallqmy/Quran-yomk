import test from 'node:test';
import assert from 'node:assert/strict';
import { handleNotifications, validPushRoute } from '../notifications/index.ts';

test('push deep links are an explicit allowlist',()=>{
  for(const route of ['/home','/prayer-times','/adhkar','/radio','/reciters','/quran','/library','/custom-reminders'])assert.equal(validPushRoute(route),true);
  for(const route of ['https://evil.test','javascript:alert(1)','/admin','../quran',null])assert.equal(validPushRoute(route),false);
});

const env=values=>name=>values[name];
test('cron and malformed device requests fail closed',async()=>{
  const values={SUPABASE_URL:'https://example.supabase.co',SUPABASE_SERVICE_ROLE_KEY:'server-key',NOTIFICATION_CRON_SECRET:'cron-key'};
  const forbidden=await handleNotifications(new Request('https://edge.test/notifications/dispatch',{method:'POST',headers:{authorization:'Bearer wrong'}}),env(values));
  assert.equal(forbidden.status,403);
  const malformed=await handleNotifications(new Request('https://edge.test/notifications/devices/register',{method:'POST',body:'{"fcm_token":"short"}'}),env(values));
  assert.equal(malformed.status,422);
});

test('missing Firebase server credential records failure without leaking device tokens',async t=>{
  const token='device-token-that-must-never-be-logged';
  const patches=[];const logs=[];
  t.mock.method(console,'error',value=>logs.push(String(value)));
  t.mock.method(globalThis,'fetch',async(input,init={})=>{
    const url=String(input);
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
