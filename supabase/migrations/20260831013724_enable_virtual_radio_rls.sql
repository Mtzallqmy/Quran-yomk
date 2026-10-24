alter table app.virtual_radio_channels enable row level security;
alter table app.virtual_radio_schedule enable row level security;
alter table app.virtual_radio_candidates enable row level security;

revoke all on app.virtual_radio_channels from anon;
revoke all on app.virtual_radio_schedule from anon;
revoke all on app.virtual_radio_candidates from anon;

revoke insert,update,delete on app.virtual_radio_channels from authenticated;
revoke insert,update,delete on app.virtual_radio_schedule from authenticated;
revoke insert,update,delete on app.virtual_radio_candidates from authenticated;

grant select,insert,update,delete on app.virtual_radio_channels to authenticated;
grant select,insert,update,delete on app.virtual_radio_schedule to authenticated;
grant select,insert,update,delete on app.virtual_radio_candidates to authenticated;

-- Policies created in smart_virtual_radio_candidates_rls now become authoritative.
-- Anonymous listeners use only the public SECURITY DEFINER resolver RPC.
