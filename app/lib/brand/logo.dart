// ============================================================================
// شعار أكاديمية نواة — كلمة «نواة» على شكل وجه روبوت
// ----------------------------------------------------------------------------
// مرسوم بـ CustomPainter لا صورة: يبقى حادّاً في كل حجم، ويتلوّن بأي لون،
// ولا يحتاج اعتمادية SVG. الإحداثيات مولّدة من هندسة الشعار نفسها
// (site/assets/favicon.svg والشعار في site/index.html من المصدر ذاته).
//
// الحروف: الألف هوائي، الواو والتاء المربوطة عينان، النون سنّ في الإطار،
// وذيل الواو ابتسامة. النقاط الثلاث (نقطة النون ونقطتا التاء) بلون التوقيع.
// ============================================================================

import 'package:flutter/material.dart';

import 'tokens.dart';

class NawahLogo extends StatelessWidget {
  const NawahLogo({
    super.key,
    this.height = 40,
    this.color = NawahColors.ink,
    this.dotColor = NawahColors.accent,
  });

  /// الارتفاع؛ العرض يُحسب من نسبة الشعار.
  final double height;
  final Color color;
  final Color dotColor;

  static const double _aspect = 2685 / 2440;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'شعار أكاديمية نواة',
      image: true,
      child: CustomPaint(
        size: Size(height * _aspect, height),
        painter: _LogoPainter(color, dotColor),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.color, this.dotColor);
  final Color color;
  final Color dotColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 2685.0, size.height / 2440.0);
    canvas.translate(564.0, 1619.0);

    final ink = Paint()..color = color;
    final dot = Paint()..color = dotColor;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 174
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(Path()
      ..moveTo(955.0, -1192.0)
      ..lineTo(1654.0, -1192.0)
      ..arcToPoint(const Offset(1954.0, -892.0), radius: const Radius.circular(300.0), largeArc: false, clockwise: true)
      ..lineTo(1954.0, -892.0), stroke);
    canvas.drawPath(Path()
      ..moveTo(1954.0, 90.0)
      ..lineTo(1954.0, 354.0)
      ..arcToPoint(const Offset(1654.0, 654.0), radius: const Radius.circular(300.0), largeArc: false, clockwise: true)
      ..lineTo(-98.0, 654.0)
      ..arcToPoint(const Offset(-398.0, 354.0), radius: const Radius.circular(300.0), largeArc: false, clockwise: true)
      ..lineTo(-398.0, -892.0)
      ..arcToPoint(const Offset(-98.0, -1192.0), radius: const Radius.circular(300.0), largeArc: false, clockwise: true)
      ..lineTo(601.0, -1192.0), stroke);
    canvas.drawRect(const Rect.fromLTWH(691.0, -1539.0, 174.0, 1539.0), ink);
    canvas.drawPath(Path()..fillType = PathFillType.evenOdd
      ..moveTo(21.0, -290.0)
      ..arcToPoint(const Offset(601.0, -290.0), radius: const Radius.circular(290.0), largeArc: true, clockwise: false)
      ..arcToPoint(const Offset(21.0, -290.0), radius: const Radius.circular(290.0), largeArc: true, clockwise: false)
      ..close()
      ..moveTo(193.0, -290.0)
      ..arcToPoint(const Offset(429.0, -290.0), radius: const Radius.circular(118.0), largeArc: true, clockwise: true)
      ..arcToPoint(const Offset(193.0, -290.0), radius: const Radius.circular(118.0), largeArc: true, clockwise: true)
      ..close(), ink);
    canvas.drawCircle(const Offset(226.0, -726.0), 76.0, dot);
    canvas.drawCircle(const Offset(396.0, -726.0), 76.0, dot);
    canvas.drawPath(Path()..fillType = PathFillType.evenOdd
      ..moveTo(955.0, -290.0)
      ..arcToPoint(const Offset(1535.0, -290.0), radius: const Radius.circular(290.0), largeArc: true, clockwise: false)
      ..arcToPoint(const Offset(955.0, -290.0), radius: const Radius.circular(290.0), largeArc: true, clockwise: false)
      ..close()
      ..moveTo(1127.0, -290.0)
      ..arcToPoint(const Offset(1363.0, -290.0), radius: const Radius.circular(118.0), largeArc: true, clockwise: true)
      ..arcToPoint(const Offset(1127.0, -290.0), radius: const Radius.circular(118.0), largeArc: true, clockwise: true)
      ..close(), ink);
    canvas.drawPath(Path()
      ..moveTo(1954.0, -560.0)
      ..lineTo(1954.0, -307.0)
      ..arcToPoint(const Offset(1734.0, -87.0), radius: const Radius.circular(220.0), largeArc: false, clockwise: true)
      ..lineTo(1361.0, -87.0), stroke);
    canvas.drawPath(Path()
      ..moveTo(1448.0, -290.0)
      ..lineTo(1448.0, 90.0)
      ..arcToPoint(const Offset(1228.0, 310.0), radius: const Radius.circular(220.0), largeArc: false, clockwise: true)
      ..lineTo(409.0, 310.0)
      ..arcToPoint(const Offset(189.0, 90.0), radius: const Radius.circular(220.0), largeArc: false, clockwise: true)
      ..lineTo(189.0, 88.0), stroke);
    canvas.drawCircle(const Offset(1954.0, -726.0), 76.0, dot);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.color != color || old.dotColor != dotColor;
}
