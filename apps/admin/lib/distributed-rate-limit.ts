import { createHash } from 'node:crypto';
import { ApiError } from './contracts.ts';
import { rpc } from './supabase.ts';

type RateLimitRow={allowed:boolean;remaining:number;reset_at:string};

export function clientIp(request:Request):string{
  return request.headers.get('x-forwarded-for')?.split(',')[0]?.trim()
    || request.headers.get('x-real-ip')?.trim()
    || 'unknown';
}

export function rateLimitBucket(action:string,subject:string):string{
  return createHash('sha256').update(`tarteel:v1:${action}:${subject}`).digest('hex');
}

export async function distributedRateLimit(action:string,subject:string,limit:number,windowMs:number):Promise<{remaining:number;resetAt:string}>{
  const windowSeconds=Math.max(1,Math.ceil(windowMs/1000));
  let data:unknown;
  try{
    data=await rpc('app','consume_rate_limit',{
      p_bucket_key:rateLimitBucket(action,subject),
      p_limit:limit,
      p_window_seconds:windowSeconds,
      p_now:new Date().toISOString(),
    });
  }catch(error){
    if((process.env.TARTEEL_ENVIRONMENT??'development')==='production')throw new ApiError(503,'RATE_LIMIT_UNAVAILABLE','Rate limiting is temporarily unavailable');
    throw error;
  }
  const row=(Array.isArray(data)?data[0]:data) as RateLimitRow|undefined;
  if(!row||typeof row.allowed!=='boolean'||typeof row.reset_at!=='string')throw new ApiError(503,'RATE_LIMIT_UNAVAILABLE','Rate limiting is temporarily unavailable');
  if(!row.allowed){
    const retryAfter=Math.max(1,Math.ceil((Date.parse(row.reset_at)-Date.now())/1000));
    throw new ApiError(429,'RATE_LIMITED','Too many requests',{retry_after_seconds:retryAfter});
  }
  return{remaining:Number(row.remaining??0),resetAt:row.reset_at};
}

export async function distributedRateLimitRequest(request:Request,action:string,limit:number,windowMs:number,subject?:string){
  return distributedRateLimit(action,subject??clientIp(request),limit,windowMs);
}
