'use client';

import Link from 'next/link';
import { FormEvent, useCallback, useEffect, useMemo, useState } from 'react';
import { ClientApiError, clientApi } from '../../lib/client-api';

type Session={user_id:string;email?:string|null;display_name?:string|null;roles:string[];permissions:string[]};
type AnyRow=Record<string,any>;

function errorText(error:unknown){return error instanceof ClientApiError?error.message:error instanceof Error?error.message:'حدث خطأ غير متوقع';}
function short(value:any){const s=String(value??'');return s.length>16?`${s.slice(0,8)}…${s.slice(-4)}`:s||'—';}
function date(value:any){if(!value)return'—';const d=new Date(value);return Number.isNaN(d.getTime())?String(value):new Intl.DateTimeFormat('ar',{dateStyle:'medium',timeStyle:'short'}).format(d);}

export default function Phase11Admin(){
  const[session,setSession]=useState<Session|null>(null);
  const[checking,setChecking]=useState(true);
  const[provider,setProvider]=useState<any>(null);
  const[virtual,setVirtual]=useState<any>(null);
  const[busy,setBusy]=useState(false);
  const[error,setError]=useState('');
  const[message,setMessage]=useState('');

  const load=useCallback(async()=>{
    setError('');
    try{
      const [p,v]=await Promise.all([
        clientApi<{data:any}>('/api/v1/admin/providers/islamic-radio-api'),
        clientApi<{data:any}>('/api/v1/admin/virtual-radio'),
      ]);
      setProvider(p.data);setVirtual(v.data);
    }catch(e){setError(errorText(e));}
  },[]);

  useEffect(()=>{
    clientApi<{data:Session}>('/api/v1/admin/auth/me')
      .then(r=>{setSession(r.data);return load();})
      .catch(()=>setSession(null))
      .finally(()=>setChecking(false));
  },[load]);

  async function syncNow(){setBusy(true);setError('');setMessage('');try{const r=await clientApi<{data:any}>('/api/v1/admin/providers/islamic-radio-api/sync',{method:'POST'});setMessage(`اكتملت المزامنة: ${JSON.stringify(r.data)}`);await load();}catch(e){setError(errorText(e));}finally{setBusy(false)}}
  async function resolveNow(){setBusy(true);try{const r=await clientApi<{data:any}>('/api/v1/admin/virtual-radio/resolve');setMessage(`المصدر الحالي: ${r.data?.station?.name_ar??'غير متاح'} — ${r.data?.program?.title_ar??'لا برنامج'}`);}catch(e){setError(errorText(e));}finally{setBusy(false)}}
  async function toggleChannel(){if(!virtual?.channel)return;setBusy(true);try{await clientApi('/api/v1/admin/virtual-radio/channel',{method:'PATCH',body:JSON.stringify({enabled:!virtual.channel.enabled})});await load();}catch(e){setError(errorText(e));}finally{setBusy(false)}}

  if(checking)return <main className="login-wrap"><div className="notice">جارٍ التحقق من جلسة الإدارة…</div></main>;
  if(!session)return <main className="login-wrap"><section className="login"><h1>إدارة إذاعة ترتيل</h1><p>يلزم تسجيل الدخول أولًا من لوحة الإدارة.</p><Link className="btn primary" href="/">العودة لتسجيل الدخول</Link></section></main>;

  return <main id="main-content" className="main" style={{maxWidth:1280,margin:'0 auto'}}>
    <div className="page-head"><div><h1>إذاعة ترتيل الافتراضية</h1><p>Flutter ← Supabase API ← جدول افتراضي ← مصدر بث خارجي. لا يوجد VPS أو Icecast في هذه المرحلة.</p></div><Link className="btn" href="/">لوحة الإدارة</Link></div>
    {error&&<div className="error-box" role="alert">{error}</div>}
    {message&&<div className="notice">{message}</div>}
    <div className="section-stack">
      <section className="card"><div className="page-head"><div><h2>Islamic Radio API</h2><p>مزامنة privileged إلى كاتالوج ترتيل مع stable IDs ومنع التكرار.</p></div><button className="btn primary" disabled={busy||!session.permissions.includes('external_stations.write')} onClick={syncNow}>{busy?'جارٍ التنفيذ…':'Sync Now'}</button></div>
        <div className="grid cards">
          <Kpi label="آخر مزامنة" value={provider?.last_sync?.status??'—'} detail={date(provider?.last_sync?.finished_at)}/>
          <Kpi label="Fetched" value={provider?.last_sync?.fetched_count??0}/>
          <Kpi label="Normalized" value={provider?.normalized_records??0}/>
          <Kpi label="Tarteel-owned rows" value={provider?.owned_station_count??0}/>
          <Kpi label="HTTP-only" value={provider?.http_only??0}/>
          <Kpi label="Missing" value={provider?.missing??0}/>
        </div>
        <p className="muted">المصدر: {provider?.provider?.source_url??'—'} · Catalog license: {provider?.provider?.license_type??'—'} · حقوق الصوت تبقى منفصلة عن ترخيص بيانات الكاتالوج.</p>
      </section>

      <section className="card"><div className="page-head"><div><h2>القناة</h2><p>{virtual?.channel?.name_ar??'إذاعة ترتيل'} · {virtual?.channel?.timezone??'Asia/Aden'}</p></div><button className="btn" disabled={busy||!session.permissions.includes('schedules.write')} onClick={toggleChannel}>{virtual?.channel?.enabled?'تعطيل القناة':'تفعيل القناة'}</button></div>
        <div className="grid cards"><Kpi label="الحالة" value={virtual?.channel?.enabled?'مفعلة':'معطلة'}/><Kpi label="البرنامج الحالي" value={virtual?.current?.program?.title_ar??'—'}/><Kpi label="المصدر الحالي" value={virtual?.current?.station?.name_ar??'—'} detail={virtual?.current?.station?.provider_name}/><Kpi label="التغيير القادم" value={date(virtual?.current?.next_change_at)}/></div>
        <button className="btn primary" disabled={busy} onClick={resolveNow}>Resolve Now / Test Current Source</button>
      </section>

      <ScheduleEditor virtualData={virtual} session={session} reload={load}/>

      <section className="card"><h2>معاينة 24 ساعة</h2><div className="table-wrap"><table><thead><tr><th>الوقت</th><th>البرنامج</th><th>التصنيف</th><th>المصدر</th></tr></thead><tbody>{(Array.isArray(virtual?.preview)?virtual.preview:[]).map((row:AnyRow,i:number)=><tr key={String(row.schedule_id??i)}><td>{date(row.started_at)}</td><td>{row.program_title_ar??'—'}</td><td>{row.category??'—'}</td><td>{row.station_name_ar??row.station_id??'—'}</td></tr>)}</tbody></table></div></section>
    </div>
  </main>;
}

