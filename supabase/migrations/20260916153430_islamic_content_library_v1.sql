-- Shared, rights-aware Islamic content library for Tarteel and future clients.
-- This migration mirrors the production migration applied to qkroecnecdxghcqvvoxn.
create extension if not exists pgcrypto;

create table if not exists public.islamic_content_sources (
  slug text primary key,
  title text not null,
  source_kind text not null check (source_kind in ('github_dataset','tanzil_text','wikimedia_audio','manual')),
  original_url text not null,
  license_name text not null,
  license_url text not null,
  license_scope text not null default 'dataset',
  redistribution_allowed boolean not null default false,
  notes text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.islamic_content_categories (
  slug text primary key,
  name_ar text not null,
  name_en text,
  sort_order integer not null default 100,
  created_at timestamptz not null default now()
);

create table if not exists public.islamic_audio_assets (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  kind text not null check (kind in ('adhan','iqamah','dua','dhikr','other')),
  title_ar text not null,
  voice_name text,
  source_slug text not null references public.islamic_content_sources(slug) on update cascade,
  original_source_url text not null,
  storage_bucket text not null default 'islamic-content-audio',
  storage_path text not null unique,
  mime_type text not null,
  byte_size bigint not null check (byte_size > 0),
  duration_ms integer check (duration_ms is null or duration_ms > 0),
  sha256 text not null check (sha256 ~ '^[0-9a-f]{64}$'),
  license_name text not null,
  license_url text not null,
  redistribution_allowed boolean not null default false,
  review_status text not null default 'pending' check (review_status in ('pending','approved','blocked')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint approved_audio_requires_rights check (review_status <> 'approved' or redistribution_allowed)
);

create table if not exists public.islamic_content_items (
  id uuid primary key default gen_random_uuid(),
  source_slug text not null references public.islamic_content_sources(slug) on update cascade,
  source_key text not null,
  title_ar text not null,
  text_ar text not null,
  reference text,
  repeat_count integer not null default 1 check (repeat_count between 1 and 10000),
  audio_asset_id uuid references public.islamic_audio_assets(id) on delete set null,
  license_name text not null,
  license_url text not null,
  original_source_url text not null,
  review_status text not null default 'pending' check (review_status in ('pending','approved','blocked')),
  sha256 text not null check (sha256 ~ '^[0-9a-f]{64}$'),
  source_file_sha256 text check (source_file_sha256 is null or source_file_sha256 ~ '^[0-9a-f]{64}$'),
  source_revision text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(source_slug, source_key)
);

create table if not exists public.islamic_content_item_categories (
  item_id uuid not null references public.islamic_content_items(id) on delete cascade,
  category_slug text not null references public.islamic_content_categories(slug) on update cascade,
  primary key (item_id, category_slug)
);

create table if not exists public.islamic_schedule_templates (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title_ar text not null,
  category_slug text not null references public.islamic_content_categories(slug),
  trigger_kind text not null check (trigger_kind in ('fixed_local_time','prayer_relative','sunrise_relative','sunset_relative')),
  fixed_local_time time,
  prayer text check (prayer is null or prayer in ('fajr','dhuhr','asr','maghrib','isha')),
  offset_minutes integer not null default 0 check (offset_minutes between -360 and 360),
  audio_asset_id uuid references public.islamic_audio_assets(id) on delete set null,
  default_enabled boolean not null default false,
  review_status text not null default 'approved' check (review_status in ('pending','approved','blocked')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint schedule_trigger_shape check (
    (trigger_kind = 'fixed_local_time' and fixed_local_time is not null and prayer is null)
    or (trigger_kind = 'prayer_relative' and prayer is not null and fixed_local_time is null)
    or (trigger_kind in ('sunrise_relative','sunset_relative') and fixed_local_time is null and prayer is null)
  )
);

create table if not exists public.islamic_content_import_runs (
  id uuid primary key default gen_random_uuid(),
  source_slug text references public.islamic_content_sources(slug),
  status text not null check (status in ('started','completed','failed')),
  inserted_count integer not null default 0,
  updated_count integer not null default 0,
  source_file_sha256 text,
  error_code text,
  details jsonb not null default '{}'::jsonb,
  started_at timestamptz not null default now(),
  completed_at timestamptz
);

insert into public.islamic_content_categories(slug,name_ar,name_en,sort_order) values
  ('adhan','أذان','Adhan',10),
  ('iqamah','إقامة','Iqamah',20),
  ('adhkar_morning','أذكار الصباح','Morning adhkar',30),
  ('adhkar_evening','أذكار المساء','Evening adhkar',40),
  ('adhkar_sleep','أذكار النوم','Sleep adhkar',50),
  ('adhkar_prayer','أذكار الصلاة','Prayer adhkar',60),
  ('dua','أدعية','Duas',70),
  ('quran','قرآن','Quran',80),
  ('other','أخرى','Other',999)
on conflict (slug) do update
set name_ar=excluded.name_ar,name_en=excluded.name_en,sort_order=excluded.sort_order;

insert into public.islamic_content_sources(slug,title,source_kind,original_url,license_name,license_url,license_scope,redistribution_allowed,notes) values
  ('seen_adhkar','Morning-And-Evening-Adhkar-DB','github_dataset','https://github.com/Seen-Arabic/Morning-And-Evening-Adhkar-DB','MIT','https://github.com/Seen-Arabic/Morning-And-Evening-Adhkar-DB/blob/main/LICENSE','repository_dataset',true,'Only repository text data is imported. External audio URLs are intentionally ignored unless separately verified.'),
  ('fitrahive_dua_dhikr','Fitrahive Dua & Dhikr','github_dataset','https://github.com/fitrahive/dua-dhikr','MIT','https://github.com/fitrahive/dua-dhikr/blob/main/LICENSE','repository_dataset',true,'Arabic text and references are imported from the repository data. No third-party audio is inherited.'),
  ('hisn_el_muslim','HisnElMuslim JSON','github_dataset','https://github.com/asellam/HisnElMuslim','MIT','https://github.com/asellam/HisnElMuslim/blob/main/LICENSE.md','repository_dataset',true,'Repository JSON text is imported; Audio fields point to third parties and are never mirrored without separate rights verification.'),
  ('tanzil_uthmani_1_1','Tanzil Quran Text Uthmani 1.1','tanzil_text','https://tanzil.net/download/','Creative Commons Attribution 3.0 + Tanzil verbatim-only terms','https://tanzil.net/docs/Text_License','verbatim_text',true,'Quran text must remain verbatim. Source attribution and Tanzil link must be preserved.'),
  ('wikimedia_commons_audio','Wikimedia Commons verified audio','wikimedia_audio','https://commons.wikimedia.org/','PER_ITEM','https://commons.wikimedia.org/wiki/Commons:Licensing','per_item',false,'Redistribution is decided per file only. Repository/site-level licensing is never assumed for individual audio.')
on conflict (slug) do update set
  title=excluded.title,source_kind=excluded.source_kind,original_url=excluded.original_url,
  license_name=excluded.license_name,license_url=excluded.license_url,license_scope=excluded.license_scope,
  redistribution_allowed=excluded.redistribution_allowed,notes=excluded.notes,updated_at=now();

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('islamic-content-audio','islamic-content-audio',true,10485760,array['audio/ogg','application/ogg']::text[])
on conflict (id) do update set
  public=excluded.public,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

create index if not exists islamic_content_items_review_idx on public.islamic_content_items(review_status,updated_at desc);
create index if not exists islamic_content_items_source_idx on public.islamic_content_items(source_slug,source_key);
create index if not exists islamic_item_categories_category_idx on public.islamic_content_item_categories(category_slug,item_id);
create index if not exists islamic_audio_assets_review_idx on public.islamic_audio_assets(review_status,kind);
create index if not exists islamic_schedule_templates_category_idx on public.islamic_schedule_templates(category_slug,review_status);

alter table public.islamic_content_sources enable row level security;
alter table public.islamic_content_categories enable row level security;
alter table public.islamic_audio_assets enable row level security;
alter table public.islamic_content_items enable row level security;
alter table public.islamic_content_item_categories enable row level security;
alter table public.islamic_schedule_templates enable row level security;
alter table public.islamic_content_import_runs enable row level security;

revoke all on public.islamic_content_sources from anon, authenticated;
revoke all on public.islamic_content_categories from anon, authenticated;
revoke all on public.islamic_audio_assets from anon, authenticated;
revoke all on public.islamic_content_items from anon, authenticated;
revoke all on public.islamic_content_item_categories from anon, authenticated;
revoke all on public.islamic_schedule_templates from anon, authenticated;
revoke all on public.islamic_content_import_runs from anon, authenticated;

create or replace function public.tarteel_public_islamic_sources()
returns table(slug text,title text,source_kind text,original_url text,license_name text,license_url text,license_scope text,redistribution_allowed boolean,notes text)
language sql stable security definer set search_path=public
as $$
  select s.slug,s.title,s.source_kind,s.original_url,s.license_name,s.license_url,s.license_scope,s.redistribution_allowed,s.notes
  from public.islamic_content_sources s where s.active order by s.slug;
$$;

create or replace function public.tarteel_public_islamic_categories()
returns table(slug text,name_ar text,name_en text,sort_order integer,item_count bigint)
language sql stable security definer set search_path=public
as $$
  select c.slug,c.name_ar,c.name_en,c.sort_order,
         count(ic.item_id) filter (where i.review_status='approved') as item_count
  from public.islamic_content_categories c
  left join public.islamic_content_item_categories ic on ic.category_slug=c.slug
  left join public.islamic_content_items i on i.id=ic.item_id
  group by c.slug,c.name_ar,c.name_en,c.sort_order
  order by c.sort_order,c.slug;
$$;

create or replace function public.tarteel_public_islamic_content(
  p_category text default null,
  p_search text default null,
  p_source text default null,
  p_limit integer default 50,
  p_offset integer default 0,
  p_id uuid default null
)
returns table(
  id uuid,
  source_slug text,
  source_title text,
  source_key text,
  title_ar text,
  text_ar text,
  categories text[],
  category_names_ar text[],
  reference text,
  repeat_count integer,
  audio jsonb,
  license_name text,
  license_url text,
  original_source_url text,
  review_status text,
  sha256 text,
  source_file_sha256 text,
  source_revision text,
  metadata jsonb,
  updated_at timestamptz
)
language sql stable security definer set search_path=public
as $$
  select i.id,i.source_slug,s.title,i.source_key,i.title_ar,i.text_ar,
         coalesce(array_agg(c.slug order by c.sort_order) filter (where c.slug is not null),array[]::text[]) as categories,
         coalesce(array_agg(c.name_ar order by c.sort_order) filter (where c.slug is not null),array[]::text[]) as category_names_ar,
         i.reference,i.repeat_count,
         case when a.id is null then null else jsonb_build_object(
           'id',a.id,'slug',a.slug,'kind',a.kind,'title_ar',a.title_ar,'voice_name',a.voice_name,
           'storage_bucket',a.storage_bucket,'storage_path',a.storage_path,'mime_type',a.mime_type,
           'byte_size',a.byte_size,'duration_ms',a.duration_ms,'sha256',a.sha256,
           'license_name',a.license_name,'license_url',a.license_url,'original_source_url',a.original_source_url
         ) end as audio,
         i.license_name,i.license_url,i.original_source_url,i.review_status,i.sha256,i.source_file_sha256,i.source_revision,i.metadata,i.updated_at
  from public.islamic_content_items i
  join public.islamic_content_sources s on s.slug=i.source_slug
  left join public.islamic_audio_assets a on a.id=i.audio_asset_id and a.review_status='approved' and a.redistribution_allowed
  left join public.islamic_content_item_categories ic on ic.item_id=i.id
  left join public.islamic_content_categories c on c.slug=ic.category_slug
  where i.review_status='approved'
    and (p_id is null or i.id=p_id)
    and (p_source is null or i.source_slug=p_source)
    and (p_category is null or exists(select 1 from public.islamic_content_item_categories x where x.item_id=i.id and x.category_slug=p_category))
    and (p_search is null or btrim(p_search)='' or i.title_ar ilike '%'||btrim(p_search)||'%' or i.text_ar ilike '%'||btrim(p_search)||'%' or coalesce(i.reference,'') ilike '%'||btrim(p_search)||'%')
  group by i.id,s.title,a.id
  order by i.updated_at desc,i.id
  limit greatest(1,least(coalesce(p_limit,50),200))
  offset greatest(coalesce(p_offset,0),0);
$$;

create or replace function public.tarteel_public_islamic_audio(
  p_kind text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table(id uuid,slug text,kind text,title_ar text,voice_name text,source_slug text,original_source_url text,storage_bucket text,storage_path text,mime_type text,byte_size bigint,duration_ms integer,sha256 text,license_name text,license_url text,metadata jsonb,updated_at timestamptz)
language sql stable security definer set search_path=public
as $$
  select a.id,a.slug,a.kind,a.title_ar,a.voice_name,a.source_slug,a.original_source_url,a.storage_bucket,a.storage_path,a.mime_type,a.byte_size,a.duration_ms,a.sha256,a.license_name,a.license_url,a.metadata,a.updated_at
  from public.islamic_audio_assets a
  where a.review_status='approved' and a.redistribution_allowed and (p_kind is null or a.kind=p_kind)
  order by case a.kind when 'adhan' then 1 when 'iqamah' then 2 else 9 end,a.title_ar,a.id
  limit greatest(1,least(coalesce(p_limit,50),100)) offset greatest(coalesce(p_offset,0),0);
$$;

create or replace function public.tarteel_public_islamic_schedules()
returns table(id uuid,slug text,title_ar text,category_slug text,trigger_kind text,fixed_local_time time,prayer text,offset_minutes integer,audio_asset_id uuid,default_enabled boolean,metadata jsonb)
language sql stable security definer set search_path=public
as $$
  select t.id,t.slug,t.title_ar,t.category_slug,t.trigger_kind,t.fixed_local_time,t.prayer,t.offset_minutes,t.audio_asset_id,t.default_enabled,t.metadata
  from public.islamic_schedule_templates t where t.review_status='approved' order by t.category_slug,t.slug;
$$;

grant execute on function public.tarteel_public_islamic_sources() to anon,authenticated,service_role;
grant execute on function public.tarteel_public_islamic_categories() to anon,authenticated,service_role;
grant execute on function public.tarteel_public_islamic_content(text,text,text,integer,integer,uuid) to anon,authenticated,service_role;
grant execute on function public.tarteel_public_islamic_audio(text,integer,integer) to anon,authenticated,service_role;
grant execute on function public.tarteel_public_islamic_schedules() to anon,authenticated,service_role;

insert into public.islamic_schedule_templates(slug,title_ar,category_slug,trigger_kind,fixed_local_time,prayer,offset_minutes,default_enabled,metadata)
values
  ('morning_adhkar_before_sunrise','تذكير أذكار الصباح قبل الشروق','adhkar_morning','sunrise_relative',null,null,-30,false,'{"user_configurable":true}'::jsonb),
  ('evening_adhkar_after_maghrib','تذكير أذكار المساء بعد المغرب','adhkar_evening','prayer_relative',null,'maghrib',15,false,'{"user_configurable":true}'::jsonb),
  ('sleep_adhkar_nightly','تذكير أذكار النوم','adhkar_sleep','fixed_local_time','22:00',null,0,false,'{"user_configurable":true}'::jsonb),
  ('after_fajr_adhkar','تذكير أذكار ما بعد صلاة الفجر','adhkar_prayer','prayer_relative',null,'fajr',5,false,'{"user_configurable":true}'::jsonb)
on conflict (slug) do update set
  title_ar=excluded.title_ar,category_slug=excluded.category_slug,trigger_kind=excluded.trigger_kind,
  fixed_local_time=excluded.fixed_local_time,prayer=excluded.prayer,offset_minutes=excluded.offset_minutes,
  default_enabled=excluded.default_enabled,metadata=excluded.metadata,updated_at=now();
