import { fetchJsonResponse as fetch } from "../_shared/http.ts";
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const SUPABASE_URL=(Deno.env.get("SUPABASE_URL")??"").replace(/\/$/,"");
const ANON_KEY=Deno.env.get("SUPABASE_ANON_KEY")??"";
const SERVICE_ROLE_KEY=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")??"";
const publishableMap=JSON.parse(Deno.env.get("SUPABASE_PUBLISHABLE_KEYS")??"{}");
const PUBLIC_KEYS=new Set(Object.values(publishableMap).map(String));
if(ANON_KEY)PUBLIC_KEYS.add(ANON_KEY);
const CORS={"access-control-allow-origin":"*","access-control-allow-headers":"apikey,authorization,content-type,x-request-id","access-control-allow-methods":"GET,POST,OPTIONS","content-type":"application/json; charset=utf-8"};

type Json=Record<string,unknown>;
class ManagedRadioError extends Error{constructor(public code:string,message:string,public status=503){super(message)}}
function out(data:unknown,status=200,requestId=crypto.randomUUID()){return new Response(JSON.stringify(data),{status,headers:{...CORS,"cache-control":"no-store","x-request-id":requestId}})}
async function read(r:Response){const t=await r.text();if(!t)return null;try{return JSON.parse(t)}catch{return t}}
async function serviceRpc(name:string,args:Json){const r=await fetch(`${SUPABASE_URL}/rest/v1/rpc/${name}`,{method:"POST",headers:{apikey:SERVICE_ROLE_KEY,authorization:`Bearer ${SERVICE_ROLE_KEY}`,"content-type":"application/json","accept-profile":"app","content-profile":"app"},body:JSON.stringify(args)});const b=await read(r);if(!r.ok)throw new ManagedRadioError("DATABASE_ERROR",typeof b==="object"&&b&&"message" in b?String((b as Json).message):`RPC ${r.status}`,502);return b}
async function serviceDb(resource:string,init:RequestInit={}){const h=new Headers(init.headers);h.set("apikey",SERVICE_ROLE_KEY);h.set("authorization",`Bearer ${SERVICE_ROLE_KEY}`);h.set("accept-profile","app");h.set("content-profile","app");h.set("prefer",h.get("prefer")??"return=representation");if(init.body)h.set("content-type","application/json");const r=await fetch(`${SUPABASE_URL}/rest/v1/${resource}`,{...init,headers:h});const b=await read(r);if(!r.ok)throw new ManagedRadioError("DATABASE_ERROR",typeof b==="object"&&b&&"message" in b?String((b as Json).message):`DB ${r.status}`,502);return b}
async function publicRpc(name:string,args:Json,key:string){const r=await fetch(`${SUPABASE_URL}/rest/v1/rpc/${name}`,{method:"POST",headers:{apikey:key,"content-type":"application/json"},body:JSON.stringify(args)});const b=await read(r);if(!r.ok)throw new ManagedRadioError("PUBLIC_RESOLVER_ERROR",`Resolver ${r.status}`,502);return b}
async function adminUser(req:Request){const auth=req.headers.get("authorization")??"";if(!auth.startsWith("Bearer "))throw new ManagedRadioError("AUTH_REQUIRED","Administrator authentication required",401);const r=await fetch(`${SUPABASE_URL}/auth/v1/user`,{headers:{apikey:ANON_KEY,authorization:auth}});const b=await read(r) as Json|null;if(!r.ok||!b?.id)throw new ManagedRadioError("SESSION_EXPIRED","Administrator session is invalid",401);const allowed=await serviceRpc("managed_radio_authorized",{p_user_id:String(b.id),p_permission:"schedules.write"});if(allowed!==true)throw new ManagedRadioError("FORBIDDEN","schedules.write permission is required",403);return String(b.id)}

async function recordRun(channelId:string,operation:string,status:string,summary:Json={},errorCode:string|null=null,errorMessage:string|null=null){await serviceDb("managed_radio_sync_runs",{method:"POST",body:JSON.stringify({channel_id:channelId,provider:"RADIO_CO",operation,status,summary,error_code:errorCode,error_message:errorMessage,finished_at:new Date().toISOString()})})}
async function config(){const v=await serviceRpc("managed_radio_overview",{p_slug:"tarteel"}) as Json|null;if(!v?.channel)throw new ManagedRadioError("MANAGED_RADIO_NOT_CONFIGURED","Managed radio config is missing",503);return v}

interface ManagedRadioService{
  getStationStatus():Promise<Json>;
  getNowPlaying():Promise<Json>;
  getProviderSchedule():Promise<unknown>;
  getFinalStreamUrl():Promise<string>;
  syncSchedule(schedule:unknown):Promise<unknown>;
  testRelay(sourceUrl:string):Promise<unknown>;
}

