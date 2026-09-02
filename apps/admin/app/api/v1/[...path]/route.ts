import { dispatch } from '@/lib/api';
import { dispatchPhase11 } from '@/lib/phase11-api';
import { distributedRateLimitRequest } from '@/lib/distributed-rate-limit';
import { attachContext, fail, requestId } from '@/lib/http';
export const runtime='nodejs';
async function handle(request:Request,context:{params:Promise<{path:string[]}>}){const id=requestId(request);try{const {path}=await context.params;if(path[0]==='search'&&request.method==='GET')await distributedRateLimitRequest(request,'public-search',60,60_000);if(path[0]==='admin'&&path[1]==='auth'&&path[2]==='login'&&request.method==='POST')await distributedRateLimitRequest(request,'admin-login',10,60_000);const phase11=await dispatchPhase11(request,path,id);const result=phase11??await dispatch(request,path,id);return attachContext(result.response,id,result.ctx);}catch(error){return fail(error,id);}}
export const GET=handle;export const POST=handle;export const PATCH=handle;export const DELETE=handle;
