import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:purereader/models/ebook_format.dart';
import 'package:purereader/parsers/ebook_parser_factory.dart';
import 'package:purereader/parsers/txt_parser.dart';

void main() {
  group('Property 5: Multi-format Support', () {
    test('Factory should create correct parser for supported formats', () {
      expect(EbookParserFactory.createParser(EbookFormat.epub), isNotNull);
      expect(EbookParserFactory.createParser(EbookFormat.pdf), isNotNull);
      expect(EbookParserFactory.createParser(EbookFormat.txt), isNotNull);
    });

    test('TXT Parser should handle pagination (Property 10)', () async {
      // Integration test with temp file
      final tempDir = await Directory.systemTemp.createTemp('txt_test');
      final file = File('${tempDir.path}/test.txt');
      
      // Create a large text file (> 3000 chars)
      final content = 'a' * 7000;
      await file.writeAsString(content);
      
      final parser = TxtParser();
      final result = await parser.parse(file.path);
      
      expect(result.format, EbookFormat.txt);
      expect(result.pages, isNotNull);
      // 7000 chars / 3000 page size = 3 pages (3000, 3000, 1000)
      expect(result.pages!.length, 3);
      expect(result.pages![0].length, 3000);
      expect(result.pages![2].length, 1000);
      
      await tempDir.delete(recursive: true);
    });
  });
}
