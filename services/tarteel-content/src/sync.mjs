import {approved,canonicalUrl,fingerprint,identity,mappingId} from './identity.mjs';
import {providers,adapters} from './registry.mjs';
export async function health(url,fetcher=fetch){
 const u=new URL(url);if(u.port||!/(^|\.)(qurango\.net|mp3quran\.net)$/.test(u.hostname))return false;
 try{const r=await fetcher(url,{headers:{Range:'bytes=0-4095'},redirect:'error',signal:AbortSignal.timeout(8000)});const ok=r.ok&&/audio|octet-stream|ogg/i.test(r.headers.get('content-type')??'');await r.body?.cancel();return ok;}catch{return false;}
}
export async function syncProvider(pool,provider,items,{baselineUrls=[],checkHealth=health}={}){
 const stats={provider:provider.id,discovered:items.length,inserted:0,matched:0,rejected:0,dead_links:0,rights_rejected:0,errors:0};
 const baseline=new Set(baselineUrls.map(canonicalUrl)),candidates=[];
 for(const item of items){
  if(!approved(item)){stats.rights_rejected++;stats.rejected++;continue;}
  try{const key=identity(item),url=item.url?canonicalUrl(item.url):null,existing=item.baseline||url&&baseline.has(url);
   if(item.url&&!existing&&!await checkHealth(item.url)){stats.dead_links++;stats.rejected++;continue;}
   candidates.push({...item,key,url,existing,mapping:mappingId(item)});
  }catch{stats.rejected++;}
 }
 const c=await pool.connect();try{
  await c.query('BEGIN');await c.query("SELECT pg_advisory_xact_lock(hashtext('tarteel-content-sync'))");
  await c.query(`INSERT INTO tarteel_catalog.providers(id,name,homepage,terms_url,enabled,checked_at) VALUES($1,$2,$3,$4,$5,now()) ON CONFLICT(id) DO UPDATE SET checked_at=now()`,[provider.id,provider.name,provider.homepage,provider.terms,provider.enabled]);
  for(const item of candidates){
   if(item.kind==='translation')await c.query(`UPDATE tarteel_catalog.entities SET metadata=jsonb_set(metadata,'{active}','false') WHERE kind='translation' AND metadata->>'key'=$1 AND edition<>$2`,[item.metadata.key,item.edition]);

   const alias=item.kind==='radio'&&item.url?fingerprint(item.url):null;
   let found=(await c.query('SELECT entity_id FROM tarteel_catalog.provider_items WHERE provider_id=$1 AND external_id=$2',[item.provider,item.mapping])).rows[0];
   if(alias){const byUrl=(await c.query('SELECT entity_id FROM tarteel_catalog.identity_aliases WHERE kind=$1 AND fingerprint=$2',[item.kind,alias])).rows[0];
    if(found&&byUrl&&String(found.entity_id)!==String(byUrl.entity_id)){stats.rejected++;continue;}
    if(!found)found=byUrl;
   }
   let id=found?.entity_id;
   if(!id){const r=(await c.query(`INSERT INTO tarteel_catalog.entities(kind,canonical_key,title_ar,language_code,narration,edition,surah_number,is_supplement,metadata) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9) ON CONFLICT(kind,canonical_key) DO UPDATE SET updated_at=now() RETURNING id,(xmax=0) AS created`,[item.kind,item.key,item.title,item.language??null,item.narration??null,item.edition??null,item.surah??null,!item.existing,item.metadata??{}])).rows[0];id=r.id;if(r.created&&!item.existing)stats.inserted++;else stats.matched++;
   }else {stats.matched++;await c.query('UPDATE tarteel_catalog.entities SET title_ar=$2,metadata=$3,updated_at=now() WHERE id=$1',[id,item.title,item.metadata??{}]);}
   await c.query(`INSERT INTO tarteel_catalog.provider_items(provider_id,external_id,entity_id,source_url,rights_url,usage_status,metadata) VALUES($1,$2,$3,$4,$5,'approved',$6) ON CONFLICT(provider_id,external_id) DO UPDATE SET last_seen=now(),metadata=excluded.metadata`,[item.provider,item.mapping,id,item.sourceUrl??provider.homepage,item.rightsUrl,item.metadata??{}]);
   if(alias){await c.query('INSERT INTO tarteel_catalog.identity_aliases(kind,fingerprint,entity_id) VALUES($1,$2,$3) ON CONFLICT DO NOTHING',[item.kind,alias,id]);await c.query(`INSERT INTO tarteel_catalog.media_endpoints(entity_id,normalized_url,url_fingerprint,status,checked_at) VALUES($1,$2,$3,'healthy',now()) ON CONFLICT(entity_id,url_fingerprint) DO UPDATE SET checked_at=now()`,[id,item.url,alias]);}
  }
  await c.query(`INSERT INTO tarteel_catalog.sync_runs(provider_id,finished_at,discovered,inserted,matched,rejected,dead_links,rights_rejected,errors) VALUES($1,now(),$2,$3,$4,$5,$6,$7,$8)`,[provider.id,...['discovered','inserted','matched','rejected','dead_links','rights_rejected','errors'].map(k=>stats[k])]);await c.query('COMMIT');return stats;
 }catch(e){await c.query('ROLLBACK');throw e;}finally{c.release();}
}
export async function syncAll(pool,options={}){
 const reports=[];for(const p of providers){if(!p.enabled){reports.push({provider:p.id,skipped:p.reason});continue;}
  try{reports.push(await syncProvider(pool,p,await adapters[p.id](),options));}catch(e){reports.push({provider:p.id,errors:1,reason:e.message});await pool.query('INSERT INTO tarteel_catalog.providers(id,name,enabled) VALUES($1,$2,true) ON CONFLICT DO NOTHING',[p.id,p.name]);await pool.query('INSERT INTO tarteel_catalog.sync_runs(provider_id,finished_at,errors,notes) VALUES($1,now(),1,$2)',[p.id,e.message]);}
 }return reports;
}
