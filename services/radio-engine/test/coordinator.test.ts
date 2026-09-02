import test from 'node:test';
import assert from 'node:assert/strict';
import type { Config } from '../src/config.js';
import { RadioCoordinator,type AutomationStore,type CoordinatorEngine } from '../src/coordinator.js';
import type { ClaimedCommand,ClaimedOccurrence,EnqueueInput } from '../src/automation-store.js';
import type { EngineSnapshot,Lease,Track } from '../src/types.js';

const lease:Lease={stationId:'00000000-0000-4000-8000-000000000006',ownerId:'test-owner',fencingToken:7,expiresAt:'2099-01-01T00:00:00Z'};
const config:Config={stationId:lease.stationId,ownerId:lease.ownerId,databaseMode:'supabase',supabaseUrl:'https://example.invalid',supabaseSecretKey:'test-only',ffmpegPath:'ffmpeg',ffprobePath:'ffprobe',liquidsoapPath:'liquidsoap',liquidsoapAllowRoot:false,icecastHost:'127.0.0.1',icecastPort:8000,mount:'/tarteel.mp3',sourceUser:'source',sourcePassword:'test',playlistPath:'/tmp/playlist.json',fallbackPath:'/tmp/fallback.m4a',workspaceRoot:'/tmp/radio',healthPort:8091,leaseSeconds:15,heartbeatSeconds:5,sourceTimeoutSeconds:20,restartMax:5,version:'test',schedulerPollSeconds:5,commandPollSeconds:2,missedGraceSeconds:120,queueLookaheadSeconds:120,liquidsoapControlPort:1234,faultInjectionEnabled:false};
function snapshot():EngineSnapshot{return{mode:'AUTO',sourceConnected:true,liquidsoapAlive:true,icecastReachable:true,mountAvailable:true,broadcasting:true,streamMount:'/tarteel.mp3',current:{mediaId:'m-main',title:'Main',path:'/main.m4a',durationSeconds:20},next:null,currentStartedAt:'2026-09-02T10:00:00Z',expectedEndAt:'2026-09-02T10:00:20Z',sourceStartedAt:'2026-09-02T09:59:59Z',lastError:null,lastRecoveryAt:null,reconnectCount:0,trackFailures:0,playoutAckCount:0};}
class FakeEngine implements CoordinatorEngine{
  activeLease:Lease|null=lease;snapshot=snapshot();applied:Track[]=[];modes:string[]=[];skipCount=0;clearCount=0;
  private tracks=new Map<string,Track>([['m1',{mediaId:'m1',title:'One',path:'/one.m4a',durationSeconds:20}],['m2',{mediaId:'m2',title:'Two',path:'/two.m4a',durationSeconds:20}]]);
  resolveMediaTrack(id:string):Track{const value=this.tracks.get(id);if(!value)throw new Error('missing');return{...value};}
  resolvePlaylistTracks():Track[]{return[this.resolveMediaTrack('m1'),this.resolveMediaTrack('m2')];}
  async applyAutomationTracks(tracks:Track[],interrupt=false):Promise<void>{this.applied=tracks.map(track=>({...track}));if(interrupt)this.modes.push('INTERRUPT');}
  async skipCurrent():Promise<void>{this.skipCount++;}
  async clearAutomation():Promise<void>{this.clearCount++;}
  async setAutomationMode(mode:'AUTO'|'SCHEDULED'|'MANUAL'):Promise<void>{this.snapshot.mode=mode;this.modes.push(mode);}
}
class FakeStore implements AutomationStore{
  occurrence:ClaimedOccurrence|null=null;command:ClaimedCommand|null=null;enqueues:EnqueueInput[]=[];effectStatuses:string[]=[];completedCommands:Array<{id:string;ok:boolean}>=[];completedOccurrences:Array<{id:string;ok:boolean}>=[];starts:string[]=[];ends:string[]=[];recoveries=0;
  async recover():Promise<Record<string,unknown>>{this.recoveries++;return{};}
  async materialize():Promise<number>{return 1;}
  async claimOccurrence():Promise<ClaimedOccurrence|null>{const value=this.occurrence;this.occurrence=null;return value;}
  async completeOccurrence(_lease:Lease,id:string,ok:boolean):Promise<boolean>{this.completedOccurrences.push({id,ok});return true;}
  async claimCommand():Promise<ClaimedCommand|null>{const value=this.command;this.command=null;return value;}
  async recordCommandEffect(_lease:Lease,_id:string,_effect:string,_hash:string,status:string):Promise<string>{this.effectStatuses.push(status);return'effect';}
  async enqueue(_lease:Lease,input:EnqueueInput):Promise<string>{this.enqueues.push(input);return`q-${this.enqueues.length}`;}
  async completeCommand(_lease:Lease,id:string,ok:boolean):Promise<boolean>{this.completedCommands.push({id,ok});return true;}
  async recordPlayoutStart(_lease:Lease,queueId:string):Promise<number>{this.starts.push(queueId);return this.starts.length;}
  async recordPlayoutEnd(_lease:Lease,playoutId:string):Promise<boolean>{this.ends.push(playoutId);return true;}
}
async function privateTick(coordinator:RadioCoordinator,name:'tickSchedule'|'tickCommand'|'tickAck',arg?:Date):Promise<void>{
  const target=coordinator as unknown as Record<string,((arg?:Date)=>Promise<void>)|undefined>;
  const tick=target[name];
  assert.ok(tick,`missing coordinator tick: ${name}`);
  await tick.call(coordinator,arg);
}

