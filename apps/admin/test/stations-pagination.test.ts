import test from 'node:test';
import assert from 'node:assert/strict';
import { dispatchPublic } from '../lib/api-public.ts';

test('station pages count eligible rows and never invent a following page', async t => {
  const original={...process.env};
  Object.assign(process.env,{SUPABASE_URL:'https://example.supabase.co',SUPABASE_PUBLISHABLE_KEY:'test',SUPABASE_SECRET_KEY:'server-test',TARTEEL_ENVIRONMENT:'production'});
  t.after(()=>{process.env=original;});
  const rows=Array.from({length:4},(_,i)=>({id:String(i),name_ar:'Station',station_source:'INTERNAL'}));
  t.mock.method(globalThis,'fetch',async(input:unknown,init?:RequestInit)=>{
    const url=new URL(String(input));
    assert.equal(url.searchParams.get('is_active'),'eq.true');
    assert.equal(url.searchParams.get('deleted_at'),'is.null');
    assert.equal(url.searchParams.get('or'),'(and(station_source.eq.INTERNAL,production_enabled.eq.true),and(station_source.eq.EXTERNAL,availability_status.eq.APPROVED_FOR_PUBLIC_RELEASE,production_enabled.eq.true,rights_status.eq.APPROVED,commercial_use_status.eq.ALLOWED))');
    const headers=new Headers(init?.headers);
    assert.equal(headers.get('prefer'),'count=exact');
    if(url.searchParams.get('limit')==='0')return Response.json([],{headers:{'content-range':'*/4'}});
    const [from,to]=headers.get('range')!.split('-').map(Number);
    if(from>=rows.length)return new Response(null,{status:416});
    return Response.json(rows.slice(from,to+1),{headers:{'content-range':`${from}-${Math.min(to,3)}/4`}});
  });
  for(const page of [1,2,3]){
    const result=await dispatchPublic(new Request(`https://example.test/stations?page=${page}&limit=2`),['stations']);
    const data=await result!.response.json();
    assert.equal(data.total,4);
    assert.equal(data.next_page,page===1?2:null);
    assert.deepEqual(data.data.map((row:{id:string})=>row.id),page===1?['0','1']:page===2?['2','3']:[]);
  }
  t.mock.method(globalThis,'fetch',async()=>Response.json([],{headers:{'content-range':'*/0'}}));
  const empty=await dispatchPublic(new Request('https://example.test/stations'),['stations']);
  assert.deepEqual(await empty!.response.json(),{data:[],page:1,limit:20,total:0,next_page:null});
});
