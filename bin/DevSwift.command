#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import time
import subprocess

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SWIFT_ROOT = os.path.join(PROJECT_ROOT, "apps", "swift-native")
SOURCES_DIR = os.path.join(SWIFT_ROOT, "PureReaderNative")

def get_mtime_hash():
    mtimes = []
    for root, _, files in os.walk(SOURCES_DIR):
        for f in files:
            if f.endswith(".swift") or f.endswith(".strings"):
                path = os.path.join(root, f)
                try:
                    mtimes.append(os.path.getmtime(path))
                except OSError:
                    pass
    return max(mtimes) if mtimes else 0

print("------------------------------------------------")
print("🔥 [DevSwift] 开启 PureReader 实时保存自动热重载 (Live Reload)")
print(f"👀 正在监听源码目录: {SOURCES_DIR}")
print("💡 提示：在编辑器中修改并保存任意 .swift 文件，软件将自动增量编译并秒级刷新！")
print("------------------------------------------------")

last_hash = get_mtime_hash()

# 首次编译并启动应用
launch_cmd = os.path.join(PROJECT_ROOT, "bin", "LaunchSwift.command")
subprocess.run(["chmod", "+x", launch_cmd])
subprocess.run([launch_cmd], cwd=PROJECT_ROOT)

try:
    while True:
        time.sleep(0.5)
        current_hash = get_mtime_hash()
        if current_hash > last_hash:
            last_hash = current_hash
            print("\n⚡️ 检测到源码文件变动，正在增量编译并刷新 PureReader.app...")
            build_res = subprocess.run(
                ["swift", "build", "--package-path", SWIFT_ROOT, "-Xlinker", "-interposable"],
                cwd=SWIFT_ROOT
            )
            if build_res.returncode == 0:
                app_bundle = os.path.join(SWIFT_ROOT, ".build", "PureReader.app")
                bin_src = os.path.join(SWIFT_ROOT, ".build", "debug", "PureReader")
                bin_dst = os.path.join(app_bundle, "Contents", "MacOS", "PureReader")
                subprocess.run(["cp", bin_src, bin_dst])
                subprocess.run(["open", app_bundle])
                print("✅ [Live Reload] 增量刷新完成！")
            else:
                print("❌ [Live Reload] 编译包含语法错误，已暂停刷新。请修改后重新保存。")
except KeyboardInterrupt:
    print("\n👋 已停止热重载监听。")
