import assert from 'node:assert/strict';

const base=process.env.TARTEEL_CLOUD_BASE_URL;
if(!base || new URL(base).protocol!=='https:') throw new Error('HTTPS endpoint required');
const invoke=async(path,method='GET',token,body)=>fetch(new URL(path,base),{
  method,headers:{'content-type':'application/json',...(token?{authorization:`Bearer ${token}`}:{})},
  ...(body?{body:JSON.stringify(body)}:{}),signal:AbortSignal.timeout(20000),redirect:'error',
});
const tokens=[];
try {
  assert.equal((await invoke('/health')).status,200);
  assert.equal((await invoke('/v1/library-backup')).status,401);
  for(let i=0;i<2;i++) {
    const result=await invoke('/v1/devices','POST',null,{consent:'favorites-backup-v1'});
    assert.equal(result.status,201);tokens.push((await result.json()).token);
  }
  const payload={stations:['acceptance-station'],reciters:[],tracks:[]};
  assert.equal((await invoke('/v1/library-backup','PUT',tokens[0],{revision:0,payload})).status,200);
  assert.equal((await (await invoke('/v1/library-backup','GET',tokens[0])).json()).data.payload.stations[0],'acceptance-station');
  assert.equal((await (await invoke('/v1/library-backup','GET',tokens[1])).json()).data,null);
  assert.equal((await invoke('/v1/library-backup','PUT',tokens[0],{revision:0,payload})).status,409);
  assert.equal((await invoke('/v1/library-backup','PUT',tokens[0],{revision:1,payload:{...payload,stations:['updated']}})).status,200);
  assert.equal((await (await invoke('/v1/library-backup','GET',tokens[0])).json()).data.payload.stations[0],'updated');
  assert.equal((await invoke('/v1/library-backup','PUT',tokens[1],{revision:0,payload:{...payload,latitude:13}})).status,422);
  assert.equal((await invoke('/v1/library-backup','GET','x'.repeat(43))).status,401);
  console.log('PASS: HTTPS health, consent registration, authenticated read/write/update, isolated devices, stale revision conflict, rejected location, invalid/absent token');
} finally {
  for(const token of tokens) {
    const result=await invoke('/v1/device','DELETE',token);
    assert.equal(result.status,200);
    assert.equal((await invoke('/v1/library-backup','GET',token)).status,401);
  }
  if(tokens.length) console.log('PASS: test backups deleted and device credentials revoked');
}
