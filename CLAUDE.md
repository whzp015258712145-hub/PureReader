# CLAUDE.md - PureReader Guidance & Commands

## Overview
PureReader is a high-performance, native macOS multi-format ebook reader developed in Swift. It provides sub-second startup, smooth native typography rendering, and format support for EPUB, PDF, TXT, MOBI, AZW3, and FB2 formats.

## Quick Commands
- **Working Directory:** `apps/swift-native/`
- **Build (Debug):** `swift build` (run inside `apps/swift-native/`)
- **Build (Release):** `swift build -c release` (run inside `apps/swift-native/`)
- **Run Application:** `swift run` (run inside `apps/swift-native/`)
- **Launch Script:** `./bin/LaunchSwift.command`

## Technology Stack & Architecture
- **Language & UI:** Swift 5.9+, SwiftUI, AppKit
- **Platforms:** macOS 13.0+
- **Dependencies:** ZIPFoundation (EPUB ZIP extraction)
- **Web Rendering Engine:** WebKit (`WKWebView`) with `HTMLTemplateBuilder` CSS variable injection
- **PDF Engine:** Quartz PDFKit (`PDFView`)
- **Parsers & Decoders:**
  - `EPUBParser` & `EPUBToHTMLConverter`
  - `MOBIParser` (supported by `PDBDecoder` and `PalmDocDecompressor`)
  - `FB2Parser`, `TXTParser`, `PDFParser`
- **Services:** `FormatDetector` (magic numbers + extensions), `CacheManager`, `ConfigStore`

## Development Conventions
- **Source of Truth:** Main development path is located under `apps/swift-native/`.
- **OpenSpec & Specs:** Follow OpenSpec standards; maintain `openspec/project.md` as the primary project source of truth and update specs in `openspec/` prior to major structural changes.
- **Modularity:** Parsers and decoders must be kept decoupled and single-responsibility.
- **HTML/CSS Generation:** All WebKit HTML wrappers must be generated through `HTMLTemplateBuilder` to enforce centralized theme, typography, and bridge script contracts.
- **Code Style:** Pure Swift 5.9 conventions, strict MainActor annotations on ViewModels, clean SwiftUI property wrappers.

