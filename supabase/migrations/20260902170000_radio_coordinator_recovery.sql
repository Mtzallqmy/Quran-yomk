-- Combined Radio Engine coordinator recovery hardening.
-- This is a forward-only migration. Historical migrations remain immutable.

create or replace function radio.record_command_effect(
  p_command_id uuid,
  p_station_id uuid,
  p_owner_id text,
  p_fencing_token bigint,
  p_effect_type text,
  p_payload_hash text,
  p_status text default 'PREPARED',
  p_result jsonb default '{}'::jsonb
) returns uuid
language plpgsql
set search_path to ''
as $$
declare v_id uuid;
begin
  perform radio.assert_station_lease(p_station_id,p_owner_id,p_fencing_token);
  if p_effect_type not in ('ENQUEUE','SKIP','STOP_AFTER_CURRENT','RESUME_AUTO')
     or p_status not in ('PREPARED','DISPATCHED','ACKED','FAILED') then
    raise exception 'invalid command effect' using errcode='22023';
  end if;
  if not exists(
    select 1 from radio.radio_commands c
    where c.id=p_command_id and c.station_id=p_station_id
      and c.status='PROCESSING' and c.claimed_by=p_owner_id
      and c.processing_fencing_token=p_fencing_token
  ) then
    raise exception 'command claim lost' using errcode='55000';
  end if;

  insert into radio.command_effects(
    command_id,station_id,effect_type,status,payload_hash,fencing_token,
    dispatched_at,acknowledged_at,result
  ) values(
    p_command_id,p_station_id,p_effect_type,p_status,p_payload_hash,p_fencing_token,
    case when p_status in ('DISPATCHED','ACKED') then clock_timestamp() end,
    case when p_status='ACKED' then clock_timestamp() end,
    coalesce(p_result,'{}')
  )
  on conflict(command_id) do update set
    status=case when radio.command_effects.status='ACKED' then 'ACKED' else excluded.status end,
    fencing_token=case when radio.command_effects.status='ACKED' then radio.command_effects.fencing_token else excluded.fencing_token end,
    dispatched_at=coalesce(radio.command_effects.dispatched_at,excluded.dispatched_at),
    acknowledged_at=coalesce(radio.command_effects.acknowledged_at,excluded.acknowledged_at),
    result=radio.command_effects.result||excluded.result
  where radio.command_effects.payload_hash=excluded.payload_hash
    and radio.command_effects.effect_type=excluded.effect_type
  returning id into v_id;

  if v_id is null then
    raise exception 'command effect mismatch' using errcode='22000';
  end if;
  return v_id;
end $$;

create or replace function radio.recover_stale_automation(
  p_station_id uuid,
  p_owner_id text,
  p_fencing_token bigint
) returns jsonb
language plpgsql
set search_path to ''
as $$
declare
  v_occurrences integer:=0;
  v_commands integer:=0;
  v_completed_commands integer:=0;
  v_failed_commands integer:=0;
  v_queue integer:=0;
begin
  perform radio.assert_station_lease(p_station_id,p_owner_id,p_fencing_token);

  update radio.schedule_occurrences o
  set status='PENDING',claimed_by=null,claimed_at=null,claimed_fencing_token=null,
      result=o.result||jsonb_build_object('recovered_by_token',p_fencing_token)
  where o.station_id=p_station_id and o.status='CLAIMED'
    and coalesce(o.claimed_fencing_token,0)<p_fencing_token
    and not exists(select 1 from radio.queue_entries q where q.occurrence_id=o.id);
  get diagnostics v_occurrences=row_count;

  -- A playout row is the durable ACK. If a process died after recording the
  -- playout but before updating command_effects, promote the effect to ACKED.
  update radio.command_effects e
  set status='ACKED',acknowledged_at=coalesce(e.acknowledged_at,clock_timestamp()),
      result=e.result||jsonb_build_object('recovered_ack',true)
  from radio.radio_commands c
  where c.id=e.command_id and c.station_id=p_station_id and c.status='PROCESSING'
    and coalesce(c.processing_fencing_token,0)<p_fencing_token
    and e.status in ('PREPARED','DISPATCHED')
    and exists(select 1 from radio.play_history h where h.command_id=c.id and h.started_at is not null);

  update radio.radio_commands c
  set status='COMPLETED',executed_at=coalesce(c.executed_at,clock_timestamp()),
      result=c.result||jsonb_build_object('recovered_by_token',p_fencing_token,'effect_ack_recovered',true)
  where c.station_id=p_station_id and c.status='PROCESSING'
    and coalesce(c.processing_fencing_token,0)<p_fencing_token
    and exists(select 1 from radio.command_effects e where e.command_id=c.id and e.status='ACKED');
  get diagnostics v_completed_commands=row_count;

  update radio.radio_commands c
  set status='FAILED',executed_at=coalesce(c.executed_at,clock_timestamp()),
      error_code=coalesce(c.error_code,'RECOVERED_FAILED_EFFECT'),
      error_message=coalesce(c.error_message,'Previous engine recorded a failed command effect')
  where c.station_id=p_station_id and c.status='PROCESSING'
    and coalesce(c.processing_fencing_token,0)<p_fencing_token
    and exists(select 1 from radio.command_effects e where e.command_id=c.id and e.status='FAILED');
  get diagnostics v_failed_commands=row_count;

  -- PREPARED/DISPATCHED without a durable playout ACK may be retried. Queue
  -- insertion is idempotent by (station_id,idempotency_key), so replay cannot
  -- create a second logical queue item.
  update radio.radio_commands c
  set status='PENDING',claimed_by=null,claimed_at=null,processing_fencing_token=null
  where c.station_id=p_station_id and c.status='PROCESSING'
    and coalesce(c.processing_fencing_token,0)<p_fencing_token
    and not exists(select 1 from radio.play_history h where h.command_id=c.id and h.started_at is not null)
    and not exists(select 1 from radio.command_effects e where e.command_id=c.id and e.status in ('ACKED','FAILED'));
  get diagnostics v_commands=row_count;

  update radio.queue_entries q
  set status='PENDING',claimed_by=null,claimed_at=null,claimed_fencing_token=null,dispatched_at=null
  where q.station_id=p_station_id and q.status='DISPATCHED'
    and coalesce(q.claimed_fencing_token,0)<p_fencing_token;
  get diagnostics v_queue=row_count;

  return jsonb_build_object(
    'occurrences',v_occurrences,
    'commands_requeued',v_commands,
    'commands_completed',v_completed_commands,
    'commands_failed',v_failed_commands,
    'queue_entries',v_queue
  );
end $$;
