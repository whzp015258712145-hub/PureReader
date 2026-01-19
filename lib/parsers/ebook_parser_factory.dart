import '../models/ebook_format.dart';
import 'ebook_parser.dart';
import 'epub_parser.dart';
import 'pdf_parser.dart';
import 'txt_parser.dart';
import 'mobi_parser.dart';
import 'azw3_parser.dart';

class EbookParserFactory {
  static EbookParser createParser(EbookFormat format) {
    switch (format) {
      case EbookFormat.epub:
        return EpubParser();
      case EbookFormat.pdf:
        return PdfParser();
      case EbookFormat.txt:
        return TxtParser();
      case EbookFormat.mobi:
        return MobiParser();
      case EbookFormat.azw3:
        return Azw3Parser();
      default:
        // Placeholder for other formats until implemented
        throw UnsupportedError('Parser for $format not implemented yet');
    }
  }
}
