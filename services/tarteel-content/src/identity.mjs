import {createHash} from 'node:crypto';
export const fingerprint=s=>createHash('sha256').update(s).digest('hex');
export const normalizeName=s=>String(s).normalize('NFKC').replace(/[\u064b-\u065f\u0670\u0640]/g,'').replace(/[أإآٱ]/g,'ا').replace(/ى/g,'ي').replace(/\s+/g,' ').trim().toLowerCase();
export function canonicalUrl(value){
 const u=new URL(value);
 if(u.protocol!=='https:'||u.username||u.password)throw Error('UNSAFE_URL');
 u.hash='';u.hostname=u.hostname.toLowerCase();
 if(/^(backup|live)\.qurango\.net$/.test(u.hostname))u.hostname='qurango.net';
 for(const k of [...u.searchParams.keys()])if(/^utm_|^(gclid|fbclid)$/.test(k))u.searchParams.delete(k);
 u.searchParams.sort();return u.toString().replace(/\/$/,'');
}
export function identity(item){
 if(!item.provider||!item.externalId)throw Error('MISSING_PROVIDER_ID');
 if(item.kind==='radio'&&item.url)return 'radio:'+fingerprint(canonicalUrl(item.url));
 if(item.kind==='translation'){
  if(!item.language||!item.edition||!item.translator)throw Error('MISSING_TRANSLATION_IDENTITY');
  return ['translation',item.provider,item.externalId,item.language,item.translator,item.edition].join('|');
 }
 if(item.kind==='recording'){
  if(!item.reciterId||!item.narration||!item.edition||!item.surah||!item.url)throw Error('MISSING_RECORDING_IDENTITY');
  return ['recording',item.provider,item.reciterId,item.narration,item.edition,item.surah,item.ayah??'',fingerprint(canonicalUrl(item.url))].join('|');
 }
 return [item.kind,item.provider,item.externalId].join('|');
}
export const approved=item=>item.rights==='approved'&&/^https:\/\//.test(item.rightsUrl??'');

export function mappingId(item){return ['translation','recording'].includes(item.kind)?item.externalId+':'+fingerprint(identity(item)):item.externalId;}
