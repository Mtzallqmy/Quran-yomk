import {createHash} from 'node:crypto';
import {fetchJson} from './registry.mjs';
const base='https://dev.surahapp.com/api/v1';
export async function syncSurahRegistry(pool,{fetcher=fetch}={}){
 // Validate the entire upstream catalog before starting any write transaction.
 const rows=await fetchJson(base+'/projects',{fetcher,attempts:2});
 const seen=new Set();
 if(!Array.isArray(rows)||!rows.length||rows.length>100||rows.some(p=>
  !p||typeof p!=='object'||!/[A-Za-z0-9]/.test(p.slug??'')||
  !/^[A-Za-z0-9][A-Za-z0-9_-]{0,99}$/.test(p.slug)||seen.has(p.slug)||!seen.add(p.slug)||
  !['sura','page','aya','word'].includes(p.type)||typeof p.title!=='string'||p.title.length>500))throw Error('INVALID_SURAH_CATALOG');
 const c=await pool.connect();
 try{
  await c.query('BEGIN');
  const lock=await c.query("SELECT pg_try_advisory_xact_lock(hashtext('tarteel:surah-registry')) AS locked");
  if(!lock.rows[0]?.locked)throw Error('SYNC_BUSY');
  let inserted=0,matched=0,rejected=0;
  for(const p of rows){
   if(p.published===false){rejected++;continue;}
   const hash=createHash('sha256').update(JSON.stringify(p)).digest('hex');
   const result=await c.query(`INSERT INTO surah_content.surah_projects(slug,title,scope,published,metadata_sha256,source_url)
    VALUES($1,$2,$3,true,$4,$5) ON CONFLICT(slug) DO UPDATE SET title=EXCLUDED.title,scope=EXCLUDED.scope,
    metadata_sha256=EXCLUDED.metadata_sha256,verified_at=now() RETURNING(xmax=0) AS inserted`,[p.slug,p.title,p.type,hash,base+'/project/'+p.slug]);
   if(result.rows[0]?.inserted)inserted++;else matched++;
   await c.query(`INSERT INTO surah_content.surah_source_rights(project_slug,policy,terms_url,attribution,review_note)
    VALUES($1,$2,'https://dev.surahapp.com/api/docs','سورة — مركز تفسير للدراسات القرآنية','Metadata only; no verified permanent storage or redistribution grant.') ON CONFLICT DO NOTHING`,[p.slug,p.slug==='word-pic'?'metadata_only':'direct_session_only']);
  }
  const report={discovered:rows.length,inserted,matched,rejected,body_storage:false};
  await c.query(`INSERT INTO surah_content.surah_sync_logs(catalog_sha256,discovered,inserted,matched,rejected,report)
   VALUES($1,$2,$3,$4,$5,$6::jsonb)`,[createHash('sha256').update(JSON.stringify(rows)).digest('hex'),rows.length,inserted,matched,rejected,JSON.stringify(report)]);
  await c.query('COMMIT');return report;
 }catch(error){await c.query('ROLLBACK');throw error;}finally{c.release();}
}
