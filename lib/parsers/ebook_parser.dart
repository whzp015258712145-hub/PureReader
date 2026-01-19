import '../models/ebook_content.dart';

abstract class EbookParser {
  Future<EbookContent> parse(String filePath);
  
  // Stream<double> get progressStream; // Optional enhancement
}
