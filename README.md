# Yagami iOS

青简（Qingjian）拼音输入法的 iOS 键盘扩展，带候选译词。

打字时，每个候选下方挂一条英文译词——和 Android 版、桌面版是同一个功能：

```text
开发        编程        架构
development programming architecture
```

本工程是 [yagami-Qingjian-android](https://github.com/Utyoin-OG/yagami-Qingjian-android)
的 iOS 衍生版，复用上游平台无关的 Core（拼音引擎、词库、释义表），
自己实现 iOS 平台壳。**非官方项目**，与 qingjian-team 无隶属关系。

## 没有 Mac 也能构建

iOS 应用必须有 Xcode 才能编译，而 Xcode 只在 macOS 上跑。本工程用
**GitHub Actions 的 macOS runner** 绕开这个限制：

1. 把本仓库推到 GitHub（公开仓库免费使用 macOS runner）
2. 推送到 `main` 后 `.github/workflows/ios.yml` 自动构建
3. 在 Actions 页面下载 `Yagami-ipa` 产物

不需要买 Mac。

## 装到 iPhone

未签名的 `.ipa` 不能直接安装，需要重签。两条路：

### 免费 Apple ID（能验证，但要反复重签）

1. Windows 上装 [Sideloadly](https://sideloadly.io/)
2. 用数据线连 iPhone，把 `Yagami-unsigned.ipa` 拖进 Sideloadly
3. 填 Apple ID，点 Start
4. **签名 7 天后过期**，过期后重跑一次即可

限制：免费账号最多同时装 3 个自签 App。

### 付费开发者账号（$99/年，可长期使用）

把证书与描述文件导出成 base64 存进仓库 Secrets，CI 会自动产出已签名的
`Yagami-signed.ipa`。Secret 名字见 `.github/workflows/ios.yml` 的 sign 步骤。

## 启用键盘

装好后**键盘不会自动启用**，必须手动开：

1. 先打开「Yagami」App，等它显示「数据已就绪」
   （这一步把词库解压进共享容器，键盘读的就是这里）
2. 设置 → 通用 → 键盘 → 键盘 → 添加新键盘 → 选 Yagami
3. 点进 Yagami，打开**「允许完全访问」**
4. 在任意输入框长按地球键，切到 Yagami

第 3 步不能省。iOS 键盘扩展默认没有共享容器权限，不开完全访问就读不到词库，
键盘会提示「请先打开 Yagami 完成初始化」。

## 工程结构

```
apps/ios/
├── native/            Rust C ABI 壳（编译成静态库）
│   ├── include/       yagami_ios.h —— Swift 侧唯一需要知道的接口
│   └── src/           engine（装配与查询）、snapshot（候选 JSON）
├── keyboard/          Swift 键盘扩展
│   ├── KeyboardViewController.swift   触摸事件 → Core，Core 快照 → 候选栏
│   ├── YagamiCore.swift               对 C ABI 的 Swift 封装
│   └── SharedData.swift               共享容器约定
└── app/               主 App（解压词库、引导启用）
```

## 与 Android 版的差异

两边共用 Core，壳的差别来自平台本身：

| | Android | iOS |
|---|---|---|
| 输入法基类 | `InputMethodService` | `UIInputViewController` |
| 胶水层 | JNI | C ABI + `extern "C"` |
| 产物 | `.so`（动态库） | `.a`（静态库） |
| 进程 | 系统内，内存较宽裕 | 独立扩展进程，**约 60 MB 预算** |
| 数据共享 | 应用私有目录 | **App Group 共享容器**（必须开完全访问） |
| 硬件键盘 | 支持 | **不支持**，扩展只收触摸 |
| 学习语言 | 英语/日语/西班牙语 | 只挂英语（内存预算所限） |
| 安装 | 直接装 APK | 必须重签，免费账号 7 天过期 |

## 本地构建（有 Mac 时）

```bash
# 1. Rust 静态库
rustup target add aarch64-apple-ios aarch64-apple-ios-sim
cargo build -p yagami-ios-native --release --target aarch64-apple-ios

# 2. 生成 Xcode 工程（工程文件不入库，由 XcodeGen 产出）
brew install xcodegen
xcodegen generate

# 3. 构建
open Yagami.xcodeproj
```

`.xcodeproj` 故意不入库：那是上千行带 UUID 的 XML，人改容易改坏、合并必冲突，
而且无法在没有 Xcode 的机器上验证。`project.yml` 是唯一真源。

## 许可证

代码以 [GPL-3.0-or-later](LICENSE) 发布。Core 与词库数据来自上游 Yagami/Qingjian，
各自的来源与许可见上游的 `NOTICE.md`。本项目不使用青简官方 Logo。
