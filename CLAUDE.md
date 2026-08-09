# CLAUDE.md - PureReader Guidance & Commands

## Overview
PureReader is a high-performance, native macOS multi-format ebook reader developed in Swift. It provides sub-second startup, smooth native typography rendering, and format support for EPUB, PDF, TXT, MOBI, AZW3, and FB2 formats.

## Quick Commands
- **Working Directory:** `apps/swift-native/`
- **Build (Debug):** `swift build` (run inside `apps/swift-native/`)
- **Build (Release):** `swift build -c release` (run inside `apps/swift-native/`)
- **Run Application:** `swift run` (run inside `apps/swift-native/`)
- **Run Automated Tests:** `swift run PureReaderTests` (run inside `apps/swift-native/`)
- **Launch Script:** `./bin/LaunchSwift.command`
- **Live Reload Development:** `./bin/DevSwift.command` (auto-build & reload on save)


## Technology Stack & Architecture
- **Language & UI:** Swift 5.9+, SwiftUI, AppKit
- **Platforms:** macOS 13.0+
- **Dependencies:** ZIPFoundation (EPUB ZIP extraction), Inject (SwiftUI Hot Reloading)
- **Web Rendering Engine:** WebKit (`WKWebView`) with `HTMLTemplateBuilder` CSS variable injection
- **PDF Engine:** Quartz PDFKit (`PDFView`)
- **Parsers & Decoders:**
  - `EPUBParser` & `EPUBToHTMLConverter`
  - `MOBIParser` (supported by `PDBDecoder` and `PalmDocDecompressor`)
  - `FB2Parser`, `TXTParser`, `PDFParser`
- **Services:** `FormatDetector` (magic numbers + extensions), `CacheManager`, `ConfigStore`, `LocalizationManager`

## Development Conventions
- **Source of Truth:** Main development path is located under `apps/swift-native/`.
- **OpenSpec & Specs:** Follow OpenSpec standards; maintain `openspec/project.md` as the primary project source of truth and update specs in `openspec/` prior to major structural changes.
- **SwiftUI Hot Reloading:** SwiftUI views integrate `@ObserveInjection var inject` and `.enableInjection()`. Builds run with `-Xlinker -interposable` via `./bin/LaunchSwift.command` to enable live code hot reloading without app restarts.
- **Decoupled Architecture:** Maintain `LocalizationManager` (`LocalizationManager.shared`) as the single decoupled source of truth for app localization and AppKit system menu bar updates (`NSApp.mainMenu`).
- **Automated Testing Mandate:** After making any code changes in `apps/swift-native/`, you MUST execute automated tests via `swift run PureReaderTests` and ensure 100% test pass rate before declaring task completion.
- **Modularity:** Parsers and decoders must be kept decoupled and single-responsibility.
- **HTML/CSS Generation:** All WebKit HTML wrappers must be generated through `HTMLTemplateBuilder` to enforce centralized theme, typography, and bridge script contracts.
- **查看历史记忆/日志规范 (Transcript Audit Rule):** 在检索或复盘历史对话日志 (`transcript.jsonl`) 时，严禁仅读取文件顶部的初始记录，必须优先读取文件尾部 (Tail Lines) 或更高行数范围，以确保准确捕获最新交互上下文与开发记录。
- **Code Style:** Pure Swift 5.9 conventions, strict MainActor annotations on ViewModels, clean SwiftUI property wrappers.
