import { fetchBackend } from './http.js';
import { createHash } from 'node:crypto';
import { mkdir, readFile, rename, stat, writeFile } from 'node:fs/promises';
import { extname, join } from 'node:path';
import { createClient,type SupabaseClient } from '@supabase/supabase-js';
import { materializeOccurrences,type ScheduleDefinition } from './scheduler.js';
import type { Lease,Track } from './types.js';
import type { Priority } from './priority.js';
import type { InterruptPolicy,QueueSource } from './queue-manager.js';

export interface ClaimedOccurrence {id:string;schedule_id:string;station_id:string;content_type:'MEDIA'|'PLAYLIST';media_id:string|null;playlist_id:string|null;priority:Priority;interrupt_policy:InterruptPolicy;scheduled_for:string;}
export interface ClaimedCommand {id:string;station_id:string;command_type:string;payload:unknown;priority:Priority;created_at:string;}
export interface EnqueueInput {mediaId:string;source:QueueSource;priority:Priority;interruptPolicy:InterruptPolicy;idempotencyKey:string;intendedAt:string;sequence?:number;commandId?:string;occurrenceId?:string;playlistId?:string;playlistItemId?:string;metadata?:Record<string,unknown>;}
export interface ResolvedTrack extends Track {playlistId?:string;playlistItemId?:string;}

