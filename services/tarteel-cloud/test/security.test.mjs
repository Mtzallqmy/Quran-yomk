import test from 'node:test';
import assert from 'node:assert/strict';
import {createHandler,validatePayload,bearer} from '../src/handler.mjs';

function fixture() {
  const credentials=new Map(),backups=new Map(),budgets=new Map();
  const db={
    async budget(p,l) { const n=(budgets.get(p)??0)+1; budgets.set(p,n); if(n>l) { const {ApiError}=await import('../src/handler.mjs'); throw new ApiError(429,'RATE_LIMITED'); } },
    async register(id,hash) { credentials.set(hash,id); },
    async authenticate(hash) { return credentials.get(hash); },
    async get(id) { return backups.get(id)??null; },
    async put(id,revision,payload) { const prior=backups.get(id); if((prior?.revision??0)!==revision) return null; const data={revision:revision+1,payload};backups.set(id,data);return data; },
    async revoke(id) {for(const [hash,value] of credentials) if(value===id) credentials.delete(hash);backups.delete(id);},
  };
  const handle=createHandler(db);
  const request=(path,method='GET',token,body)=>handle(new Request(`https://cloud.example${path}`,{method,headers:{...(token?{authorization:`Bearer ${token}`}:{ }),'content-type':'application/json'},...(body?{body:JSON.stringify(body)}:{})}));
  const register=async()=>{const result=await request('/v1/devices','POST',null,{consent:'favorites-backup-v1'});assert.equal(result.status,201);return (await result.json()).token;};
  return {request,register,credentials};
}
test('anonymous and forged credentials cannot read or write backups',async()=>{
  const {request}=fixture();
  assert.equal((await request('/v1/library-backup')).status,401);
  assert.equal((await request('/v1/library-backup','PUT','x'.repeat(43),{revision:0,payload:{}})).status,401);
});
test('two device principals are isolated, optimistic concurrency preserves prior data, revoke works',async()=>{
  const {request,register}=fixture();const a=await register(),b=await register();
  const payload={stations:['station-1'],reciters:[],tracks:[]};
  assert.equal((await request('/v1/library-backup','PUT',a,{revision:0,payload})).status,200);
  assert.equal((await request('/v1/library-backup','GET',b)).status,200);
  assert.equal((await (await request('/v1/library-backup','GET',b)).json()).data,null);
  assert.equal((await request('/v1/library-backup','PUT',a,{revision:0,payload:{...payload,stations:['lost']}})).status,409);
  assert.equal((await (await request('/v1/library-backup','GET',a)).json()).data.payload.stations[0],'station-1');
  assert.equal((await request('/v1/library-backup','PUT',a,{revision:1,payload})).status,200);
  assert.equal((await request('/v1/device','DELETE',a)).status,200);
  assert.equal((await request('/v1/library-backup','GET',a)).status,401);
});
test('backup rejects prayer/location fields and bounds sizes',()=>{
  assert.throws(()=>validatePayload({stations:[],reciters:[],tracks:[],prayer:{}}));
  assert.throws(()=>validatePayload({stations:['a'.repeat(201)],reciters:[],tracks:[]}));
  assert.deepEqual(validatePayload({stations:['a','a'],reciters:[],tracks:[]}).stations,['a']);
  assert.throws(()=>bearer(new Request('https://example.com',{headers:{authorization:'Bearer short'}})));
});
test('consent and persistent admission quotas are enforced',async()=>{
  const {request}=fixture();
  assert.equal((await request('/v1/devices','POST',null,{consent:'wrong'})).status,422);
  let result;for(let i=0;i<21;i++)result=await request('/v1/devices','POST',null,{consent:'wrong'});
  assert.equal(result.status,429);assert.equal(result.headers.get('retry-after'),'60');
});
test('oversized body rejected before JSON parsing',async()=>{
  const {request,register}=fixture();const token=await register();
  assert.equal((await request('/v1/library-backup','PUT',token,{revision:0,payload:'x'.repeat(70000)})).status,413);
});
