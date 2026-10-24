import { ApiError } from './contracts.ts';
import type { AdminContext } from './auth.ts';
import { sessionCookies } from './auth.ts';
export function requestId(request:Request){const supplied=request.headers.get('x-request-id');return supplied&&/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(supplied)?supplied:crypto.randomUUID();}
export function json(data:unknown,status=200,headers?:HeadersInit){const h=new Headers(headers);h.set('content-type','application/json; charset=utf-8');return new Response(JSON.stringify(data),{status,headers:h});}
export function fail(error:unknown,id:string){const e=error instanceof ApiError?error:new ApiError(500,'INTERNAL_ERROR','Unexpected server error');if(e.status>=500)console.error(JSON.stringify({level:'ERROR',event:'API_ERROR',request_id:id,code:e.code,status:e.status}));return json({error:{code:e.code,message:e.message,request_id:id}},e.status,{'x-request-id':id,'cache-control':'no-store'});}
export function attachContext(response:Response,id:string,ctx?:AdminContext){response.headers.set('x-request-id',id);if(ctx?.refreshed){for(const c of sessionCookies({access_token:ctx.refreshed.access,refresh_token:ctx.refreshed.refresh,expires_in:ctx.refreshed.expires}))response.headers.append('set-cookie',c);}return response;}
export async function body(request:Request,maxBytes=64_000){
  const length=request.headers.get('content-length');
  if(length!==null&&(!/^\d+$/.test(length)||Number(length)>maxBytes)){await request.body?.cancel().catch(()=>{});throw new ApiError(413,'PAYLOAD_TOO_LARGE','Request body is too large');}
  const reader=request.body?.getReader();if(!reader)return {};
  let total=0,text='';const decoder=new TextDecoder('utf-8',{fatal:true});
  try{while(true){const {value,done}=await reader.read();if(done)break;total+=value.byteLength;if(total>maxBytes)throw new ApiError(413,'PAYLOAD_TOO_LARGE','Request body is too large');text+=decoder.decode(value,{stream:true});}text+=decoder.decode();return text?JSON.parse(text):{};}
  catch(error){await reader.cancel().catch(()=>{});if(error instanceof ApiError)throw error;throw new ApiError(400,'MALFORMED_JSON','Malformed JSON body');}
  finally{reader.releaseLock();}
}
export function sameOrigin(request:Request){
  const origin=request.headers.get('origin');
  try { if(!origin||new URL(origin).origin!==new URL(request.url).origin||request.headers.get('sec-fetch-site')==='cross-site')throw new Error(); }
  catch { throw new ApiError(403,'CSRF_REJECTED','Cross-origin mutation rejected'); }
}
