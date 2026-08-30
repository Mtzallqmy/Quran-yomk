import 'package:flutter/widgets.dart';

class TarteelStrings {
  const TarteelStrings(this.english);
  final bool english;
  static TarteelStrings of(BuildContext context) => TarteelStrings(Localizations.localeOf(context).languageCode == 'en');
  String get appName => english ? 'Tarteel' : 'ترتيل';
  String get home => english ? 'Home' : 'الرئيسية';
  String get radio => english ? 'Radio' : 'الإذاعة';
  String get reciters => english ? 'Reciters' : 'القراء';
  String get library => english ? 'Library' : 'المكتبة';
  String get favorites => english ? 'Favorites' : 'المفضلة';
  String get settings => english ? 'Settings' : 'الإعدادات';
  String get search => english ? 'Search' : 'بحث';
  String get live => english ? 'LIVE' : 'مباشر';
  String get retry => english ? 'Retry' : 'إعادة المحاولة';
  String get noData => english ? 'No content available' : 'لا يوجد محتوى متاح';
  String get offline => english ? 'Unable to reach the service. Cached content may be shown.' : 'تعذر الوصول إلى الخدمة. قد يظهر المحتوى المحفوظ.';
  String get about => english ? 'About' : 'حول التطبيق';
  String get privacy => english ? 'Privacy Policy' : 'سياسة الخصوصية';
  String get terms => english ? 'Terms' : 'الشروط';
  String get support => english ? 'Support' : 'الدعم';
}
