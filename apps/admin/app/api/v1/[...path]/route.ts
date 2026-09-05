import { adminMutation } from '@/lib/admin-mutation';
import type { AdminContext } from '@/lib/auth';
import { dispatch } from '@/lib/api';
import { dispatchPhase11 } from '@/lib/phase11-api';
import { attachContext, fail, requestId } from '@/lib/http';
import { distributedRateLimit } from '@/lib/rate-limit';
export const runtime='nodejs';
function ip(request:Request){return request.headers.get('x-forwarded-for')?.split(',')[0]?.trim()??request.headers.get('x-real-ip')?.trim()??'local';}
async function enforceDistributedLimits(request:Request,path:string[]){
  if(request.method==='GET'&&path.length===1&&path[0]==='search')await distributedRateLimit(`search:${ip(request)}`,60,60_000);
  if(request.method==='POST'&&path[0]==='admin'&&path[1]==='media'&&path[3]==='upload-intent')await distributedRateLimit(`upload:${ip(request)}`,30,60_000);
}
async function handle(request:Request,context:{params:Promise<{path:string[]}>}){const id=requestId(request);try{const {path}=await context.params;await enforceDistributedLimits(request,path);const run=async(ctx?:AdminContext)=>(await dispatchPhase11(request,path,id,ctx))??await dispatch(request,path,id,ctx);const mutation=path[0]==='admin'&&path[1]!=='auth'&&request.method!=='GET';const result=mutation?await adminMutation(request,id,run):await run();return attachContext(result.response,id,result.ctx);}catch(error){return fail(error,id);}}
export const GET=handle;export const POST=handle;export const PATCH=handle;export const DELETE=handle;
