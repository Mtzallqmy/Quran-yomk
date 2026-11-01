import { ApiError, assertString, assertUuid, int } from './contracts';
import { adminContext, requirePermission } from './auth';
import type { AdminContext } from './auth';
import { body, json, sameOrigin } from './http';
import { db, rpc } from './supabase';
import { rateLimit } from './rate-limit';

type DispatchResult={response:Response;ctx?:any};

function time(value:unknown,field:string){
  const v=assertString(value,field,8)!;
  if(!/^(?:[01]\d|2[0-3]):[0-5]\d(?::[0-5]\d)?$/.test(v))throw new ApiError(422,'VALIDATION_ERROR',`${field} must be HH:MM or HH:MM:SS`);
  return v.length===5?`${v}:00`:v;
}
function days(value:unknown){
  if(!Array.isArray(value)||!value.length||value.length>7)throw new ApiError(422,'VALIDATION_ERROR','days_of_week must contain 1-7 values');
  const out=[...new Set(value.map((v)=>int(v,'day_of_week',0,6)))];
  if(!out.length)throw new ApiError(422,'VALIDATION_ERROR','days_of_week is required');
  return out;
}
async function audit(ctx:any,requestId:string,action:string,resourceType:string,resourceId:string|null,oldValues:any,newValues:any){
  await db('app','audit_logs',{method:'POST',body:JSON.stringify({actor_id:ctx.userId,action,resource_type:resourceType,resource_id:resourceId,request_id:requestId,old_values:oldValues??null,new_values:newValues??null,metadata:{source:'phase11-admin-api'}})});
}
async function providerOverview(ctx:any){
  requirePermission(ctx,'stations.read');
  const providers=(await db('app','content_providers?slug=eq.islamic-radio-api&deleted_at=is.null&select=id,slug,name,provider_type,website_url,api_base_url,is_active,production_enabled,health_status,last_checked_at,last_success_at,rights_status,commercial_use_status,attribution_text,source_url,integration_basis,license_type,license_url,metadata')).data as any[];
  const provider=providers[0];
  if(!provider)throw new ApiError(404,'NOT_FOUND','Islamic Radio API provider is not configured');
  const [runs,records,owned]=await Promise.all([
    db('app',`provider_sync_runs?provider_id=eq.${provider.id}&select=id,status,started_at,finished_at,fetched_count,inserted_count,updated_count,unchanged_count,missing_count,invalid_count,error_code,error_message,metadata&order=created_at.desc&limit=10`),
    db('app',`provider_station_records?provider_id=eq.${provider.id}&select=station_id,external_key,discovered_stream_url,last_seen_at,missing_since`),
    db('app',`stations?provider_id=eq.${provider.id}&deleted_at=is.null&select=id,health_status,stream_type,stream_url,availability_status`),
  ]);
  const rs=records.data as any[];const os=owned.data as any[];
  return json({data:{provider,last_sync:(runs.data as any[])[0]??null,sync_runs:runs.data,normalized_records:rs.length,http_only:rs.filter(r=>String(r.discovered_stream_url??'').startsWith('http://')).length,missing:rs.filter(r=>r.missing_since).length,owned_station_count:os.length,owned_health:{healthy:os.filter(r=>r.health_status==='HEALTHY').length,degraded:os.filter(r=>r.health_status==='DEGRADED').length,unavailable:os.filter(r=>['UNREACHABLE','INVALID'].includes(r.health_status)).length,unknown:os.filter(r=>r.health_status==='UNKNOWN').length},owned_unsupported:os.filter(r=>r.stream_type==='UNKNOWN_STREAM').length}});
}
async function providerSync(ctx:any,request:Request,requestId:string){
  requirePermission(ctx,'external_stations.write');sameOrigin(request);await rateLimit(`phase11-sync:${ctx.userId}`,3,60_000);
  const result=await rpc('app','sync_islamic_radio_api_stations',{});
  await audit(ctx,requestId,'provider.sync','content_provider',null,null,{provider:'islamic-radio-api',result});
  return json({data:result});
}
async function virtualOverview(ctx:any){
  requirePermission(ctx,'schedules.read');
  const channels=(await db('app','virtual_radio_channels?slug=eq.tarteel&select=*')).data as any[];
  const channel=channels[0];if(!channel)throw new ApiError(404,'NOT_FOUND','Tarteel virtual radio is not configured');
  const schedules=(await db('app',`virtual_radio_schedule?channel_id=eq.${channel.id}&select=*&order=start_time.asc,priority.desc`)).data as any[];
  const ids=schedules.map(s=>s.id);
  const candidates=ids.length?(await db('app',`virtual_radio_candidates?schedule_id=in.(${ids.join(',')})&select=*&order=priority.desc`)).data:[];
  const [categories,stations,providers,preview,current]=await Promise.all([
    db('app','categories?deleted_at=is.null&is_active=eq.true&select=id,slug,name_ar,name_en&order=sort_order.asc,name_ar.asc'),
    db('app',"stations?station_source=eq.EXTERNAL&deleted_at=is.null&is_active=eq.true&select=id,slug,name_ar,name_en,category_id,provider_id,stream_type,stream_url,health_status,availability_status&order=name_ar.asc"),
    db('app','content_providers?deleted_at=is.null&is_active=eq.true&select=id,slug,name&order=priority.asc,name.asc'),
    rpc('app','virtual_radio_preview',{p_slug:'tarteel',p_hours:24,p_environment:'development'}),
    rpc('app','resolve_virtual_radio',{p_slug:'tarteel',p_environment:'development',p_exclude_station_ids:[]}),
  ]);
  return json({data:{channel,schedules,candidates,categories:categories.data,stations:stations.data,providers:providers.data,preview,current}});
}
async function channelUpdate(ctx:any,request:Request,requestId:string){
  requirePermission(ctx,'schedules.write');sameOrigin(request);const p=await body(request) as any;
  const current=((await db('app','virtual_radio_channels?slug=eq.tarteel&select=*')).data as any[])[0];if(!current)throw new ApiError(404,'NOT_FOUND','Virtual channel not found');
  const patch:any={};
  for(const k of ['name_ar','name_en','description_ar','description_en','artwork_url','enabled'])if(k in p)patch[k]=p[k];
  if('timezone' in p){const tz=assertString(p.timezone,'timezone',80)!;const valid=await rpc('app','validate_timezone_name',{p_timezone:tz});if(valid!==true)throw new ApiError(422,'INVALID_TIMEZONE','Unknown IANA timezone');patch.timezone=tz;}
  const data=(await db('app',`virtual_radio_channels?id=eq.${current.id}`,{method:'PATCH',body:JSON.stringify(patch)})).data;const updated=Array.isArray(data)?data[0]:data;
  await audit(ctx,requestId,'virtual_radio.channel.update','virtual_radio_channel',current.id,current,updated);return json({data:updated});
}
async function scheduleMutation(ctx:any,request:Request,parts:string[],requestId:string){
  requirePermission(ctx,request.method==='GET'?'schedules.read':'schedules.write');
  if(request.method==='GET')return virtualOverview(ctx);
  sameOrigin(request);const p=await body(request) as any;
  const channel=((await db('app','virtual_radio_channels?slug=eq.tarteel&select=id')).data as any[])[0];if(!channel)throw new ApiError(404,'NOT_FOUND','Virtual channel not found');
  if(request.method==='POST'&&parts.length===3){
    const row:any={channel_id:channel.id,days_of_week:days(p.days_of_week??[0,1,2,3,4,5,6]),start_time:time(p.start_time,'start_time'),end_time:time(p.end_time,'end_time'),program_title_ar:assertString(p.program_title_ar,'program_title_ar',200)!,program_title_en:assertString(p.program_title_en,'program_title_en',200,false),program_subtitle_ar:assertString(p.program_subtitle_ar,'program_subtitle_ar',500,false),program_subtitle_en:assertString(p.program_subtitle_en,'program_subtitle_en',500,false),category_id:p.category_id?assertUuid(p.category_id,'category_id'):null,fallback_category_id:p.fallback_category_id?assertUuid(p.fallback_category_id,'fallback_category_id'):null,preferred_provider_id:p.preferred_provider_id?assertUuid(p.preferred_provider_id,'preferred_provider_id'):null,preferred_station_id:p.preferred_station_id?assertUuid(p.preferred_station_id,'preferred_station_id'):null,allow_degraded:p.allow_degraded!==false,enabled:p.enabled!==false,priority:int(p.priority??100,'priority',0,100000)};
    const data=(await db('app','virtual_radio_schedule',{method:'POST',body:JSON.stringify(row)})).data;const created=Array.isArray(data)?data[0]:data;await audit(ctx,requestId,'virtual_radio.schedule.create','virtual_radio_schedule',created.id,null,created);return json({data:created},201);
  }
  const id=assertUuid(parts[3],'schedule_id');const old=((await db('app',`virtual_radio_schedule?id=eq.${id}&channel_id=eq.${channel.id}&select=*`)).data as any[])[0];if(!old)throw new ApiError(404,'NOT_FOUND','Virtual schedule not found');
  if(request.method==='PATCH'){
    const patch:any={};for(const k of ['program_title_ar','program_title_en','program_subtitle_ar','program_subtitle_en','category_id','fallback_category_id','preferred_provider_id','preferred_station_id','allow_degraded','enabled','priority'])if(k in p)patch[k]=p[k];if('start_time' in p)patch.start_time=time(p.start_time,'start_time');if('end_time' in p)patch.end_time=time(p.end_time,'end_time');if('days_of_week' in p)patch.days_of_week=days(p.days_of_week);
    const data=(await db('app',`virtual_radio_schedule?id=eq.${id}`,{method:'PATCH',body:JSON.stringify(patch)})).data;const updated=Array.isArray(data)?data[0]:data;await audit(ctx,requestId,'virtual_radio.schedule.update','virtual_radio_schedule',id,old,updated);return json({data:updated});
  }
  if(request.method==='DELETE'){await db('app',`virtual_radio_schedule?id=eq.${id}`,{method:'DELETE'});await audit(ctx,requestId,'virtual_radio.schedule.delete','virtual_radio_schedule',id,old,{deleted:true});return json({data:{id,deleted:true}});}
  throw new ApiError(405,'METHOD_NOT_ALLOWED','Method not allowed');
}
async function candidateMutation(ctx:any,request:Request,parts:string[],requestId:string){
  requirePermission(ctx,request.method==='GET'?'schedules.read':'schedules.write');if(request.method!=='GET')sameOrigin(request);const scheduleId=assertUuid(parts[3],'schedule_id');
  if(request.method==='GET')return json({data:(await db('app',`virtual_radio_candidates?schedule_id=eq.${scheduleId}&select=*&order=priority.desc`)).data});
  const p=await body(request) as any;
  if(request.method==='POST'&&parts.length===5){const stationId=assertUuid(p.station_id,'station_id');const station=((await db('app',`stations?id=eq.${stationId}&station_source=eq.EXTERNAL&deleted_at=is.null&select=id,stream_url`)).data as any[])[0];if(!station)throw new ApiError(422,'EXTERNAL_STATION_REQUIRED','Candidate must be an external station');const row={schedule_id:scheduleId,station_id:stationId,priority:int(p.priority??100,'priority',0,100000),weight:int(p.weight??1,'weight',1,1000),enabled:p.enabled!==false};const data=(await db('app','virtual_radio_candidates',{method:'POST',body:JSON.stringify(row)})).data;const created=Array.isArray(data)?data[0]:data;await audit(ctx,requestId,'virtual_radio.candidate.create','virtual_radio_candidate',created.id,null,created);return json({data:created},201);}
  const candidateId=assertUuid(parts[5],'candidate_id');const old=((await db('app',`virtual_radio_candidates?id=eq.${candidateId}&schedule_id=eq.${scheduleId}&select=*`)).data as any[])[0];if(!old)throw new ApiError(404,'NOT_FOUND','Candidate not found');
  if(request.method==='PATCH'){const patch:any={};for(const k of ['priority','weight','enabled'])if(k in p)patch[k]=p[k];const data=(await db('app',`virtual_radio_candidates?id=eq.${candidateId}`,{method:'PATCH',body:JSON.stringify(patch)})).data;const updated=Array.isArray(data)?data[0]:data;await audit(ctx,requestId,'virtual_radio.candidate.update','virtual_radio_candidate',candidateId,old,updated);return json({data:updated});}
  if(request.method==='DELETE'){await db('app',`virtual_radio_candidates?id=eq.${candidateId}`,{method:'DELETE'});await audit(ctx,requestId,'virtual_radio.candidate.delete','virtual_radio_candidate',candidateId,old,{deleted:true});return json({data:{id:candidateId,deleted:true}});}
  throw new ApiError(405,'METHOD_NOT_ALLOWED','Method not allowed');
}
async function resolveNow(ctx:any,request:Request){requirePermission(ctx,'schedules.read');const u=new URL(request.url);const failed=(u.searchParams.get('failed_station_ids')??'').split(',').map(x=>x.trim()).filter(Boolean).slice(0,8).map((x,i)=>assertUuid(x,`failed_station_ids[${i}]`));const data=await rpc('app','resolve_virtual_radio',{p_slug:'tarteel',p_environment:'development',p_exclude_station_ids:failed});return json({data});}
async function preview(ctx:any,request:Request){requirePermission(ctx,'schedules.read');const u=new URL(request.url);const hours=int(u.searchParams.get('hours')??24,'hours',1,168);return json({data:await rpc('app','virtual_radio_preview',{p_slug:'tarteel',p_hours:hours,p_environment:'development'})});}

