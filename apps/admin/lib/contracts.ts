export type Json = null | boolean | number | string | Json[] | { [key: string]: Json };
export type RoleCode = 'SUPER_ADMIN'|'RADIO_MANAGER'|'CONTENT_EDITOR'|'VIEWER';
export type StationSource = 'INTERNAL'|'EXTERNAL';
export type CommandType = 'PLAY_NOW'|'PLAY_NEXT'|'SKIP'|'STOP_AFTER_CURRENT'|'RESUME_AUTO';
export type InterruptPolicy = 'FINISH_CURRENT'|'INTERRUPT'|'PLAY_NEXT';
export type ScheduleType = 'ONE_TIME'|'DAILY'|'WEEKLY';
export type Priority = 'LOW'|'NORMAL'|'HIGH'|'EMERGENCY'|'LIVE';
export type ApiErrorShape = { error: { code: string; message: string; request_id: string } };
export type Page<T> = { data:T[]; page:number; limit:number; total:number; next_page:number|null };

export class ApiError extends Error {
  status:number; code:string; details?:unknown;
  constructor(status:number, code:string, message:string, details?:unknown){ super(message); this.status=status; this.code=code; this.details=details; }
}
export const UUID_RE=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
export function assertUuid(value:unknown,name='id'):string{
  if(typeof value!=='string'||!UUID_RE.test(value)) throw new ApiError(422,'VALIDATION_ERROR',`${name} must be a UUID`);
  return value;
}
export function assertString(value:unknown,name:string,max=500,required=true):string|null{
  if(value==null&&!required)return null;
  if(typeof value!=='string'||(required&&!value.trim())||value.length>max) throw new ApiError(422,'VALIDATION_ERROR',`${name} is invalid`);
  return value.trim();
}
export function assertEnum<T extends string>(value:unknown, allowed:readonly T[], name:string):T{
  if(typeof value!=='string'||!allowed.includes(value as T))throw new ApiError(422,'VALIDATION_ERROR',`${name} is invalid`);
  return value as T;
}
export function bool(value:unknown,name:string):boolean{
  if(typeof value!=='boolean')throw new ApiError(422,'VALIDATION_ERROR',`${name} must be boolean`); return value;
}
export function int(value:unknown,name:string,min:number,max:number):number{
  const n=typeof value==='number'?value:Number(value); if(!Number.isInteger(n)||n<min||n>max)throw new ApiError(422,'VALIDATION_ERROR',`${name} is invalid`); return n;
}
export function pageParams(url:URL,maxLimit=100){const page=int(url.searchParams.get('page')??1,'page',1,100000);const limit=int(url.searchParams.get('limit')??20,'limit',1,maxLimit);return{page,limit,from:(page-1)*limit,to:page*limit-1};}
export function normalizeArabic(input:string):string{
  return input.normalize('NFKD').replace(/[\u064B-\u065F\u0670\u06D6-\u06ED]/g,'').replace(/ـ/g,'').replace(/[أإآٱ]/g,'ا').replace(/ى/g,'ي').replace(/ؤ/g,'و').replace(/ئ/g,'ي').replace(/ة/g,'ه').replace(/\s+/g,' ').trim().toLowerCase();
}
export function safeLike(input:string):string{return input.replace(/[,%()]/g,' ').trim().slice(0,120);}
export function publicExternalEligible(row:Record<string,unknown>,environment='production'):boolean{
  if(row.station_source!=='EXTERNAL'||row.is_active!==true||row.deleted_at!=null)return false;
  if(environment==='development'){
    return ['PLAYABLE_IN_DEVELOPMENT','APPROVED_FOR_PUBLIC_RELEASE'].includes(String(row.availability_status??''))&&['HEALTHY','DEGRADED'].includes(String(row.health_status??''));
  }
  return row.availability_status==='APPROVED_FOR_PUBLIC_RELEASE'&&row.production_enabled===true&&row.rights_status==='APPROVED'&&row.commercial_use_status==='ALLOWED';
}
export function publicInternalEligible(row:Record<string,unknown>,environment:string):boolean{
  return row.station_source==='INTERNAL'&&row.is_active===true&&row.deleted_at==null&&(environment==='development'||row.production_enabled===true);
}
export function redact<T>(value:T):T{
  if(!value||typeof value!=='object')return value; const copy=structuredClone(value) as Record<string,unknown>;
  for(const key of Object.keys(copy))if(/secret|password|token|authorization|service.?role/i.test(key))copy[key]='[REDACTED]';
  return copy as T;
}
