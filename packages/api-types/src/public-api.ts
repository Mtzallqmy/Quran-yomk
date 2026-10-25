export type StationSource='INTERNAL'|'EXTERNAL';
export type StreamHealth='HEALTHY'|'DEGRADED'|'UNREACHABLE'|'INVALID'|'UNKNOWN';
export type NowPlayingSource='AUTO'|'SCHEDULED'|'MANUAL'|'FALLBACK'|'EMERGENCY';
export type QuranAudioProvider='ALQURAN_CLOUD'|'MP3QURAN';
export interface PublicStation {id:string;slug:string;name_ar:string;name_en:string|null;logo_url:string|null;station_source:StationSource;stream_type:string;playback_url:string|null;health_status?:StreamHealth;attribution?:string|null}
export interface Surah {id:number;number:number;name_ar:string;name_en:string;ayah_count:number}
export interface Reciter {id:string;slug:string;name_ar:string;name_en:string|null;image_url:string|null;country:string|null;rewaya:string|null;description?:string|null}
export interface ReciterTrack {id:string;media_id:string|null;duration_ms:number|null;quality:string|null;rewaya:string|null;format:string|null;bitrate_kbps:number|null;playback_url:string|null}
export interface ReciterSurah {surah:Surah;track:ReciterTrack}
export interface QuranReciterIdentityV1 {schema_version:1;provider:QuranAudioProvider;provider_reciter_id:string;edition:string;moshaf_id:string|null;riwayah:string|null;surah_number:number;ayah_number?:number|null}
export interface NowPlaying {station:Pick<PublicStation,'id'|'slug'|'name_ar'|'name_en'>;media_id:string|null;title:string|null;subtitle:string|null;started_at:string|null;expected_end_at:string|null;source:NowPlayingSource|null;is_live:boolean;server_time:string}
export interface Page<T>{data:T[];page:number;limit:number;total:number;next_page:number|null}
export interface ApiError {error:{code:string;message:string;request_id:string}}
