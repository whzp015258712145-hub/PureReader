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
		if name of mItem is in {"语言", "語言", "Language", "Sprache", "Langue", "Idioma", "言語", "언어", "Lingua", "Язык", "Taal", "Język", "Dil"} then
			return name of menu items of menu 1 of mItem
		end if
	end repeat
end tell')

echo "📊 当前菜单栏 [语言] 子菜单实测渲染项:"
echo "   -> $MENU_ITEMS"

# 校验菜单栏项 8 (语言/Language/Sprache) 与项 9 (窗口/Window/Fenster) 之间的物理 X 轴间距 (防止飞到屏幕右侧 bug)
MENU_GAP=$(osascript -e 'tell application "System Events"
	tell process "PureReader"
		set pos8 to position of menu bar item 8 of menu bar 1
		set pos9 to position of menu bar item 9 of menu bar 1
		return (item 1 of pos9) - (item 1 of pos8)
	end tell
end tell')

echo "📏 菜单栏 [语言] -> [窗口] 物理间距实测: ${MENU_GAP}px"

if [[ "$MENU_ITEMS" == "繁體中文, 简体中文, English, Deutsch"* ]] && [ "$MENU_GAP" -le 80 ]; then
  echo "------------------------------------------------"
  echo "🎉 ✅ [GUI Audit SUCCESS] 菜单子项顺序完全准确（1.繁體 2.简体 3.English 4.Deutsch）且顶层菜单无飞右间距 bug（间距: ${MENU_GAP}px <= 80px）！"
  echo "------------------------------------------------"
  exit 0
else
  echo "------------------------------------------------"
  echo "❌ [GUI Audit FAILED] 实测未通过！子项为: $MENU_ITEMS, 间距为: ${MENU_GAP}px"
  echo "------------------------------------------------"
  exit 1
fi
