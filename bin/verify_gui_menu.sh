#!/bin/bash
# PureReader GUI Menu Bar Automated Verification Script
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$DIR")"

echo "------------------------------------------------"
echo "🔍 [GUI Audit] 正在对运行中的 PureReader 菜单栏进行 AppleScript 真实渲染校验..."
echo "------------------------------------------------"

# 检查 PureReader 进程是否在运行，若未运行则启动
if ! pgrep -x PureReader > /dev/null; then
  echo "⚠️ PureReader 进程未运行，正在唤起..."
  "$PROJECT_ROOT/bin/LaunchSwift.command"
  sleep 1.5
fi

# 抓取当前“语言”菜单下的所有实际子菜单项名称
MENU_ITEMS=$(osascript -e 'tell application "System Events"
	repeat with mItem in menu bar items of menu bar 1 of process "PureReader"
		if name of mItem is in {"语言", "Language", "Sprache", "Langue", "Idioma", "言語", "언어", "Lingua", "Язык", "Taal", "Język", "Dil"} then
			return name of menu items of menu 1 of mItem
		end if
	end repeat
end tell')

echo "📊 当前菜单栏 [语言] 子菜单实测渲染项:"
echo "   -> $MENU_ITEMS"

if [[ "$MENU_ITEMS" == *"English"* ]] && [[ "$MENU_ITEMS" == *"简体中文"* ]] && [[ "$MENU_ITEMS" == *"繁體中文"* ]] && [[ "$MENU_ITEMS" == *"Deutsch"* ]] && [[ "$MENU_ITEMS" == *"Français"* ]] && [[ "$MENU_ITEMS" == *"Español"* ]] && [[ "$MENU_ITEMS" == *"日本語"* ]] && [[ "$MENU_ITEMS" == *"한국어"* ]] && [[ "$MENU_ITEMS" == *"Italiano"* ]] && [[ "$MENU_ITEMS" == *"Русский"* ]] && [[ "$MENU_ITEMS" == *"Português"* ]] && [[ "$MENU_ITEMS" == *"Nederlands"* ]] && [[ "$MENU_ITEMS" == *"Polski"* ]] && [[ "$MENU_ITEMS" == *"Türkçe"* ]]; then
  echo "------------------------------------------------"
  echo "🎉 ✅ [GUI Audit SUCCESS] 实测渲染包含完整 14 种语言选项：English, 简体中文, 繁體中文, Deutsch, Français, Español, 日本語, 한국어, Italiano, Русский, Português, Nederlands, Polski, Türkçe！"
  echo "------------------------------------------------"
  exit 0
else
  echo "------------------------------------------------"
  echo "❌ [GUI Audit FAILED] 实测渲染未满足预期！完整子项为: $MENU_ITEMS"
  echo "------------------------------------------------"
  exit 1
fi
