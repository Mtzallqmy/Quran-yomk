import { readFile, writeFile } from 'node:fs/promises';
import { spawn } from 'node:child_process';
import { isAbsolute, resolve } from 'node:path';
import type { Track } from './types.js';

async function probe(path:string,ffprobePath:string,timeoutMs=10_000):Promise<number> {
  return await new Promise((resolvePromise,reject)=>{
    const child=spawn(ffprobePath,['-v','error','-select_streams','a:0','-show_entries','format=duration','-of','default=nw=1:nk=1','--',path],{stdio:['ignore','pipe','pipe']});
    let stdout='';let stderr='';const timer=setTimeout(()=>{child.kill('SIGKILL');reject(new Error('ffprobe timeout'));},timeoutMs);
    child.stdout.on('data',d=>stdout+=String(d));child.stderr.on('data',d=>{if(stderr.length<2048)stderr+=String(d);});
    child.once('error',reject);child.once('exit',code=>{clearTimeout(timer);const value=Number(stdout.trim());if(code!==0||!Number.isFinite(value)||value<=0)reject(new Error(stderr.trim()||'invalid audio'));else resolvePromise(value);});
  });
}

export async function loadAndValidatePlaylist(manifestPath:string,fallbackPath:string,ffprobePath:string):Promise<{tracks:Track[];failed:string[];fallbackUsed:boolean}> {
  const parsed=JSON.parse(await readFile(manifestPath,'utf8')) as {tracks?:Array<{media_id?:string|null;title?:string;path?:string}>};
  const tracks:Track[]=[];const failed:string[]=[];
  for(const [index,item] of (parsed.tracks??[]).entries()) {
    if(!item.path||!isAbsolute(item.path)||!item.title){failed.push(`track-${index}: invalid manifest`);continue;}
    try{tracks.push({mediaId:item.media_id??null,title:item.title,path:resolve(item.path),durationSeconds:await probe(resolve(item.path),ffprobePath)});}
    catch(error){failed.push(`${item.title??`track-${index}`}: ${error instanceof Error?error.message:'invalid audio'}`);}
  }
  if(tracks.length)return {tracks,failed,fallbackUsed:false};
  const duration=await probe(fallbackPath,ffprobePath);
  return {tracks:[{mediaId:null,title:'Development Fallback',path:fallbackPath,durationSeconds:duration}],failed,fallbackUsed:true};
}

export async function writeSourcePlaylist(path:string,tracks:Track[]):Promise<void>{
  await writeFile(path,`${tracks.map(track=>track.path).join('\n')}\n`,{encoding:'utf8',flag:'wx'});
}
