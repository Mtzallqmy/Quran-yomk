import type { AdminContext } from './auth';
import { redact } from './contracts';
import { db } from './supabase';

export async function auditAdminAction(
  ctx:AdminContext,
  requestId:string,
  action:string,
  targetType:string,
  targetId:string|null,
  oldValue:unknown,
  newValue:unknown,
  reason?:string|null,
){
  await db('app','audit_logs',{
    method:'POST',
    body:JSON.stringify({
      actor_id:ctx.userId,
      action,
      resource_type:targetType,
      resource_id:targetId,
      request_id:requestId,
      old_values:oldValue==null?null:redact(oldValue),
      new_values:newValue==null?null:redact(newValue),
      metadata:{source:'next_admin_api',reason:reason?.trim()||null,aal:ctx.aal??null},
    }),
  });
}
