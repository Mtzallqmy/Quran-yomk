alter table app.categories
  add column if not exists is_system boolean not null default false;

update app.categories
set is_system = true
where slug in ('quran','recitations','tafsir','adhkar','lectures','nasheeds','radio','external-radio');

create or replace function app.protect_system_category()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if old.is_system and (
    new.slug is distinct from old.slug
    or new.deleted_at is distinct from old.deleted_at
  ) then
    raise exception 'system category identifier cannot be changed or archived'
      using errcode = '42501';
  end if;
  return new;
end
$$;

drop trigger if exists protect_system_category on app.categories;
create trigger protect_system_category
before update on app.categories
for each row execute function app.protect_system_category();

revoke all on function app.protect_system_category() from public, anon, authenticated;
grant execute on function app.protect_system_category() to service_role;

insert into app.app_config (key,value,value_type,is_public,description) values
  ('app_name_ar', to_jsonb('ترتيل'::text), 'STRING', true, 'Approved Arabic product name'),
  ('app_name_en', to_jsonb('Tarteel'::text), 'STRING', true, 'Approved English product name'),
  ('technical_identifier', to_jsonb('tarteel'::text), 'STRING', true, 'Approved technical identifier'),
  ('owner_developer_ar', to_jsonb('معتز العلقمي'::text), 'STRING', true, 'Approved owner and developer'),
  ('developer_location_ar', to_jsonb('تعز، اليمن'::text), 'STRING', true, 'Approved Arabic developer location'),
  ('developer_location_en', to_jsonb('Taiz, Yemen'::text), 'STRING', true, 'Approved English developer location'),
  ('copyright_holder', to_jsonb('معتز العلقمي'::text), 'STRING', true, 'Approved copyright holder'),
  ('contact_email', 'null'::jsonb, 'JSON', true, 'Not supplied; remains null'),
  ('website_url', 'null'::jsonb, 'JSON', true, 'Not supplied; remains null')
on conflict (key) do update set
  value=excluded.value,value_type=excluded.value_type,is_public=excluded.is_public,
  description=excluded.description,updated_at=now();

update app.app_config
set value='null'::jsonb,value_type='JSON',
    description=case key
      when 'support_url' then 'Not supplied; remains null'
      when 'privacy_url' then 'Not supplied; remains null'
      when 'terms_url' then 'Not supplied; remains null'
    end,
    updated_at=now()
where key in ('support_url','privacy_url','terms_url');

insert into app.audit_logs(action,resource_type,resource_id,new_values,metadata)
values (
  'PRODUCT_IDENTITY_FOUNDATION_APPLIED','app_config','product_identity',
  jsonb_build_object(
    'app_name_ar','ترتيل','app_name_en','Tarteel','technical_identifier','tarteel',
    'owner_developer_ar','معتز العلقمي','developer_location_ar','تعز، اليمن',
    'developer_location_en','Taiz, Yemen'
  ),
  jsonb_build_object('phase','7+8','legal_urls','null')
);
