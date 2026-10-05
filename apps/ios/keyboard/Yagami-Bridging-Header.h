// Yagami-Bridging-Header.h
// 主 App 的 Swift ↔ Rust C ABI 桥接头。
//
// 键盘扩展 target 也要在 Build Settings 里指向本文件
// （SWIFT_OBJC_BRIDGING_HEADER），否则 Swift 看不到 yagami_engine_* 函数。

#ifndef YAGAMI_BRIDGING_HEADER_H
#define YAGAMI_BRIDGING_HEADER_H

#include "yagami_ios.h"

#endif /* YAGAMI_BRIDGING_HEADER_H */
