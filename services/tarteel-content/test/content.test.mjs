import test from 'node:test';import assert from 'node:assert/strict';
import {identity,mappingId,canonicalUrl,normalizeName,approved} from '../src/identity.mjs';
import {authorized,admin} from '../src/admin.mjs';import {handler} from '../src/handler.mjs';import {fetchJson,providers} from '../src/registry.mjs';import {health} from '../src/sync.mjs';
const recording={kind:'recording',provider:'test',externalId:'7',reciterId:'1',narration:'hafs',edition:'murattal',surah:1,url:'https://cdn.example.org/take1.mp3'};
test('distinct recordings and narrations remain distinct for the same surah and reciter',()=>{
 assert.notEqual(identity(recording),identity({...recording,url:'https://cdn.example.org/take2.mp3'}));assert.notEqual(identity(recording),identity({...recording,narration:'warsh'}));assert.notEqual(mappingId(recording),mappingId({...recording,edition:'mujawwad'}));
});
test('station mirrors match while names alone do not merge reciters',()=>{
 assert.equal(identity({kind:'radio',provider:'one',externalId:'1',url:'https://backup.qurango.net/radio/a'}),identity({kind:'radio',provider:'two',externalId:'8',url:'https://live.qurango.net/radio/a'}));
 assert.notEqual(identity({kind:'reciter',provider:'one',externalId:'1',title:'محمد'}),identity({kind:'reciter',provider:'one',externalId:'2',title:'محمد'}));
 assert.notEqual(canonicalUrl('https://example.org:8443/a'),canonicalUrl('https://example.org/a'));assert.throws(()=>canonicalUrl('https://user:pass@example.org/a'));
});
test('translation language, translator, version and provider mappings remain distinct',()=>{
 const t={kind:'translation',provider:'quranenc',externalId:'english_test',language:'en',translator:'test',edition:'1'};
 assert.notEqual(identity(t),identity({...t,edition:'2'}));assert.notEqual(mappingId(t),mappingId({...t,edition:'2'}));assert.throws(()=>identity({...t,translator:''}));
});
test('normalization keeps original names; rights fail closed',()=>{
 const name='أَحْمَد  العَلْقَمِي';assert.equal(normalizeName(name),'احمد العلقمي');assert.equal(name,'أَحْمَد  العَلْقَمِي');assert.equal(approved({rights:'pending',rightsUrl:'https://example.org'}),false);assert.equal(approved({rights:'approved'}),false);
});
test('admin writes reject absent or invalid credentials before touching DB',async()=>{
 const db={query(){throw Error('DB must not be reached');}};const write=admin(db,'private-test');
 assert.equal((await write(new Request('https://example.org/admin/sync',{method:'POST'}))).status,401);
 assert.equal(authorized(new Request('https://example.org',{headers:{Authorization:'Bearer wrong'}}),'private-test'),false);
 assert.equal((await write(new Request('https://example.org/admin/sync',{headers:{Authorization:'Bearer private-test'}}))).status,405);
});
test('public catalog has no write routes and DB failures are bounded',async()=>{
 const h=handler({connect(){throw Error('unavailable');}});
 assert.equal((await h(new Request('https://example.org/v1/catalog',{method:'POST'}))).status,405);
 assert.equal((await h(new Request('https://example.org/v1/catalog'))).status,503);
 assert.equal((await h(new Request('https://example.org/v1/translations/x/999'))).status,404);
});
test('source errors retry without fabricating data',async()=>{
 let calls=0;await assert.rejects(fetchJson('https://example.org',{attempts:2,fetcher:async()=>{calls++;return new Response('{}',{status:503});}}));assert.equal(calls,2);
});
test('health checks never follow redirects or access arbitrary/private hosts',async()=>{
 let called=false;assert.equal(await health('https://127.0.0.1/secret',async()=>{called=true;}),false);assert.equal(called,false);
 assert.equal(await health('https://backup.qurango.net/radio/a',async(_,options)=>{assert.equal(options.redirect,'error');return new Response('x',{headers:{'content-type':'audio/mpeg'}});}),true);
});
test('unreviewed provider rights stay disabled independently',()=>{for(const id of ['archive','islamic-radio','quran-foundation','kfgqpc','quran-android'])assert.equal(providers.find(p=>p.id===id).enabled,false);});

test('mushaf catalog exposes approved views through read-only role and no writes',async()=>{
 const statements=[];let releases=0;
 const pool={async connect(){return {async query(sql){statements.push(sql);return {rows:sql.includes('public_library_status')?[{canonical_ayahs:'6236',topics:'6100',covered_ayahs:'3673',complete_reviewed_tajweed_available:false}]:sql.includes('public_editions')?[{id:'madinah-hafs-svg-v1',rights_status:'approved'}]:[]};},release(){releases++;}};}};
 const h=handler(pool);const response=await h(new Request('https://example.org/v1/mushaf-library'));
 assert.equal(response.status,200);const body=await response.json();assert.equal(body.status.topics,'6100');assert.equal(body.status.complete_reviewed_tajweed_available,false);
 assert.equal(releases,3);assert.equal(statements.filter(s=>s==='SET LOCAL ROLE tarteel_catalog_reader').length,3);assert.equal(statements.filter(s=>s==='BEGIN READ ONLY').length,3);
 assert.equal((await h(new Request('https://example.org/v1/mushaf-library',{method:'POST'}))).status,405);
});

test('Surah exposes metadata through read-only view, never educational bodies',async()=>{
 const statements=[];const h=handler({async connect(){return {async query(sql){statements.push(sql);return {rows:sql.includes('public_projects')?[{slug:'tafsir-mokhtasar',permanent_storage_allowed:false}]:[]};},release(){}};}});
 const r=await h(new Request('https://example.org/v1/surah-projects'));assert.equal(r.status,200);const b=await r.json();assert.equal(b.contentStorage,'metadata_only');assert.equal(b.projects[0].permanent_storage_allowed,false);assert.ok(statements.includes('SET LOCAL ROLE tarteel_catalog_reader'));assert.ok(statements.includes('BEGIN READ ONLY'));assert.equal((await h(new Request('https://example.org/v1/surah-projects',{method:'POST'}))).status,405);assert.equal((await h(new Request('https://example.org/v1/aya/tafsir-saadi/1/1'))).status,404);
});
