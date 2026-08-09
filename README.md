# PureReader 📖

**PureReader** 是一款专为 macOS 打造的高性能、原生的多格式电子书阅读器。采用 **Swift (SwiftUI + AppKit + WebKit + PDFKit)** 编写，致力于提供极致流畅的阅读体验、毫秒级的开卷速度与优雅的排版。

---

## 🌟 核心特性

- **多格式原生支持**：支持 EPUB, PDF, TXT, MOBI, AZW3, FB2 格式。
- **14 种全球语言原生支持**：
  - 繁體中文、简体中文、English、Deutsch、Français、Español、日本語、한국어、Italiano、Русский、Português、Nederlands、Polski、Türkçe。
  - 支持系统级 AppKit 菜单栏与应用 UI 实时无缝无卡顿切换。
- **高性能原生渲染**：
  - 基于 WebKit (`WKWebView`) 的 EPUB / MOBI / AZW3 / FB2 自适应排版，窗口缩放响应时间 < 5ms。
  - 基于 Quartz PDFKit 的原生 PDF 渲染。
- **智能格式检测与编码识别**：
  - 基于文件头魔数 (Magic Numbers) 与扩展名的智能格式识别。
  - 自动识别 TXT 编码（UTF-8, GBK, Shift-JIS, Windows-1252/1251）。
- **个性化阅读体验**：
  - 内置多种经典阅读主题（日间、夜间、无印、森林）。
  - 支持字号、行高、字体族实时无缝调整。
  - 目录 (TOC) 侧边栏平滑跳转。

---

## 🛠️ 构建与运行

### 系统要求
- macOS 13.0 (Ventura) 或更高版本
- Xcode 15.0+ / Swift 5.9+

### 命令行运行
```bash
# 进入 Swift 原生工程路径
cd apps/swift-native

# 编译工程 (Debug)
swift build

# 运行自动化测试 (19 组测试套件 100% 通过)
swift run PureReaderTests

# 运行应用
swift run
```

### 一键脚本启动
在 Finder 中双击或在终端中运行：
```bash
./bin/LaunchSwift.command
```