export class SupabaseAutomationStore {
  private client:SupabaseClient;
  constructor(url:string,key:string,private readonly mediaCacheRoot='/tmp/tarteel/radio-media'){
    this.client=createClient(url,key,{global:{fetch:fetchBackend},auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false}});
  }
  async materialize(stationId:string,windowStart:Date,windowEnd:Date):Promise<number>{
    const query=this.client.schema('app').from('schedules')
      .select('id,version,schedule_type,enabled,timezone,start_date,end_date,start_time,days_of_week,priority,created_at,content_type,media_id,playlist_id,interrupt_policy')
      .eq('station_id',stationId).eq('enabled',true).is('deleted_at',null);
    const {data,error}=await query;if(error)throw error;
    const rows:Record<string,unknown>[]=[];
    for(const schedule of data??[]){
      if(schedule.content_type==='PROGRAM')continue;
      const definition:ScheduleDefinition={
        id:String(schedule.id),version:Number(schedule.version),type:schedule.schedule_type as ScheduleDefinition['type'],enabled:Boolean(schedule.enabled),
        timezone:String(schedule.timezone),startDate:String(schedule.start_date),endDate:schedule.end_date?String(schedule.end_date):null,
        startTime:String(schedule.start_time),daysOfWeek:schedule.days_of_week as number[]|null,priority:schedule.priority as Priority,createdAt:String(schedule.created_at)
      };
      for(const occurrence of materializeOccurrences(definition,windowStart,windowEnd)){
        rows.push({schedule_id:schedule.id,station_id:stationId,occurrence_key:`v${definition.version}:${occurrence.localKey}:fold${occurrence.fold}`,
          scheduled_for:occurrence.intendedAt,local_date:occurrence.localKey.slice(0,10),local_time:definition.startTime,timezone:definition.timezone,
          fold:occurrence.fold,priority:schedule.priority,interrupt_policy:schedule.interrupt_policy,schedule_version:definition.version,
          content_type:schedule.content_type,media_id:schedule.media_id,playlist_id:schedule.playlist_id,
          expires_at:new Date(Date.parse(occurrence.intendedAt)+3_600_000).toISOString(),result:{dst_shifted:occurrence.shiftedForDst}});
      }
    }
    if(rows.length===0)return 0;
    const {error:upsertError}=await this.client.schema('radio').from('schedule_occurrences').upsert(rows,{onConflict:'schedule_id,occurrence_key',ignoreDuplicates:true});
    if(upsertError)throw upsertError;
    return rows.length;
  }
  async claimOccurrence(lease:Lease,graceSeconds:number,now=new Date()):Promise<ClaimedOccurrence|null>{const {data,error}=await this.client.schema('radio').rpc('claim_due_occurrence',{p_station_id:lease.stationId,p_owner_id:lease.ownerId,p_fencing_token:lease.fencingToken,p_grace_seconds:graceSeconds,p_now:now.toISOString()});if(error)throw error;return(data as ClaimedOccurrence[]|null)?.[0]??null;}
  async claimCommand(lease:Lease):Promise<ClaimedCommand|null>{const {data,error}=await this.client.schema('radio').rpc('claim_radio_command',{p_station_id:lease.stationId,p_owner_id:lease.ownerId,p_fencing_token:lease.fencingToken});if(error)throw error;return(data as ClaimedCommand[]|null)?.[0]??null;}
  async enqueue(lease:Lease,input:EnqueueInput):Promise<string>{const {data,error}=await this.client.schema('radio').rpc('enqueue_media',{p_station_id:lease.stationId,p_owner_id:lease.ownerId,p_fencing_token:lease.fencingToken,p_media_id:input.mediaId,p_source:input.source,p_priority:input.priority,p_interrupt_policy:input.interruptPolicy,p_idempotency_key:input.idempotencyKey,p_intended_at:input.intendedAt,p_sequence:input.sequence??0,p_command_id:input.commandId??null,p_occurrence_id:input.occurrenceId??null,p_playlist_id:input.playlistId??null,p_playlist_item_id:input.playlistItemId??null,p_metadata:input.metadata??{}});if(error)throw error;return String(data);}
  async completeCommand(lease:Lease,id:string,succeeded:boolean,result:Record<string,unknown>={},errorCode?:string,errorMessage?:string):Promise<boolean>{const {data,error}=await this.client.schema('radio').rpc('complete_radio_command',{p_command_id:id,p_station_id:lease.stationId,p_owner_id:lease.ownerId,p_fencing_token:lease.fencingToken,p_succeeded:succeeded,p_result:result,p_error_code:errorCode??null,p_error_message:errorMessage??null});if(error)throw error;return Boolean(data);}
  async completeOccurrence(lease:Lease,id:string,succeeded:boolean,result:Record<string,unknown>={},errorCode?:string,errorMessage?:string):Promise<boolean>{const {data,error}=await this.client.schema('radio').rpc('complete_schedule_occurrence',{p_occurrence_id:id,p_station_id:lease.stationId,p_owner_id:lease.ownerId,p_fencing_token:lease.fencingToken,p_succeeded:succeeded,p_result:result,p_error_code:errorCode??null,p_error_message:errorMessage??null});if(error)throw error;return Boolean(data);}
  async recordCommandEffect(lease:Lease,commandId:string,effectType:string,payloadHash:string,status:'PREPARED'|'DISPATCHED'|'ACKED'|'FAILED',result:Record<string,unknown>={}):Promise<string>{const {data,error}=await this.client.schema('radio').rpc('record_command_effect',{p_command_id:commandId,p_station_id:lease.stationId,p_owner_id:lease.ownerId,p_fencing_token:lease.fencingToken,p_effect_type:effectType,p_payload_hash:payloadHash,p_status:status,p_result:result});if(error)throw error;return String(data);}
  async recoverAutomation(lease:Lease):Promise<Record<string,unknown>>{const {data,error}=await this.client.schema('radio').rpc('recover_stale_automation',{p_station_id:lease.stationId,p_owner_id:lease.ownerId,p_fencing_token:lease.fencingToken});if(error)throw error;return (data??{}) as Record<string,unknown>;}
  async recordPlayoutStart(lease:Lease,queueEntryId:string,playoutId:string,startedAt:string):Promise<number>{const {data,error}=await this.client.schema('radio').rpc('record_playout_start',{p_queue_entry_id:queueEntryId,p_playout_id:playoutId,p_station_id:lease.stationId,p_owner_id:lease.ownerId,p_fencing_token:lease.fencingToken,p_started_at:startedAt});if(error)throw error;return Number(data);}
  async recordPlayoutEnd(lease:Lease,playoutId:string,endedAt:string,completedNaturally:boolean,reason?:string):Promise<boolean>{const {data,error}=await this.client.schema('radio').rpc('record_playout_end',{p_playout_id:playoutId,p_station_id:lease.stationId,p_owner_id:lease.ownerId,p_fencing_token:lease.fencingToken,p_ended_at:endedAt,p_completed_naturally:completedNaturally,p_reason:reason??null});if(error)throw error;return Boolean(data);}

  async resolveMedia(stationId:string,mediaId:string):Promise<ResolvedTrack>{
    const {data,error}=await this.client.schema('app').from('media')
      .select('id,station_id,title,processed_path,duration_ms,sha256,status,deleted_at')
      .eq('id',mediaId).maybeSingle();
    if(error)throw error;
    if(!data||data.status!=='READY'||data.deleted_at||!data.processed_path||!data.duration_ms||!data.sha256)throw new Error('media is not READY');
    if(data.station_id&&String(data.station_id)!==stationId)throw new Error('media does not belong to station');
    const path=String(data.processed_path);
    if(path.startsWith('/')||path.includes('..')||path.includes('\\')||/[\0-\x1f\x7f]/.test(path))throw new Error('unsafe processed media path');
    const localPath=await this.cacheProcessedMedia(String(data.id),path,String(data.sha256));
    return {mediaId:String(data.id),title:String(data.title),path:localPath,durationSeconds:Number(data.duration_ms)/1000};
  }

  async resolvePlaylist(stationId:string,playlistId:string):Promise<ResolvedTrack[]>{
    const {data:playlist,error:playlistError}=await this.client.schema('app').from('playlists')
      .select('id,station_id,is_active,deleted_at').eq('id',playlistId).maybeSingle();
    if(playlistError)throw playlistError;
    if(!playlist||String(playlist.station_id)!==stationId||playlist.is_active!==true||playlist.deleted_at)throw new Error('playlist is not active for station');
    const {data:items,error}=await this.client.schema('app').from('playlist_items')
      .select('id,media_id,position').eq('playlist_id',playlistId).order('position',{ascending:true});
    if(error)throw error;
    const resolved:ResolvedTrack[]=[];
    for(const item of items??[]){const track=await this.resolveMedia(stationId,String(item.media_id));resolved.push({...track,playlistId,playlistItemId:String(item.id)});}
    if(!resolved.length)throw new Error('playlist is empty');
    return resolved;
  }

  private async cacheProcessedMedia(mediaId:string,objectKey:string,expectedSha:string):Promise<string>{
    await mkdir(this.mediaCacheRoot,{recursive:true,mode:0o700});
    const suffix=extname(objectKey).toLowerCase();
    if(!/^\.[a-z0-9]{1,8}$/.test(suffix))throw new Error('processed media extension is invalid');
    const destination=join(this.mediaCacheRoot,`${mediaId}${suffix}`);
    if(await this.validCachedFile(destination,expectedSha))return destination;
    const {data,error}=await this.client.storage.from('tarteel-media-processed').download(objectKey);
    if(error||!data)throw error??new Error('processed media download failed');
    const bytes=Buffer.from(await data.arrayBuffer());
    if(bytes.length<=0||bytes.length>52_428_800)throw new Error('processed media size is invalid');
    const digest=createHash('sha256').update(bytes).digest('hex');
    if(digest!==expectedSha.toLowerCase())throw new Error('processed media checksum mismatch');
    const temporary=`${destination}.${process.pid}.${Date.now()}.tmp`;
    await writeFile(temporary,bytes,{mode:0o600,flag:'wx'});
    await rename(temporary,destination);
    return destination;
  }

  private async validCachedFile(path:string,expectedSha:string):Promise<boolean>{
    try{const file=await stat(path);if(file.size<=0||file.size>52_428_800)return false;const bytes=await readFile(path);return createHash('sha256').update(bytes).digest('hex')===expectedSha.toLowerCase();}catch{return false;}
  }
}
