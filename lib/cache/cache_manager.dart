import '../models/ebook_content.dart';

class CacheManager {
  // Simple in-memory cache for now.
  // In a real app, this should probably use Hive or SQLite for metadata, 
  // and file system for cached parsed content (like unzipped epub images).
  static final Map<String, EbookContent> _memoryCache = {};
  static const int _maxCacheEntries = 5;

  static Future<EbookContent?> getCachedContent(String filePath) async {
    return _memoryCache[filePath];
  }

  static Future<void> cacheContent(String filePath, EbookContent content) async {
    if (_memoryCache.length >= _maxCacheEntries) {
      // Simple FIFO eviction for prototype
      _memoryCache.remove(_memoryCache.keys.first);
    }
    _memoryCache[filePath] = content;
  }

  static void clearCache() {
    _memoryCache.clear();
  }
}
