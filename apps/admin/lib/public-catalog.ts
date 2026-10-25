import { ApiError, assertEnum, int, safeLike } from './contracts';
import { publicEnv, publicRpc } from './supabase';
import type { Json } from './contracts';

const SOURCES=['INTERNAL','EXTERNAL'] as const;

function playbackUrl(row:Record<string,unknown>):string|null{
  if(row.station_source==='EXTERNAL')return typeof row.playback_url==='string'?row.playback_url:null;
  const e=publicEnv();
  return e.streamBase?`${e.streamBase}${e.mount}`:null;
}

function station(row:Record<string,unknown>){
  return {
    id:row.id,slug:row.slug,name_ar:row.name_ar,name_en:row.name_en,description:row.description,logo_url:row.logo_url,
    category_id:row.category_id,category:row.category,station_source:row.station_source,stream_type:row.stream_type,
    playback_url:playbackUrl(row),timezone:row.timezone,status:row.status,health_status:row.health_status,is_featured:row.is_featured,
    provider:row.provider,provider_name:row.provider_name,integration_basis:row.integration_basis,attribution:row.attribution,
    terms_url:row.terms_url,license_url:row.license_url,availability_status:row.availability_status,
  };
}

export async function listPublicStations(request:Request){
  const url=new URL(request.url);
  const page=int(url.searchParams.get('page')??1,'page',1,100000);
  const limit=int(url.searchParams.get('limit')??50,'limit',1,200);
  const source=url.searchParams.get('source');
  const category=url.searchParams.get('category');
  const provider=url.searchParams.get('provider');
  const search=safeLike(url.searchParams.get('search')??url.searchParams.get('q')??'');
  const args:Record<string,Json>={
    p_environment:publicEnv().environment,
    p_source:source?assertEnum(source.toUpperCase(),SOURCES,'source'):null,
    p_category:category?.trim().toUpperCase()||null,
    p_provider:provider?.trim().toLowerCase()||null,
    p_search:search||null,
    p_limit:limit,
    p_offset:(page-1)*limit,
    p_slug:null,
  };
  const rows=await publicRpc('public_station_catalog',args) as Record<string,unknown>[];
  return {data:rows.map(station),page,limit,total:rows.length,next_page:rows.length===limit?page+1:null};
}

export async function getPublicStation(slug:string){
  if(!slug||slug.length>160)throw new ApiError(422,'VALIDATION_ERROR','slug is invalid');
  const rows=await publicRpc('public_station_catalog',{
    p_environment:publicEnv().environment,p_source:null,p_category:null,p_provider:null,p_search:null,p_limit:1,p_offset:0,p_slug:slug,
  }) as Record<string,unknown>[];
  if(!rows[0])throw new ApiError(404,'NOT_FOUND','Station not found');
  return {data:station(rows[0])};
}

export async function publicContentSources(){
  const rows=await publicRpc('public_content_sources',{}) as Record<string,unknown>[];
  return {data:rows};
}
