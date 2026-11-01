import test from 'node:test';import assert from 'node:assert/strict';
import {createHandler} from '../src/handler.mjs';
import {validatePrayerPreferences} from '../src/prayer-preferences.mjs';
export const payload={schema:1,calculation_method:'muslimWorldLeague',asr_method:'shafi',offsets:{fajr:2},reminder_modes:{fajr:'adhan'},before_minutes:{fajr:5},after_minutes:{},volumes:{fajr:0.7},audio_assets:{fajr:'assets/audio/user_makkah.mp3'}};
test('prayer preferences reject location, paths, schedules and out of range values',()=>{
 assert.deepEqual(validatePrayerPreferences(payload),payload);
 for(const field of ['latitude','longitude','timezone','manual_times','alarms','audio_paths'])assert.throws(()=>validatePrayerPreferences({...payload,[field]:{}}));
 for(const bad of [{volumes:{fajr:2}},{before_minutes:{fajr:121}},{offsets:{fajr:0.5}},{reminder_modes:{sunrise:'adhan'}},{audio_assets:{fajr:'/data/private/recording.mp3'}},{audio_assets:{fajr:'https://example.com/a.mp3'}}])assert.throws(()=>validatePrayerPreferences({...payload,...bad}));
});
test('prayer endpoint requires its own consent, isolates tokens and rejects stale writes',async()=>{
 const credentials=new Map(),backups=new Map();
 const h=createHandler({budget:async()=>{},register:async(id,hash)=>credentials.set(hash,id),authenticate:async hash=>credentials.get(hash),getPrayer:async id=>backups.get(id)??null,putPrayer:async(id,rev,payload)=>{if((backups.get(id)?.revision??0)!==rev)return null;const data={revision:rev+1,payload};backups.set(id,data);return data;}});
 const request=(path,method='GET',token,body)=>h(new Request('https://example.org'+path,{method,headers:{'content-type':'application/json',...(token?{authorization:'Bearer '+token}:{})},...(body?{body:JSON.stringify(body)}:{})}));
 assert.equal((await request('/v1/prayer-preferences')).status,401);
 const register=async()=>(await(await request('/v1/devices','POST',null,{consent:'favorites-backup-v1'})).json()).token;
 const a=await register(),b=await register();
 assert.equal((await request('/v1/prayer-preferences','PUT',a,{revision:0,payload})).status,422);
 const body={consent:'prayer-preferences-v1',revision:0,payload};
 assert.equal((await request('/v1/prayer-preferences','PUT',a,body)).status,200);
 assert.equal((await(await request('/v1/prayer-preferences','GET',b)).json()).data,null);
 assert.equal((await request('/v1/prayer-preferences','PUT',a,body)).status,409);
 assert.deepEqual((await(await request('/v1/prayer-preferences','GET',a)).json()).data.payload,payload);
});
