import 'package:flutter/material.dart';

class TarteelBrandMark extends StatelessWidget {
  const TarteelBrandMark({super.key, this.size = 48, this.radio = false});

  final double size;
  final bool radio;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: radio ? 'شعار إذاعة ترتيل' : 'شعار ترتيل',
      image: true,
      child: CustomPaint(
        size: Size.square(size),
        painter: _TarteelMarkPainter(
          foreground: scheme.onPrimary,
          accent: scheme.tertiary,
          background: scheme.primary,
          radio: radio,
        ),
      ),
    );
  }
}

class _TarteelMarkPainter extends CustomPainter {
  const _TarteelMarkPainter({
    required this.foreground,
    required this.accent,
    required this.background,
    required this.radio,
  });

  final Color foreground;
  final Color accent;
  final Color background;
  final bool radio;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(w * 0.24),
    );
    canvas.drawRRect(r, Paint()..color = background);

    final line = Paint()
      ..color = foreground
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = w * 0.055;
    final fill = Paint()..color = accent;

    final book = Path()
      ..moveTo(w * 0.20, h * 0.62)
      ..quadraticBezierTo(w * 0.35, h * 0.53, w * 0.49, h * 0.66)
      ..quadraticBezierTo(w * 0.64, h * 0.53, w * 0.80, h * 0.62)
      ..lineTo(w * 0.78, h * 0.75)
      ..quadraticBezierTo(w * 0.64, h * 0.68, w * 0.50, h * 0.78)
      ..quadraticBezierTo(w * 0.36, h * 0.68, w * 0.22, h * 0.75)
      ..close();
    canvas.drawPath(book, line);
    canvas.drawLine(Offset(w * 0.50, h * 0.65), Offset(w * 0.50, h * 0.77), line);

    final minaret = Path()
      ..moveTo(w * 0.47, h * 0.52)
      ..lineTo(w * 0.47, h * 0.31)
      ..lineTo(w * 0.50, h * 0.23)
      ..lineTo(w * 0.53, h * 0.31)
      ..lineTo(w * 0.53, h * 0.52)
      ..close();
    canvas.drawPath(minaret, fill);
    canvas.drawCircle(Offset(w * 0.50, h * 0.21), w * 0.018, fill);

    if (radio) {
      final wave = Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = w * 0.035;
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(w * 0.50, h * 0.40),
          width: w * 0.38,
          height: h * 0.32,
        ),
        -0.7,
        1.4,
        false,
        wave,
      );
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(w * 0.50, h * 0.40),
          width: w * 0.58,
          height: h * 0.48,
        ),
        -0.62,
        1.24,
        false,
        wave,
      );
    } else {
      canvas.drawCircle(Offset(w * 0.35, h * 0.39), w * 0.025, fill);
      canvas.drawCircle(Offset(w * 0.65, h * 0.39), w * 0.025, fill);
    }
  }

  @override
  bool shouldRepaint(covariant _TarteelMarkPainter oldDelegate) =>
      oldDelegate.foreground != foreground ||
      oldDelegate.accent != accent ||
      oldDelegate.background != background ||
      oldDelegate.radio != radio;
}