test('schedule claim materializes queue and ACK closes history and occurrence',async()=>{
  const engine=new FakeEngine(),store=new FakeStore();store.occurrence={id:'occ-1',schedule_id:'schedule-1',station_id:lease.stationId,content_type:'MEDIA',media_id:'m1',playlist_id:null,priority:'NORMAL',interrupt_policy:'FINISH_CURRENT',scheduled_for:'2026-09-02T10:00:00Z'};
  const coordinator=new RadioCoordinator(config,engine,store);await privateTick(coordinator,'tickSchedule',new Date('2026-09-02T10:00:00Z'));
  assert.equal(store.enqueues[0]?.idempotencyKey,'occurrence:occ-1:0');assert.equal(engine.applied[0]?.queueEntryId,'q-1');assert.equal(engine.snapshot.mode,'SCHEDULED');
  engine.snapshot.current=engine.applied[0]!;engine.snapshot.currentStartedAt='2026-09-02T10:00:20Z';engine.snapshot.expectedEndAt='2026-09-02T10:00:40Z';engine.snapshot.playoutAckCount=1;await privateTick(coordinator,'tickAck');assert.deepEqual(store.starts,['q-1']);
  engine.snapshot.current={mediaId:'m-main',title:'Main',path:'/main.m4a',durationSeconds:20};engine.snapshot.currentStartedAt='2026-09-02T10:00:40Z';engine.snapshot.expectedEndAt='2026-09-02T10:01:00Z';engine.snapshot.playoutAckCount=2;await privateTick(coordinator,'tickAck');assert.equal(store.ends.length,1);assert.deepEqual(store.completedOccurrences,[{id:'occ-1',ok:true}]);
});

test('PLAY_NOW is completed only after real playout ACK',async()=>{
  const engine=new FakeEngine(),store=new FakeStore();store.command={id:'cmd-1',station_id:lease.stationId,command_type:'PLAY_NOW',payload:{media_id:'m2',interrupt:true},priority:'HIGH',created_at:'2026-09-02T10:00:00Z'};
  const coordinator=new RadioCoordinator(config,engine,store);await privateTick(coordinator,'tickCommand');assert.deepEqual(store.effectStatuses,['PREPARED','DISPATCHED']);assert.equal(store.completedCommands.length,0);assert.ok(engine.modes.includes('INTERRUPT'));
  engine.snapshot.current=engine.applied[0]!;engine.snapshot.currentStartedAt='2026-09-02T10:00:01Z';engine.snapshot.expectedEndAt='2026-09-02T10:00:21Z';engine.snapshot.playoutAckCount=1;await privateTick(coordinator,'tickAck');assert.deepEqual(store.effectStatuses,['PREPARED','DISPATCHED','ACKED']);assert.deepEqual(store.completedCommands,[{id:'cmd-1',ok:true}]);
});

test('invalid playout timeline fails closed and retries the same ACK',async()=>{
  const engine=new FakeEngine(),store=new FakeStore();const coordinator=new RadioCoordinator(config,engine,store);engine.snapshot.current={mediaId:'m1',title:'One',path:'/one.m4a',durationSeconds:20,queueEntryId:'q-x'};engine.snapshot.currentStartedAt='2026-09-02T10:00:20Z';engine.snapshot.expectedEndAt='2026-09-02T10:00:10Z';engine.snapshot.playoutAckCount=1;await privateTick(coordinator,'tickAck');assert.equal(store.starts.length,0);engine.snapshot.expectedEndAt='2026-09-02T10:00:40Z';await privateTick(coordinator,'tickAck');assert.deepEqual(store.starts,['q-x']);
});

test('control commands acknowledge only after local Liquidsoap control succeeds',async()=>{
  const engine=new FakeEngine(),store=new FakeStore(),coordinator=new RadioCoordinator(config,engine,store);
  for(const [type,expected] of [['SKIP','skip'],['STOP_AFTER_CURRENT','clear'],['RESUME_AUTO','clear']] as const){store.command={id:`cmd-${type}`,station_id:lease.stationId,command_type:type,payload:{},priority:'NORMAL',created_at:'2026-09-02T10:00:00Z'};await privateTick(coordinator,'tickCommand');assert.equal(store.completedCommands.at(-1)?.ok,true);if(expected==='skip')assert.ok(engine.skipCount>0);else assert.ok(engine.clearCount>0);}
});