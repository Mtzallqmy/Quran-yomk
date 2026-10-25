import { adminContext, requirePermission, type AdminContext } from './auth.ts';
import { ApiError } from './contracts.ts';
import { json } from './http.ts';
import { backendResponse, env } from './supabase.ts';

const permission=(method:string,parts:string[])=>method==='GET'
  ?(parts[2]==='devices'?'devices.read':'notifications.read')
  :(parts.at(-1)==='cancel'?'notifications.cancel':'notifications.send');

export async function dispatchNotifications(request:Request,parts:string[],_requestId:string,authorized?:AdminContext){
  if(parts[0]!=='admin'||!['notifications','devices','notification-overview'].includes(parts[1]??''))return null;
  const ctx=authorized??await adminContext(request);requirePermission(ctx,permission(request.method,parts));
  const e=env();
  let edgePath=parts[1]==='notification-overview'?'overview':parts.slice(1).join('/');
  if(edgePath==='notifications/test')edgePath='test';
  const headers:Record<string,string>={authorization:`Bearer ${e.secret}`,'x-admin-user-id':ctx.userId,'content-type':'application/json'};
  const idem=request.headers.get('idempotency-key');if(idem)headers['idempotency-key']=idem;
  const response=await backendResponse(`${e.url}/functions/v1/notifications/admin/${edgePath}`,{method:request.method,headers,body:request.method==='GET'?undefined:await request.text(),cache:'no-store'});
  if(!response.ok)throw new ApiError(response.status,'NOTIFICATION_BACKEND_ERROR','Notification backend request failed');
  const payload=await response.json();return{ctx,response:json(payload)};
}
