import { mkdir, writeFile } from 'node:fs/promises';
import { spawn } from 'node:child_process';
import { resolve, join } from 'node:path';
import { createClient } from '@supabase/supabase-js';

const root=resolve(import.meta.dirname,'../../..');
const stationId=process.env.TARTEEL_STATION_ID??'00000000-0000-4000-8000-000000000006';
const url=required('TARTEEL_SUPABASE_URL');
const runtimeKey=required('TARTEEL_SUPABASE_RUNTIME_KEY');
const targetMediaId='00000000-0000-4000-8100-000000000004';
const streamUrl=process.env.TARTEEL_COMBINED_STREAM_URL??'http://127.0.0.1:8000/tarteel.mp3';
const client=createClient(url,runtimeKey,{auth:{persistSession:false,autoRefreshToken:false}});
const idempotencyKey=`combined-runtime:${process.env.GITHUB_RUN_ID??Date.now()}:${Date.now()}`;
const result={status:'FAILED',station_id:stationId,target_media_id:targetMediaId,idempotency_key:idempotencyKey};
let listener;
function required(name){const value=process.env[name];if(!value)throw new Error(`${name} is required`);return value;}
const sleep=ms=>new Promise(resolvePromise=>setTimeout(resolvePromise,ms));
async function waitFor(fn,timeout,label){const deadline=Date.now()+timeout;while(Date.now()<deadline){const value=await fn();if(value)return value;await sleep(500);}throw new Error(`${label} timeout`);}
async function one(schema,table,filters){let q=client.schema(schema).from(table).select('*');for(const [key,value] of Object.entries(filters))q=q.eq(key,value);const {data,error}=await q.limit(1);if(error)throw error;return data?.[0]??null;}
async function stop(child){if(!child||child.exitCode!==null)return;child.kill('SIGTERM');await Promise.race([new Promise(r=>child.once('exit',r)),sleep(2000)]);if(child.exitCode===null)child.kill('SIGKILL');}
try{
  const {data:station,error:stationError}=await client.schema('app').from('stations').select('id,slug,production_enabled').eq('id',stationId).single();if(stationError)throw stationError;if(!station||station.slug!=='tarteel-dev'||station.production_enabled!==false)throw new Error('NON_PRODUCTION_STATION_REQUIRED');
  const {data:media,error:mediaError}=await client.schema('app').from('media').select('id,status,station_id').eq('id',targetMediaId).single();if(mediaError)throw mediaError;if(!media||media.status!=='READY'||media.station_id!==stationId)throw new Error('ACCEPTANCE_MEDIA_NOT_READY');
  const chunks=[];listener=spawn('ffmpeg',['-hide_banner','-loglevel','error','-fflags','nobuffer','-i',streamUrl,'-t','45','-f','s16le','-ac','1','-ar','8000','pipe:1']);listener.stdout.on('data',chunk=>chunks.push(chunk));
  const {data:command,error:commandError}=await client.schema('radio').from('radio_commands').insert({station_id:stationId,command_type:'PLAY_NOW',payload:{media_id:targetMediaId,interrupt:true,acceptance:'combined-runtime'},priority:'HIGH',idempotency_key:idempotencyKey}).select('id,status').single();if(commandError)throw commandError;
  const completed=await waitFor(async()=>{const row=await one('radio','radio_commands',{id:command.id});return row?.status==='COMPLETED'?row:null;},60000,'command completion');
  const effect=await waitFor(async()=>{const row=await one('radio','command_effects',{command_id:command.id});return row?.status==='ACKED'?row:null;},30000,'command effect ACK');
  const history=await waitFor(async()=>{const row=await one('radio','play_history',{command_id:command.id});return row?.started_at?row:null;},30000,'play history');
  const nowPlaying=await waitFor(async()=>{const row=await one('radio','now_playing',{station_id:stationId});return row?.media_id===targetMediaId?row:null;},30000,'now playing');
  await sleep(5000);const decodedBytes=chunks.reduce((total,chunk)=>total+chunk.length,0);if(decodedBytes<16000)throw new Error(`DECODER_OUTPUT_TOO_SMALL:${decodedBytes}`);
  Object.assign(result,{status:'PASS',command_id:command.id,command_status:completed.status,effect_status:effect.status,fencing_token:Number(effect.fencing_token),queue_entry_id:history.queue_entry_id,playout_started_at:history.started_at,now_playing_media_id:nowPlaying.media_id,decoded_bytes:decodedBytes,secret_leak:false});
}catch(error){result.error=error instanceof Error?error.message:String(error);throw error;}finally{await stop(listener);await mkdir(join(root,'artifacts'),{recursive:true});await writeFile(join(root,'artifacts/combined-runtime-result.json'),JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result,null,2));}
if(result.status!=='PASS')process.exitCode=1;
