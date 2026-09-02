import { readFile, rename, writeFile } from 'node:fs/promises';
import { spawn } from 'node:child_process';
import { isAbsolute, resolve } from 'node:path';
import type { Track } from './types.js';

type ManifestTrack={media_id?:string|null;title?:string;path?:string};
type Manifest={tracks?:ManifestTrack[];catalog?:ManifestTrack[];playlists?:Record<string,string[]>};

async function probe(path:string,ffprobePath:string,timeoutMs=10_000):Promise<number> {
  return await new Promise((resolvePromise,reject)=>{
    const child=spawn(ffprobePath,['-v','error','-select_streams','a:0','-show_entries','format=duration','-of','default=nw=1:nk=1','--',path],{stdio:['ignore','pipe','pipe']});
    let stdout='';let stderr='';const timer=setTimeout(()=>{child.kill('SIGKILL');reject(new Error('ffprobe timeout'));},timeoutMs);
    child.stdout.on('data',d=>stdout+=String(d));child.stderr.on('data',d=>{if(stderr.length<2048)stderr+=String(d);});
    child.once('error',reject);child.once('exit',code=>{clearTimeout(timer);const value=Number(stdout.trim());if(code!==0||!Number.isFinite(value)||value<=0)reject(new Error(stderr.trim()||'invalid audio'));else resolvePromise(value);});
  });
}

async function validate(items:ManifestTrack[],ffprobePath:string,failed:string[],prefix:string):Promise<Track[]> {
  const tracks:Track[]=[];
  for(const [index,item] of items.entries()) {
    if(!item.path||!isAbsolute(item.path)||/[\u0000\r\n]/.test(item.path)||!item.title){failed.push(`${prefix}-${index}: invalid manifest`);continue;}
    try{tracks.push({mediaId:item.media_id??null,title:item.title,path:resolve(item.path),durationSeconds:await probe(resolve(item.path),ffprobePath)});}
    catch(error){failed.push(`${item.title??`${prefix}-${index}`}: ${error instanceof Error?error.message:'invalid audio'}`);}
  }
  return tracks;
}

export async function loadAndValidatePlaylist(manifestPath:string,fallbackPath:string,ffprobePath:string):Promise<{tracks:Track[];catalog:Track[];playlists:Record<string,string[]>;failed:string[];fallbackUsed:boolean}> {
  const parsed=JSON.parse(await readFile(manifestPath,'utf8')) as Manifest;const failed:string[]=[];
  const main=await validate(parsed.tracks??[],ffprobePath,failed,'track');
  const extra=await validate(parsed.catalog??[],ffprobePath,failed,'catalog');
  const catalogByMedia=new Map<string,Track>();
  for(const track of [...main,...extra])if(track.mediaId&&!catalogByMedia.has(track.mediaId))catalogByMedia.set(track.mediaId,track);
  const playlists:Record<string,string[]>={};
  for(const [id,mediaIds] of Object.entries(parsed.playlists??{})){
    if(!id||!Array.isArray(mediaIds)||mediaIds.length===0||mediaIds.some(mediaId=>typeof mediaId!=='string'||!catalogByMedia.has(mediaId))){failed.push(`playlist-${id||'unknown'}: invalid media identity`);continue;}
    playlists[id]=[...mediaIds];
  }
  if(main.length)return {tracks:main,catalog:[...catalogByMedia.values()],playlists,failed,fallbackUsed:false};
  const duration=await probe(fallbackPath,ffprobePath);const fallback={mediaId:null,title:'Development Fallback',path:fallbackPath,durationSeconds:duration};
  return {tracks:[fallback],catalog:[...catalogByMedia.values()],playlists,failed,fallbackUsed:true};
}

export async function writeSourcePlaylist(path:string,tracks:Track[]):Promise<void>{
  await writeFile(path,sourcePlaylist(tracks),{encoding:'utf8',flag:'wx'});
}
function safeMetadata(value:string):string{return value.replace(/[^a-zA-Z0-9._-]/g,'_').slice(0,200);}
function sourcePlaylist(tracks:Track[]):string{return `${tracks.map((track,index)=>`annotate:tarteel_index="${index}",media_id="${safeMetadata(track.mediaId??'none')}",queue_entry_id="none":${track.path}`).join('\n')}\n`;}
export async function replaceSourcePlaylist(path:string,tracks:Track[]):Promise<void>{const next=`${path}.next`;await writeFile(next,sourcePlaylist(tracks),{encoding:'utf8',flag:'w',mode:0o600});await rename(next,path);}
