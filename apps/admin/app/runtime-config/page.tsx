'use client';

import Link from 'next/link';
import { useEffect, useMemo, useState } from 'react';

type Row = { key: string; value: unknown; description?: string };
type Values = Record<string, unknown>;

const booleanKeys = [
  ['radio_enabled', 'الإذاعات'],
  ['virtual_radio_enabled', 'إذاعة ترتيل الذكية'],
  ['virtual_radio_show_next_program', 'إظهار البرنامج التالي'],
  ['virtual_radio_allow_degraded_fallback', 'السماح بالمصدر الاحتياطي المتدهور'],
  ['offline_downloads_enabled', 'التنزيل والاستماع بدون إنترنت'],
  ['mushaf_tajweed_enabled', 'مصحف التجويد'],
  ['elysia_api_enabled', 'Elysia API'],
] as const;

const sectionOptions = [
  ['featured', 'مختارات ترتيل'],
  ['stations', 'الإذاعات'],
  ['reciters', 'القراء'],
  ['offline', 'الاستماع بدون إنترنت'],
  ['categories', 'التصنيفات'],
] as const;

export default function RuntimeConfigPage() {
  const [values, setValues] = useState<Values>({});
  const [manifestText, setManifestText] = useState('');
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState('');

  const homeSections = useMemo(() =>
    Array.isArray(values.home_sections)
      ? values.home_sections.filter((item): item is string => typeof item === 'string')
      : ['featured', 'stations', 'reciters', 'offline', 'categories'],
  [values.home_sections]);

  async function load() {
    setLoading(true);
    setMessage('');
    try {
      const response = await fetch('/api/v1/admin/runtime-config', { cache: 'no-store' });
      const root = await response.json();
      if (!response.ok) throw new Error(root?.error?.message ?? 'تعذر تحميل الإعدادات');
      const next: Values = {};
      for (const row of (root.data ?? []) as Row[]) next[row.key] = row.value;
      setValues(next);
      setManifestText(JSON.stringify(next.content_manifest ?? { schema_version: 1, home_sections: next.home_sections ?? [] }, null, 2));
    } catch (error) {
      setMessage(error instanceof Error ? error.message : 'تعذر تحميل الإعدادات');
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => { void load(); }, []);

  function toggleSection(id: string) {
    const next = homeSections.includes(id)
      ? homeSections.filter((item) => item !== id)
      : [...homeSections, id];
    setValues((current) => ({ ...current, home_sections: next }));
  }

  async function save() {
    setSaving(true);
    setMessage('');
    try {
      const manifest = JSON.parse(manifestText || '{}');
      const updates: Values = {
        ...Object.fromEntries(booleanKeys.map(([key]) => [key, values[key] !== false])),
        virtual_radio_max_failed_sources: Number(values.virtual_radio_max_failed_sources ?? 8),
        reciters_page_size: Number(values.reciters_page_size ?? 100),
        home_sections: homeSections,
        content_manifest_version: String(values.content_manifest_version ?? '2026.09.02.1'),
        content_manifest: { ...manifest, schema_version: 1, home_sections: homeSections },
      };
      const response = await fetch('/api/v1/admin/runtime-config', {
        method: 'PUT',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ updates }),
      });
      const root = await response.json();
      if (!response.ok) throw new Error(root?.error?.message ?? 'تعذر حفظ الإعدادات');
      setMessage('تم حفظ التحديثات. سيحصل التطبيق عليها عند تحديث Remote Config دون إصدار APK جديد.');
      await load();
    } catch (error) {
      setMessage(error instanceof Error ? error.message : 'تعذر حفظ الإعدادات');
    } finally {
      setSaving(false);
    }
  }

  return (
    <main dir="rtl" style={{maxWidth: 980, margin: '0 auto', padding: 24, fontFamily: 'system-ui'}}>
      <div style={{display:'flex', justifyContent:'space-between', gap:12, alignItems:'center', flexWrap:'wrap'}}>
        <div>
          <h1 style={{marginBottom:4}}>تحديثات ترتيل بدون APK</h1>
          <p style={{marginTop:0, opacity:.75}}>Feature Flags + ترتيب الرئيسية + Content Manifest. لا يتم تنزيل أو تنفيذ كود Dart من الخادم.</p>
        </div>
        <Link href="/" className="btn">العودة للوحة الإدارة</Link>
      </div>

      {loading ? <p>جارٍ التحميل…</p> : <>
        <section style={card}>
          <h2>تفعيل الميزات</h2>
          <div style={{display:'grid', gridTemplateColumns:'repeat(auto-fit,minmax(260px,1fr))', gap:10}}>
            {booleanKeys.map(([key, label]) => (
              <label key={key} style={toggleRow}>
                <span>{label}</span>
                <input
                  type="checkbox"
                  checked={values[key] !== false}
                  onChange={(event) => setValues((current) => ({...current, [key]: event.target.checked}))}
                />
              </label>
            ))}
          </div>
        </section>

        <section style={card}>
          <h2>سلوك التطبيق</h2>
          <div style={{display:'grid', gridTemplateColumns:'repeat(auto-fit,minmax(240px,1fr))', gap:12}}>
            <label>أقصى مصادر فاشلة في إذاعة ترتيل
              <input style={input} type="number" min={1} max={12} value={Number(values.virtual_radio_max_failed_sources ?? 8)} onChange={(e)=>setValues((v)=>({...v,virtual_radio_max_failed_sources:Number(e.target.value)}))}/>
            </label>
            <label>عدد القراء في الصفحة
              <input style={input} type="number" min={30} max={300} value={Number(values.reciters_page_size ?? 100)} onChange={(e)=>setValues((v)=>({...v,reciters_page_size:Number(e.target.value)}))}/>
            </label>
            <label>إصدار Content Manifest
              <input style={input} value={String(values.content_manifest_version ?? '')} onChange={(e)=>setValues((v)=>({...v,content_manifest_version:e.target.value}))}/>
            </label>
          </div>
        </section>

        <section style={card}>
          <h2>أقسام الصفحة الرئيسية</h2>
          <p style={{opacity:.75}}>يمكن إظهار/إخفاء الأقسام وتغيير ترتيبها في الـmanifest لاحقًا. التطبيق يقبل فقط الأقسام المعروفة.</p>
          <div style={{display:'flex', flexWrap:'wrap', gap:10}}>
            {sectionOptions.map(([id,label]) => (
              <label key={id} style={toggleRow}>
                <span>{label}</span>
                <input type="checkbox" checked={homeSections.includes(id)} onChange={()=>toggleSection(id)}/>
              </label>
            ))}
          </div>
        </section>

        <section style={card}>
          <h2>Content Manifest</h2>
          <textarea
            spellCheck={false}
            value={manifestText}
            onChange={(e)=>setManifestText(e.target.value)}
            style={{...input, minHeight:260, fontFamily:'ui-monospace,monospace', direction:'ltr'}}
          />
          <p style={{opacity:.7}}>يُرفض أي Manifest غير schema_version=1 أو يحتوي حقولًا تنفيذية مثل code / script / eval.</p>
        </section>

        <div style={{display:'flex', gap:10, alignItems:'center', marginBottom:40}}>
          <button className="btn" disabled={saving} onClick={()=>void save()}>{saving ? 'جارٍ الحفظ…' : 'حفظ ونشر الإعدادات'}</button>
          <button className="btn" disabled={saving} onClick={()=>void load()}>إعادة تحميل</button>
        </div>
      </>}
      {message && <p style={{padding:12, borderRadius:10, background:'rgba(127,127,127,.12)'}}>{message}</p>}
    </main>
  );
}

const card = {padding:18, margin:'16px 0', border:'1px solid rgba(127,127,127,.25)', borderRadius:16} as const;
const toggleRow = {display:'flex', justifyContent:'space-between', alignItems:'center', gap:16, padding:'10px 12px', border:'1px solid rgba(127,127,127,.2)', borderRadius:10} as const;
const input = {display:'block', width:'100%', boxSizing:'border-box', marginTop:6, padding:10, borderRadius:8, border:'1px solid rgba(127,127,127,.3)', background:'transparent', color:'inherit'} as const;
