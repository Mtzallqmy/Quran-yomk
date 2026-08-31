// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'ترتيل';

  @override
  String get home => 'الرئيسية';

  @override
  String get radio => 'الإذاعة';

  @override
  String get reciters => 'القراء';

  @override
  String get mushaf => 'المصحف';

  @override
  String get library => 'المكتبة';

  @override
  String get favorites => 'المفضلة';

  @override
  String get settings => 'الإعدادات';

  @override
  String get search => 'بحث';

  @override
  String get live => 'مباشر';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get loading => 'جارٍ التحميل…';

  @override
  String get noData => 'لا يوجد محتوى متاح';

  @override
  String get offlineMessage =>
      'تعذر الوصول إلى الخدمة. قد يظهر المحتوى المحفوظ.';

  @override
  String get about => 'حول التطبيق';

  @override
  String get aboutTarteel => 'حول ترتيل';

  @override
  String get privacyPolicy => 'سياسة الخصوصية';

  @override
  String get terms => 'الشروط';

  @override
  String get support => 'الدعم';

  @override
  String get notAvailable => 'غير متوفر حاليًا';

  @override
  String get featuredTarteel => 'مختارات ترتيل';

  @override
  String get quranRadios => 'إذاعات القرآن';

  @override
  String get noRadiosAvailable => 'لا توجد إذاعات متاحة حاليًا.';

  @override
  String get noRecitersIndexed => 'لا توجد تلاوات قارئ مفهرسة حاليًا.';

  @override
  String get categories => 'التصنيفات';

  @override
  String get favorite => 'المفضلة';

  @override
  String get play => 'تشغيل';

  @override
  String get pause => 'إيقاف مؤقت';

  @override
  String get stop => 'إيقاف';

  @override
  String unablePlayStation(String station) {
    return 'تعذر تشغيل $station.';
  }

  @override
  String get appearance => 'المظهر';

  @override
  String get followSystem => 'حسب النظام';

  @override
  String get light => 'فاتح';

  @override
  String get dark => 'داكن';

  @override
  String get language => 'اللغة';

  @override
  String get arabic => 'العربية';

  @override
  String get english => 'English';

  @override
  String get playback => 'التشغيل';

  @override
  String get defaultRecitationSpeed => 'سرعة التلاوة الافتراضية';

  @override
  String get defaultRecitationSpeedHelp =>
      'تُطبق على التلاوات عند الطلب فقط، ولا تُطبق على البث المباشر.';

  @override
  String get cancelSleepTimer => 'إلغاء مؤقت النوم';

  @override
  String get savedClips => 'المحفوظات';

  @override
  String get savedClipsSubtitle => 'تشغيل المقاطع المحفوظة محليًا بدون إنترنت';

  @override
  String get aboutSection => 'حول التطبيق';

  @override
  String get aboutSubtitle => 'معلومات التطبيق ومصادر المحتوى وحقوق النشر';

  @override
  String get contentSourcesCopyright => 'مصادر المحتوى وحقوق النشر';

  @override
  String get contentSourcesSubtitle =>
      'المصادر الخارجية، نسب المحتوى، والشروط المرتبطة بها';

  @override
  String versionLabel(String version) {
    return 'الإصدار $version';
  }

  @override
  String get appRights => 'حقوق التطبيق';

  @override
  String get appRightsLine1 => 'ترتيل — Tarteel';

  @override
  String get appRightsLine2 => 'تطوير وملكية: معتز العلقمي';

  @override
  String get appRightsLine3 => 'تعز، اليمن';

  @override
  String get appRightsLine4 => '© 2026 معتز العلقمي. جميع حقوق التطبيق محفوظة.';

  @override
  String get thirdPartyRights => 'مصادر المحتوى وحقوق الجهات الخارجية';

  @override
  String get thirdPartyOwnershipNotice =>
      'ترتيل لا يدّعي ملكية الإذاعات أو التلاوات أو العلامات الخاصة بالمصادر الخارجية. عند تشغيل محطة خارجية قد يتصل جهازك مباشرةً ببنية مقدم البث.';

  @override
  String get savedClipsUnsupported =>
      'الحفظ بدون إنترنت غير متاح على هذه المنصة.';

  @override
  String get noSavedClips => 'لا توجد مقاطع محفوظة بعد';

  @override
  String get savingClip => 'جارٍ حفظ مقطع…';

  @override
  String get stopSaving => 'إيقاف الحفظ';

  @override
  String get delete => 'حذف';

  @override
  String get deleteClipQuestion => 'حذف المقطع؟';

  @override
  String get cancel => 'إلغاء';

  @override
  String get savedPartially => 'محفوظ جزئيًا';

  @override
  String get fileMissing => 'ملف المقطع غير موجود.';

  @override
  String get unablePlaySavedClip => 'تعذر تشغيل المقطع المحفوظ.';

  @override
  String get sleepTimer => 'مؤقت النوم';

  @override
  String get minutes10 => '10 دقائق';

  @override
  String get minutes20 => '20 دقيقة';

  @override
  String get minutes30 => '30 دقيقة';

  @override
  String get minutes45 => '45 دقيقة';

  @override
  String get minutes60 => '60 دقيقة';

  @override
  String get endOfCurrentRecitation => 'نهاية التلاوة الحالية';

  @override
  String get timerCancelled => 'تم إلغاء مؤقت النوم';

  @override
  String stopsAfter(String time) {
    return 'يتوقف بعد $time';
  }

  @override
  String get player => 'المشغل';

  @override
  String get noCurrentPlayback => 'لا يوجد تشغيل حالي';

  @override
  String get previous => 'السابق';

  @override
  String get next => 'التالي';

  @override
  String get stopLive => 'إيقاف البث';

  @override
  String get volume => 'مستوى الصوت';

  @override
  String get repeatSurah => 'تكرار السورة';

  @override
  String get liveTranscription => 'التفريغ المباشر';

  @override
  String get transcriptionUnavailable =>
      'التفريغ المباشر غير متاح في هذا الإصدار';

  @override
  String get browseBySection => 'تصفح حسب القسم';

  @override
  String quranSurahsCount(int count) {
    return 'سور القرآن — $count سورة';
  }

  @override
  String ayahCount(int count) {
    return '$count آية';
  }

  @override
  String get mushafTitle => 'القرآن الكريم';

  @override
  String get browseBySurah => 'بالسورة';

  @override
  String get browseByJuz => 'بالجزء';

  @override
  String get browseByPage => 'بالصفحة';

  @override
  String get surah => 'السورة';

  @override
  String get juz => 'الجزء';

  @override
  String get page => 'الصفحة';

  @override
  String pageOf604(int page) {
    return 'الصفحة $page من 604';
  }

  @override
  String get selectSurah => 'اختر السورة';

  @override
  String get selectJuz => 'اختر الجزء';

  @override
  String get selectPage => 'اختر الصفحة';

  @override
  String get lastReadingPosition => 'آخر موضع قراءة';

  @override
  String get continueReading => 'متابعة القراءة';

  @override
  String get bookmark => 'حفظ علامة';

  @override
  String get removeBookmark => 'إزالة العلامة';

  @override
  String get bookmarked => 'محفوظة';

  @override
  String get fontSize => 'حجم النص';

  @override
  String get tajweedColors => 'ألوان التجويد';

  @override
  String get thematicSections => 'التقسيم الموضوعي';

  @override
  String get thematicRukuNote =>
      'طبقة التقسيم تعتمد حدود الركوع الموثقة من مصدر القرآن ولا تغيّر نص القرآن.';

  @override
  String get chooseReciter => 'اختيار القارئ';

  @override
  String get playSurah => 'تشغيل السورة';

  @override
  String get noAudioForSurah => 'لا تتوفر تلاوة لهذه السورة بالقارئ المحدد.';

  @override
  String get quranLoading => 'جارٍ تحميل نص القرآن…';

  @override
  String get quranLoadError => 'تعذر تحميل نص القرآن.';

  @override
  String get quranSource => 'مصدر نص القرآن';

  @override
  String get quranSourceFallback =>
      'يُستخدم Quran Foundation عند تهيئته، وAl Quran Cloud كبديل تطوير موثوق.';

  @override
  String rukuLabel(int number) {
    return 'الركوع $number';
  }

  @override
  String ayahNumber(int number) {
    return 'الآية $number';
  }

  @override
  String get previousPage => 'الصفحة السابقة';

  @override
  String get nextPage => 'الصفحة التالية';

  @override
  String get previousSurah => 'السورة السابقة';

  @override
  String get nextSurah => 'السورة التالية';

  @override
  String get mushafSettings => 'إعدادات القراءة';

  @override
  String get showTajweed => 'إظهار ألوان التجويد';

  @override
  String get showThemes => 'إظهار التقسيم الموضوعي';

  @override
  String get readerModeSurah => 'سورة';

  @override
  String get readerModeJuz => 'جزء';

  @override
  String get readerModePage => 'صفحة';

  @override
  String get reciterToday => 'القارئ';

  @override
  String get sourceCurrent => 'المصدر الحالي';

  @override
  String get directExternalStream => 'بث خارجي';

  @override
  String get currentProgram => 'البرنامج الحالي';

  @override
  String get nextProgram => 'البرنامج التالي';

  @override
  String get tarteelRadio => 'إذاعة ترتيل';

  @override
  String get tarteelCuratedLive => 'إذاعة ترتيل — بث مختار';

  @override
  String get all => 'الكل';

  @override
  String get showAll => 'عرض الكل';

  @override
  String get searchStationsHint => 'ابحث في الإذاعات';

  @override
  String get noSearchResults => 'لا توجد نتائج';

  @override
  String get unablePlay => 'تعذر تشغيل الصوت.';

  @override
  String get contentSourceUnavailable => 'معلومات المصدر غير متاحة حاليًا.';

  @override
  String get loadingSources => 'جارٍ تحميل مصادر المحتوى…';

  @override
  String get externalSourceDisclaimer =>
      'يتم تقديم بعض الصوت مباشرةً من مزودي خدمات خارجيين، وتبقى الحقوق والعلامات لأصحابها.';

  @override
  String get recordingNotPermitted => 'حفظ المقاطع غير مسموح لهذه المحطة.';

  @override
  String get saveOfflineClip => 'حفظ مقطع للاستماع بدون إنترنت';

  @override
  String get save5Minutes => 'حفظ 5 دقائق';

  @override
  String get save10Minutes => 'حفظ 10 دقائق';

  @override
  String get save30Minutes => 'حفظ 30 دقيقة';

  @override
  String get saveUntilStopped => 'حفظ حتى الإيقاف';

  @override
  String get clipSavingStarted => 'بدأ حفظ المقطع';

  @override
  String get clipSavingStopped => 'تم حفظ المقطع';

  @override
  String get clipSavingFailed => 'تعذر حفظ هذا المقطع.';

  @override
  String get networkRequiredForPlayback =>
      'الاتصال بالإنترنت مطلوب لتشغيل البث المباشر.';

  @override
  String get searchReciters => 'بحث في القراء';

  @override
  String get noReciters => 'لم يتم العثور على قراء';

  @override
  String get reciterDetails => 'القارئ';

  @override
  String get availableSurahs => 'السور المتاحة';

  @override
  String get noTracks => 'لا توجد سور قابلة للتشغيل لهذا القارئ.';

  @override
  String get searchHint => 'ابحث في الإذاعات والقراء والسور والأقسام';

  @override
  String get searchSections => 'الأقسام';

  @override
  String get searchStations => 'المحطات';

  @override
  String get searchSurahs => 'السور';

  @override
  String get searchReciterResults => 'القراء';

  @override
  String get radioGeneralQuran => 'القرآن العام';

  @override
  String get radioReciters => 'القراء';

  @override
  String get radioTafseer => 'التفسير';

  @override
  String get radioHadith => 'الحديث';

  @override
  String get radioSeerah => 'السيرة';

  @override
  String get radioSahabah => 'الصحابة';

  @override
  String get radioAdhkar => 'الأذكار';

  @override
  String get radioRuqyah => 'الرقية';

  @override
  String get radioFatwa => 'الفتاوى';

  @override
  String get radioTranslation => 'ترجمات القرآن';

  @override
  String get radioSurahs => 'سور مختارة';

  @override
  String get radioLiveTv => 'البث المباشر';

  @override
  String get radioOther => 'أخرى';
}
