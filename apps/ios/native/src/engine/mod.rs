//! iOS 侧持有的 Core 实例；装配与查询分别放在子模块。

mod querying;
mod setup;

use qingjian_core::Engine;

/// iOS 键盘扩展持有的引擎。
///
/// `pub` 是给 C ABI 的：`pub extern "C"` 函数的签名带 `*mut IosEngine`，
/// 类型不可见会触发 private_interfaces。调用方只把它当不透明句柄
/// （见 include/yagami_ios.h），字段与子模块可见性不变。
///
/// 字段 `pub(super)` 让同 crate 的 `engine` 子模块直接取用，
/// 但 C ABI 只以裸指针形式把它交给 Swift——Swift 从不触碰内部结构。
pub struct IosEngine {
    pub(super) engine: Engine,
}
