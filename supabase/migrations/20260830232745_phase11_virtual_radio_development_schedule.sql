-- Development editorial schedule for the logical Tarteel Radio channel.
-- Uses station/category slugs rather than generated UUIDs.

do $$
declare
  v_channel uuid;
begin
  select id into v_channel from app.virtual_radio_channels where slug='tarteel';
  if v_channel is null then raise exception 'virtual channel tarteel is missing'; end if;

  delete from app.virtual_radio_schedule where channel_id=v_channel;

  insert into app.virtual_radio_schedule(
    channel_id,days_of_week,start_time,end_time,
    program_title_ar,program_title_en,program_subtitle_ar,
    category_id,fallback_category_id,preferred_station_id,
    allow_degraded,enabled,priority
  )
  select v_channel,array[0,1,2,3,4,5,6]::smallint[],x.start_time,x.end_time,
    x.title_ar,x.title_en,x.subtitle_ar,
    c.id,fc.id,s.id,true,true,100
  from (values
    ('00:00'::time,'04:00'::time,'تلاوات هادئة','Quiet Quran Recitations','اختيار مباشر من إذاعات القرآن المتاحة','QURAN_GENERAL','RECITER','qurango-mix'),
    ('04:00'::time,'06:00'::time,'أذكار الصباح','Morning Adhkar','بث مختار للأذكار','ADHKAR','QURAN_GENERAL','qurango-morning-adhkar'),
    ('06:00'::time,'10:00'::time,'قارئ اليوم','Featured Reciter','تلاوات مختارة بصوت قارئ','RECITER','QURAN_GENERAL','qurango-abdulrahman-alsudais'),
    ('10:00'::time,'14:00'::time,'مع التفسير','Tafsir','تفسير وبيان مع مصدر متاح','TAFSEER','QURAN_GENERAL','qurango-tabari-summary'),
    ('14:00'::time,'18:00'::time,'من السنة والحديث','Hadith','مختارات من الحديث والسنة','HADITH','QURAN_GENERAL','qurango-riyad-al-salihin'),
    ('18:00'::time,'00:00'::time,'إذاعات القرآن','Quran Radio','بث قرآني مباشر مختار','QURAN_GENERAL','RECITER','saudi-quran-radio')
  ) as x(start_time,end_time,title_ar,title_en,subtitle_ar,category_slug,fallback_slug,station_slug)
  join app.categories c on c.slug=x.category_slug and c.deleted_at is null
  join app.categories fc on fc.slug=x.fallback_slug and fc.deleted_at is null
  left join app.stations s on s.slug=x.station_slug and s.deleted_at is null;
end $$;
