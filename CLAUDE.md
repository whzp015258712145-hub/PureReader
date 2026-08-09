# CLAUDE.md - PureReader Guidance & Commands

## Overview
PureReader is a high-performance, native macOS multi-format ebook reader developed in Swift. It provides sub-second startup, smooth native typography rendering, and format support for EPUB, PDF, TXT, MOBI, AZW3, and FB2 formats with native 14-language localization support.

## Quick Commands
- **Working Directory:** `apps/swift-native/`
- **Build (Debug):** `swift build` (run inside `apps/swift-native/`)
- **Build (Release):** `swift build -c release` (run inside `apps/swift-native/`)
- **Run Application:** `swift run` (run inside `apps/swift-native/`)
- **Run Automated Tests:** `swift run PureReaderTests` (run inside `apps/swift-native/`)
- **Launch Script:** `./bin/LaunchSwift.command`
- **Live Reload Development:** `./bin/DevSwift.command` (auto-build & reload on save)
- **Verify GUI Menu Items & Spacing:** `./bin/verify_gui_menu.sh` (AppleScript live GUI menu audit)

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
- **Services:** `FormatDetector` (magic numbers + extensions), `CacheManager`, `ConfigStore`, `LocalizationManager` (14 languages)

## Documentation & Repository Rules
- **Reader-Facing README Mandate:** `README.md` is strictly reader-facing (面向开源读者与终端用户). Keep it clean, polished, concise, and focused on product features, native performance, and user build instructions.
- **Internal Docs Isolation:** All project-internal technical documentation, architecture notes, or temporary developer records MUST be written into `docs/` or `doc/` directories.
- **Git Ignore for Internal Docs:** `docs/` and `doc/` directories MUST be listed in `.gitignore` and kept OUT of git version control.
- **Debug Screenshot Auto-Clean Mandate:** Any temporary debug screenshots (`shot_*.png` or `.tempmediaStorage` caches) captured during visual layout debugging MUST be deleted immediately after viewing/verification so they never accumulate or consume disk space.
- **Code Over Documentation Rule (文档与代码冲突以代码为准):** If there is any discrepancy or conflict between documentation (including markdown files, design notes, or comments) and the actual source code, the executable source code in `apps/swift-native/` is ALWAYS the ultimate source of truth.

## Development & Code Conventions
- **Source of Truth:** Main development path is located under `apps/swift-native/`.
- **AppKit Menu Bar Width & Spacing Rule:** Top-level application menu titles must be concise (e.g., German `Ansicht` instead of `Darstellung`, Spanish `Ver` instead of `Visualización`, `Thema` instead of `Erscheinungsbild`) to keep total menu bar width under 550px, ensuring `Window` and `Help` menus remain tightly grouped on the left without right-alignment gap spillover.
- **Real-App GUI Verification Mandate:** After making changes to menu items or AppKit UI, you MUST execute `./bin/verify_gui_menu.sh` (or AppleScript system events) to verify that the live running macOS process actually renders expected UI elements and that physical menu gaps remain <= 80px before declaring task completion.
- **Process Renewal Mandate:** Launch scripts MUST kill pre-existing instances (`pkill -x PureReader`) before invoking `open "$APP_BUNDLE"`, preventing macOS `open` command from merely focusing a stale process instance.
- **SwiftUI Hot Reloading:** SwiftUI views integrate `@ObserveInjection var inject` and `.enableInjection()`. Builds run with `-Xlinker -interposable` via `./bin/LaunchSwift.command` to enable live code hot reloading without app restarts.
- **Decoupled Architecture:** Maintain `LocalizationManager` (`LocalizationManager.shared`) as the single decoupled source of truth for app localization and AppKit system menu bar updates (`NSApp.mainMenu`).
- **Automated Testing Mandate:** After making any code changes in `apps/swift-native/`, you MUST execute automated tests via `swift run PureReaderTests` and ensure 100% test pass rate before declaring task completion.
- **Base Language First Development Workflow (简体中文优先研发模式):** The primary base development language is Simplified Chinese (`zh-Hans`) (with English `en`). During active feature iteration, implement and verify UI/features using `zh-Hans` first. Do NOT spend cycles translating to all 14 languages for WIP features. Expand translations to all 14 languages in batch prior to release/stabilization milestones.
- **Transcript Audit Rule:** When inspecting history logs (`transcript.jsonl`), never read only the top lines; read tail lines to accurately capture latest context.
