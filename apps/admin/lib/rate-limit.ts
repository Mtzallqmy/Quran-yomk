import { createHash } from 'node:crypto';
import { ApiError } from './contracts.ts';
import { rpc } from './supabase.ts';

export async function distributedRateLimit(key:string,limit:number,windowMs:number):Promise<void>{
  if(!Number.isInteger(limit)||limit<1||!Number.isInteger(windowMs)||windowMs<1000)throw new Error('invalid distributed rate limit configuration');
  const bucketKey=createHash('sha256').update(key).digest('hex');
  const allowed=await rpc('app','consume_rate_limit',{p_bucket_key:bucketKey,p_limit:limit,p_window_ms:windowMs});
  if(allowed!==true)throw new ApiError(429,'RATE_LIMITED','Too many requests');
}

export const rateLimit = distributedRateLimit;
