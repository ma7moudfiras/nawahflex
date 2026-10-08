// ============================================================================
// إطار المستوى — صورة الطالب داخل «وجه الروبوت»
// ----------------------------------------------------------------------------
// الشعار كلمة «نواة» داخل إطار بزوايا مستديرة، بثلاث نقاط قرميدية وهوائي
// (الألف). الإطار نفسه هو مقياس المستوى: يكتمل وجه الروبوت مع التقدّم.
//
//   ١ نواة   إطار وحده
//   ٢ شرارة  + نقطة قرميدية
//   ٣ دائرة  + نقطتان
//   ٤ آلة    + ثلاث نقاط (نقاط الشعار كاملة)
//   ٥ مخترع  الإطار بالقرميدي + الهوائي — الشعار كاملاً
//
// النِّسَب من هندسة الشعار (logo.dart): عرض الإطار ٢٣٥٢، نصف قطر الزاوية
// ٣٠٠ (≈ ١٢.٨٪)، سماكة الخط ١٧٤ (≈ ٧.٤٪)، والنقطة ٧٦ (≈ ٣.٢٪). بلا تدرّج
// ولا توهّج — ألوان الرموز فقط.
// ============================================================================

import 'package:flutter/material.dart';

import 'tokens.dart';

/// أعلى مستوى يرسمه الإطار؛ ما فوقه يُرسم كالخامس.
const int kMaxFrameLevel = 5;

class LevelFrame extends StatelessWidget {
  const LevelFrame({
    super.key,
    required this.level,
    required this.child,
    this.size = 96,
    this.color = NawahColors.ink,
    this.background = NawahColors.paper,
  });

  final int level;

  /// ما بداخل الإطار — صورة الطالب أو حرفه الأول.
  final Widget child;

  /// عرض الإطار وارتفاعه بلا الهوائي (يُضاف فوقه).
  final double size;

  /// لون الإطار في المستويات ١–٤.
  final Color color;

  /// لون ما خلف الإطار — يقطع الخط حول النقاط كما في الشعار.
  final Color background;

  static double antennaHeight(double size) => size * 0.22;

  @override
  Widget build(BuildContext context) {
    final lv = level.clamp(1, kMaxFrameLevel);
    final stroke = size * 0.074;
    final antenna = antennaHeight(size);
    final inset = stroke * 1.9;
    return Semantics(
      label: 'المستوى $lv',
      child: SizedBox(
        width: size,
        height: size + antenna,
        child: Stack(
          children: [
            Positioned(
              left: inset,
              right: inset,
              top: antenna + inset,
              bottom: inset,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(size * 0.09),
                child: child,
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _FramePainter(
                  level: lv,
                  color: lv >= kMaxFrameLevel ? NawahColors.accent : color,
                  antennaColor: color,
                  background: background,
                  stroke: stroke,
                  antenna: antenna,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter({
    required this.level,
    required this.color,
    required this.antennaColor,
    required this.background,
    required this.stroke,
    required this.antenna,
  });

  final int level;
  final Color color;
  final Color antennaColor;
  final Color background;
  final double stroke;
  final double antenna;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final frame = Rect.fromLTWH(stroke / 2, antenna + stroke / 2, w - stroke, w - stroke);

    canvas.drawRRect(
      RRect.fromRectAndRadius(frame, Radius.circular(w * 0.128)),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    // النقاط على الحافة العليا متجاورة جهة اليمين (بداية السطر العربي)،
    // بعيداً عن الهوائي في المنتصف. كل نقطة تقطع الخط بحلقة بلون الخلفية،
    // فتبدو «مزروعة» فيه لا ملصقة عليه. الحلقات أولاً كي لا تقصّ نقطةٌ جارتها.
    final dots = (level - 1).clamp(0, 3);
    final r = w * 0.052;
    final centers = [0.81, 0.695, 0.58].take(dots).map((fx) => Offset(w * fx, frame.top)).toList();
    for (final c in centers) {
      canvas.drawCircle(c, r + stroke * 0.55, Paint()..color = background);
    }

    // الهوائي (الألف): عمود من منتصف الحافة العليا — للمستوى الأخير وحده.
    if (level >= kMaxFrameLevel) {
      canvas.drawRect(
        Rect.fromLTWH(w / 2 - stroke / 2, 0, stroke, antenna + stroke),
        Paint()..color = antennaColor,
      );
    }

    for (final c in centers) {
      canvas.drawCircle(c, r, Paint()..color = NawahColors.accent);
    }
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.level != level || old.color != color || old.background != background || old.stroke != stroke;
}

/// الحرف الأول داخل الإطار حين لا توجد صورة.
class InitialAvatar extends StatelessWidget {
  const InitialAvatar({
    super.key,
    required this.initial,
    this.background = NawahColors.inkTint,
    this.foreground = NawahColors.ink,
  });

  final String initial;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: background,
      child: Center(
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Text(
              initial,
              style: TextStyle(
                fontFamily: NawahFonts.display,
                fontWeight: FontWeight.w800,
                fontSize: 40,
                color: foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
