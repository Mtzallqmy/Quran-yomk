'use client';

import Link from 'next/link';
import { useCallback, useEffect, useState } from 'react';

type Json=Record<string,any>;
const box:React.CSSProperties={border:'1px solid #e5e7eb',borderRadius:14,padding:16,background:'#fff'};
const grid:React.CSSProperties={display:'grid',gridTemplateColumns:'repeat(auto-fit,minmax(240px,1fr))',gap:12};

export default function ManagedRadioPage(){
  const [data,setData]=useState<Json|null>(null);
  const [error,setError]=useState('');
  const [busy,setBusy]=useState('');
  const load=useCallback(async()=>{
    setError('');
    const r=await fetch('/api/v1/admin/managed-radio',{cache:'no-store'});
    const j=await r.json().catch(()=>({}));
    if(!r.ok)throw new Error(j?.error?.message??'تعذر تحميل حالة الإذاعة');
    setData(j.data);
  },[]);
  useEffect(()=>{load().catch(e=>setError(String(e.message??e)))},[load]);
  async function run(operation:string){
    setBusy(operation);setError('');
    try{
      const r=await fetch('/api/v1/admin/managed-radio',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({operation})});
      const j=await r.json().catch(()=>({}));
      if(!r.ok)throw new Error(`${j?.error?.code??'ERROR'} — ${j?.error?.message??'فشلت العملية'}`);
      await load();
    }catch(e:any){setError(String(e?.message??e))}finally{setBusy('')}
  }
  const o=data?.overview??{};const current=data?.current??{};const managed=o.enabled===true&&o.configured===true;
  const source=current?.station??{};const now=o.provider_now_playing?.data??o.provider_now_playing??{};
  return <main id="main-content" style={{maxWidth:1180,margin:'0 auto',padding:20,fontFamily:'system-ui'}}>
    <div style={{display:'flex',gap:10,alignItems:'center',justifyContent:'space-between',flexWrap:'wrap'}}>
      <div><h1 style={{marginBottom:4}}>Managed Radio — إذاعة ترتيل</h1><p style={{marginTop:0,color:'#6b7280'}}>Supabase هو مصدر الحقيقة؛ Radio.co منفذ البث فقط.</p></div>
      <div style={{display:'flex',gap:8}}><Link className="btn" href="/phase11">الجدول الافتراضي</Link><Link className="btn" href="/">الرئيسية</Link></div>
    </div>
    {error&&<div style={{...box,borderColor:'#dc2626',margin:'12px 0',color:'#991b1b'}}>{error}</div>}
    <section style={grid}>
      <div style={box}><strong>المزود</strong><p>Radio.co</p><small>{o.configured?'تم ربط Station ID ورابط البث':'غير مهيأ بعد — يحتاج حساب Radio.co فعلي'}</small></div>
      <div style={box}><strong>وضع التشغيل</strong><p>{managed?'MANAGED — رابط ثابت':'DIRECT_FALLBACK — تطوير'}</p><small>{o.fixed_stream_url??'لا يوجد رابط Managed نهائي بعد'}</small></div>
      <div style={box}><strong>حالة المحطة</strong><p>{o.provider_status??'غير معروفة'}</p><small>آخر فحص: {o.last_provider_check_at??'—'}</small></div>
      <div style={box}><strong>آخر مزامنة</strong><p>{o.last_sync_status??'NEVER'}</p><small>{o.last_sync_error_code??o.last_sync_at??'—'}</small></div>
    </section>
    <section style={{...box,marginTop:14}}>
      <h2>البرنامج الحالي</h2>
      <p><b>{current?.program?.title_ar??'—'}</b></p>
      <p>المصدر التحريري: {source?.name_ar??'—'} {source?.provider_name?`(${source.provider_name})`:''}</p>
      <p>الرابط الذي يسمعه Flutter: {managed?o.fixed_stream_url:(source?.playback_url??'—')}</p>
      <p>التالي: {current?.next_program?.title_ar??'—'} — {current?.next_change_at??'—'}</p>
    </section>
    <section style={{...box,marginTop:14}}>
      <h2>Now Playing من المزود</h2>
      <pre style={{whiteSpace:'pre-wrap',overflowWrap:'anywhere'}}>{Object.keys(now).length?JSON.stringify(now,null,2):'لا توجد بيانات Radio.co بعد.'}</pre>
    </section>
    <section style={{...box,marginTop:14}}>
      <h2>جدول اليوم — Asia/Aden</h2>
      <div style={{overflowX:'auto'}}><table style={{width:'100%',borderCollapse:'collapse'}}><thead><tr><th>البداية</th><th>النهاية</th><th>البرنامج</th><th>الأولوية</th></tr></thead><tbody>{(data?.today_schedule??[]).map((row:Json)=><tr key={row.id}><td>{row.start_time}</td><td>{row.end_time}</td><td>{row.program_title_ar}</td><td>{row.priority}</td></tr>)}</tbody></table></div>
    </section>
    <section style={{...box,marginTop:14}}>
      <h2>التحكم</h2>
      <p style={{color:'#6b7280'}}>لن يبدأ ميكروفون أو Live DJ من هنا. هذه العمليات خاصة بالحالة والRelay والجدول فقط.</p>
      <div style={{display:'flex',gap:8,flexWrap:'wrap'}}>
        <button className="btn" disabled={!!busy} onClick={()=>run('REFRESH_STATUS')}>{busy==='REFRESH_STATUS'?'جارٍ الفحص…':'Refresh Status'}</button>
        <button className="btn" disabled={!!busy} onClick={()=>run('REFRESH_NOW_PLAYING')}>{busy==='REFRESH_NOW_PLAYING'?'جارٍ التحديث…':'Now Playing'}</button>
        <button className="btn" disabled={!!busy} onClick={()=>run('SYNC_SCHEDULE')}>{busy==='SYNC_SCHEDULE'?'جارٍ المزامنة…':'Sync Schedule'}</button>
        <button className="btn" disabled={!!busy} onClick={()=>run('TEST_RELAY')}>{busy==='TEST_RELAY'?'جارٍ الاختبار…':'Test Relay'}</button>
      </div>
    </section>
    <section style={{...box,marginTop:14}}><h2>آخر العمليات</h2><ul>{(data?.sync_runs??[]).slice(0,10).map((r:Json)=><li key={r.id}>{r.operation}: <b>{r.status}</b>{r.error_code?` — ${r.error_code}`:''}</li>)}</ul></section>
  </main>;
}
