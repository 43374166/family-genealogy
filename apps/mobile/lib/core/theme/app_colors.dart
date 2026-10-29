import 'package:flutter/material.dart';

/// A restrained ink-and-paper palette shared by the whole client.
abstract final class AppColors {
  static const Color ink = Color(0xFF1C2A32);
  static const Color inkSoft = Color(0xFF54646D);
  static const Color inkMuted = Color(0xFF89969C);
  static const Color background = Color(0xFFF4F7F8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceWarm = Color(0xFFFBFAF5);
  static const Color line = Color(0xFFECF0F1);

  static const Color primary = Color(0xFF4E7DF4);
  static const Color primaryDeep = Color(0xFF3764D8);
  static const Color primarySoft = Color(0xFFEAF0FF);

  static const Color cinnabar = Color(0xFFB4423D);
  static const Color cinnabarSoft = Color(0xFFFBEEEA);
  static const Color gold = Color(0xFFE4A636);
  static const Color goldSoft = Color(0xFFFFF4DF);
  static const Color jade = Color(0xFF3DA77C);
  static const Color jadeSoft = Color(0xFFE8F6EF);
  static const Color teal = Color(0xFF35ABC0);
  static const Color tealSoft = Color(0xFFE8F7F9);
  static const Color violet = Color(0xFF8A6BE8);
  static const Color violetSoft = Color(0xFFF1EDFF);
  static const Color rose = Color(0xFFE46A72);
  static const Color roseSoft = Color(0xFFFDECEE);
  static const Color slate = Color(0xFF6A7C88);
  static const Color slateSoft = Color(0xFFEDF2F5);

  /// Cinnabar is used for the seal; a subtle shadow keeps the header airy.
  static const List<Color> heroFade = [
    Color(0x00F4F7F8),
    Color(0xB3F4F7F8),
    Color(0xFFF4F7F8),
  ];
}
