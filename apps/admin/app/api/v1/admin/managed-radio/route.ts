import { adminMutation } from '@/lib/admin-mutation';
import type { AdminContext } from '@/lib/auth';
import { attachContext, fail, requestId } from '@/lib/http';
import { adminContext, requirePermission } from '@/lib/auth';
import { ApiError } from '@/lib/contracts';
import { body, json, sameOrigin } from '@/lib/http';
import { rateLimit } from '@/lib/rate-limit';
import { backendResponse, db, publicEnv, rpc } from '@/lib/supabase';

function accessToken(request:Request){
  for(const pair of (request.headers.get('cookie')??'').split(';')){
    const i=pair.indexOf('=');
    if(i>0&&pair.slice(0,i).trim()==='tarteel_admin_access')return decodeURIComponent(pair.slice(i+1).trim());
  }
  throw new ApiError(401,'AUTH_REQUIRED','Authentication required');
}
function adenDay(){
  const short=new Intl.DateTimeFormat('en-US',{timeZone:'Asia/Aden',weekday:'short'}).format(new Date());
  return ({Sun:0,Mon:1,Tue:2,Wed:3,Thu:4,Fri:5,Sat:6} as Record<string,number>)[short]??0;
}

export async function GET(request:Request){
  const id=requestId(request);try{
  const ctx=await adminContext(request);requirePermission(ctx,'schedules.read');
  const overview=await rpc('app','managed_radio_overview',{p_slug:'tarteel'});
  const channel=(overview as any)?.channel;
  const channelId=channel?.id;
  if(!channelId)throw new ApiError(404,'NOT_FOUND','Managed radio channel not found');
  const [current,schedules,runs]=await Promise.all([
    rpc('app','resolve_virtual_radio',{p_slug:'tarteel',p_environment:'development',p_exclude_station_ids:[]}),
    db('app',`virtual_radio_schedule?channel_id=eq.${channelId}&enabled=eq.true&select=id,days_of_week,start_time,end_time,program_title_ar,program_title_en,preferred_station_id,fallback_category_id,priority&order=start_time.asc,priority.desc`),
    db('app',`managed_radio_sync_runs?channel_id=eq.${channelId}&select=id,operation,status,summary,error_code,error_message,started_at,finished_at&order=created_at.desc&limit=20`),
  ]);
  const day=adenDay();
  const today=(schedules.data as any[]).filter((row)=>Array.isArray(row.days_of_week)&&row.days_of_week.includes(day));
  return attachContext(json({data:{overview,current,today_schedule:today,sync_runs:runs.data}}),id,ctx);

  }catch(error){return fail(error,id);}
}

async function mutate(request:Request,ctx:AdminContext,id:string){
  await rateLimit(`managed-radio:${ctx.userId}`,8,60_000);
  const payload=await body(request) as any;
  const operation=String(payload?.operation??'');
  if(!['REFRESH_STATUS','REFRESH_NOW_PLAYING','SYNC_SCHEDULE','TEST_RELAY'].includes(operation))throw new ApiError(422,'VALIDATION_ERROR','Unsupported managed radio operation');
  const e=publicEnv();
  const response=await backendResponse(`${e.url}/functions/v1/tarteel-managed-radio`,{
    method:'POST',
    headers:{apikey:e.publishable,authorization:`Bearer ${ctx.refreshed?.access??accessToken(request)}`,'content-type':'application/json','x-request-id':id},
    body:JSON.stringify({operation}),
    cache:'no-store',
  });
  if(!response.ok)throw new ApiError(response.status,'MANAGED_RADIO_ERROR','Managed radio operation failed');
  const result=await response.json();
  if(!result||typeof result!=='object'||!('data' in result))throw new ApiError(502,'MANAGED_RADIO_BAD_RESPONSE','Managed radio response was invalid');
  return json(result);
}

export async function POST(request:Request){const id=requestId(request);try{return await adminMutation(request,id,async ctx=>attachContext(await mutate(request,ctx,id),id,ctx),'schedules.write');}catch(error){return fail(error,id);}}
