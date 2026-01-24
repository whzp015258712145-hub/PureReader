import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class EncodingDetector {
  /// Detects the encoding of the provided bytes.
  /// Returns a string encoding name compatible with CharsetConverter.
  static Future<String> detectEncoding(Uint8List bytes, {String? overrideLocale}) async {
    // 1. Check BOM
    String? bomEncoding = _checkBOM(bytes);
    if (bomEncoding != null) return bomEncoding;

    // 2. Try UTF-8
    try {
      utf8.decode(bytes, allowMalformed: false);
      return 'utf-8';
    } catch (_) {
      // Not valid UTF-8
    }

    // 3. Heuristic / Fallback based on Locale
    final String locale = (overrideLocale ?? Platform.localeName).toLowerCase();
    
    if (locale.startsWith('zh')) {
      // Handle Traditional Chinese (Big5) specifically if possible
      if (locale.contains('tw') || locale.contains('hk')) {
        return 'big5';
      }
      return 'gbk';
    }
    
    if (locale.startsWith('ja')) return 'shift_jis';
    if (locale.startsWith('ko')) return 'euc-kr';
    if (locale.startsWith('ru') || locale.startsWith('uk') || locale.startsWith('be')) {
      return 'windows-1251'; // Cyrillic
    }
    
    // Western European / Latin-1 as a safe global fallback
    return 'windows-1252';
  }

  static String? _checkBOM(Uint8List bytes) {
    if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
      return 'utf-8';
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return 'utf-16be';
    }
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return 'utf-16le';
    }
    return null;
  }
}
