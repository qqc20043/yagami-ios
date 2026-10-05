# iOS 平台壳的设计

本页说明 iOS 壳为什么长这样。实现要点在源码注释里，这里只记决策与理由。

## 为什么复用 Core 而不是重写

拼音解析、候选排序、整句转换、词库查询、释义表查询都在 `qingjian-core` 及其兄弟
crate 里，是平台无关的。iOS 壳只做两件事——把触摸翻译成 Core 的输入，把 Core 的
快照画到候选栏。这与上游 `docs/contributing.md` 的架构约束一致：**平台层里不允许
出现排序逻辑、词库访问、翻译调用或文本变换**。

判断标准：把 `UIInputViewController` 换成别的输入框架，不应该需要改 Core 的任何一行。
本壳满足这条——`apps/ios/native` 只 import Core 的公开 API（`Engine`、`Dictionary`、
`Glossary`），没有碰任何内部实现。

## 为什么是 C ABI 而不是像 Android 那样用 JNI

Android 的 JNI 是 Java ↔ native 的机制，iOS 侧对应的机制是 Objective-C/Swift 的
C 互操作——`extern "C"` 函数 + 桥接头。Swift 可以直接调 C 函数，没有中间层。

于是 `apps/android/native/src/lib.rs` 的每个 `Java_..._nativeXxx` 函数，在
`apps/ios/native/src/lib.rs` 里对应一个 `yagami_engine_xxx`：

| Android（JNI） | iOS（C ABI） |
|---|---|
| `nativeCreate(dict, gloss) -> jlong` | `yagami_engine_create(dict, gloss) -> *mut IosEngine` |
| `nativeSnapshot(handle) -> jstring` | `yagami_engine_snapshot(handle) -> *mut c_char` |
| `nativeCommit(handle, index) -> jstring` | `yagami_engine_commit(handle, index) -> *mut c_char` |

差别最大的是**字符串所有权**：JNI 的 `jstring` 由 JVM 管，C ABI 的 `char*` 得手工管。
本壳的规则是「谁返回谁负责」——返回的 `char*` 调用方必须用 `yagami_string_free` 释放，
传入的 `const char*` 一律借用。Swift 侧用 `defer { yagami_string_free(pointer) }`
把它收在 `YagamiCore.take(_:)` 一个函数里，调用方见不到指针。

## 为什么编静态库

iOS 不允许把动态库打进 App Bundle 再 `dlopen`——App Store 审核会拒，而且键盘扩展
的沙箱也加载不了。所以 `crate-type = ["staticlib"]`，主 App 与键盘扩展各链一份。

两个 target 都链接同一份归档，符号都是 `yagami_` 前缀，不会冲突。

## 为什么词库走 App Group

键盘扩展是**独立进程**，读不到主 App 的 Bundle。词库必须放在 App Group 共享容器里：

```
主 App 启动 → 从 Bundle 解压 dict.tsv / glossary-en.tsv → App Group 容器
                                                              ↓
键盘扩展启动 → 从 App Group 容器读 → 装配 Engine
```

这带来一个用户可见的后果：**必须打开「允许完全访问」**。iOS 键盘默认没有共享容器
权限，不开就读不到词库，键盘会提示「请先打开 Yagami 完成初始化」。这一点写进了
`Info.plist` 的 `RequestsOpenAccess` 和引导页文案。

`SharedData.install` 会比对文件大小跳过重复复制——词库十几 MB，每次启动都重拷会
明显拖慢冷启动。

## 为什么只挂英语释义表

键盘扩展的内存预算约 60 MB（低端设备更少）。上游 Android 版同时打包英/日/西三张
释义表（合计 25 MB），iOS 侧全挂进去会让「装得下」变成靠运气。

`engine/setup.rs` 因此硬编码 `Language::English`。要换语言改那一行，与 Android 的
`AppSettings.glossaryAsset` 是同一处决策点。

## 为什么不用手写的 .xcodeproj

`.xcodeproj` 是上千行带 UUID 的 XML。三个问题：人改容易改坏、多人协作必冲突、
**在没有 Xcode 的机器上无法验证**。

`project.yml`（XcodeGen）把工程定义收敛成可读的 YAML，CI 里 `xcodegen generate`
现场产出 `.xcodeproj`。工程文件进 `.gitignore`，`project.yml` 是唯一真源。

## 为什么用云端 macOS 构建

Xcode 只在 macOS 上跑。本工程的目标之一就是**让没有 Mac 的人也能做出 iOS 输入法**，
所以 `.github/workflows/ios.yml` 用 GitHub 的 macOS runner 构建，产出未签名 `.ipa`。

未签名包不能直接装真机，需要本地重签（免费 Apple ID + Sideloadly，7 天过期）。
要长期使用需要付费开发者账号——这是 Apple 的限制，不是本工程能绕开的。

## 与 Android 版的行为差异

| 行为 | Android | iOS | 原因 |
|---|---|---|---|
| 硬件键盘输入 | 支持 | 不支持 | 键盘扩展收不到 `pressesBegan`，只能处理触摸 |
| 读取宿主文本上下文 | 可读整段 | 只有 `documentContextBeforeInput` | 系统 API 限制 |
| 剪贴板历史 | 有 | 未实现 | 键盘扩展读剪贴板需要完全访问，且 iOS 会提示用户 |
| 长按空格切换输入法 | 有 | 用地球键 | iOS 的切换键是系统约定，不该被覆盖 |
| 用户词频持久化 | 未实现 | 未实现 | 两边都缺，属上游 Core 的 `FrequencyLearner` 尚未接线 |
