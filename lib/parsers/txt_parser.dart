import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:charset_converter/charset_converter.dart';
import '../models/ebook_content.dart';
import '../models/ebook_format.dart';
import '../formats/encoding_detector.dart';
import 'ebook_parser.dart';

// Top-level function for isolate
String _decodeUtf8(Uint8List bytes) => utf8.decode(bytes, allowMalformed: true);

class TxtParser implements EbookParser {
  final String? explicitEncoding;

  TxtParser({this.explicitEncoding});

  @override
  Future<EbookContent> parse(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    
    // Detect encoding or use explicit one
    String encoding = explicitEncoding ?? await EncodingDetector.detectEncoding(bytes);
    debugPrint('Using encoding for $filePath: $encoding (Explicit: ${explicitEncoding != null})');
    
    String content;
    if (encoding.toLowerCase() == 'utf-8') {
      content = await compute(_decodeUtf8, bytes);
    } else {
      try {
        content = await CharsetConverter.decode(encoding, bytes);
      } catch (e) {
        debugPrint('Error decoding with $encoding, trying fallback...');
        content = await CharsetConverter.decode("gbk", bytes);
      }
    }

    // Split into pages (Naive implementation for now)
    // In a real reader, this should be done based on text layout metrics.
    // Here we split by character count to support "pagination" requirement 4.1 loosely.
    final pages = await compute(_paginate, content);

    return EbookContent(
      format: EbookFormat.txt,
      textContent: content,
      pages: pages,
      pageCount: pages.length,
      metadata: {'path': filePath, 'encoding': encoding},
    );
  }
  
  static List<String> _paginate(String content) {
    const pageSize = 3000;
    List<String> pages = [];
    for (int i = 0; i < content.length; i += pageSize) {
      int end = (i + pageSize < content.length) ? i + pageSize : content.length;
      pages.add(content.substring(i, end));
    }
    return pages;
  }
}
