//
//  LocalizationManagerTests.swift
//  PureReaderTests
//
//  Created by OpenSpec on 2026-03-24.
//

import Foundation
import PureReaderCore

@main
struct LocalizationManagerTests {

    static func main() async {
        print("------------------------------------------------")
        print("🧪 [PureReader Test Runner] Starting Automated Unit Tests...")
        print("------------------------------------------------")

        var passedCount = 0
        var failedCount = 0

        func runTest(_ name: String, block: () async throws -> Void) async {
            do {
                try await block()
                passedCount += 1
                print("  ✅ \(name) PASSED")
            } catch {
                failedCount += 1
                print("  ❌ \(name) FAILED: \(error)")
            }
        }

        func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String, file: String = #file, line: Int = #line) throws {
            if actual != expected {
                throw TestFailure(message: "Assertion Failed: expected '\(expected)', got '\(actual)'. \(message) (\(file):\(line))")
            }
        }

        func assertTrue(_ condition: Bool, _ message: String, file: String = #file, line: Int = #line) throws {
            if !condition {
                throw TestFailure(message: "Assertion Failed: expected true. \(message) (\(file):\(line))")
            }
        }

        let manager = await LocalizationManager.shared

        // Test 1: Language enum parsing
        await runTest("testLanguageEnumParsing") {
            try assertEqual(AppLanguage.from(localeString: "en"), .english, "en -> english")
            try assertEqual(AppLanguage.from(localeString: "en_US"), .english, "en_US -> english")
            try assertEqual(AppLanguage.from(localeString: "zh"), .simplifiedChinese, "zh -> chinese")
            try assertEqual(AppLanguage.from(localeString: "zh-Hans"), .simplifiedChinese, "zh-Hans -> chinese")
            try assertEqual(AppLanguage.from(localeString: "unknown"), .english, "fallback -> english")
        }

        // Test 2: English Localization
        await runTest("testEnglishLocalization") {
            await manager.setLanguage(.english)
            try assertEqual(manager.currentLanguage, .english, "Language is English")
            try assertEqual(manager.string(for: "file"), "File", "file key")
            try assertEqual(manager.string(for: "edit"), "Edit", "edit key")
            try assertEqual(manager.string(for: "view"), "View", "view key")
            try assertEqual(manager.string(for: "window"), "Window", "window key")
            try assertEqual(manager.string(for: "help"), "Help", "help key")
            try assertEqual(manager.string(for: "open_file"), "Open...", "open_file key")
            try assertEqual(manager.string(for: "encoding"), "Encoding", "encoding key")
            try assertEqual(manager.string(for: "zoom_in"), "Zoom In", "zoom_in key")
            try assertEqual(manager.string(for: "zoom_out"), "Zoom Out", "zoom_out key")
            try assertEqual(manager.string(for: "actual_size"), "Actual Size", "actual_size key")
            try assertEqual(manager.string(for: "toggle_sidebar"), "Toggle Sidebar", "toggle_sidebar key")
            try assertEqual(manager.string(for: "theme"), "Theme", "theme key")
            try assertEqual(manager.string(for: "language"), "Language", "language key")
            try assertEqual(manager.string(for: "theme_day"), "Day", "theme_day key")
            try assertEqual(manager.string(for: "theme_night"), "Night", "theme_night key")
            try assertEqual(manager.string(for: "theme_muji"), "Muji", "theme_muji key")
            try assertEqual(manager.string(for: "theme_forest"), "Forest", "theme_forest key")
        }

        // Test 3: Simplified Chinese Localization
        await runTest("testSimplifiedChineseLocalization") {
            await manager.setLanguage(.simplifiedChinese)
            try assertEqual(manager.currentLanguage, .simplifiedChinese, "Language is Chinese")
            try assertEqual(manager.string(for: "file"), "文件", "file key")
            try assertEqual(manager.string(for: "edit"), "编辑", "edit key")
            try assertEqual(manager.string(for: "view"), "显示", "view key")
            try assertEqual(manager.string(for: "window"), "窗口", "window key")
            try assertEqual(manager.string(for: "help"), "帮助", "help key")
            try assertEqual(manager.string(for: "open_file"), "打开...", "open_file key")
            try assertEqual(manager.string(for: "encoding"), "编码", "encoding key")
            try assertEqual(manager.string(for: "zoom_in"), "放大", "zoom_in key")
            try assertEqual(manager.string(for: "zoom_out"), "缩小", "zoom_out key")
            try assertEqual(manager.string(for: "actual_size"), "实际大小", "actual_size key")
            try assertEqual(manager.string(for: "toggle_sidebar"), "切换侧边栏", "toggle_sidebar key")
            try assertEqual(manager.string(for: "theme"), "外观主题", "theme key")
            try assertEqual(manager.string(for: "language"), "语言", "language key")
            try assertEqual(manager.string(for: "theme_day"), "日光", "theme_day key")
            try assertEqual(manager.string(for: "theme_night"), "夜间", "theme_night key")
            try assertEqual(manager.string(for: "theme_muji"), "纸感", "theme_muji key")
            try assertEqual(manager.string(for: "theme_forest"), "护眼", "theme_forest key")
        }

        // Test 4: All Keys Completeness
        await runTest("testAllKeysCompleteness") {
            let allKeys = [
                "file", "edit", "view", "window", "help", "open_file", "encoding", "zoom_in", "zoom_out",
                "actual_size", "toggle_sidebar", "theme", "language",
                "theme_day", "theme_night", "theme_muji", "theme_forest",
                "toc", "no_chapters", "no_chapters_subtitle", "appearance",
                "font_family", "font_size", "line_height", "ok", "open", "retry", "unsupported_format"
            ]

            for lang in AppLanguage.allCases {
                await manager.setLanguage(lang)
                for key in allKeys {
                    let localized = manager.string(for: key)
                    try assertTrue(!localized.isEmpty, "Key '\(key)' should not be empty in \(lang.rawValue)")
                    try assertTrue(localized != key, "Key '\(key)' missing translation in \(lang.rawValue)")
                }
            }
        }

        print("------------------------------------------------")
        if failedCount == 0 {
            print("🎉 ALL \(passedCount) TEST SUITES PASSED (100% SUCCESS)")
            print("------------------------------------------------")
            exit(0)
        } else {
            print("❌ \(failedCount) TEST SUITE(S) FAILED out of \(passedCount + failedCount)")
            print("------------------------------------------------")
            exit(1)
        }
    }
}

struct TestFailure: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
}
