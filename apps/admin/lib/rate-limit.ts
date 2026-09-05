import { createHash } from 'node:crypto';
import { ApiError } from './contracts';
import { rpc } from './supabase';

type Bucket={count:number;reset:number};const buckets=new Map<string,Bucket>();

// Local limiter remains as a cheap defense-in-depth guard inside one process.
export function rateLimit(key:string,limit:number,windowMs:number){const now=Date.now();const b=buckets.get(key);if(!b||b.reset<=now){buckets.set(key,{count:1,reset:now+windowMs});return;}if(b.count>=limit)throw new ApiError(429,'RATE_LIMITED','Too many requests');b.count++;}

export async function distributedRateLimit(key:string,limit:number,windowMs:number):Promise<void>{
  if(!Number.isInteger(limit)||limit<1||!Number.isInteger(windowMs)||windowMs<1000)throw new Error('invalid distributed rate limit configuration');
  const bucketKey=createHash('sha256').update(key).digest('hex');
  const allowed=await rpc('app','consume_rate_limit',{p_bucket_key:bucketKey,p_limit:limit,p_window_ms:windowMs});
  if(allowed!==true)throw new ApiError(429,'RATE_LIMITED','Too many requests');
}
