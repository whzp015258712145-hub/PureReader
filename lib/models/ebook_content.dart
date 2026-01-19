import 'ebook_format.dart';

class EbookContent {
  final EbookFormat format;
  final String? textContent; // For TXT
  final List<String>? pages; // For TXT pagination
  final String? htmlContent; // For MOBI/AZW3
  final dynamic controller; // For EPUB (EpubController) or PDF
  final int? pageCount;
  final Map<String, dynamic>? metadata;
  
  EbookContent({
    required this.format,
    this.textContent,
    this.pages,
    this.htmlContent,
    this.controller,
    this.pageCount,
    this.metadata,
  });
}
