delete from app.virtual_radio_candidates vc
using app.virtual_radio_schedule s, app.stations st, app.virtual_radio_channels ch
where vc.schedule_id=s.id
  and vc.station_id=st.id
  and s.channel_id=ch.id
  and ch.slug='tarteel'
  and s.category_id is not null
  and st.category_id is distinct from s.category_id;
