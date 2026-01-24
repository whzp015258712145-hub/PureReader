#!/bin/bash

# 修正：精准定位项目根目录（脚本所在目录的上一级）
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$DIR")"
cd "$PROJECT_ROOT"

echo "------------------------------------------------"
echo "🚀 PureReader 生产级重构启动器"
echo "------------------------------------------------"

# 检查当前是否在正确的目录
if [ ! -f "pubspec.yaml" ]; then
    # 如果上一级不是根目录，尝试当前目录（兼容性处理）
    if [ -f "$DIR/pubspec.yaml" ]; then
        cd "$DIR"
    else
        echo "❌ 错误: 无法定位项目根目录 (未找到 pubspec.yaml)"
        read -p "按回车键退出..."
        exit 1
    fi
fi

echo "🧹 1/3 正在清理旧编译产物..."
flutter clean > /dev/null 2>&1

echo "📦 2/3 正在同步依赖并强制生成代码..."
flutter pub get > /dev/null
# 核心修复：确保在根目录执行生成
flutter gen-l10n > /dev/null

echo "⚡ 3/3 正在以最新配置启动应用..."
flutter run -d macos

echo "------------------------------------------------"
echo "✅ 运行结束"
read -p "按回车键关闭窗口..."