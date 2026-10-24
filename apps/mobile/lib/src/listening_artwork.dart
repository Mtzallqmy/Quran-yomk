import 'package:flutter/material.dart';

import 'theme.dart';

/// Original vector artwork, packaged as code: no remote images or permissions.
class ListeningArtwork extends StatelessWidget {
  const ListeningArtwork({super.key, required this.size, this.radio = true});
  final double size;
  final bool radio;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(size > 100 ? 28 : 12),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: radio
                ? const [
                    Color(0xFF243B6B),
                    Color(0xFF162746),
                    Color(0xFF2E9E9E),
                  ]
                : const [
                    Color(0xFF162746),
                    Color(0xFF243B6B),
                    Color(0xFFC77955),
                  ],
          ),
        ),
        child: CustomPaint(
          painter: const IslamicGeometryPainter(color: Color(0x18F8F6F1)),
          foregroundPainter: _ListeningSilhouette(radio: radio),
          child: Center(
            child: Icon(
              radio ? Icons.graphic_eq_rounded : Icons.menu_book_rounded,
              color: const Color(0xFFF8F6F1),
              size: size * .32,
            ),
          ),
        ),
      ),
    ),
  );
}

class _ListeningSilhouette extends CustomPainter {
  const _ListeningSilhouette({required this.radio});
  final bool radio;
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = const Color(0x33F8F6F1);
    final w = size.width, h = size.height;
    final skyline = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * .88)
      ..lineTo(w * .18, h * .88)
      ..lineTo(w * .18, h * .68)
      ..lineTo(w * .23, h * .59)
      ..lineTo(w * .28, h * .68)
      ..lineTo(w * .28, h * .88)
      ..lineTo(w * .36, h * .88)
      ..lineTo(w * .36, h * .82)
      ..quadraticBezierTo(w * .5, h * .61, w * .64, h * .82)
      ..lineTo(w * .64, h * .88)
      ..lineTo(w * .72, h * .88)
      ..lineTo(w * .72, h * .68)
      ..lineTo(w * .77, h * .59)
      ..lineTo(w * .82, h * .68)
      ..lineTo(w * .82, h * .88)
      ..lineTo(w, h * .88)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(skyline, fill);
    canvas.drawCircle(
      Offset(w * .78, h * .2),
      w * .055,
      Paint()..color = const Color(0x99C77955),
    );
  }

  @override
  bool shouldRepaint(_ListeningSilhouette oldDelegate) =>
      radio != oldDelegate.radio;
}

class ListeningBackdrop extends StatelessWidget {
  const ListeningBackdrop({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Theme.of(context).colorScheme.secondary.withValues(alpha: .08),
          Theme.of(context).colorScheme.surface.withValues(alpha: 0),
        ],
      ),
    ),
    child: CustomPaint(
      painter: IslamicGeometryPainter(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: .035),
      ),
      child: child,
    ),
  );
}
