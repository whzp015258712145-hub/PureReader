import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/reader_theme.dart';

class ReaderConfig {
  final double fontSize;
  final double lineHeight;
  final double padding;
  final ReaderTheme theme;
  final String fontFamily;
  final Locale locale;

  ReaderConfig({
    required this.fontSize,
    required this.lineHeight,
    required this.padding,
    required this.theme,
    required this.fontFamily,
    required this.locale,
  });

  factory ReaderConfig.defaultConfig() => ReaderConfig(
        fontSize: 18.0,
        lineHeight: 1.6,
        padding: 40.0,
        theme: ReaderTheme.day,
        fontFamily: '.SF Pro Text',
        locale: const Locale('en'),
      );

  ReaderConfig copyWith({
    double? fontSize,
    double? lineHeight,
    double? padding,
    ReaderTheme? theme,
    Locale? locale,
    String? fontFamily,
  }) {
    return ReaderConfig(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      padding: padding ?? this.padding,
      theme: theme ?? this.theme,
      fontFamily: fontFamily ?? this.fontFamily,
      locale: locale ?? this.locale,
    );
  }
}

final readerConfigProvider = StateNotifierProvider<ReaderNotifier, ReaderConfig>((ref) {
  return ReaderNotifier();
});

final openFileRequestProvider = StateProvider<String?>((ref) => null);

/// Signal to reload current file with specific encoding.
/// Format: "path|encoding"
final openFileWithEncodingProvider = StateProvider<String?>((ref) => null);

class ReaderNotifier extends StateNotifier<ReaderConfig> {
  ReaderNotifier() : super(ReaderConfig.defaultConfig()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? lang = prefs.getString('lang');
      String? themeId = prefs.getString('theme');
      double? fontSize = prefs.getDouble('fontSize');
      String? font = prefs.getString('font');
      
      if (lang == null) {
        final systemLocale = Platform.localeName.split('_')[0];
        lang = (systemLocale == 'zh') ? 'zh' : 'en';
      }
      
      ReaderTheme theme;
      if (themeId == 'custom') {
        int bg = prefs.getInt('custom_bg') ?? ReaderTheme.day.backgroundColor.value;
        int text = prefs.getInt('custom_text') ?? ReaderTheme.day.textColor.value;
        theme = ReaderTheme.fromId('custom', customBg: Color(bg), customText: Color(text));
      } else {
        theme = themeId != null ? ReaderTheme.fromId(themeId) : ReaderTheme.day;
      }

      double finalFontSize = fontSize ?? 18.0;
      
      if (finalFontSize > 40.0) {
        finalFontSize = 18.0;
      }
      
      state = state.copyWith(
        locale: Locale(lang),
        theme: theme,
        fontSize: finalFontSize,
        fontFamily: font ?? '.SF Pro Text',
      );
    } catch (e) {
      debugPrint('Error loading settings: $e');
      // On error, we keep the default state assigned in constructor
    }
  }

  void updateFontSize(double v) {
    state = state.copyWith(fontSize: v.clamp(12.0, 40.0));
    SharedPreferences.getInstance().then((p) => p.setDouble('fontSize', state.fontSize));
  }

  void updateLineHeight(double v) => state = state.copyWith(lineHeight: v);
  void updatePadding(double v) => state = state.copyWith(padding: v);
  void updateFontFamily(String font) {
    state = state.copyWith(fontFamily: font);
    SharedPreferences.getInstance().then((p) => p.setString('font', font));
  }

  void setLocale(String lang) {
    state = state.copyWith(locale: Locale(lang));
    SharedPreferences.getInstance().then((p) => p.setString('lang', lang));
  }

  void setTheme(String themeId) {
    final newTheme = ReaderTheme.fromId(themeId);
    state = state.copyWith(theme: newTheme);
    SharedPreferences.getInstance().then((p) => p.setString('theme', themeId));
  }

  void setCustomTheme(Color bg, Color text) {
    final newTheme = ReaderTheme.fromId('custom', customBg: bg, customText: text);
    state = state.copyWith(theme: newTheme);
    SharedPreferences.getInstance().then((p) {
      p.setString('theme', 'custom');
      p.setInt('custom_bg', bg.value);
      p.setInt('custom_text', text.value);
    });
  }
}