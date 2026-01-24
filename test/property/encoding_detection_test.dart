import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:purereader/formats/encoding_detector.dart';

void main() {
  group('Property 8: Encoding Auto Detection', () {
    test('Should detect UTF-8 BOM', () async {
      final bytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, 0x61, 0x62, 0x63]);
      expect(await EncodingDetector.detectEncoding(bytes), 'utf-8');
    });

    test('Should detect valid UTF-8 without BOM', () async {
      final bytes = Uint8List.fromList(utf8.encode('Hello World'));
      expect(await EncodingDetector.detectEncoding(bytes), 'utf-8');
    });

    test('Should fallback to locale-specific encoding for invalid UTF-8', () async {
      final bytes = Uint8List.fromList([0xC4, 0xE3, 0xBA, 0xC3]); // "你好" in GBK
      
      // Chinese
      expect(await EncodingDetector.detectEncoding(bytes, overrideLocale: 'zh_CN'), 'gbk');
      expect(await EncodingDetector.detectEncoding(bytes, overrideLocale: 'zh_TW'), 'big5');
      
      // Japanese
      expect(await EncodingDetector.detectEncoding(bytes, overrideLocale: 'ja_JP'), 'shift_jis');
      
      // Russian
      expect(await EncodingDetector.detectEncoding(bytes, overrideLocale: 'ru_RU'), 'windows-1251');
      
      // Western/Fallback
      expect(await EncodingDetector.detectEncoding(bytes, overrideLocale: 'en_US'), 'windows-1252');
    });
  });
}
