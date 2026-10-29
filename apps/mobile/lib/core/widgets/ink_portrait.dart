import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/family_member.dart';

/// A small, self-contained illustrated portrait.
///
/// The design deliberately avoids stock photography: every person is painted
/// from the same ink-inspired visual language, with palette and features
/// derived from their profile. This keeps the prototype licensing-clean and
/// makes the tree feel coherent when there are dozens of faces on screen.
class InkPortrait extends StatelessWidget {
  const InkPortrait({
    super.key,
    required this.person,
    this.width = 48,
    this.height = 56,
    this.radius = 14,
    this.circle = false,
    this.showBorder = false,
    this.borderColor = Colors.white,
  });

  final FamilyMember person;
  final double width;
  final double height;
  final double radius;
  final bool circle;
  final bool showBorder;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final portrait = CustomPaint(
      size: Size(width, height),
      painter: _PortraitPainter(profile: _PortraitProfile.fromPerson(person)),
      isComplex: true,
      willChange: false,
    );

    final clipped = circle
        ? ClipOval(
            child: SizedBox(width: width, height: height, child: portrait),
          )
        : ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: SizedBox(width: width, height: height, child: portrait),
          );

    if (!showBorder) return clipped;
    return Container(
      decoration: BoxDecoration(
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: 2.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A20323B),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: clipped,
    );
  }
}

@immutable
class _PortraitProfile {
  const _PortraitProfile({
    required this.seed,
    required this.female,
    required this.elder,
    required this.child,
    required this.beard,
    required this.palette,
  });

  factory _PortraitProfile.fromPerson(FamilyMember person) {
    var seed = 0;
    for (final unit in person.id.codeUnits) {
      seed = (seed * 31 + unit) & 0x7fffffff;
    }
    final palette = _palettes[seed % _palettes.length];
    return _PortraitProfile(
      seed: seed,
      female: person.isFemale,
      elder: person.isElder,
      child: person.isChild,
      beard: !person.isFemale && person.isElder,
      palette: palette,
    );
  }

  final int seed;
  final bool female;
  final bool elder;
  final bool child;
  final bool beard;
  final _PortraitPalette palette;
}

@immutable
class _PortraitPalette {
  const _PortraitPalette({
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.robe,
    required this.robeShadow,
    required this.accent,
    required this.skin,
    required this.hair,
  });

  final Color backgroundTop;
  final Color backgroundBottom;
  final Color robe;
  final Color robeShadow;
  final Color accent;
  final Color skin;
  final Color hair;
}

const List<_PortraitPalette> _palettes = [
  _PortraitPalette(
    backgroundTop: Color(0xFFD6E6EB),
    backgroundBottom: Color(0xFFF0F5F2),
    robe: Color(0xFF486774),
    robeShadow: Color(0xFF344D58),
    accent: Color(0xFFD5B78A),
    skin: Color(0xFFEEC8A9),
    hair: Color(0xFF292B2A),
  ),
  _PortraitPalette(
    backgroundTop: Color(0xFFE9DDCB),
    backgroundBottom: Color(0xFFF8F3E9),
    robe: Color(0xFF6E5B4C),
    robeShadow: Color(0xFF55463B),
    accent: Color(0xFFE1C59A),
    skin: Color(0xFFF1CEAF),
    hair: Color(0xFF332B26),
  ),
  _PortraitPalette(
    backgroundTop: Color(0xFFD7E7DF),
    backgroundBottom: Color(0xFFF4F8F1),
    robe: Color(0xFF536A5F),
    robeShadow: Color(0xFF3D5048),
    accent: Color(0xFFCBB787),
    skin: Color(0xFFEBC4A2),
    hair: Color(0xFF2D2B27),
  ),
  _PortraitPalette(
    backgroundTop: Color(0xFFDCE1EB),
    backgroundBottom: Color(0xFFF5F1EA),
    robe: Color(0xFF4F647B),
    robeShadow: Color(0xFF3A4A5C),
    accent: Color(0xFFE0C29A),
    skin: Color(0xFFF0CAAA),
    hair: Color(0xFF34302D),
  ),
  _PortraitPalette(
    backgroundTop: Color(0xFFF0DDE0),
    backgroundBottom: Color(0xFFFAF3EE),
    robe: Color(0xFF81544F),
    robeShadow: Color(0xFF643F3C),
    accent: Color(0xFFD8B889),
    skin: Color(0xFFF2CFB0),
    hair: Color(0xFF332A28),
  ),
];

