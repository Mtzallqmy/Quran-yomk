-- Cache the caller identity once per statement instead of evaluating
-- auth.uid() for every candidate row. Authorization semantics are unchanged.
alter policy virtual_radio_channels_admin_select
  on app.virtual_radio_channels
  using (app.managed_radio_authorized((select auth.uid()), 'schedules.read'));
alter policy virtual_radio_channels_admin_insert
  on app.virtual_radio_channels
  with check (app.managed_radio_authorized((select auth.uid()), 'schedules.write'));
alter policy virtual_radio_channels_admin_update
  on app.virtual_radio_channels
  using (app.managed_radio_authorized((select auth.uid()), 'schedules.write'))
  with check (app.managed_radio_authorized((select auth.uid()), 'schedules.write'));
alter policy virtual_radio_channels_admin_delete
  on app.virtual_radio_channels
  using (app.managed_radio_authorized((select auth.uid()), 'schedules.write'));

alter policy virtual_radio_schedule_admin_select
  on app.virtual_radio_schedule
  using (app.managed_radio_authorized((select auth.uid()), 'schedules.read'));
alter policy virtual_radio_schedule_admin_insert
  on app.virtual_radio_schedule
  with check (app.managed_radio_authorized((select auth.uid()), 'schedules.write'));
alter policy virtual_radio_schedule_admin_update
  on app.virtual_radio_schedule
  using (app.managed_radio_authorized((select auth.uid()), 'schedules.write'))
  with check (app.managed_radio_authorized((select auth.uid()), 'schedules.write'));
alter policy virtual_radio_schedule_admin_delete
  on app.virtual_radio_schedule
  using (app.managed_radio_authorized((select auth.uid()), 'schedules.write'));

alter policy virtual_radio_candidates_admin_select
  on app.virtual_radio_candidates
  using (app.managed_radio_authorized((select auth.uid()), 'schedules.read'));
alter policy virtual_radio_candidates_admin_insert
  on app.virtual_radio_candidates
  with check (app.managed_radio_authorized((select auth.uid()), 'schedules.write'));
alter policy virtual_radio_candidates_admin_update
  on app.virtual_radio_candidates
  using (app.managed_radio_authorized((select auth.uid()), 'schedules.write'))
  with check (app.managed_radio_authorized((select auth.uid()), 'schedules.write'));
alter policy virtual_radio_candidates_admin_delete
  on app.virtual_radio_candidates
  using (app.managed_radio_authorized((select auth.uid()), 'schedules.write'));
