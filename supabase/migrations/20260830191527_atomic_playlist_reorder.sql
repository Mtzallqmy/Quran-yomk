-- Phase 7: make playlist reordering all-or-nothing and reject partial lists.
alter table app.playlist_items
  drop constraint playlist_items_playlist_id_position_key;

alter table app.playlist_items
  add constraint playlist_items_playlist_id_position_key
  unique (playlist_id, position) deferrable initially deferred;

create or replace function app.reorder_playlist_items(
  p_playlist_id uuid,
  p_item_ids uuid[]
) returns void
language plpgsql
security invoker
set search_path = pg_catalog, app
as $$
declare
  v_expected integer;
  v_received integer;
begin
  if p_item_ids is null then
    raise exception 'item_ids is required' using errcode = '22023';
  end if;

  select count(*) into v_expected
  from app.playlist_items
  where playlist_id = p_playlist_id;

  select count(distinct item_id) into v_received
  from unnest(p_item_ids) as item_id;

  if v_received <> cardinality(p_item_ids) or v_received <> v_expected then
    raise exception 'item_ids must contain every playlist item exactly once' using errcode = '22023';
  end if;

  if exists (
    select 1 from unnest(p_item_ids) as item_id
    where not exists (
      select 1 from app.playlist_items pi
      where pi.id = item_id and pi.playlist_id = p_playlist_id
    )
  ) then
    raise exception 'item does not belong to playlist' using errcode = '22023';
  end if;

  update app.playlist_items pi
  set position = ordered.ordinality - 1
  from unnest(p_item_ids) with ordinality as ordered(item_id, ordinality)
  where pi.id = ordered.item_id and pi.playlist_id = p_playlist_id;
end;
$$;

revoke all on function app.reorder_playlist_items(uuid, uuid[]) from public, anon, authenticated;
grant execute on function app.reorder_playlist_items(uuid, uuid[]) to service_role;
