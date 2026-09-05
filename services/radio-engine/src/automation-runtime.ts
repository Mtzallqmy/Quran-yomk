import { createHash, randomUUID } from 'node:crypto';
import type { Config } from './config.js';
import { commandEffect,type ContentResolver,type RadioCommand } from './commands.js';
import type { ClaimedCommand,ClaimedOccurrence,ResolvedTrack,SupabaseAutomationStore } from './automation-store.js';
import type { RadioEngine } from './engine.js';
import { Logger } from './logger.js';
import type { Lease,Track } from './types.js';

function errorMessage(error:unknown):string{return error instanceof Error?error.message:String(error);}
function commandHash(command:ClaimedCommand):string{return createHash('sha256').update(JSON.stringify({id:command.id,type:command.command_type,payload:command.payload,priority:command.priority,created_at:command.created_at})).digest('hex');}

export class AutomationRuntime {
  private schedulerTimer?:NodeJS.Timeout;private commandTimer?:NodeJS.Timeout;private schedulerRunning=false;private commandRunning=false;
  private recoveredToken:number|null=null;private activePlayout:{id:string;queueEntryId:string}|null=null;private unsubscribeTrack?:()=>void;
  constructor(private readonly config:Config,private readonly store:SupabaseAutomationStore,private readonly engine:RadioEngine,private readonly logger=new Logger('radio-automation')){}

  start():void{
    if(this.schedulerTimer||this.commandTimer)return;
    this.unsubscribeTrack=this.engine.onTrackStart(event=>void this.onTrackStart(event.track,event.startedAt));
    this.schedulerTimer=setInterval(()=>void this.schedulerTick(),this.config.schedulerPollSeconds*1000);this.schedulerTimer.unref();
    this.commandTimer=setInterval(()=>void this.commandTick(),this.config.commandPollSeconds*1000);this.commandTimer.unref();
    void this.schedulerTick();void this.commandTick();
  }
  stop():void{if(this.schedulerTimer)clearInterval(this.schedulerTimer);if(this.commandTimer)clearInterval(this.commandTimer);this.schedulerTimer=undefined;this.commandTimer=undefined;this.unsubscribeTrack?.();this.unsubscribeTrack=undefined;}

  async schedulerTick(now=new Date()):Promise<void>{
    if(this.schedulerRunning)return;const lease=this.engine.currentLease();if(!lease)return;this.schedulerRunning=true;
    try{
      await this.ensureRecovered(lease);
      const materialized=await this.store.materialize(lease.stationId,new Date(now.getTime()-this.config.missedGraceSeconds*1000),new Date(now.getTime()+this.config.queueLookaheadSeconds*1000));
      const occurrence=await this.store.claimOccurrence(lease,this.config.missedGraceSeconds,now);
      if(!occurrence){this.logger.info('SCHEDULER_TICK',{materialized,occurrence_id:null});return;}
      await this.dispatchOccurrence(lease,occurrence);
      this.logger.info('SCHEDULER_TICK',{materialized,occurrence_id:occurrence.id});
    }catch(error){this.logger.error('SCHEDULER_FAILED',error);}finally{this.schedulerRunning=false;}
  }

  async commandTick():Promise<void>{
    if(this.commandRunning)return;const lease=this.engine.currentLease();if(!lease)return;this.commandRunning=true;
    try{
      await this.ensureRecovered(lease);
      const command=await this.store.claimCommand(lease);if(!command)return;
      await this.dispatchCommand(lease,command);
    }catch(error){this.logger.error('COMMAND_LOOP_FAILED',error);}finally{this.commandRunning=false;}
  }

  private async ensureRecovered(lease:Lease):Promise<void>{if(this.recoveredToken===lease.fencingToken)return;const recovered=await this.store.recoverAutomation(lease);this.recoveredToken=lease.fencingToken;this.logger.info('AUTOMATION_RECOVERED',{fencing_token:lease.fencingToken,...recovered});}

  private async dispatchOccurrence(lease:Lease,occurrence:ClaimedOccurrence):Promise<void>{
    try{
      const resolved=occurrence.content_type==='MEDIA'
        ? [await this.store.resolveMedia(lease.stationId,occurrence.media_id!)]
        : await this.store.resolvePlaylist(lease.stationId,occurrence.playlist_id!);
      const tracks=await this.persistTracks(lease,resolved,{source:'SCHEDULED',priority:occurrence.priority,interruptPolicy:occurrence.interrupt_policy,intendedAt:occurrence.scheduled_for,occurrenceId:occurrence.id,playlistId:occurrence.playlist_id??undefined,idempotencyPrefix:`occurrence:${occurrence.id}`});
      await this.engine.applyAutomationTracks(tracks,occurrence.interrupt_policy==='INTERRUPT');
      await this.engine.setAutomationMode('SCHEDULED');
      await this.store.completeOccurrence(lease,occurrence.id,true,{queue_entries:tracks.map(x=>x.queueEntryId),dispatched_at:new Date().toISOString()});
    }catch(error){await this.store.completeOccurrence(lease,occurrence.id,false,{},'DISPATCH_FAILED',errorMessage(error)).catch(()=>false);throw error;}
  }

