import { ApiError } from './contracts';

// Local buckets are retained only as a deterministic development safeguard.
// Production requests are enforced by distributed-rate-limit.ts before sensitive handlers.
type Bucket={count:number;reset:number};
const buckets=new Map<string,Bucket>();
export function rateLimit(key:string,limit:number,windowMs:number){
  if((process.env.TARTEEL_ENVIRONMENT??'development')==='production')return;
  const now=Date.now();const b=buckets.get(key);
  if(!b||b.reset<=now){buckets.set(key,{count:1,reset:now+windowMs});return;}
  if(b.count>=limit)throw new ApiError(429,'RATE_LIMITED','Too many requests',{retry_after_seconds:Math.max(1,Math.ceil((b.reset-now)/1000))});
  b.count++;
}
