import { ApiError } from './contracts';
type Bucket={count:number;reset:number};const buckets=new Map<string,Bucket>();
export function rateLimit(key:string,limit:number,windowMs:number){const now=Date.now();const b=buckets.get(key);if(!b||b.reset<=now){buckets.set(key,{count:1,reset:now+windowMs});return;}if(b.count>=limit)throw new ApiError(429,'RATE_LIMITED','Too many requests');b.count++;}