class _PortraitPainter extends CustomPainter {
  _PortraitPainter({required this.profile});

  final _PortraitProfile profile;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 100;
    final sy = size.height / 128;
    canvas.save();
    canvas.scale(sx, sy);

    final palette = profile.palette;
    final hairColor = profile.elder ? const Color(0xFF8D8B84) : palette.hair;

    _paintBackdrop(canvas, palette);

    // Hair behind the shoulders for long-haired figures.
    if (profile.female) {
      final backHair = Path()
        ..moveTo(24, 42)
        ..cubicTo(18, 55, 17, 80, 21, 104)
        ..cubicTo(28, 111, 39, 112, 49, 111)
        ..cubicTo(59, 112, 72, 111, 80, 104)
        ..cubicTo(84, 79, 83, 55, 77, 42)
        ..close();
      canvas.drawPath(
        backHair,
        Paint()..color = hairColor.withValues(alpha: 0.92),
      );
    }

    _paintRobe(canvas, palette);
    _paintNeck(canvas, palette);

    final faceWidth = profile.child ? 1.05 : 1.0;
    _paintFace(canvas, palette, faceWidth);
    _paintHair(canvas, hairColor);
    _paintFeatures(canvas, palette, hairColor);

    if (profile.female) {
      _paintHairOrnament(canvas, palette);
    }
    if (profile.beard) {
      _paintBeard(canvas, hairColor);
    }

