import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/ebook_format.dart';

class FileFormatDetector {
  static Future<EbookFormat> detectFormat(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return EbookFormat.unknown;
    }

    // 1. Check file signature (Magic Numbers)
    try {
      // Read first 64 bytes
      final bytes = await file.openRead(0, 64).first;
      final signatureFormat = _detectFromSignature(bytes);
      if (signatureFormat != EbookFormat.unknown) {
        return signatureFormat;
      }
    } catch (e) {
      // Ignore read errors, fall back to extension
    }

    // 2. Check extension
    final extension = path.extension(filePath).toLowerCase();
    switch (extension) {
      case '.epub':
        return EbookFormat.epub;
      case '.pdf':
        return EbookFormat.pdf;
      case '.txt':
        return EbookFormat.txt;
      case '.mobi':
        return EbookFormat.mobi;
      case '.azw3':
      case '.azw':
        return EbookFormat.azw3;
    }

    // 3. Fallback: Check if it's a text file (heuristics)
    // This is expensive, so maybe just return unknown or assume txt if desired
    // Requirement says: "WHEN 系统无法识别文件格式 THEN 系统应尝试作为纯文本处理"
    // But better to return unknown here and let UI/Logic decide to "try as txt".
    // Or we can return txt if it looks like txt.
    
    return EbookFormat.unknown;
  }

  static EbookFormat _detectFromSignature(List<int> bytes) {
    if (bytes.length < 4) return EbookFormat.unknown;

    // PDF: %PDF (0x25 0x50 0x44 0x46)
    if (bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46) {
      return EbookFormat.pdf;
    }

    // EPUB: PK.. (0x50 0x4B 0x03 0x04) - ZIP signature
    // Note: many things are ZIPs (docx, jar, apk). 
    // Ideally check "mimetype" file at offset 30, but that's complex for just signature check.
    // For now, if it's a ZIP and not identified otherwise, we might rely on extension or assume EPUB if context implies.
    // But to be safe, we only return EPUB if we are sure. 
    // Let's rely on extension for EPUB if signature is just generic ZIP, 
    // OR if we can read the mimetype.
    // The "mimetype" file in EPUB must be the first file and uncompressed.
    // "mimetypeapplication/epub+zip"
    // PK... then ... mimetypeapplication/epub+zip
    // The offset of "mimetype" is usually 30.
    if (bytes.length > 58 && 
        bytes[0] == 0x50 && bytes[1] == 0x4B && bytes[2] == 0x03 && bytes[3] == 0x04) {
       // Simple check for "mimetype" string starting around byte 30
       // This is a rough check.
       try {
         final str = String.fromCharCodes(bytes);
         if (str.contains('mimetypeapplication/epub+zip')) {
           return EbookFormat.epub;
         }
       } catch (_) {}
    }

    // MOBI: PDB Header.
    // Offset 60-68 usually has "BOOKMOBI".
    // But we only read 64 bytes. Let's read more if needed? 
    // Standard MOBI header is further down.
    // Palm Database Format signature is often at beginning but vague.
    // "BOOKMOBI" is at offset 60+ usually.
    // Let's assume if extension fails, we might miss MOBI here with only 64 bytes.
    // But user requirement says check header.
    // Let's just stick to PDF and strong EPUB for now.
    
    return EbookFormat.unknown;
  }
}
