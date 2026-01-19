import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:purereader/formats/file_format_detector.dart';
import 'package:purereader/models/ebook_format.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('format_test_');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  group('Property 15: Intelligent Format Detection', () {
    test('Should detect format by extension', () async {
      final file = File(path.join(tempDir.path, 'book.epub'));
      await file.writeAsBytes([0x00]); // Dummy content
      expect(await FileFormatDetector.detectFormat(file.path), EbookFormat.epub);
      
      final file2 = File(path.join(tempDir.path, 'book.pdf'));
      await file2.writeAsBytes([0x00]);
      expect(await FileFormatDetector.detectFormat(file2.path), EbookFormat.pdf);
    });

    test('Should detect format by signature (PDF)', () async {
      final file = File(path.join(tempDir.path, 'wrong_extension.txt'));
      // PDF Signature: %PDF
      await file.writeAsBytes([0x25, 0x50, 0x44, 0x46, 0x00, 0x00]);
      expect(await FileFormatDetector.detectFormat(file.path), EbookFormat.pdf);
    });

    test('Should return unknown for non-existent file', () async {
      expect(
        await FileFormatDetector.detectFormat(path.join(tempDir.path, 'missing.epub')),
        EbookFormat.unknown,
      );
    });
    
    // Test Property 16: Fallback (which is partially implemented by returning unknown or handling later)
    // The requirement says "Attempt to process as plain text".
    // Detection returns unknown, then Parser logic handles it.
  });
}
