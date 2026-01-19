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

    test('Should fallback to GBK (or heuristic) for invalid UTF-8', () async {
      // Invalid UTF-8 sequence (e.g. single 0xFF byte or GBK sequence)
      // "你好" in GBK is C4 E3 BA C3
      final bytes = Uint8List.fromList([0xC4, 0xE3, 0xBA, 0xC3]);
      
      // Since it's not valid UTF-8, it should return 'gbk'
      expect(await EncodingDetector.detectEncoding(bytes), 'gbk');
    });
  });
}
