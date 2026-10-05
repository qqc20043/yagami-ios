#!/usr/bin/env bash
# 本地预检：在没有 Xcode 的机器上也能跑的那部分。
#
# 完整的 iOS 构建必须 macOS + Xcode，本脚本只覆盖能在 Linux/Windows 上验证的检查，
# 让「推上去才发现 Rust 编不过」这类问题提前暴露。
#
# 用法：bash scripts/preflight.sh

set -euo pipefail

cd "$(dirname "$0")/.."

echo "== Rust 格式 =="
cargo fmt --all --check

echo "== Rust 编译检查 =="
cargo check -p yagami-ios-native

echo "== Rust lint =="
cargo clippy -p yagami-ios-native --all-targets -- -D warnings

echo "== C 头文件与 Rust 导出符号是否一一对应 =="
# 这条检查的价值：头文件与实现不同步时编译器不会报错，
# Swift 拿到错误的调用约定后运行时才崩，且崩在键盘扩展里很难查。
HEADER="apps/ios/native/include/yagami_ios.h"
LIB="apps/ios/native/src/lib.rs"

header_functions=$(grep -oE '\byagami_[a-z_]+' "$HEADER" | sort -u)
rust_functions=$(grep -oE 'pub (unsafe )?extern "C" fn (yagami_[a-z_]+)' -r "$LIB" \
    | grep -oE 'yagami_[a-z_]+' | sort -u)

missing_in_rust=$(comm -23 <(echo "$header_functions") <(echo "$rust_functions") || true)
missing_in_header=$(comm -13 <(echo "$header_functions") <(echo "$rust_functions") || true)

if [ -n "$missing_in_rust" ]; then
    echo "头文件声明了但 Rust 没实现："
    echo "$missing_in_rust"
    exit 1
fi
if [ -n "$missing_in_header" ]; then
    echo "Rust 实现了但头文件没声明："
    echo "$missing_in_header"
    exit 1
fi
echo "C ABI 一致（$(echo "$header_functions" | wc -l | tr -d ' ') 个函数）"

echo "== project.yml 引用的文件是否都存在 =="
for path in apps/ios/app/Info.plist apps/ios/keyboard/Info.plist \
            apps/ios/app/Yagami.entitlements apps/ios/keyboard/YagamiKeyboard.entitlements \
            apps/ios/native/include/yagami_ios.h; do
    if [ ! -f "$path" ]; then
        echo "缺少 $path"
        exit 1
    fi
done
echo "工程描述引用的文件齐全"

echo
echo "预检通过。完整构建需要 macOS + Xcode，见 .github/workflows/ios.yml"
