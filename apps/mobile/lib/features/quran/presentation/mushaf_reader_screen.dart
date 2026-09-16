import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MushafReaderScreen extends StatefulWidget {
  final int initialPage;
  const MushafReaderScreen({super.key, this.initialPage = 293});

  @override
  State<MushafReaderScreen> createState() => _MushafReaderScreenState();
}

class _MushafReaderScreenState extends State<MushafReaderScreen> {
  late int _currentPage;
  bool _isImmersive = false;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
  }

  void _toggleImmersive() {
    setState(() {
      _isImmersive = !_isImmersive;
    });
    if (_isImmersive) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F4), // Premium Quran Pearl/Paper Canvas
      appBar: _isImmersive
          ? null
          : AppBar(
              title: Text('صفحة $_currentPage من 604'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.bookmark_border),
                  tooltip: 'حفظ علامة القراءة',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('تم حفظ الإشارة المرجعية عند الصفحة $_currentPage')),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.fullscreen),
                  tooltip: 'وضع القراءة الغامر',
                  onPressed: _toggleImmersive,
                ),
              ],
            ),
      body: GestureDetector(
        onTap: _toggleImmersive,
        child: Stack(
          children: [
            // Quran Mushaf Page Simulated Container
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 600),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFC77955).withOpacity(0.3), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Header Page / Surah ornament
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF243B6B).withOpacity(0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF243B6B).withOpacity(0.15)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text('الجزء الخامس عشر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            Text('سُورَةُ الكَهْفِ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF243B6B))),
                            Text('الحزب التاسع والعشرون', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Basmalah
                      const Text(
                        'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF243B6B),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Quran Verses text (sample canonical Uthmani)
                      const Text(
                        'الْحَمْدُ لِلَّهِ الَّذِي أَنزَلَ عَلَىٰ عَبْدِهِ الْكِتَابَ وَلَمْ يَجْعَل لَّهُ عِوَجًا ﴿١﴾ قَيِّمًا لِّيُنذِرَ بَأْسًا شَدِيدًا مِّن لَّدُنْهُ وَيُبَشِّرَ الْمُؤْمِنِينَ الَّذِينَ يَعْمَلُونَ الصَّالِحَاتِ أَنَّ لَهُمْ أَجْرًا حَسَنًا ﴿٢﴾ مَّاكِثِينَ فِيهِ أَبَدًا ﴿٣﴾ وَيُنذِرَ الَّذِينَ قَالُوا اتَّخَذَ اللَّهُ وَلَدًا ﴿٤﴾ مَّا لَهُم بِهِ مِنْ عِلْمٍ وَلَا لِآبَائِهِمْ ۚ كَبُرَتْ كَلِمَةً تَخْرُجُ مِنْ أَفْوَاهِهِمْ ۚ إِن يَقُولُونَ إِلَّا كَذِبًا ﴿٥﴾ فَلَعَلَّكَ بَاخِعٌ نَّفْسَكَ عَلَىٰ آثَارِهِمْ إِن لَّمْ يُؤْمِنُوا بِهَٰذَا الْحَدِيثِ أَسَفًا ﴿٦﴾ إِنَّا جَعَلْنَا مَا عَلَى الْأَرْضِ زِينَةً لَّهَا لِنَبْلُوَهُمْ أَيُّهُمْ أَحْسَنُ عَمَلًا ﴿٧﴾',
                        style: TextStyle(
                          fontSize: 21,
                          height: 2.3,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF141C2B),
                        ),
                        textAlign: TextAlign.justify,
                      ),
                      const SizedBox(height: 24),

                      // Footer page indicator
                      Text(
                        '$_currentPage',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC77955)),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Page Navigation Floating controls
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: AnimatedOpacity(
                opacity: _isImmersive ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF162746).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
                        tooltip: 'الصفحة السابقة',
                        onPressed: _currentPage > 1
                            ? () => setState(() => _currentPage--)
                            : null,
                      ),
                      Text(
                        'الصفحة $_currentPage من 604',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
                        tooltip: 'الصفحة التالية',
                        onPressed: _currentPage < 604
                            ? () => setState(() => _currentPage++)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