class RadioCoManagedRadioService implements ManagedRadioService{
  readonly stationId=(Deno.env.get("RADIOCO_STATION_ID")??"").trim();
  readonly studioAuthorization=(Deno.env.get("RADIOCO_STUDIO_AUTHORIZATION")??"").trim();
  readonly studioScheduleSyncUrl=(Deno.env.get("RADIOCO_STUDIO_SCHEDULE_SYNC_URL")??"").trim();
  readonly studioRelayTestUrl=(Deno.env.get("RADIOCO_STUDIO_RELAY_TEST_URL")??"").trim();
  private requireStation(){if(!this.stationId)throw new ManagedRadioError("RADIOCO_ACCOUNT_NOT_CONFIGURED","RADIOCO_STATION_ID is not configured in Supabase Edge secrets",503)}
  private async get(url:string){const r=await fetch(url,{headers:{accept:"application/json"},signal:AbortSignal.timeout(10000)});const b=await read(r);if(!r.ok)throw new ManagedRadioError("RADIOCO_PUBLIC_API_ERROR",`Radio.co public API returned ${r.status}`,502);if(!b||typeof b!=="object")throw new ManagedRadioError("RADIOCO_INVALID_RESPONSE","Radio.co response was invalid",502);return b as Json}
  async stationInfo(){this.requireStation();return await this.get(`https://public.radio.co/api/v2/${encodeURIComponent(this.stationId)}`)}
  async getStationStatus(){this.requireStation();return await this.get(`https://public.radio.co/stations/${encodeURIComponent(this.stationId)}/status`)}
  async getNowPlaying(){this.requireStation();return await this.get(`https://public.radio.co/api/v2/${encodeURIComponent(this.stationId)}/track/current`)}
  async getProviderSchedule(){this.requireStation();return await this.get(`https://public.radio.co/stations/${encodeURIComponent(this.stationId)}/embed/schedule`)}
  async getFinalStreamUrl(){const info=await this.stationInfo();const data=info.data&&typeof info.data==="object"?info.data as Json:info;const links=Array.isArray(data.streaming_links)?data.streaming_links:[];for(const item of links){if(item&&typeof item==="object"&&typeof (item as Json).url==="string"){const raw=String((item as Json).url);if(raw.startsWith("https://"))return raw;if(raw.startsWith("http://")&&new URL(raw).hostname.endsWith("radio.co"))return `https://${raw.slice(7)}`}}return `https://streaming.radio.co/${encodeURIComponent(this.stationId)}/listen`}
  private async studio(url:string,payload:unknown){if(!this.studioAuthorization||!url)throw new ManagedRadioError("RADIOCO_STUDIO_API_NOT_CONFIGURED","Radio.co Studio write API contract/authorization is not configured in Supabase Edge secrets",503);const r=await fetch(url,{method:"POST",headers:{authorization:this.studioAuthorization,"content-type":"application/json","accept":"application/json"},body:JSON.stringify(payload),signal:AbortSignal.timeout(15000)});const b=await read(r);if(!r.ok)throw new ManagedRadioError("RADIOCO_STUDIO_API_ERROR",`Radio.co Studio API returned ${r.status}`,502);return b}
  async syncSchedule(schedule:unknown){return await this.studio(this.studioScheduleSyncUrl,{station_id:this.stationId,timezone:"Asia/Aden",source_of_truth:"SUPABASE",schedule})}
  async testRelay(sourceUrl:string){return await this.studio(this.studioRelayTestUrl,{station_id:this.stationId,source_url:sourceUrl})}
}

async function refreshProvider(service:RadioCoManagedRadioService,channelId:string){const [status,nowPlaying,providerSchedule,fixedStreamUrl]=await Promise.all([service.getStationStatus(),service.getNowPlaying(),service.getProviderSchedule(),service.getFinalStreamUrl()]);await serviceDb(`managed_radio_configs?channel_id=eq.${encodeURIComponent(channelId)}`,{method:"PATCH",body:JSON.stringify({station_external_id:service.stationId,fixed_stream_url:fixedStreamUrl,provider_status:String(status.status??(status.data as Json|undefined)?.status??"UNKNOWN"),provider_source:status.source&&typeof status.source==="object"?status.source:{},provider_now_playing:nowPlaying,last_provider_check_at:new Date().toISOString()})});return{status,now_playing:nowPlaying,provider_schedule:providerSchedule,fixed_stream_url:fixedStreamUrl}}

async function schedulePayload(channelId:string){const schedules=await serviceDb(`virtual_radio_schedule?channel_id=eq.${encodeURIComponent(channelId)}&enabled=eq.true&select=id,days_of_week,start_time,end_time,program_title_ar,program_title_en,preferred_station_id,allow_degraded,priority&order=start_time.asc,priority.desc`) as unknown[];const ids=schedules.map((x)=>String((x as Json).id));const candidates=ids.length?await serviceDb(`virtual_radio_candidates?schedule_id=in.(${ids.join(",")})&enabled=eq.true&select=schedule_id,station_id,priority,weight&order=priority.desc`) as unknown[]:[];const stationIds=[...new Set([...schedules.map(x=>(x as Json).preferred_station_id),...candidates.map(x=>(x as Json).station_id)].filter(Boolean).map(String))];const stations=stationIds.length?await serviceDb(`stations?id=in.(${stationIds.join(",")})&select=id,slug,name_ar,stream_url,health_status,provider_id`) as unknown[]:[];return{timezone:"Asia/Aden",schedules,candidates,stations,fallback_order:["PRIMARY_RELAY","SECONDARY_RELAY","BACKUP_PLAYLIST"]}}

