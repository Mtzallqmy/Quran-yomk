import { createServer, type Server } from 'node:http';
import { randomUUID } from 'node:crypto';
import type { EngineSnapshot, Lease } from './types.js';

export function engineReady(snapshot: EngineSnapshot, lease: Lease | null, now = Date.now()): boolean {
  return ['AUTO', 'SCHEDULED', 'MANUAL', 'LIVE'].includes(snapshot.mode) &&
    snapshot.liquidsoapAlive && snapshot.icecastReachable && snapshot.sourceConnected &&
    snapshot.mountAvailable && snapshot.broadcasting && lease !== null && Date.parse(lease.expiresAt) > now;
}

export function startHealthServer(port:number,getSnapshot:()=>EngineSnapshot,ready:()=>boolean):Promise<Server>{
  const server=createServer((request,response)=>{
    const id=randomUUID();
    const isReady=request.url==='/ready';const isHealth=request.url==='/health';const isState=request.url==='/state';
    const headers={'content-type':'application/json','cache-control':'no-store','x-request-id':id};
    if(!isReady&&!isHealth&&!isState){response.writeHead(404,headers).end(JSON.stringify({error:{code:'NOT_FOUND',request_id:id}}));return;}
    try {
      const snapshot=getSnapshot();const ok=isState||ready();
      response.writeHead(ok?200:503,headers);
      response.end(JSON.stringify(isState?snapshot:{
        status:ok?'ok':'not_ready',request_id:id,mode:snapshot.mode,engine_alive:true,
        liquidsoap_alive:snapshot.liquidsoapAlive,icecast_reachable:snapshot.icecastReachable,
        source_connected:snapshot.sourceConnected,mount_available:snapshot.mountAvailable,
        broadcasting:snapshot.broadcasting,
        counters:{reconnects:snapshot.reconnectCount,track_failures:snapshot.trackFailures,playout_acks:snapshot.playoutAckCount}
      }));
    } catch {
      response.writeHead(500,headers).end(JSON.stringify({error:{code:'HEALTH_CHECK_FAILED',request_id:id}}));
    }
  });
  return new Promise((resolve,reject)=>{server.once('error',reject);server.listen(port,'127.0.0.1',()=>resolve(server));});
}
