import { spawnSync } from 'node:child_process';
import { join } from 'node:path';
import { loadConfig } from './config.js';
import { DevelopmentLeaseStore, SupabaseLeaseStore } from './database.js';
import { SupabaseAutomationStore } from './automation-store.js';
import { AutomationRuntime } from './automation-runtime.js';
import { RadioEngine } from './engine.js';

if(process.argv[2]==='check-dependencies'){
  const dependencies=[
    {name:'ffmpeg',path:process.env.TARTEEL_FFMPEG_PATH??'ffmpeg',argument:'-version'},
    {name:'ffprobe',path:process.env.TARTEEL_FFPROBE_PATH??'ffprobe',argument:'-version'},
    {name:'liquidsoap',path:process.env.TARTEEL_LIQUIDSOAP_PATH??'liquidsoap',argument:'--version'}
  ];
  for(const dependency of dependencies){
    const env={...process.env};
    if(dependency.name==='liquidsoap'&&process.env.TARTEEL_LIQUIDSOAP_LIBRARY_PATH)env.LD_LIBRARY_PATH=process.env.TARTEEL_LIQUIDSOAP_LIBRARY_PATH;
    const result=spawnSync(dependency.path,[dependency.argument],{encoding:'utf8',env});
    if(result.status!==0)throw new Error(`${dependency.name} unavailable`);
    process.stdout.write(`${result.stdout.split('\n')[0]}\n`);
  }
  process.exit(0);
}
const config=loadConfig();
const store=config.databaseMode==='supabase'?new SupabaseLeaseStore(config.supabaseUrl!,config.supabaseSecretKey!):new DevelopmentLeaseStore();
const engine=new RadioEngine(config,store);
const automation=config.databaseMode==='supabase'
  ?new AutomationRuntime(config,new SupabaseAutomationStore(config.supabaseUrl!,config.supabaseSecretKey!,join(config.workspaceRoot,'media-cache')),engine)
  :null;
let shuttingDown=false;
async function shutdown():Promise<void>{if(shuttingDown)return;shuttingDown=true;automation?.stop();await engine.stop();}
for(const signal of ['SIGINT','SIGTERM'] as const)process.on(signal,()=>void shutdown().finally(()=>process.exit(0)));
process.on('SIGUSR2',()=>{try{engine.crashSourceForTest();}catch(error){process.stderr.write(`${JSON.stringify({timestamp:new Date().toISOString(),service:'radio-engine',level:'WARN',event:'FAULT_INJECTION_REJECTED',error:error instanceof Error?error.message:String(error)})}\n`);}});
engine.start().then(()=>{automation?.start();}).catch(error=>{automation?.stop();process.stderr.write(`${JSON.stringify({timestamp:new Date().toISOString(),service:'radio-engine',level:'ERROR',event:'ENGINE_FATAL',error:error instanceof Error?error.message:String(error)})}\n`);process.exitCode=1;});
