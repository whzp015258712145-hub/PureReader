//
//  CacheManager.swift
//  PureReader
//
//  Created by OpenSpec on 2026-03-23.
//
//  对应 Flutter: lib/cache/cache_manager.dart
//  内存缓存使用 NSCache（对应 Flutter 的 LinkedHashMap LRU 实现）
//  最近打开路径列表持久化到 UserDefaults，key: "recent_books_paths"
//

import Foundation

final class CacheManager {

    // MARK: - Private state

    /// NSCache 作为内存缓存，系统内存不足时自动淘汰
    /// 对应 Flutter cache_manager.dart 的 _cache = LinkedHashMap
    private let cache = NSCache<NSString, CacheEntry>()

    /// UserDefaults key，与 Flutter cache_manager.dart 的 SharedPreferences key 一致
    private let recentKey = "recent_books_paths"

    /// 最近打开顺序（尾部为最新），与 NSCache 并行维护
    /// 对应 Flutter _cache 的插入顺序
    private var recentOrder: [String] = []

    /// 最大缓存条目数，对应 Flutter `_maxCacheEntries = 10`
    private let maxEntries = 10

    // MARK: - Init

    init() {
        cache.countLimit = maxEntries
        // 从 UserDefaults 恢复最近打开路径列表
        recentOrder = UserDefaults.standard.stringArray(forKey: recentKey) ?? []
    }

    // MARK: - Public interface

    /// 获取缓存内容。
    /// EPUB 格式不缓存（对应 Flutter cache_manager.dart 的 EPUB 排除逻辑）
    /// 未命中或已淘汰返回 nil。
    func get(path: String) -> EbookContent? {
        guard let entry = cache.object(forKey: path as NSString) else { return nil }
        return entry.content
    }

    /// 写入缓存。
    /// EPUB 格式不缓存（htmlContent 可能超大，且每次打开需重新解析）
    /// 对应 Flutter: if (content.format == EbookFormat.epub) return;
    func set(path: String, content: EbookContent) {
        // EPUB 不缓存
        guard content.format != .epub else { return }
        cache.setObject(CacheEntry(content: content), forKey: path as NSString)
        updateRecentOrder(path: path)
    }

    /// 移除指定路径的缓存条目。
    func remove(path: String) {
        cache.removeObject(forKey: path as NSString)
        // recentOrder 保留（最近打开路径不因移除缓存而丢失）
    }

    /// 清空所有缓存及最近打开路径列表。
    /// 对应 Flutter CacheManager.clear()
    func clear() {
        cache.removeAllObjects()
        recentOrder.removeAll()
        UserDefaults.standard.removeObject(forKey: recentKey)
    }

    /// 返回最近打开路径列表（尾部为最新，最多 maxEntries 条）。
    /// 对应 Flutter CacheManager.getRecentPaths()
    func recentPaths() -> [String] {
        return recentOrder
    }

    // MARK: - Private helpers

    /// 维护最近打开顺序并持久化到 UserDefaults。
    /// 对应 Flutter cache_manager.dart 的 LRU 插入逻辑：
    ///   先移除旧条目，再追加到尾部，超出 maxEntries 时移除头部。
    private func updateRecentOrder(path: String) {
        recentOrder.removeAll { $0 == path }
        recentOrder.append(path)
        if recentOrder.count > maxEntries {
            recentOrder.removeFirst()
        }
        UserDefaults.standard.set(recentOrder, forKey: recentKey)
    }
}

// MARK: - NSCache value wrapper

/// NSCache 要求值类型为 AnyObject，用此 wrapper 包装 EbookContent
private final class CacheEntry: NSObject {
    let content: EbookContent
    init(content: EbookContent) {
        self.content = content
    }
}


