import test from 'node:test';
import assert from 'node:assert/strict';
import {createHandler} from '../src/handler.mjs';

test('public catalog supports read only and never registers a device', async()=>{
  let reads=0;
  const handle=createHandler({async radioCatalog(){reads++;return [{id:'one',name_ar:'الشمائل المحمدية'}];}});
  const get=()=>handle(new Request('https://example.com/v1/radio/stations'));
  const [a,b]=await Promise.all([get(),get()]);
  assert.equal(a.status,200);assert.equal(b.status,200);assert.equal(reads,1);
  assert.equal((await a.json()).data[0].id,'one');
  assert.match(a.headers.get('cache-control'),/public/);
  await get();assert.equal(reads,1);
  for(const method of ['POST','PUT','DELETE']) {
    assert.equal((await handle(new Request('https://example.com/v1/radio/stations',{method}))).status,405);
  }
});

test('failed catalog read is not cached as an empty successful catalog',async()=>{
  let reads=0;
  const handle=createHandler({async radioCatalog(){if(++reads===1)throw new Error('unavailable');return [];}});
  const request=()=>handle(new Request('https://example.com/v1/radio/stations'));
  assert.equal((await request()).status,503);
  assert.equal((await request()).status,200);
});
