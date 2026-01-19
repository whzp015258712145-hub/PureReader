import 'package:pdfx/pdfx.dart';
import '../models/ebook_content.dart';
import '../models/ebook_format.dart';
import 'ebook_parser.dart';

class PdfParser implements EbookParser {
  @override
  Future<EbookContent> parse(String filePath) async {
    // Open the PDF document
    final document = await PdfDocument.openFile(filePath);
    
    return EbookContent(
      format: EbookFormat.pdf,
      controller: document,
      pageCount: document.pagesCount,
      metadata: {'path': filePath},
    );
  }
}
