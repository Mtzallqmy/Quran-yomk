import { ApiError, assertString, type RoleCode } from './contracts';
import { clientIp, distributedRateLimit } from './distributed-rate-limit';
import { authPassword, authSignOut, authUser, db, env, refreshSession } from './supabase';

const ACCESS='tarteel_admin_access'; const REFRESH='tarteel_admin_refresh';
export type AdminContext={userId:string;email:string|null;displayName:string;roles:RoleCode[];permissions:Set<string>;aal:'aal1'|'aal2'|null;sessionId:string|null;refreshed?:{access:string;refresh:string;expires:number}};
function cookies(header:string|null){const out=new Map<string,string>();for(const pair of (header??'').split(';')){const i=pair.indexOf('=');if(i>0)out.set(pair.slice(0,i).trim(),decodeURIComponent(pair.slice(i+1).trim()));}return out;}
function cookie(name:string,value:string,maxAge:number){const e=env();return `${name}=${encodeURIComponent(value)}; Path=/; HttpOnly; SameSite=Lax; Max-Age=${maxAge}${e.secureCookies?'; Secure':''}`;}
function validatedClaims(token:string):{aal:'aal1'|'aal2'|null;sessionId:string|null}{
  try{
    const payload=JSON.parse(Buffer.from(token.split('.')[1]??'','base64url').toString('utf8')) as Record<string,unknown>;
    const aal=payload.aal==='aal2'?'aal2':payload.aal==='aal1'?'aal1':null;
    const sessionId=typeof payload.session_id==='string'?payload.session_id:null;
    return{aal,sessionId};
  }catch{return{aal:null,sessionId:null};}
}
function mutationPolicy(request:Request):{action:string;limit:number;sensitive:boolean}|null{
  if(['GET','HEAD','OPTIONS'].includes(request.method))return null;
  const pathname=new URL(request.url).pathname;
  if(!pathname.includes('/api/v1/admin/'))return null;
  if(pathname.includes('/auth/login')||pathname.includes('/auth/logout'))return null;
  if(pathname.includes('/commands'))return{action:'radio-command',limit:30,sensitive:true};
  if(pathname.includes('/managed-radio'))return{action:'managed-radio',limit:8,sensitive:true};
  if(pathname.includes('/runtime-config'))return{action:'runtime-config',limit:20,sensitive:true};
  if(pathname.includes('/external-stations'))return{action:'external-station',limit:40,sensitive:true};
  if(pathname.includes('/settings'))return{action:'settings',limit:30,sensitive:true};
  if(pathname.includes('/roles')||pathname.includes('/permissions'))return{action:'rbac',limit:20,sensitive:true};
  if(pathname.includes('/upload-intents'))return{action:'upload-intent',limit:30,sensitive:false};
  return{action:'admin-mutation',limit:120,sensitive:false};
}
export function clearCookies(){return[cookie(ACCESS,'',0),cookie(REFRESH,'',0)];}
export function sessionCookies(session:any){return[cookie(ACCESS,String(session.access_token),Math.max(60,Number(session.expires_in??3600))),cookie(REFRESH,String(session.refresh_token),60*60*24*30)];}
async function loadAuthorization(user:{id:string;email?:string},security:{aal:'aal1'|'aal2'|null;sessionId:string|null}={aal:null,sessionId:null}):Promise<AdminContext>{
  const admins=(await db('app',`administrators?id=eq.${encodeURIComponent(user.id)}&is_active=eq.true&deleted_at=is.null&select=id,display_name`)).data as any[];
  const admin=admins[0]; if(!admin)throw new ApiError(403,'ADMIN_REQUIRED','Administrator access is required');
  const ar=(await db('app',`administrator_roles?administrator_id=eq.${user.id}&select=role_id`)).data as any[];const roleIds=ar.map(x=>x.role_id);
  if(!roleIds.length)throw new ApiError(403,'ROLE_REQUIRED','Administrator has no role');
  const roles=(await db('app',`roles?id=in.(${roleIds.join(',')})&select=id,code`)).data as any[];
  const rp=(await db('app',`role_permissions?role_id=in.(${roleIds.join(',')})&select=permission_id`)).data as any[];const permissionIds=[...new Set(rp.map(x=>x.permission_id))];
  const perms=permissionIds.length?(await db('app',`permissions?id=in.(${permissionIds.join(',')})&select=code`)).data as any[]:[];
  return{userId:user.id,email:user.email??null,displayName:admin.display_name,roles:roles.map(r=>r.code as RoleCode),permissions:new Set(perms.map(p=>p.code)),...security};
}
export async function adminContext(request:Request):Promise<AdminContext>{
  const c=cookies(request.headers.get('cookie'));let token=c.get(ACCESS);let refreshed:AdminContext['refreshed'];
  if(!token){const rt=c.get(REFRESH);if(!rt)throw new ApiError(401,'AUTH_REQUIRED','Authentication required');const s=await refreshSession(rt);token=s.access_token;refreshed={access:s.access_token,refresh:s.refresh_token,expires:s.expires_in??3600};}
  if(!token)throw new ApiError(401,'AUTH_REQUIRED','Authentication required');
  let user;try{user=await authUser(token);}catch(error){const rt=c.get(REFRESH);if(!rt)throw error;const s=await refreshSession(rt);const refreshedAccess=String(s.access_token);token=refreshedAccess;refreshed={access:refreshedAccess,refresh:String(s.refresh_token),expires:s.expires_in??3600};user=await authUser(refreshedAccess);}
  const ctx={...(await loadAuthorization(user,validatedClaims(token))),refreshed};
  const policy=mutationPolicy(request);
  if(policy){
    await Promise.all([
      distributedRateLimit(`admin:${policy.action}:user`,ctx.userId,policy.limit,60_000),
      distributedRateLimit(`admin:${policy.action}:ip`,clientIp(request),policy.limit*2,60_000),
    ]);
    if(policy.sensitive)requireSensitiveAdmin(ctx);
  }
  return ctx;
}
export function requirePermission(ctx:AdminContext,permission:string){if(!ctx.permissions.has(permission))throw new ApiError(403,'FORBIDDEN','You do not have permission for this action');}
export function mfaMode():'off'|'ready'|'required'{const raw=(process.env.TARTEEL_ADMIN_MFA_MODE??'ready').toLowerCase();return raw==='required'?'required':raw==='off'?'off':'ready';}
export function requireSensitiveAdmin(ctx:AdminContext){if(mfaMode()==='required'&&ctx.aal!=='aal2')throw new ApiError(403,'MFA_REQUIRED','Multi-factor authentication is required for this sensitive action',{current_aal:ctx.aal??'aal1'});}
export async function login(body:any){const email=assertString(body?.email,'email',320)!;const password=assertString(body?.password,'password',512)!;const s=await authPassword(email,password);const token=String(s.access_token);const ctx=await loadAuthorization({id:s.user.id,email:s.user.email},validatedClaims(token));return{ctx,cookies:sessionCookies(s)};}
export async function logout(request:Request){const token=cookies(request.headers.get('cookie')).get(ACCESS);if(token){try{await authSignOut(token);}catch(error){console.error(JSON.stringify({level:'WARN',event:'ADMIN_SESSION_REVOCATION_FAILED',error:error instanceof Error?error.message:String(error)}));}}return clearCookies();}
