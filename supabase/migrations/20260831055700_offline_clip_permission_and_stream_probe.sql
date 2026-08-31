-- Offline clip saving remains fail-closed and is only enabled for providers
-- whose published terms explicitly allow copying material/using links.
-- MP3Quran's policy also states that it applies to qurango.net.
update app.stations s
set offline_clip_allowed = true,
    offline_clip_evidence = 'https://www.mp3quran.net/ar/privacy',
    offline_clip_verified_at = now(),
    updated_at = now()
from app.content_providers p
where p.id = s.provider_id
  and p.slug in ('mp3quran','qurango')
  and s.station_source = 'EXTERNAL'
  and s.deleted_at is null
  and s.is_active = true
  and s.rights_status = 'APPROVED'
  and s.commercial_use_status = 'ALLOWED'
  and s.stream_url ~* '^https://';

create or replace function public.tarteel_public_offline_clip_policy(p_station_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $function$
  select jsonb_build_object(
    'station_id', s.id,
    'allowed', (
      s.offline_clip_allowed = true
      and s.offline_clip_evidence is not null
      and length(btrim(s.offline_clip_evidence)) > 0
      and s.rights_status = 'APPROVED'
      and s.commercial_use_status = 'ALLOWED'
      and s.stream_type in ('MP3_STREAM','AAC_STREAM','SHOUTCAST','ICECAST')
      and s.stream_url ~* '^https://'
      and s.deleted_at is null
      and s.is_active = true
    ),
    'supported_stream', (s.stream_type in ('MP3_STREAM','AAC_STREAM','SHOUTCAST','ICECAST')),
    'requires_content_probe', (s.stream_type in ('SHOUTCAST','ICECAST')),
    'stream_type', s.stream_type,
    'verified_at', s.offline_clip_verified_at
  )
  from app.stations s
  where s.id = p_station_id;
$function$;

grant execute on function public.tarteel_public_offline_clip_policy(uuid) to anon, authenticated;
