import 'dart:convert';
import 'dart:typed_data';

class EncodingDetector {
  /// Detects the encoding of the provided bytes.
  /// Returns a string encoding name compatible with CharsetConverter.
  static Future<String> detectEncoding(Uint8List bytes) async {
    // 1. Check BOM
    String? bomEncoding = _checkBOM(bytes);
    if (bomEncoding != null) return bomEncoding;

    // 2. Try UTF-8
    // UTF-8 is the most common and standard. If it validates, use it.
    try {
      utf8.decode(bytes, allowMalformed: false);
      return 'utf-8';
    } catch (_) {
      // Not valid UTF-8
    }

    // 3. Heuristic / Fallback
    // If not UTF-8, it's likely a legacy encoding.
    // For a Chinese context, GBK/GB18030 is extremely common.
    // For Western, ISO-8859-1.
    // Ideally we would use a statistical detector (like uchardet), but in pure Dart/Flutter
    // without heavy native bindings, we can guess.
    
    // We will return 'gbk' as a strong candidate for non-UTF-8 files in this context.
    // The UI should allow overriding this if it looks wrong.
    return 'gbk';
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
