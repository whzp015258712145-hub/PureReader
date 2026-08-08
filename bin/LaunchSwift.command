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

# 优先命令行运行 Swift Package
if [ -f "$SWIFT_ROOT/Package.swift" ]; then
  echo "📦 检测到 Package.swift，使用 swift run 启动..."
  swift run --package-path "$SWIFT_ROOT"
  echo "------------------------------------------------"
  echo "✅ Swift Native 版本已退出"
  read -p "按回车键关闭窗口..."
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