export async function dispatchPhase11(request:Request,segments:string[],requestId:string,authorized?:AdminContext):Promise<DispatchResult|null>{
  const parts=segments.filter(Boolean);if(parts[0]!=='admin')return null;
  if(parts[1]==='providers'&&parts[2]==='islamic-radio-api'){
    const ctx=authorized??await adminContext(request);
    if(parts.length===3&&request.method==='GET')return{ctx,response:await providerOverview(ctx)};
    if(parts[3]==='sync'&&request.method==='POST')return{ctx,response:await providerSync(ctx,request,requestId)};
    throw new ApiError(405,'METHOD_NOT_ALLOWED','Method not allowed');
  }
  if(parts[1]==='virtual-radio'){
    const ctx=authorized??await adminContext(request);
    if(parts.length===2&&request.method==='GET')return{ctx,response:await virtualOverview(ctx)};
    if(parts[2]==='channel'&&request.method==='PATCH')return{ctx,response:await channelUpdate(ctx,request,requestId)};
    if(parts[2]==='schedules'&&parts[4]==='candidates')return{ctx,response:await candidateMutation(ctx,request,parts,requestId)};
    if(parts[2]==='schedules')return{ctx,response:await scheduleMutation(ctx,request,parts,requestId)};
    if(parts[2]==='resolve'&&request.method==='GET')return{ctx,response:await resolveNow(ctx,request)};
    if(parts[2]==='preview'&&request.method==='GET')return{ctx,response:await preview(ctx,request)};
    throw new ApiError(405,'METHOD_NOT_ALLOWED','Method not allowed');
  }
  return null;
}
