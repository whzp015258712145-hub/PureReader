import 'dart:io';
import 'package:epub_view/epub_view.dart';
import '../models/ebook_content.dart';
import '../models/ebook_format.dart';
import 'ebook_parser.dart';

class EpubParser implements EbookParser {
  @override
  Future<EbookContent> parse(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }

    // EpubController is initialized here. 
    // Actual loading happens when the controller is attached to the view or document is awaited.
    // For "progressive loading" requirement, passing the Future<EpubBook> (from openFile) 
    // to the controller is correct as per existing code.
    final controller = EpubController(
      document: EpubDocument.openFile(file),
    );
    
    return EbookContent(
      format: EbookFormat.epub,
      controller: controller,
      metadata: {'path': filePath},
    );
  }
}
