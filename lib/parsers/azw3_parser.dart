import '../models/ebook_content.dart';
import '../models/ebook_format.dart';
import 'ebook_parser.dart';
import 'mobi_parser.dart';

class Azw3Parser implements EbookParser {
  final _mobiParser = MobiParser();

  @override
  Future<EbookContent> parse(String filePath) async {
    // AZW3 is often KF8, which is a newer MOBI format. 
    // We try to use the Mobi parser.
    final content = await _mobiParser.parse(filePath);
    
    // Return content with correct format enum
    return EbookContent(
      format: EbookFormat.azw3,
      controller: content.controller,
      metadata: content.metadata,
      textContent: content.textContent,
    );
  }
}