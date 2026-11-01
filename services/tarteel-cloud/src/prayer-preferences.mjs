import manifest from '../../../apps/mobile/assets/audio/manifest.json' with {type:'json'};
import {ApiError} from './handler.mjs';
const prayers=['fajr','sunrise','dhuhr','asr','maghrib','isha'];
const methods=['muslimWorldLeague','egyptian','ummAlQura','karachi','northAmerica'];
const modes=['disabled','silent','notificationOnly','adhan','shortAlert'];
const assets=new Set(manifest.assets.map(a=>a.path));
export function validatePrayerPreferences(value){
 const fail=()=>{throw new ApiError(422,'INVALID_PRAYER_PREFERENCES');};
 const fields=['schema','calculation_method','asr_method','offsets','reminder_modes','before_minutes','after_minutes','volumes','audio_assets'];
 if(!value||Array.isArray(value)||typeof value!=='object'||Object.keys(value).sort().join()!==fields.sort().join()||value.schema!==1||!methods.includes(value.calculation_method)||!['shafi','hanafi'].includes(value.asr_method))fail();
 for(const [key,valid] of [
  ['offsets',v=>Number.isInteger(v)&&v>=-60&&v<=60],
  ['reminder_modes',v=>modes.includes(v)],
  ['before_minutes',v=>Number.isInteger(v)&&v>=0&&v<=120],
  ['after_minutes',v=>Number.isInteger(v)&&v>=0&&v<=120],
  ['volumes',v=>typeof v==='number'&&Number.isFinite(v)&&v>=0&&v<=1],
  ['audio_assets',v=>assets.has(v)],
 ]){
  const map=value[key];if(!map||Array.isArray(map)||typeof map!=='object')fail();
  for(const [prayer,v] of Object.entries(map))if(!prayers.includes(prayer)||!valid(v)||(key==='reminder_modes'&&prayer==='sunrise'))fail();
 }
 if(Buffer.byteLength(JSON.stringify(value))>8192)fail();
 return value;
}
