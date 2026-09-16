import 'package:flutter/material.dart';
import '../../../core/config/brand_config.dart';
import '../../../core/widgets/brand_mark.dart';

class AboutAndSourcesScreen extends StatelessWidget {
  const AboutAndSourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المصادر وعن التطبيق'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: const [
                QuranYutlaBrandMark(size: 72),
                SizedBox(height: 14),
                Text(
                  BrandConfig.nameAr,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF243B6B)),
                ),
                SizedBox(height: 4),
                Text(
                  BrandConfig.taglineAr,
                  style: TextStyle(color: Color(0xFF5B677A), fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const Text('المصادر المعتمدة والتراخيص', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildSourceCard(
            'النص القرآني والرسم العثماني',
            'مجمع الملك فهد لطباعة المصحف الشريف بالمدينة المنورة برواية حفص عن عاصم، تم التحقق الرقمي ومطابقة الهاش (SHA-256).',
            Icons.verified,
          ),
          _buildSourceCard(
            'التسجيلات الصوتية والتلاوات',
            'أرشيف إذاعة القرآن الكريم ومجمع الملك فهد، معتمدة وموحدة الصوتيات وفق معيار EBU R128 (-16 LUFS).',
            Icons.audiotrack,
          ),
          _buildSourceCard(
            'محرك البث الإذاعي المدار',
            'خوادم Icecast 2 و Liquidsoap المدارة ذاتياً عبر بنية قرآن يتلى السحابية دون انقطاع.',
            Icons.radio,
          ),
          _buildSourceCard(
            'مواقيت الصلاة والأذان',
            'حساب محلي دقيق مبني على خوارزمية مكتبة Adhan دون إرسال بيانات الموقع لأي خادم خارجي (خصوصية كاملة).',
            Icons.location_on_outlined,
          ),
          const SizedBox(height: 24),
          const Text('سياسة الخصوصية والاستقلالية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'تطبيق «قرآن يتلى» مستقل بالكامل وخالٍ من أي إعلانات أو متتبعات تجارية. البيانات الخاصة بالقراءة، التنزيلات، وقوائم التشغيل محفوظة محلياً على جهاز المستخدم.',
            style: TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF5B677A)),
          ),
        ],
      ),
    );
  }

  static Widget _buildSourceCard(String title, String desc, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF2E9E9E), size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(desc, style: const TextStyle(color: Color(0xFF5B677A), fontSize: 12, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