Deno.serve(async(req:Request)=>{const requestId=req.headers.get("x-request-id")??crypto.randomUUID();if(req.method==="OPTIONS")return new Response(null,{status:204,headers:CORS});try{
  const u=new URL(req.url);const marker="/tarteel-managed-radio";const i=u.pathname.indexOf(marker);const path=(i>=0?u.pathname.slice(i+marker.length):u.pathname).replace(/^\/+|\/+$/g,"");
  if(req.method==="GET"&&path.startsWith("virtual-radio")){
    const key=req.headers.get("apikey")??"";if(!key||!PUBLIC_KEYS.has(key))throw new ManagedRadioError("INVALID_API_KEY","A valid Tarteel publishable key is required",401);
    const failed=(u.searchParams.get("failed_station_ids")??"").split(",").filter(Boolean).slice(0,8);
    const data=await publicRpc("tarteel_public_virtual_radio_managed",{p_slug:"tarteel",p_environment:Deno.env.get("TARTEEL_PUBLIC_ENVIRONMENT")??"development",p_exclude_station_ids:failed,p_now:new Date().toISOString()},key);
    return out({data},200,requestId);
  }
  if(req.method!=="POST")throw new ManagedRadioError("METHOD_NOT_ALLOWED","Unsupported managed-radio operation",405);
  const actor=await adminUser(req);const body=await req.json().catch(()=>({})) as Json;const operation=String(body.operation??"");const overview=await config();const channel=overview.channel as Json;const channelId=String(channel.id);const service=new RadioCoManagedRadioService();
  try{
    if(operation==="REFRESH_STATUS"||operation==="REFRESH_NOW_PLAYING"){
      const data=await refreshProvider(service,channelId);await recordRun(channelId,operation,"SUCCESS",{actor,station_id:service.stationId,fixed_stream_url:data.fixed_stream_url});return out({data},200,requestId);
    }
    if(operation==="SYNC_SCHEDULE"){
      const payload=await schedulePayload(channelId);const provider=await service.syncSchedule(payload);await serviceDb(`managed_radio_configs?channel_id=eq.${encodeURIComponent(channelId)}`,{method:"PATCH",body:JSON.stringify({last_sync_at:new Date().toISOString(),last_sync_status:"SUCCESS",last_sync_error_code:null})});await recordRun(channelId,operation,"SUCCESS",{actor,schedule_count:(payload.schedules as unknown[]).length});return out({data:{provider,payload}},200,requestId);
    }
    if(operation==="TEST_RELAY"){
      const resolved=await serviceRpc("resolve_virtual_radio",{p_slug:"tarteel",p_environment:"development",p_exclude_station_ids:[]}) as Json;const station=resolved.station as Json|undefined;const source=String(station?.playback_url??"");if(!source.startsWith("https://"))throw new ManagedRadioError("NO_RELAY_SOURCE","No HTTPS relay source is currently resolvable",503);const provider=await service.testRelay(source);await recordRun(channelId,operation,"SUCCESS",{actor,source_station_id:station?.id??null});return out({data:{source_station:station,provider}},200,requestId);
    }
    throw new ManagedRadioError("VALIDATION_ERROR","Unknown operation",422);
  }catch(error){const e=error instanceof ManagedRadioError?error:new ManagedRadioError("MANAGED_RADIO_ERROR","Unexpected managed radio error",500);await recordRun(channelId,operation||"REFRESH_STATUS",e.code.includes("NOT_CONFIGURED")||e.code.includes("ACCOUNT_NOT_CONFIGURED")?"BLOCKED":"FAILED",{actor},e.code,e.message).catch(()=>{});await serviceDb(`managed_radio_configs?channel_id=eq.${encodeURIComponent(channelId)}`,{method:"PATCH",body:JSON.stringify({last_sync_status:e.code.includes("NOT_CONFIGURED")||e.code.includes("ACCOUNT_NOT_CONFIGURED")?"BLOCKED":"FAILED",last_sync_error_code:e.code})}).catch(()=>{});throw e}
}catch(error){const e=error instanceof ManagedRadioError?error:new ManagedRadioError("INTERNAL_ERROR","Unexpected managed radio error",500);console.error(JSON.stringify({event:"MANAGED_RADIO_ERROR",request_id:requestId,code:e.code,status:e.status}));return out({error:{code:e.code,message:e.message,request_id:requestId}},e.status,requestId)}});
