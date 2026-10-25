import baseline from '../baseline-inventory.json' with {type:'json'};
const knownReciters=new Set(baseline.quranReciters.map(r=>String(r.provider_reciter_id)));
const knownEditions=new Set(baseline.quranReciters.map(r=>r.provider_reciter_id+':'+r.moshaf_id));
export const providers=[
 {id:'mp3quran',name:'MP3Quran',homepage:'https://www.mp3quran.net',terms:'https://www.mp3quran.net/ar/api',enabled:true},
 {id:'quranenc',name:'QuranEnc',homepage:'https://quranenc.com',terms:'https://quranenc.com/en/home/api/',enabled:true},
 {id:'quran-foundation',name:'Quran Foundation',homepage:'https://api-docs.quran.foundation/',enabled:false,reason:'Developer credentials and Content Sync authorization required'},
 {id:'tanzil',name:'Tanzil',homepage:'https://tanzil.net/download/',terms:'https://tanzil.net/docs/text_license',enabled:false,reason:'Verification source only; existing Quran text retained'},
 {id:'kfgqpc',name:'King Fahd Complex',homepage:'https://qurancomplex.gov.sa/quran-dev/',enabled:false,reason:'Per-asset rights and narration verification pending'},
 {id:'quran-android',name:'Quran Android',homepage:'https://github.com/quran/quran_android',enabled:false,reason:'GPL code and independently licensed data; no copying'},
 {id:'islamic-radio',name:'Islamic Radio API',homepage:'https://github.com/uthumany/radio-api',enabled:false,reason:'Per-station redistribution rights pending'},
 {id:'archive',name:'Internet Archive',homepage:'https://archive.org/developers/index-apis.html',enabled:false,reason:'Item-specific license required'},
];
export async function fetchJson(url,{fetcher=fetch,attempts=3}={}){
 let error;
 for(let n=0;n<attempts;n++){
  try{const r=await fetcher(url,{signal:AbortSignal.timeout(12000)});if(!r.ok)throw Error('UPSTREAM_'+r.status);
   const body=await r.text();if(body.length>8_000_000)throw Error('RESPONSE_TOO_LARGE');return JSON.parse(body);
  }catch(e){error=e;if(n+1<attempts)await new Promise(r=>setTimeout(r,250*2**n));}
 }throw error;
}
export const adapters={
 async quranenc(){const d=await fetchJson('https://quranenc.com/api/v1/translations/list/?localization=ar');return(d.translations??d).map(r=>({provider:'quranenc',externalId:r.key,kind:'translation',title:r.title,language:r.language_iso_code,edition:String(r.version),translator:r.key,rights:'approved',rightsUrl:providers[1].terms,sourceUrl:'https://quranenc.com/en/browse/'+r.key,metadata:{...r,publisher:'QuranEnc.com',translatorIdentity:r.key,attribution:'QuranEnc.com — '+r.title,termsUrl:providers[1].terms}}));},
 async mp3quran(){
  const result=[],data=await fetchJson('https://mp3quran.net/api/v3/reciters?language=ar');
  for(const r of data.reciters){result.push({provider:'mp3quran',externalId:'reciter:'+r.id,kind:'reciter',title:r.name,baseline:knownReciters.has(String(r.id)),rights:'approved',rightsUrl:providers[0].terms,metadata:{providerReciterId:r.id}});
   for(const m of r.moshaf??[])result.push({provider:'mp3quran',externalId:'moshaf:'+r.id+':'+m.id,kind:'mushaf',title:r.name+' — '+m.name,baseline:knownEditions.has(r.id+':'+m.id),url:m.server+String(m.surah_list.split(',')[0]).padStart(3,'0')+'.mp3',narration:m.name,edition:String(m.id),rights:'approved',rightsUrl:providers[0].terms,metadata:{reciterId:r.id,...m}});
  }
  const radios=await fetchJson('https://mp3quran.net/api/v3/radios?language=ar');for(const r of radios.radios)result.push({provider:'mp3quran',externalId:'radio:'+r.id,kind:'radio',title:r.name,url:r.url,rights:'approved',rightsUrl:providers[0].terms,metadata:{providerStationId:r.id}});return result;
 },
};
