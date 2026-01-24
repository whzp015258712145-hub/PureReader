import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// Top-level function for background isolate processing
String _detectEncodingTask(Map<String, dynamic> params) {
  final Uint8List bytes = params['bytes'];
  final String locale = params['locale'];

  // 1. Check BOM
  if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
    return 'utf-8';
  }
  if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
    return 'utf-16be';
  }
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    return 'utf-16le';
  }

  // 2. Try UTF-8
  try {
    utf8.decode(bytes, allowMalformed: false);
    return 'utf-8';
  } catch (_) {
    // Not valid UTF-8
  }

  // 3. Heuristic / Fallback based on Locale
  if (locale.startsWith('zh')) {
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
  
  return 'windows-1252';
}

class EncodingDetector {
  /// Detects the encoding of the provided bytes.
  /// Returns a string encoding name compatible with CharsetConverter.
  static Future<String> detectEncoding(Uint8List bytes, {String? overrideLocale}) async {
    final String locale = (overrideLocale ?? Platform.localeName).toLowerCase();
    
    // Use compute to run in background isolate
    return await compute(_detectEncodingTask, {
      'bytes': bytes,
      'locale': locale,
    });
  }

  // Keeping private BOM check for internal use if needed, 
  // though it's now integrated into the top-level task.
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
