import { adminContext, requirePermission, type AdminContext } from './auth.ts';
import { ApiError } from './contracts.ts';
import { sameOrigin } from './http.ts';
import { db } from './supabase.ts';

export async function adminMutation<T>(request: Request, id: string, run: (ctx: AdminContext) => Promise<T>, permission?: string): Promise<T> {
  sameOrigin(request);
  const ctx = await adminContext(request);
  if (permission) requirePermission(ctx, permission);
  const record = async (status: string) => {
    await db('app', 'audit_logs', { method: 'POST', body: JSON.stringify({
      actor_id: ctx.userId, action: `admin.mutation.${status.toLowerCase()}`,
      resource_type: 'admin_endpoint', request_id: id,
      metadata: { method: request.method, path: new URL(request.url).pathname.slice(0, 500), status },
    }) });
  };
  // An unavailable audit store prevents side effects. Never record body/cookies.
  await record('STARTED');
  let result: T;
  try { result = await run(ctx); }
  catch (error) {
    await record('FAILED').catch(() => console.error(JSON.stringify({ event: 'AUDIT_FINALIZE_FAILED', request_id: id })));
    throw error;
  }
  try { await record('COMPLETED'); }
  catch {
    console.error(JSON.stringify({ event: 'AUDIT_RESULT_UNCONFIRMED', request_id: id }));
    throw new ApiError(503, 'AUDIT_RESULT_UNCONFIRMED', 'Operation result could not be confirmed; check current state before retrying');
  }
  return result;
}
