import 'dart:collection';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ebook_content.dart';

class CacheManager {
  // Using LinkedHashMap to maintain insertion/access order for LRU
  static final LinkedHashMap<String, EbookContent> _cache = LinkedHashMap<String, EbookContent>();
  static const int _maxCacheEntries = 10;
  static const String _recentBooksKey = 'recent_books_paths';

  static Future<EbookContent?> getCachedContent(String filePath) async {
    if (_cache.containsKey(filePath)) {
      // Move to end (most recently used)
      final content = _cache.remove(filePath)!;
      _cache[filePath] = content;
      return content;
    }
    return null;
  }

  static Future<void> cacheContent(String filePath, EbookContent content) async {
    if (_cache.containsKey(filePath)) {
      _cache.remove(filePath);
    } else if (_cache.length >= _maxCacheEntries) {
      // Remove least recently used (first item)
      _cache.remove(_cache.keys.first);
    }
    _cache[filePath] = content;
    
    // Persist the list of recent paths
    _persistRecentPaths();
  }

  static Future<void> _persistRecentPaths() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final paths = _cache.keys.toList();
      await prefs.setStringList(_recentBooksKey, paths);
    } catch (e) {
      // Silent error for cache persistence
    }
  }

  static Future<List<String>> getRecentPaths() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_recentBooksKey) ?? [];
  }

  static void clearCache() {
    _cache.clear();
    SharedPreferences.getInstance().then((p) => p.remove(_recentBooksKey));
  }
}
