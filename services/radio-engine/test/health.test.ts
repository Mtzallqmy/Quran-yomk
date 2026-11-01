import test from 'node:test';
import assert from 'node:assert/strict';
import { engineReady, startHealthServer } from '../src/health.js';
import type { EngineSnapshot, Lease } from '../src/types.js';

const snapshot = (): EngineSnapshot => ({ mode:'AUTO',sourceConnected:true,liquidsoapAlive:true,icecastReachable:true,mountAvailable:true,broadcasting:true,streamMount:'/test',current:null,next:null,currentStartedAt:null,expectedEndAt:null,sourceStartedAt:null,lastError:null,lastRecoveryAt:null,reconnectCount:0,trackFailures:0,playoutAckCount:1 });
const lease: Lease = { stationId:'station',ownerId:'owner',fencingToken:1,expiresAt:new Date(Date.now()+60000).toISOString() };

test('readiness requires a live lease and all distribution components', () => {
  for (const mode of ['AUTO','SCHEDULED','MANUAL','LIVE'] as const) assert.equal(engineReady({...snapshot(),mode},lease),true);
  for (const flag of ['sourceConnected','liquidsoapAlive','icecastReachable','mountAvailable','broadcasting']) assert.equal(engineReady({...snapshot(),[flag]:false},lease),false);
  assert.equal(engineReady(snapshot(),null),false);
  assert.equal(engineReady(snapshot(),{...lease,expiresAt:'invalid'}),false);
  assert.equal(engineReady(snapshot(),{...lease,expiresAt:new Date(0).toISOString()}),false);
  assert.equal(engineReady({...snapshot(),mode:'RECOVERING'},lease),false);
});

test('health cannot return 200 for an unready engine and errors remain private', async t => {
  let broken = false;
  const server=await startHealthServer(0,()=>{if(broken)throw new Error('password=private');return snapshot();},()=>false);
  t.after(()=>new Promise<void>((resolve,reject)=>server.close(error=>error?reject(error):resolve())));
  const address=server.address();assert.ok(address&&typeof address==='object');
  const url=`http://127.0.0.1:${address.port}`;
  for(const path of ['/health','/ready']){
    const response=await fetch(url+path);assert.equal(response.status,503);
    const body=await response.json() as {request_id:string};assert.equal(body.request_id,response.headers.get('x-request-id'));
  }
  broken=true;
  const response=await fetch(url+'/health');assert.equal(response.status,500);assert.ok(!(await response.text()).includes('private'));
});
