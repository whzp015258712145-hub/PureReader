import 'dart:io';
// import 'package:mobi/mobi.dart'; // Package not available
import '../models/ebook_content.dart';
import '../models/ebook_format.dart';
import 'ebook_parser.dart';

class MobiParser implements EbookParser {
  @override
  Future<EbookContent> parse(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }
    
    // MobiFile from package 'mobi' is not available.
    // Placeholder implementation.
    // In a real app, we would implement a PalmDOC/MOBI header parser here.
    
    return EbookContent(
      format: EbookFormat.mobi,
      controller: null, 
      metadata: {'path': filePath, 'status': 'Parsing not supported yet'},
      textContent: "MOBI parsing is currently disabled due to missing dependency.",
    );
  }
}