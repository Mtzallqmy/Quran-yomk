import { ApiError, assertString, type RoleCode } from './contracts.ts';
import { authPassword, authSignOut, authUser, db, env, refreshSession } from './supabase.ts';

const ACCESS='tarteel_admin_access'; const REFRESH='tarteel_admin_refresh';
export type AdminContext={userId:string;email:string|null;displayName:string;roles:RoleCode[];permissions:Set<string>;refreshed?:{access:string;refresh:string;expires:number}};
function cookies(header:string|null){const out=new Map<string,string>();for(const pair of (header??'').split(';')){const i=pair.indexOf('=');if(i>0)out.set(pair.slice(0,i).trim(),decodeURIComponent(pair.slice(i+1).trim()));}return out;}
function cookie(name:string,value:string,maxAge:number){const e=env();return `${name}=${encodeURIComponent(value)}; Path=/; HttpOnly; SameSite=Lax; Max-Age=${maxAge}${e.secureCookies?'; Secure':''}`;}
export function clearCookies(){return[cookie(ACCESS,'',0),cookie(REFRESH,'',0)];}
export function sessionCookies(session:any){return[cookie(ACCESS,String(session.access_token),Math.max(60,Number(session.expires_in??3600))),cookie(REFRESH,String(session.refresh_token),60*60*24*30)];}
async function loadAuthorization(user:{id:string;email?:string}):Promise<AdminContext>{
  const admins=(await db('app',`administrators?id=eq.${encodeURIComponent(user.id)}&is_active=eq.true&deleted_at=is.null&select=id,display_name`)).data as any[];
  const admin=admins[0]; if(!admin)throw new ApiError(403,'ADMIN_REQUIRED','Administrator access is required');
  const ar=(await db('app',`administrator_roles?administrator_id=eq.${user.id}&select=role_id`)).data as any[];const roleIds=ar.map(x=>x.role_id);
  if(!roleIds.length)throw new ApiError(403,'ROLE_REQUIRED','Administrator has no role');
  const roles=(await db('app',`roles?id=in.(${roleIds.join(',')})&select=id,code`)).data as any[];
  const rp=(await db('app',`role_permissions?role_id=in.(${roleIds.join(',')})&select=permission_id`)).data as any[];const permissionIds=[...new Set(rp.map(x=>x.permission_id))];
  const perms=permissionIds.length?(await db('app',`permissions?id=in.(${permissionIds.join(',')})&select=code`)).data as any[]:[];
  return{userId:user.id,email:user.email??null,displayName:admin.display_name,roles:roles.map(r=>r.code as RoleCode),permissions:new Set(perms.map(p=>p.code))};
}
export async function adminContext(request:Request):Promise<AdminContext>{
  const c=cookies(request.headers.get('cookie'));let token=c.get(ACCESS);let refreshed:AdminContext['refreshed'];
  if(!token){const rt=c.get(REFRESH);if(!rt)throw new ApiError(401,'AUTH_REQUIRED','Authentication required');const s=await refreshSession(rt);token=s.access_token;refreshed={access:s.access_token,refresh:s.refresh_token,expires:s.expires_in??3600};}
  if(!token)throw new ApiError(401,'AUTH_REQUIRED','Authentication required');
  let user;try{user=await authUser(token);}catch(error){const rt=c.get(REFRESH);if(!rt)throw error;const s=await refreshSession(rt);const refreshedAccess=String(s.access_token);token=refreshedAccess;refreshed={access:refreshedAccess,refresh:String(s.refresh_token),expires:s.expires_in??3600};user=await authUser(refreshedAccess);}
  return{...(await loadAuthorization(user)),refreshed};
}
export function requirePermission(ctx:AdminContext,permission:string){if(!ctx.permissions.has(permission))throw new ApiError(403,'FORBIDDEN','You do not have permission for this action');}
export async function login(body:any){const email=assertString(body?.email,'email',320)!;const password=assertString(body?.password,'password',512)!;const s=await authPassword(email,password);const ctx=await loadAuthorization({id:s.user.id,email:s.user.email});return{ctx,cookies:sessionCookies(s)};}
export async function logout(request:Request){const token=cookies(request.headers.get('cookie')).get(ACCESS);if(token)await authSignOut(token);return clearCookies();}
