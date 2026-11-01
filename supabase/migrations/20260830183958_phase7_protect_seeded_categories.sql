update app.categories
set is_system = true
where slug in (
  'QURAN_GENERAL','RECITER','TAFSEER','HADITH','SEERAH','SAHABAH','ADHKAR',
  'RUQYAH','FATWA','QURAN_TRANSLATION','QURAN_SURAH','LIVE_TV_AUDIO','OTHER'
);
