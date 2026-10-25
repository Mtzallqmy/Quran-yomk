import {fetchJson} from './registry.mjs';
const json=(data,status=200)=>Response.json(data,{status,headers:{'Cache-Control':status===200?'public,max-age=60':'no-store','X-Content-Type-Options':'nosniff'}});
export function handler(pool){
 let cached=null,until=0;
 async function read(sql,values=[]){const c=await pool.connect();try{await c.query('BEGIN READ ONLY');await c.query('SET LOCAL ROLE tarteel_catalog_reader');const r=await c.query(sql,values);await c.query('COMMIT');return r.rows;}catch(e){await c.query('ROLLBACK');throw e;}finally{c.release();}}
 return async request=>{
  const u=new URL(request.url);if(request.method!=='GET')return json({error:'METHOD_NOT_ALLOWED'},405);
  try{
   if(u.pathname==='/health')return json({service:'tarteel-content',status:'ok'});
   if(u.pathname==='/v1/mushaf-library'){
    const editions=await read('SELECT * FROM tarteel_mushaf.public_editions ORDER BY id');
    const packages=await read('SELECT * FROM tarteel_mushaf.public_packages ORDER BY id');
    const status=await read('SELECT * FROM tarteel_mushaf.public_library_status');
    return json({editions,packages,status:status[0]??null});
   }
   // Indexed Quran metadata only: immutable Quran text and large page assets
   // remain under their separately verified/licensed providers.
   const p=u.pathname.match(/^\\/v1\\/mushaf\\/page\\/([1-9][0-9]{0,2})$/);
   if(p){
    const page=Number(p[1]);
    if(page>604)return json({error:'PAGE_OUT_OF_RANGE'},400);
    const rows=await read(
      'SELECT edition_id,verse_key,source_bounds FROM tarteel_mushaf.public_ayah_positions WHERE page=$1 ORDER BY verse_key',
      [page]
    );
    return json({page,positions:rows,source:'tarteel_mushaf.mushaf_ayah_positions'});
   }
   const t=u.pathname.match(/^\\/v1\\/mushaf\\/themes\\/([1-9][0-9]{0,2})$/);
   if(t){
    const surah=Number(t[1]);
    if(surah>114)return json({error:'SURAH_OUT_OF_RANGE'},400);
    const rows=await read(
      "SELECT r.verse_key,s.id,s.title_ar,s.source_id FROM tarteel_mushaf.public_thematic_ayahs r JOIN tarteel_mushaf.public_thematic_sections s ON s.id=r.section_id WHERE split_part(r.verse_key,':',1)::integer=$1 ORDER BY r.verse_key,s.id LIMIT 5000",
      [surah]
    );
    return json({surah,themes:rows,kind:'tags-not-exclusive-contiguous-passages'});
   }
   if(u.pathname==='/v1/catalog'){
    if(cached&&Date.now()<until)return json(cached);
    const rows=await read('SELECT id,kind,title_ar,language_code,edition,metadata FROM tarteel_catalog.public_catalog ORDER BY kind,id LIMIT 500');cached={data:rows};until=Date.now()+60000;return json(cached);
   }
   const m=u.pathname.match(/^\/v1\/translations\/([a-z0-9_]{1,100})\/([1-9][0-9]{0,2})$/);
   if(m&&+m[2]<=114){
    const rows=await read("SELECT edition,metadata FROM tarteel_catalog.public_catalog WHERE kind='translation' AND metadata->>'key'=$1 LIMIT 1",[m[1]]);
    if(!rows.length)return json({error:'NOT_FOUND'},404);
    const budget=(await pool.query(`INSERT INTO tarteel_catalog.api_budgets(principal) VALUES('translation-proxy') ON CONFLICT(principal) DO UPDATE SET window_at=date_trunc('minute',now()),requests=CASE WHEN api_budgets.window_at>=date_trunc('minute',now()) THEN api_budgets.requests+1 ELSE 1 END RETURNING requests`)).rows[0];
    if(budget.requests>120)return json({error:'RATE_LIMITED'},429);
    const list=await fetchJson('https://quranenc.com/api/v1/translations/list/');const current=(list.translations??list).find(v=>v.key===m[1]);
    if(!current||String(current.version)!==rows[0].edition)return json({error:'TRANSLATION_VERSION_CHANGED'},503);
    const result=await fetchJson(`https://quranenc.com/api/v1/translation/sura/${m[1]}/${m[2]}`),verses=result.result??result;
    if(!Array.isArray(verses)||verses.some(v=>+v.sura!==+m[2]||!v.aya||typeof v.translation!=='string'))throw Error('INVALID_TRANSLATION');
    return json({source:'QuranEnc.com',sourceUrl:'https://quranenc.com/en/browse/'+m[1],termsUrl:'https://quranenc.com/en/home/api/',version:rows[0].edition,title:rows[0].metadata.title,description:rows[0].metadata.description,verses});
   }
   return json({error:'NOT_FOUND'},404);
  }catch{return json({error:'CONTENT_TEMPORARILY_UNAVAILABLE'},503);}
 };
}
