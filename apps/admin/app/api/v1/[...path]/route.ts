import { adminMutation } from '@/lib/admin-mutation';
import type { AdminContext } from '@/lib/auth';
import { dispatch } from '@/lib/api';
import { dispatchPhase11 } from '@/lib/phase11-api';
import { attachContext, fail, requestId } from '@/lib/http';
export const runtime='nodejs';
async function handle(request:Request,context:{params:Promise<{path:string[]}>}){const id=requestId(request);try{const {path}=await context.params;const run=async(ctx?:AdminContext)=>(await dispatchPhase11(request,path,id,ctx))??await dispatch(request,path,id,ctx);const mutation=path[0]==='admin'&&path[1]!=='auth'&&request.method!=='GET';const result=mutation?await adminMutation(request,id,run):await run();return attachContext(result.response,id,result.ctx);}catch(error){return fail(error,id);}}
export const GET=handle;export const POST=handle;export const PATCH=handle;export const DELETE=handle;
