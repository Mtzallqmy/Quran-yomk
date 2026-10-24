import {createHash,timingSafeEqual} from 'node:crypto';
import baseline from '../baseline-inventory.json' with {type:'json'};
import {syncAll} from './sync.mjs';
export function authorized(request,secret){if(!secret)return false;const digest=s=>createHash('sha256').update(s).digest();return timingSafeEqual(digest(request.headers.get('authorization')??''),digest('Bearer '+secret));}
export function admin(pool,secret){let running=null;return async request=>{
 if(!authorized(request,secret))return Response.json({error:'UNAUTHORIZED'},{status:401});
 if(request.method!=='POST')return Response.json({error:'METHOD_NOT_ALLOWED'},{status:405});
 if(new URL(request.url).pathname!=='/admin/sync')return Response.json({error:'NOT_FOUND'},{status:404});
 // Coalesce retries on one isolate; the DB lock covers different isolates.
 if(!running){const baselineUrls=baseline.stations.map(s=>s.playback_url).filter(v=>v?.startsWith('https://'));baselineUrls.push('https://backup.qurango.net/radio/shmaeel');running=syncAll(pool,{baselineUrls}).finally(()=>{running=null;});}
 return Response.json({report:await running});
};}