    canvas.restore();
  }

  void _paintBackdrop(Canvas canvas, _PortraitPalette palette) {
    final rect = const Rect.fromLTWH(0, 0, 100, 128);
    final background = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [palette.backgroundTop, palette.backgroundBottom],
      ).createShader(rect);
    canvas.drawRect(rect, background);

    final glow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.35, -0.35),
        radius: 0.9,
        colors: [
          Colors.white.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, glow);

    // Quiet mountain lines anchor the portrait in the same world as the hero.
    final ridge = Path()
      ..moveTo(-8, 102)
      ..quadraticBezierTo(13, 88, 30, 99)
      ..quadraticBezierTo(50, 82, 70, 97)
      ..quadraticBezierTo(88, 86, 108, 98)
      ..lineTo(108, 128)
      ..lineTo(-8, 128)
      ..close();
    canvas.drawPath(
      ridge,
      Paint()..color = const Color(0xFF5B7B84).withValues(alpha: 0.08),
    );

    final sun = Paint()
      ..color =
          (profile.female ? const Color(0xFFD9A89A) : const Color(0xFFE4C18B))
              .withValues(alpha: 0.18);
    canvas.drawCircle(const Offset(78, 28), 12, sun);
  }

  void _paintRobe(Canvas canvas, _PortraitPalette palette) {
    final shoulders = Path()
      ..moveTo(-6, 128)
      ..cubicTo(0, 108, 18, 94, 38, 91)
      ..cubicTo(43, 98, 57, 98, 62, 91)
      ..cubicTo(82, 94, 100, 108, 106, 128)
      ..close();
    final robePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [palette.robe, palette.robeShadow],
      ).createShader(const Rect.fromLTWH(0, 86, 100, 42));
    canvas.drawPath(shoulders, robePaint);

    // Crossed lapels.
    final collarLeft = Path()
      ..moveTo(38, 91)
      ..cubicTo(44, 98, 50, 102, 49, 109)
      ..lineTo(38, 128)
      ..lineTo(26, 128)
      ..cubicTo(29, 111, 32, 99, 38, 91)
      ..close();
    canvas.drawPath(
      collarLeft,
      Paint()..color = palette.accent.withValues(alpha: 0.78),
    );

    final collarRight = Path()
      ..moveTo(62, 91)
      ..cubicTo(56, 98, 51, 102, 51, 109)
      ..lineTo(62, 128)
      ..lineTo(73, 128)
      ..cubicTo(70, 111, 67, 99, 62, 91)
      ..close();
    canvas.drawPath(
      collarRight,
      Paint()..color = Colors.white.withValues(alpha: 0.16),
    );

    final inner = Path()
      ..moveTo(43, 93)
      ..quadraticBezierTo(50, 102, 57, 93)
      ..lineTo(54, 105)
      ..quadraticBezierTo(50, 109, 46, 105)
      ..close();
    canvas.drawPath(
      inner,
      Paint()..color = const Color(0xFFF1E9D8).withValues(alpha: 0.88),
    );

    final foldPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.09)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (var i = 0; i < 4; i++) {
      final x = 14.0 + i * 20;
      canvas.drawPath(
        Path()
          ..moveTo(x, 110)
          ..quadraticBezierTo(x + 3, 118, x + 1, 128),
        foldPaint,
      );
    }

    // A hint of woven texture.
    final weave = Paint()
      ..color = Colors.white.withValues(alpha: 0.055)
      ..strokeWidth = 0.6;
    for (var y = 106.0; y < 128; y += 4.5) {
      canvas.drawLine(Offset(4, y), Offset(96, y + 3), weave);
    }
  }

  void _paintNeck(Canvas canvas, _PortraitPalette palette) {
    final neck = RRect.fromRectAndRadius(
      const Rect.fromLTWH(43, 70, 14, 23),
      const Radius.circular(7),
    );
    canvas.drawRRect(neck, Paint()..color = palette.skin);
    canvas.drawRRect(
      neck,
      Paint()
        ..color = const Color(0xFF815D4D).withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  void _paintFace(Canvas canvas, _PortraitPalette palette, double widthScale) {
    canvas.save();
    canvas.translate(50, 52);
    canvas.scale(widthScale, 1);
    canvas.translate(-50, -52);
    final face = Path()
      ..moveTo(28, 47)
      ..cubicTo(28.5, 32, 37, 24, 50, 24)
      ..cubicTo(63, 24, 71.5, 32, 72, 47)
      ..cubicTo(72.5, 61, 65, 76, 50, 79)
      ..cubicTo(35, 76, 27.5, 61, 28, 47)
      ..close();
    final facePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(palette.skin, Colors.white, 0.15)!,
          palette.skin,
          Color.lerp(palette.skin, const Color(0xFF9B674F), 0.10)!,
        ],
      ).createShader(const Rect.fromLTWH(26, 23, 48, 58));
    canvas.drawPath(face, facePaint);
    canvas.drawPath(
      face,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = const Color(0xFF8E6552).withValues(alpha: 0.20),
    );

    final earPaint = Paint()..color = palette.skin;
    canvas.drawOval(const Rect.fromLTWH(24.2, 49, 6, 11), earPaint);
    canvas.drawOval(const Rect.fromLTWH(69.8, 49, 6, 11), earPaint);
    canvas.drawArc(
      const Rect.fromLTWH(25, 51, 3, 6),
      -math.pi / 2,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = const Color(0xFF9A6E59).withValues(alpha: 0.45),
    );
    canvas.restore();
  }

  void _paintHair(Canvas canvas, Color hairColor) {
    // Side hair and crown.
    final crown = Path()
      ..moveTo(26.5, 48)
      ..cubicTo(25, 31, 34, 19, 50, 19)
      ..cubicTo(66, 19, 75.5, 30, 74, 48)
      ..cubicTo(71.5, 40, 67, 32.5, 60, 31.5)
      ..cubicTo(54, 30.6, 49, 33.5, 45, 35)
      ..cubicTo(39, 37.2, 34, 39.5, 31.5, 46.5)
      ..close();
    canvas.drawPath(crown, Paint()..color = hairColor);
    // Soft highlight for a painted rather than flat look.
    canvas.drawPath(
      Path()
        ..moveTo(35, 31)
        ..cubicTo(40, 24, 52, 22, 60, 26)
        ..cubicTo(55, 24, 44, 25, 39, 31)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: 0.12),
    );

    if (!profile.female) {
      final sideburns = Path()
        ..moveTo(27.5, 45)
        ..cubicTo(26.5, 52, 28, 57, 29, 61)
        ..lineTo(33, 60)
        ..cubicTo(31.2, 54, 31, 49, 31.6, 44)
        ..close()
        ..moveTo(72.5, 45)
        ..cubicTo(73.5, 52, 72, 57, 71, 61)
        ..lineTo(67, 60)
        ..cubicTo(68.8, 54, 69, 49, 68.4, 44)
        ..close();
      canvas.drawPath(sideburns, Paint()..color = hairColor);
    } else {
      final sideLocks = Path()
        ..moveTo(26.9, 43)
        ..cubicTo(23.5, 57, 24, 75, 26, 91)
        ..cubicTo(29.4, 93, 32, 92, 34, 90)
        ..cubicTo(31, 73, 31.5, 57, 33.2, 42)
        ..close()
        ..moveTo(73.1, 43)
        ..cubicTo(76.5, 57, 76, 75, 74, 91)
        ..cubicTo(70.6, 93, 68, 92, 66, 90)
        ..cubicTo(69, 73, 68.5, 57, 66.8, 42)
        ..close();
      canvas.drawPath(
        sideLocks,
        Paint()..color = hairColor.withValues(alpha: 0.96),
      );

      if (profile.elder) {
        final bun = RRect.fromRectAndRadius(
          const Rect.fromLTWH(41, 13, 18, 12),
          const Radius.circular(6),
        );
        canvas.drawRRect(bun, Paint()..color = hairColor);
      }
    }
  }

  void _paintFeatures(
    Canvas canvas,
    _PortraitPalette palette,
    Color hairColor,
  ) {
    final browPaint = Paint()
      ..color = hairColor.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(36, 45.8)
        ..quadraticBezierTo(40, 43.9, 44.5, 45.2),
      browPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(55.5, 45.2)
        ..quadraticBezierTo(60, 43.9, 64, 45.8),
      browPaint,
    );

    if (profile.elder) {
      final line = Paint()
        ..color = const Color(0xFF7E5D4D).withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.55;
      canvas.drawLine(const Offset(39, 35), const Offset(45, 34.2), line);
      canvas.drawLine(const Offset(56, 34.2), const Offset(61.8, 35), line);
    }

    final eyeWhite = Paint()..color = const Color(0xFFFFFBF4);
    canvas.drawOval(const Rect.fromLTWH(36, 50.2, 9, 4.5), eyeWhite);
    canvas.drawOval(const Rect.fromLTWH(55, 50.2, 9, 4.5), eyeWhite);
    final iris = Paint()..color = const Color(0xFF3A3430);
    canvas.drawOval(const Rect.fromLTWH(39.3, 50.8, 3.4, 3.4), iris);
    canvas.drawOval(const Rect.fromLTWH(57.5, 50.8, 3.4, 3.4), iris);
    final catchlight = Paint()..color = Colors.white.withValues(alpha: 0.9);
    canvas.drawCircle(const Offset(40.3, 51.7), 0.65, catchlight);
    canvas.drawCircle(const Offset(58.5, 51.7), 0.65, catchlight);

    final lash = Paint()
      ..color = hairColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round;
    if (profile.female) {
      canvas.drawArc(
        const Rect.fromLTWH(35.4, 49.2, 10.4, 5.8),
        math.pi,
        math.pi * 0.86,
        false,
        lash,
      );
      canvas.drawArc(
        const Rect.fromLTWH(54.2, 49.2, 10.4, 5.8),
        math.pi,
        math.pi * 0.86,
        false,
        lash,
      );
      canvas.drawLine(const Offset(44.5, 51.5), const Offset(47, 50.6), lash);
      canvas.drawLine(const Offset(55.5, 51.5), const Offset(53, 50.6), lash);
    }

    final nose = Paint()
      ..color = const Color(0xFF9D6E58).withValues(alpha: 0.48)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(50.2, 55)
        ..quadraticBezierTo(51.3, 60.5, 48.2, 61.6),
      nose,
    );

    final lipColor = profile.female
        ? const Color(0xFFB96060)
        : const Color(0xFFA7675C);
    final lip = Paint()
      ..color = lipColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(44.8, 67.2)
        ..quadraticBezierTo(50, 70.2, 55.2, 67.2),
      lip,
    );

    if (profile.female || profile.child) {
      final blush = Paint()
        ..color = const Color(
          0xFFD78678,
        ).withValues(alpha: profile.child ? 0.30 : 0.18);
      canvas.drawOval(const Rect.fromLTWH(31.5, 59, 8.5, 4.5), blush);
      canvas.drawOval(const Rect.fromLTWH(60, 59, 8.5, 4.5), blush);
    }

    // Freckles / subtle texture.
    if (profile.seed % 3 == 0) {
      final freckle = Paint()
        ..color = const Color(0xFF9B6D55).withValues(alpha: 0.30);
      canvas.drawCircle(const Offset(38, 61), 0.55, freckle);
      canvas.drawCircle(const Offset(41.5, 62), 0.45, freckle);
      canvas.drawCircle(const Offset(60.5, 61.5), 0.5, freckle);
    }
  }

  void _paintHairOrnament(Canvas canvas, _PortraitPalette palette) {
    final pin = Paint()
      ..color = const Color(0xFFD8B576)
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(32, 28.5), const Offset(39, 25.8), pin);
    canvas.drawCircle(
      const Offset(39.3, 25.6),
      1.25,
      Paint()..color = const Color(0xFFE6C98E),
    );
  }

  void _paintBeard(Canvas canvas, Color hairColor) {
    final beardPaint = Paint()..color = hairColor.withValues(alpha: 0.82);
    final beard = Path()
      ..moveTo(36, 69)
      ..cubicTo(38, 77, 42, 84, 50, 87)
      ..cubicTo(58, 84, 62, 77, 64, 69)
      ..cubicTo(63, 76, 60, 79, 53, 80)
      ..cubicTo(47, 79, 41, 77, 36, 69)
      ..close();
    canvas.drawPath(beard, beardPaint);
    final moustache = Path()
      ..moveTo(44, 65.2)
      ..quadraticBezierTo(47, 63.8, 50, 65.1)
      ..quadraticBezierTo(53, 63.8, 56, 65.2)
      ..quadraticBezierTo(53, 67, 50, 66.2)
      ..quadraticBezierTo(47, 67, 44, 65.2)
      ..close();
    canvas.drawPath(moustache, beardPaint);
    // A few grey strokes give the beard a hand-painted texture.
    final stroke = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..strokeWidth = 0.65;
    canvas.drawLine(const Offset(44, 76), const Offset(46, 82), stroke);
    canvas.drawLine(const Offset(56, 75), const Offset(54, 82), stroke);
  }

  @override
  bool shouldRepaint(_PortraitPainter oldDelegate) {
    return oldDelegate.profile.seed != profile.seed ||
        oldDelegate.profile.palette != profile.palette ||
        oldDelegate.profile.elder != profile.elder;
  }
}
