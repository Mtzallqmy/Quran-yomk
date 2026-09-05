import { ApiError, type Json } from './contracts.ts';
import { fetchJsonResponse, UpstreamHttpError } from '../../../supabase/functions/_shared/http.ts';

async function fetch(input: RequestInfo | URL, init: RequestInit = {}): Promise<Response> {
  try { return await fetchJsonResponse(input, init); }
  catch (error) { if (error instanceof UpstreamHttpError) throw new ApiError(error.status, error.code, 'Backend request failed'); throw error; }
}
function session(body: any) {
  if (!body || typeof body.access_token !== 'string' || !body.access_token || typeof body.refresh_token !== 'string' || !body.refresh_token || !Number.isFinite(body.expires_in) || body.expires_in <= 0) throw new ApiError(502, 'INVALID_AUTH_RESPONSE', 'Authentication response was invalid');
  return body;
}

type PublicEnv={url:string;publishable:string;environment:string;streamBase:string;mount:string;secureCookies:boolean};
type Env=PublicEnv&{secret:string};
export function publicEnv():PublicEnv{
  const url=process.env.SUPABASE_URL?.replace(/\/$/,'');
  const publishable=process.env.SUPABASE_PUBLISHABLE_KEY;
  if(!url||!publishable)throw new ApiError(503,'SERVER_NOT_CONFIGURED','Public backend configuration is not available');
  return {url,publishable,environment:process.env.TARTEEL_ENVIRONMENT??'development',streamBase:(process.env.TARTEEL_PUBLIC_STREAM_BASE_URL??'').replace(/\/$/,''),mount:process.env.TARTEEL_INTERNAL_MOUNT??'/tarteel.mp3',secureCookies:process.env.TARTEEL_COOKIE_SECURE==='true'};
}
export function env():Env{
  const base=publicEnv();
  const secret=process.env.SUPABASE_SECRET_KEY;
  if(!secret)throw new ApiError(503,'SERVER_NOT_CONFIGURED','Backend credentials are not configured');
  return {...base,secret};
}
async function readBody(response:Response):Promise<unknown>{const text=await response.text();if(!text)return null;try{return JSON.parse(text)}catch{return text}}
function mapStatus(status:number){if(status===400)return 422;if(status===401)return 401;if(status===403)return 403;if(status===404)return 404;if(status===409)return 409;return status>=500?502:status;}
export async function db(schema:'app'|'radio',resource:string,init:RequestInit={},count=false):Promise<{data:any;count:number|null;headers:Headers}>{
  const e=env(); const headers=new Headers(init.headers); headers.set('apikey',e.secret);headers.set('accept-profile',schema);headers.set('content-profile',schema);
  if(init.body&&!headers.has('content-type'))headers.set('content-type','application/json'); if(!headers.has('prefer'))headers.set('prefer',count?'count=exact':'return=representation');
  const response=await fetch(`${e.url}/rest/v1/${resource}`,{...init,headers,cache:'no-store'});const data=await readBody(response);
  if(!response.ok){const message='Database request failed';throw new ApiError(mapStatus(response.status),'DATABASE_ERROR',message);}
  const range=response.headers.get('content-range');const total=range&&range.includes('/')?Number(range.split('/')[1]):null;return{data,count:Number.isFinite(total as number)?total:null,headers:response.headers};
}
export async function rpc(schema:'app'|'radio',fn:string,args:Record<string,Json>):Promise<any>{return (await db(schema,`rpc/${fn}`,{method:'POST',body:JSON.stringify(args),headers:{prefer:'return=representation'}})).data;}
export async function publicRpc(fn:string,args:Record<string,Json>):Promise<any>{
  const e=publicEnv();
  const response=await fetch(`${e.url}/rest/v1/rpc/${fn}`,{method:'POST',headers:{apikey:e.publishable,'accept-profile':'app','content-profile':'app','content-type':'application/json'},body:JSON.stringify(args),cache:'no-store'});
  const data=await readBody(response);
  if(!response.ok){const message='Public catalog request failed';throw new ApiError(mapStatus(response.status),'CATALOG_ERROR',message);}
  return data;
}
export async function authPassword(email:string,password:string){const e=env();const r=await fetch(`${e.url}/auth/v1/token?grant_type=password`,{method:'POST',headers:{apikey:e.publishable,'content-type':'application/json'},body:JSON.stringify({email,password}),cache:'no-store'});const body=await readBody(r);if(!r.ok)throw new ApiError(401,'INVALID_CREDENTIALS','Invalid email or password');return session(body);}
export async function refreshSession(refresh_token:string){const e=env();const r=await fetch(`${e.url}/auth/v1/token?grant_type=refresh_token`,{method:'POST',headers:{apikey:e.publishable,'content-type':'application/json'},body:JSON.stringify({refresh_token}),cache:'no-store'});const body=await readBody(r);if(!r.ok)throw new ApiError(401,'SESSION_EXPIRED','Session expired');return session(body);}
export async function authUser(accessToken:string){const e=env();const r=await fetch(`${e.url}/auth/v1/user`,{headers:{apikey:e.publishable,authorization:`Bearer ${accessToken}`},cache:'no-store'});if(!r.ok)throw new ApiError(401,'SESSION_EXPIRED','Session expired');const user=await r.json();if(!user||typeof user.id!=='string'||!/^[0-9a-f-]{36}$/i.test(user.id))throw new ApiError(502,'INVALID_AUTH_RESPONSE','Authentication response was invalid');return user as {id:string;email?:string};}
export async function authSignOut(accessToken:string){const e=env();const r=await fetch(`${e.url}/auth/v1/logout`,{method:'POST',headers:{apikey:e.publishable,authorization:`Bearer ${accessToken}`},cache:'no-store'});if(!r.ok)throw new ApiError(502,'LOGOUT_FAILED','Could not revoke session');}
export async function createSignedUpload(bucket:string,path:string){const e=env();const r=await fetch(`${e.url}/storage/v1/object/upload/sign/${encodeURIComponent(bucket)}/${path.split('/').map(encodeURIComponent).join('/')}`,{method:'POST',headers:{apikey:e.secret,'content-type':'application/json'},body:'{}',cache:'no-store'});const body=await readBody(r) as any;if(!r.ok)throw new ApiError(mapStatus(r.status),'STORAGE_ERROR','Could not create signed upload');const relative=typeof body?.url==='string'?body.url:null;if(!relative)throw new ApiError(502,'STORAGE_ERROR','Signed upload response was invalid');const signedUrl=`${e.url}/storage/v1${relative.startsWith('/')?relative:`/${relative}`}`;const token=new URL(signedUrl).searchParams.get('token');if(!token)throw new ApiError(502,'STORAGE_ERROR','Signed upload token was missing');return{signedUrl,token,path};}
export async function createSignedDownload(bucket:string,path:string,expiresIn=900){const e=env();const r=await fetch(`${e.url}/storage/v1/object/sign/${encodeURIComponent(bucket)}/${path.split('/').map(encodeURIComponent).join('/')}`,{method:'POST',headers:{apikey:e.secret,'content-type':'application/json'},body:JSON.stringify({expiresIn}),cache:'no-store'});const body=await readBody(r);if(!r.ok)throw new ApiError(mapStatus(r.status),'STORAGE_ERROR','Could not sign media URL');const signed=(body as any)?.signedURL??(body as any)?.signedUrl;if(typeof signed!=='string'||!signed)throw new ApiError(502,'STORAGE_ERROR','Signed download response was invalid');return `${e.url}/storage/v1${signed.startsWith('/')?signed:`/${signed}`}`;}
