import test from 'node:test';
import assert from 'node:assert/strict';
import { AutomationRuntime } from '../src/automation-runtime.js';
import type { SupabaseAutomationStore,ClaimedCommand,ClaimedOccurrence } from '../src/automation-store.js';
import type { Config } from '../src/config.js';
import type { RadioEngine,TrackStartEvent } from '../src/engine.js';
import type { Logger } from '../src/logger.js';
import type { Lease,Track } from '../src/types.js';

const lease:Lease={stationId:'00000000-0000-4000-8000-000000000006',ownerId:'test-owner',fencingToken:7,expiresAt:'2026-09-05T12:00:00Z'};
const config={schedulerPollSeconds:5,commandPollSeconds:2,missedGraceSeconds:120,queueLookaheadSeconds:120} as Config;
const logger={info(){},warn(){},error(){}} as unknown as Logger;

function harness(options:{occurrence?:ClaimedOccurrence|null;command?:ClaimedCommand|null}){
  const calls:{name:string;args:unknown[]}[]=[];let trackListener:((event:TrackStartEvent)=>void)|null=null;
  const store={
    async recoverAutomation(){calls.push({name:'recover',args:[]});return{occurrences:0,commands:0,queue_entries:0};},
    async materialize(){calls.push({name:'materialize',args:[]});return 1;},
    async claimOccurrence(){const value=options.occurrence??null;options.occurrence=null;return value;},
    async claimCommand(){const value=options.command??null;options.command=null;return value;},
    async resolveMedia(_stationId:string,id:string){calls.push({name:'resolveMedia',args:[id]});return{mediaId:id,title:`track-${id}`,path:`/${id}.m4a`,durationSeconds:20};},
    async resolvePlaylist(){throw new Error('not used');},
    async enqueue(_lease:Lease,input:{mediaId:string}){calls.push({name:'enqueue',args:[input]});return`queue-${input.mediaId}`;},
    async completeOccurrence(_lease:Lease,id:string,succeeded:boolean,result:unknown){calls.push({name:'completeOccurrence',args:[id,succeeded,result]});return true;},
    async completeCommand(_lease:Lease,id:string,succeeded:boolean,result:unknown){calls.push({name:'completeCommand',args:[id,succeeded,result]});return true;},
    async recordCommandEffect(_lease:Lease,id:string,kind:string,_hash:string,status:string){calls.push({name:'effect',args:[id,kind,status]});return'effect';},
    async recordPlayoutStart(_lease:Lease,queueEntryId:string){calls.push({name:'playoutStart',args:[queueEntryId]});return 1;},
    async recordPlayoutEnd(){return true;}
  } as unknown as SupabaseAutomationStore;
  const engine={
    currentLease:()=>lease,
    onTrackStart(listener:(event:TrackStartEvent)=>void){trackListener=listener;return()=>{trackListener=null;};},
    async applyAutomationTracks(tracks:Track[],interrupt=false){calls.push({name:'apply',args:[tracks,interrupt]});},
    async setAutomationMode(mode:string){calls.push({name:'mode',args:[mode]});},
    async skipAutomationCurrent(){calls.push({name:'skip',args:[]});},
    async requestStopAfterCurrent(){calls.push({name:'stopAfter',args:[]});},
    async resumeAuto(){calls.push({name:'resume',args:[]});}
  } as unknown as RadioEngine;
  return{runtime:new AutomationRuntime(config,store,engine,logger),calls,emit:(event:TrackStartEvent)=>trackListener?.(event)};
}

test('scheduler claim is materialized, fenced-enqueued, dispatched, and completed',async()=>{
  const occurrence:ClaimedOccurrence={id:'occ-1',schedule_id:'schedule-1',station_id:lease.stationId,content_type:'MEDIA',media_id:'media-1',playlist_id:null,priority:'HIGH',interrupt_policy:'INTERRUPT',scheduled_for:'2026-09-05T10:00:00Z'};
  const {runtime,calls}=harness({occurrence});
  await runtime.schedulerTick(new Date('2026-09-05T10:00:00Z'));
  assert.ok(calls.some(call=>call.name==='recover'));
  assert.ok(calls.some(call=>call.name==='enqueue'));
  const apply=calls.find(call=>call.name==='apply');assert.ok(apply);const tracks=apply.args[0] as Track[];assert.equal(tracks[0]?.queueEntryId,'queue-media-1');assert.equal(apply.args[1],true);
  assert.ok(calls.some(call=>call.name==='mode'&&call.args[0]==='SCHEDULED'));
  assert.ok(calls.some(call=>call.name==='completeOccurrence'&&call.args[1]===true));
});

test('PLAY_NOW command is claimed, ledgered, enqueued, dispatched and completed',async()=>{
  const command:ClaimedCommand={id:'cmd-1',station_id:lease.stationId,command_type:'PLAY_NOW',payload:{media_id:'media-2',interrupt:true},priority:'NORMAL',created_at:'2026-09-05T10:00:00Z'};
  const {runtime,calls}=harness({command});
  await runtime.commandTick();
  assert.ok(calls.some(call=>call.name==='effect'&&call.args[2]==='PREPARED'));
  const apply=calls.find(call=>call.name==='apply');assert.ok(apply);assert.equal(apply.args[1],true);
  assert.ok(calls.some(call=>call.name==='effect'&&call.args[2]==='ACKED'));
  assert.ok(calls.some(call=>call.name==='mode'&&call.args[0]==='MANUAL'));
  assert.ok(calls.some(call=>call.name==='completeCommand'&&call.args[1]===true));
});

test('Liquidsoap track-start callback persists playout ACK for queue-backed tracks',async()=>{
  const {runtime,calls,emit}=harness({});runtime.start();
  emit({track:{mediaId:'media-3',queueEntryId:'queue-media-3',title:'three',path:'/three.m4a',durationSeconds:20},previous:null,startedAt:'2026-09-05T10:00:01Z'});
  await new Promise(resolve=>setImmediate(resolve));runtime.stop();
  assert.ok(calls.some(call=>call.name==='playoutStart'&&call.args[0]==='queue-media-3'));
});
