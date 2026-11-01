import test from 'node:test';
import assert from 'node:assert/strict';
import { dispatchNotifications } from '../lib/notification-api.ts';

const user='00000000-0000-4000-8000-000000000011';
function request(){return new Request('https://admin.test/api/v1/admin/notifications',{headers:{cookie:'tarteel_admin_access=user-jwt'}});}

test('notification proxy rechecks RBAC and keeps provider credentials server-side',async t=>{
  process.env.SUPABASE_URL='https://example.supabase.co';
  process.env.SUPABASE_PUBLISHABLE_KEY='public-test';
  process.env.SUPABASE_SECRET_KEY='server-secret-test';
  let permitted=true,edgeCalls=0;
  t.mock.method(globalThis,'fetch',async(input:unknown,init:RequestInit)=>{
    const url=String(input);
    if(url.includes('/auth/v1/user'))return Response.json({id:user});
    if(url.includes('/administrators?'))return Response.json([{id:user,display_name:'Admin'}]);
    if(url.includes('/administrator_roles?'))return Response.json([{role_id:user}]);
    if(url.includes('/roles?'))return Response.json([{id:user,code:'SUPER_ADMIN'}]);
    if(url.includes('/role_permissions?'))return Response.json([{permission_id:user}]);
    if(url.includes('/permissions?'))return Response.json(permitted?[{code:'notifications.read'}]:[]);
    if(url.includes('/functions/v1/notifications/admin/notifications')){
      edgeCalls++;
      const headers=new Headers(init.headers);
      assert.equal(headers.get('authorization'),'Bearer server-secret-test');
      assert.equal(headers.get('x-admin-user-id'),user);
      assert.ok(!url.includes('server-secret-test'));
      return Response.json({data:{items:[]}});
    }
    throw new Error(`unexpected ${url}`);
  });
  const result=await dispatchNotifications(request(),['admin','notifications'],'00000000-0000-4000-8000-000000000012');
  assert.equal(result?.response.status,200);
  assert.equal(edgeCalls,1);
  permitted=false;
  await assert.rejects(dispatchNotifications(request(),['admin','notifications'],'00000000-0000-4000-8000-000000000012'),{code:'FORBIDDEN'});
  assert.equal(edgeCalls,1);
});
