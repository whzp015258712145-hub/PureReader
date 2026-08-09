#!/bin/bash

# PureReader Swift Native 启动脚本
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$DIR")"
SWIFT_ROOT="$PROJECT_ROOT/apps/swift-native"

cd "$SWIFT_ROOT"

echo "------------------------------------------------"
echo "🚀 启动 Swift Native 版本 (apps/swift-native)"
echo "------------------------------------------------"

# 优先编译并打包成 macOS App Bundle 运行（确保 macOS 顶部菜单栏正确显示为 PureReader）
if [ -f "$SWIFT_ROOT/Package.swift" ]; then
  echo "📦 正在编译 Swift Package (已开启 Inject 热重载支持)..."
  swift build --package-path "$SWIFT_ROOT" -Xlinker -interposable


  APP_BUNDLE="$SWIFT_ROOT/.build/PureReader.app"
  mkdir -p "$APP_BUNDLE/Contents/MacOS"
  mkdir -p "$APP_BUNDLE/Contents/Resources"

  cp "$SWIFT_ROOT/.build/debug/PureReader" "$APP_BUNDLE/Contents/MacOS/PureReader"

  # 同步 Swift SPM 编译出的所有资源 Bundle（包含 Localizable.strings 语言包）
  cp -R "$SWIFT_ROOT/.build/debug/"*.bundle "$APP_BUNDLE/Contents/Resources/" 2>/dev/null || true

  # 写入/生成 Info.plist，使顶部菜单栏显示为 PureReader 并支持菜单调试与文件关联
  if [ -f "$SWIFT_ROOT/PureReaderNative/Resources/Info.plist" ]; then
    sed -e 's/\$(EXECUTABLE_NAME)/PureReader/g' \
        -e 's/\$(PRODUCT_NAME)/PureReader/g' \
        -e 's/\$(PRODUCT_BUNDLE_IDENTIFIER)/com.purereader.app/g' \
        -e 's/\$(DEVELOPMENT_LANGUAGE)/en/g' \
        -e 's/\$(MARKETING_VERSION)/1.0.0/g' \
        -e 's/\$(CURRENT_PROJECT_VERSION)/1/g' \
        -e 's/\$(MACOSX_DEPLOYMENT_TARGET)/13.0/g' \
        -e 's/\$(PRODUCT_COPYRIGHT)/Copyright © 2026/g' \
        "$SWIFT_ROOT/PureReaderNative/Resources/Info.plist" > "$APP_BUNDLE/Contents/Info.plist"
  fi

  # 杀死可能滞留的旧 PureReader 进程，避免 macOS open 命令仅置顶旧 PID 实例
  pkill -x PureReader 2>/dev/null || true
  sleep 0.2

  echo "✨ 启动 PureReader.app..."
  open "$APP_BUNDLE"

  echo "------------------------------------------------"
  echo "✅ PureReader 已启动！"
  exit 0
fi


# 其次打开 Xcode 工程
XCODEPROJ=$(ls "$SWIFT_ROOT"/*.xcodeproj 2>/dev/null | head -n 1 || true)
if [ -n "$XCODEPROJ" ]; then
  echo "🛠 未检测到 Package.swift，打开 Xcode 工程..."
  open "$XCODEPROJ"
  echo "请在 Xcode 中点击 ▶︎ 运行"
  read -p "按回车键关闭窗口..."
  exit 0
fi

# 当前只有源码目录时，直接打开源码目录给你运行
echo "⚠️ 未检测到可直接运行入口（Package.swift / .xcodeproj）"
echo "将打开 Swift 源码目录，请在 Xcode 中创建或打开工程后运行。"
open "$SWIFT_ROOT"
read -p "按回车键关闭窗口..."