  private async dispatchCommand(lease:Lease,claimed:ClaimedCommand):Promise<void>{
    const command:RadioCommand={id:claimed.id,stationId:claimed.station_id,type:claimed.command_type as RadioCommand['type'],priority:claimed.priority,payload:claimed.payload,createdAt:claimed.created_at};
    const resolver:ContentResolver={resolveMedia:async id=>this.stripResolved(await this.store.resolveMedia(lease.stationId,id)),resolvePlaylist:async id=>(await this.store.resolvePlaylist(lease.stationId,id)).map(track=>this.stripResolved(track))};
    const hash=commandHash(claimed);
    try{
      const effect=await commandEffect(command,resolver);
      await this.store.recordCommandEffect(lease,claimed.id,effect.kind,hash,'PREPARED');
      if(effect.kind==='ENQUEUE'){
        const resolved=effect.items.map(item=>({mediaId:item.mediaId,title:item.title,path:item.path,durationSeconds:item.durationSeconds}));
        const tracks=await this.persistTracks(lease,resolved,{source:effect.items[0]!.source,priority:effect.items[0]!.priority,interruptPolicy:effect.items[0]!.interruptPolicy,intendedAt:claimed.created_at,commandId:claimed.id,playlistId:this.payloadString(claimed.payload,'playlist_id')??undefined,idempotencyPrefix:`command:${claimed.id}`});
        const interrupt=effect.items.some(item=>item.interruptPolicy==='INTERRUPT');
        await this.engine.applyAutomationTracks(tracks,interrupt);await this.engine.setAutomationMode('MANUAL');
      }else if(effect.kind==='SKIP'){await this.engine.skipAutomationCurrent();}
      else if(effect.kind==='STOP_AFTER_CURRENT'){await this.engine.requestStopAfterCurrent();}
      else if(effect.kind==='RESUME_AUTO'){await this.engine.resumeAuto();}
      await this.store.recordCommandEffect(lease,claimed.id,effect.kind,hash,'ACKED',{dispatched_at:new Date().toISOString()});
      await this.store.completeCommand(lease,claimed.id,true,{effect:effect.kind});
      this.logger.info('COMMAND_EXECUTED',{command_id:claimed.id,effect:effect.kind});
    }catch(error){await this.store.recordCommandEffect(lease,claimed.id,'ENQUEUE',hash,'FAILED',{error:errorMessage(error)}).catch(()=>null);await this.store.completeCommand(lease,claimed.id,false,{},'COMMAND_DISPATCH_FAILED',errorMessage(error)).catch(()=>false);throw error;}
  }

  private async persistTracks(lease:Lease,resolved:ResolvedTrack[]|Track[],options:{source:'SCHEDULED'|'MANUAL'|'EMERGENCY';priority:ClaimedOccurrence['priority'];interruptPolicy:ClaimedOccurrence['interrupt_policy'];intendedAt:string;idempotencyPrefix:string;commandId?:string;occurrenceId?:string;playlistId?:string}):Promise<Track[]>{
    const tracks:Track[]=[];
    for(const [index,track] of resolved.entries()){
      if(!track.mediaId)throw new Error('automation media id is required');
      const rich=track as ResolvedTrack;
      const queueEntryId=await this.store.enqueue(lease,{mediaId:track.mediaId,source:options.source,priority:options.priority,interruptPolicy:options.interruptPolicy,idempotencyKey:`${options.idempotencyPrefix}:${index}`,intendedAt:options.intendedAt,sequence:index,commandId:options.commandId,occurrenceId:options.occurrenceId,playlistId:rich.playlistId??options.playlistId,playlistItemId:rich.playlistItemId,metadata:{runtime:'radio-engine'}});
      tracks.push({...track,queueEntryId});
    }
    return tracks;
  }

  private stripResolved(track:ResolvedTrack){return{mediaId:track.mediaId!,title:track.title,path:track.path,durationSeconds:track.durationSeconds};}
  private payloadString(payload:unknown,key:string):string|null{if(!payload||typeof payload!=='object'||Array.isArray(payload))return null;const value=(payload as Record<string,unknown>)[key];return typeof value==='string'?value:null;}

  private async onTrackStart(track:Track,startedAt:string):Promise<void>{
    const lease=this.engine.currentLease();if(!lease||!track.queueEntryId)return;
    try{
      if(this.activePlayout&&this.activePlayout.queueEntryId!==track.queueEntryId){await this.store.recordPlayoutEnd(lease,this.activePlayout.id,startedAt,true);}
      const playoutId=randomUUID();await this.store.recordPlayoutStart(lease,track.queueEntryId,playoutId,startedAt);this.activePlayout={id:playoutId,queueEntryId:track.queueEntryId};
      this.logger.info('PLAYOUT_ACK_PERSISTED',{queue_entry_id:track.queueEntryId,playout_id:playoutId});
    }catch(error){this.logger.error('PLAYOUT_ACK_FAILED',error,{queue_entry_id:track.queueEntryId});}
  }
}
