import 'package:flutter/material.dart';

class ReaderTheme {
  final String id;
  final String name;
  final Color backgroundColor;
  final Color textColor;
  final Color uiOverlayColor;
  final Color accentColor;

  const ReaderTheme({
    required this.id,
    required this.name,
    required this.backgroundColor,
    required this.textColor,
    required this.uiOverlayColor,
    required this.accentColor,
  });

  // Presets
  static const ReaderTheme day = ReaderTheme(
    id: 'day',
    name: 'Day',
    backgroundColor: Color(0xFFF9F7F1),
    textColor: Color(0xFF333333),
    uiOverlayColor: Color(0xFFEBE8DF),
    accentColor: Color(0xFF555555),
  );

  static const ReaderTheme night = ReaderTheme(
    id: 'night',
    name: 'Night',
    backgroundColor: Color(0xFF1E1E1E),
    textColor: Color(0xFFCECECE),
    uiOverlayColor: Color(0xFF2C2C2C),
    accentColor: Color(0xFF888888),
  );
  
  static const ReaderTheme mujiYellow = ReaderTheme(
    id: 'muji',
    name: 'Muji',
    backgroundColor: Color(0xFFF7F2E6),
    textColor: Color(0xFF4A443A),
    uiOverlayColor: Color(0xFFE8E2D2),
    accentColor: Color(0xFF8C8472),
  );

  static const ReaderTheme forestGreen = ReaderTheme(
    id: 'forest',
    name: 'Forest',
    backgroundColor: Color(0xFFE3EDCD),
    textColor: Color(0xFF2E4033),
    uiOverlayColor: Color(0xFFD3E0BA),
    accentColor: Color(0xFF5A7561),
  );

  static const List<ReaderTheme> all = [day, night, mujiYellow, forestGreen];

  static ReaderTheme fromId(String id, {Color? customBg, Color? customText}) {
    if (id == 'custom' && customBg != null && customText != null) {
      return ReaderTheme(
        id: 'custom',
        name: 'Custom',
        backgroundColor: customBg,
        textColor: customText,
        uiOverlayColor: customBg.withOpacity(0.1),
        accentColor: customText.withOpacity(0.5),
      );
    }
    return all.firstWhere((t) => t.id == id, orElse: () => day);
  }
}