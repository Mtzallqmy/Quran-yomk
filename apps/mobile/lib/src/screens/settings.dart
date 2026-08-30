import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common.dart';
import '../models.dart';
import '../services.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});
  @override Widget build(BuildContext context,WidgetRef ref){
    final services=ref.watch(servicesProvider);final settings=services.settings;
    return AnimatedBuilder(animation:settings,builder:(context,_)=>Scaffold(
      appBar:AppBar(title:const Text('الإعدادات')),
      body:ListView(children:<Widget>[
        const SectionHeader('المظهر'),
        RadioGroup<ThemeMode>(groupValue:settings.themeMode,onChanged:(value){if(value!=null)settings.setThemeMode(value);},child:const Column(children:<Widget>[
          RadioListTile(value:ThemeMode.system,title:Text('حسب النظام')),RadioListTile(value:ThemeMode.light,title:Text('فاتح')),RadioListTile(value:ThemeMode.dark,title:Text('داكن')),
        ])),
        const SectionHeader('اللغة'),
        ListTile(leading:const Icon(Icons.language),title:const Text('اللغة'),trailing:DropdownButton<String>(
          value:settings.locale.languageCode,items:const <DropdownMenuItem<String>>[DropdownMenuItem(value:'ar',child:Text('العربية')),DropdownMenuItem(value:'en',child:Text('English'))],
          onChanged:(value){if(value!=null)settings.setLocale(Locale(value));},
        )),
        const SectionHeader('التشغيل'),
        ListTile(leading:const Icon(Icons.speed),title:const Text('سرعة التلاوة الافتراضية'),subtitle:const Text('تُطبق على التلاوات عند الطلب فقط، ولا تُطبق على البث المباشر.'),trailing:DropdownButton<double>(
          value:settings.playbackSpeed,items:const <DropdownMenuItem<double>>[DropdownMenuItem(value:0.75,child:Text('0.75×')),DropdownMenuItem(value:1.0,child:Text('1×')),DropdownMenuItem(value:1.25,child:Text('1.25×')),DropdownMenuItem(value:1.5,child:Text('1.5×')),DropdownMenuItem(value:2.0,child:Text('2×'))],
          onChanged:(value){if(value!=null)settings.setPlaybackSpeed(value);},
        )),
        ListTile(leading:const Icon(Icons.bedtime_outlined),title:const Text('إلغاء مؤقت النوم'),onTap:services.playback.cancelSleepTimer),
        const SectionHeader('حول التطبيق'),
        const ListTile(title:Text('ترتيل — Tarteel'),subtitle:Text('الإصدار 0.1.0 (1)\nالمطور: معتز العلقمي\nتعز، اليمن')),
        const SectionHeader('مصادر المحتوى'),
        const Padding(padding:EdgeInsets.symmetric(horizontal:16,vertical:8),child:Text(
          'يتيح ترتيل الوصول إلى بعض الإذاعات والمصادر الصوتية الخارجية من خلال خدمات ومصادر البث الخاصة بمقدميها. تبقى حقوق المحتوى والعلامات الخاصة بكل مصدر لأصحابها. عند تشغيل بث خارجي يتصل جهازك مباشرة ببنية مقدم البث، ولا يتحكم ترتيل في تلك البنية التحتية.\n\nTarteel provides access to some external radio and audio sources through services operated by their respective providers. Content and trademark rights remain with their owners. Playing an external stream may connect your device directly to the provider infrastructure, which Tarteel does not control.',
        )),
        FutureBuilder<List<ContentSource>>(future:services.repository.api.contentSources(),builder:(context,snapshot){
          if(snapshot.connectionState!=ConnectionState.done&&!snapshot.hasData)return const Padding(padding:EdgeInsets.all(16),child:LinearProgressIndicator());
          if(snapshot.hasError)return const ListTile(leading:Icon(Icons.error_outline),title:Text('تعذر تحميل مصادر المحتوى'),subtitle:Text('يمكن إعادة المحاولة عند توفر الاتصال.'));
          final sources=snapshot.data??const <ContentSource>[];
          return Column(children:sources.map((source)=>ExpansionTile(
            leading:const Icon(Icons.source_outlined),title:Text(source.providerName),subtitle:Text(source.attribution??source.provider),
            children:<Widget>[
              ListTile(title:const Text('أساس التكامل'),subtitle:Text(source.integrationBasis)),
              if(source.licenseType!=null)ListTile(title:const Text('نوع الإذن/الترخيص'),subtitle:Text(source.licenseType!)),
              if(source.commercialUseStatus!=null)ListTile(title:const Text('الاستخدام التجاري'),subtitle:Text(source.commercialUseStatus!)),
              if(source.redistributionMode!=null)ListTile(title:const Text('طريقة التوزيع'),subtitle:Text(source.redistributionMode!)),
              if(source.providerUrl!=null)ListTile(title:const Text('المصدر'),subtitle:Text(source.providerUrl!)),
              if(source.termsUrl!=null)ListTile(title:const Text('الشروط/المرجع'),subtitle:Text(source.termsUrl!)),
            ],
          )).toList(growable:false));
        }),
        FutureBuilder<JsonMap>(future:services.repository.appConfig(),builder:(context,snapshot){final config=snapshot.data??const <String,dynamic>{};return Column(children:<Widget>[
          _LegalTile(title:'سياسة الخصوصية',value:config['privacy_url']),_LegalTile(title:'الشروط',value:config['terms_url']),_LegalTile(title:'الدعم',value:config['support_url']),
        ]);}),
        const Padding(padding:EdgeInsets.all(16),child:Text('الشعار والأيقونة والألوان الحالية قابلة للاستبدال حتى اعتماد الأصول النهائية من المالك.',textAlign:TextAlign.center)),
      ]),
    ));
  }
}

class _LegalTile extends StatelessWidget {
  const _LegalTile({required this.title,required this.value});final String title;final dynamic value;
  @override Widget build(BuildContext context){final url=value is String&&(value as String).isNotEmpty?value as String:null;return ListTile(leading:const Icon(Icons.description_outlined),title:Text(title),subtitle:Text(url??'غير متوفر حاليًا — TBD'),enabled:false);}
}
