import test from 'node:test';import assert from 'node:assert/strict';
import {handler} from '../src/handler.mjs';import {syncSurahRegistry} from '../src/surah-registry.mjs';
test('bootstrap is read-only metadata and explicitly keeps alarms local',async()=>{
 const sql=[];const h=handler({async connect(){return{query:async s=>{sql.push(s);return{rows:s.includes('public_app_releases')?[{version_code:2094}]:[]};},release(){}};}});
 const r=await h(new Request('https://example.org/v1/bootstrap'));assert.equal(r.status,200);const b=await r.json();assert.equal(b.release.version_code,2094);assert.equal(b.prayer.cloudRequired,false);assert.equal(b.surah.contentStorage,'metadata_only');assert.ok(sql.includes('BEGIN READ ONLY'));assert.ok(sql.includes('SET LOCAL ROLE tarteel_catalog_reader'));assert.equal((await h(new Request('https://example.org/v1/bootstrap',{method:'POST'}))).status,405);
});
test('Surah registry sync twice adds no duplicate projects and never fetches bodies',async()=>{
 const existing=new Set(),paths=[],sql=[];
 const pool={async connect(){return{async query(q,p){sql.push(q);return{rows:q.includes('pg_try_advisory')?[{locked:true}]:q.includes('RETURNING(xmax=0)')?[{inserted:!existing.has(p[0])&&!!existing.add(p[0])}]:[]};},release(){}};}};
 const fetcher=async url=>{paths.push(url);return Response.json([{slug:'tafsir-mokhtasar',title:'المختصر',type:'aya'}]);};
 assert.equal((await syncSurahRegistry(pool,{fetcher})).inserted,1);assert.equal((await syncSurahRegistry(pool,{fetcher})).inserted,0);assert.equal(existing.size,1);assert.ok(paths.every(p=>p.endsWith('/projects')));assert.ok(!sql.some(s=>/DELETE|TRUNCATE/.test(s)));
});
test('invalid or failed source never removes or replaces registry rows',async()=>{
 let touched=false;const pool={connect(){touched=true;throw Error();}};
 await assert.rejects(syncSurahRegistry(pool,{fetcher:async()=>Response.json([{slug:'../bad',type:'aya'}])}));assert.equal(touched,false);
 await assert.rejects(syncSurahRegistry(pool,{fetcher:async()=>new Response('{}',{status:503})}));assert.equal(touched,false);
});