function Kpi({label,value,detail}:{label:string;value:any;detail?:any}){return <div className="card"><div className="kpi-label">{label}</div><div className="metric">{String(value??'—')}</div>{detail&&<span className="muted">{String(detail)}</span>}</div>}

function ScheduleEditor({virtualData,session,reload}:{virtualData:any;session:Session;reload:()=>Promise<void>}){
  const[title,setTitle]=useState('');const[start,setStart]=useState('10:00');const[end,setEnd]=useState('11:00');const[category,setCategory]=useState('');const[msg,setMsg]=useState('');const[busy,setBusy]=useState(false);
  const categories=Array.isArray(virtualData?.categories)?virtualData.categories:[];
  const schedules=Array.isArray(virtualData?.schedules)?virtualData.schedules:[];
  const candidates=Array.isArray(virtualData?.candidates)?virtualData.candidates:[];
  const stationMap=useMemo(()=>new Map((Array.isArray(virtualData?.stations)?virtualData.stations:[]).map((s:AnyRow)=>[s.id,s])),[virtualData]);
  async function create(e:FormEvent){e.preventDefault();setBusy(true);setMsg('');try{await clientApi('/api/v1/admin/virtual-radio/schedules',{method:'POST',body:JSON.stringify({days_of_week:[0,1,2,3,4,5,6],start_time:start,end_time:end,program_title_ar:title,category_id:category||null,allow_degraded:true,enabled:true,priority:100})});setTitle('');setMsg('تم إنشاء الفترة.');await reload();}catch(x){setMsg(errorText(x));}finally{setBusy(false)}}
  async function remove(id:string){setBusy(true);try{await clientApi(`/api/v1/admin/virtual-radio/schedules/${id}`,{method:'DELETE'});await reload();}catch(x){setMsg(errorText(x));}finally{setBusy(false)}}
  return <section className="card"><h2>الجدول</h2><form onSubmit={create} className="toolbar"><label className="field">عنوان البرنامج<input value={title} onChange={e=>setTitle(e.target.value)} required/></label><label className="field">من<input type="time" value={start} onChange={e=>setStart(e.target.value)} required/></label><label className="field">إلى<input type="time" value={end} onChange={e=>setEnd(e.target.value)} required/></label><label className="field">التصنيف<select value={category} onChange={e=>setCategory(e.target.value)}><option value="">بدون تقييد</option>{categories.map((c:AnyRow)=><option key={c.id} value={c.id}>{c.name_ar} ({c.slug})</option>)}</select></label><button className="btn primary" disabled={busy||!session.permissions.includes('schedules.write')}>إضافة فترة</button></form>{msg&&<div className="notice">{msg}</div>}<div className="table-wrap"><table><thead><tr><th>البرنامج</th><th>الوقت</th><th>الأيام</th><th>البدائل</th><th></th></tr></thead><tbody>{schedules.map((s:AnyRow)=><tr key={s.id}><td>{s.program_title_ar}</td><td>{String(s.start_time).slice(0,5)}–{String(s.end_time).slice(0,5)}</td><td>{Array.isArray(s.days_of_week)?s.days_of_week.join(', '):'—'}</td><td>{candidates.filter((c:AnyRow)=>c.schedule_id===s.id).map((c:AnyRow)=>stationMap.get(c.station_id)?.name_ar??short(c.station_id)).join(' ← ')||'اختيار تلقائي حسب التصنيف'}</td><td><button type="button" className="btn" disabled={busy||!session.permissions.includes('schedules.write')} onClick={()=>remove(s.id)}>حذف</button></td></tr>)}</tbody></table></div></section>;
}
