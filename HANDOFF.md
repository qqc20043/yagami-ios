# 会话交接文档

> 本文档面向接手的 agent。所有路径、哈希、状态均在 **2026-10-04** 实测核对过。
> 未验证的推断会明确标注「未验证」。

---

## 0. 一句话背景

用户要一个**能在手机上打字时看英文译词**的输入法。原目标是从青简（Qingjian）的
Android 衍生版「Yagami 输入法」开始，测出并修掉了它的一个 bug，然后基于同一套 Core
另开了一个 iOS 工程。用户**没有 Mac**，这是 iOS 部分的核心约束。

---

## 1. 关键路径清单

| 用途 | 路径 |
|---|---|
| 上游 Android 仓库（已克隆） | `D:\work\dsh\yagami-android` |
| **iOS 新工程（本次新建）** | `D:\work\yagami-ios` |
| 交付给用户的 APK | `D:\dsh\qingjian-android\` |
| 测试截图与中间产物 | `D:\dsh\tmp\qingjian-android\` |
| 官方原版 APK（未修改） | `D:\dsh\qingjian-android\yagami-ime-android-0.1.6.apk` |
| **修复版 APK（自签名）** | `D:\dsh\qingjian-android\yagami-ime-android-0.1.6-nullfix.apk` |
| MuMu 模拟器 | `D:\MuMuPlayer`（ADB 端口 `127.0.0.1:16384`） |
| 测试截图（37 张）与中间产物 | `D:\dsh\tmp\qingjian-android\`（共 58 个文件） |
| Android SDK | `C:\Users\ASUS\AppData\Local\Android\Sdk` |
| JDK 17 | `D:\dev-env\java\jdk-17.0.14` |
| Rust（本次装的） | `C:\Users\ASUS\.cargo\bin`（1.99.0） |

---

## 2. 已完成的四件事

### 2.1 调研青简与 Yagami（无改动）

- **青简 Qingjian**：`qingjian-team/qingjian`，Rust 写的拼音输入法，3429 star。
  核心特性是**候选词旁显示外语译词**（英语/日语/西班牙语）。官方**没有 Android 版**
  （`apps/` 下只有 cli/linux/macos/windows）。
- **Yagami**：`Utyoin-OG/yagami-Qingjian-android`，第三方 Android 衍生版，
  2026-10-02 建库。复用青简 Core，自己做 `InputMethodService` 壳。
- 竞品对比写在青简的 `docs/design/landscape.md`：水杉输入法（仅 Windows）、Rime 系。

### 2.2 在 MuMu 模拟器上装并实测 Yagami（无改动）

模拟器修复过程（用户原先打不开）——**根因不是内存不足**，是三个因素叠加：

```powershell
# 1. 彻底停掉残留进程（互斥体 dwError:183 说明有僵尸进程）
Get-Process | Where-Object { $_.ProcessName -match "^MuMu|^Mumu" } | Stop-Process -Force

# 2. 虚拟机内存从 6GB 降到 3GB、CPU 6核降到4核（关键）
& "D:\MuMuPlayer\nx_main\MuMuManager.exe" setting -v 0 --key performance_mode --value custom
& "D:\MuMuPlayer\nx_main\MuMuManager.exe" setting -v 0 --key performance_mem.custom --value 3
& "D:\MuMuPlayer\nx_main\MuMuManager.exe" setting -v 0 --key performance_cpu.custom --value 4

# 3. 启动（改完 20 秒起，之前 2 分钟起不来）
& "D:\MuMuPlayer\nx_main\MuMuManager.exe" control -v 0 launch
```

> 曾误判为「Hyper-V 冲突」，看 `VBox.log` 后纠正：NEM 就是 Hyper-V 兼容模式，
> 且分区已成功建立（`NEM: Successfully set up partition`）。真正的失败链是
> `VERR_VBOX_OBJECT_NOT_FOUND`（vboxmanager.log）→ 状态残留。

**实测确认可用的功能**：拼音输入、候选带译词、点候选上屏、空格上屏、中/EN 切换、
数字页、符号页、Shift、长按空格切换输入法、剪贴板面板、平板模式、短按/长按退格。

### 2.3 找到并修复一个 bug（**这是唯一的代码改动**）

**Bug**：约 4.14% 的词条在候选栏显示字面量字符串 `null`。

**根因**：Android `org.json` 的 `optString()` 遇到 JSON `null` 时返回**字符串 `"null"`**
（因为 `JSONObject.NULL.toString()` 就是 `"null"`），而不是空串。于是
`candidateText()` 里 `gloss.isEmpty()` 判断为 false，把 `"null"` 画了上去。

Rust 侧是正确的（`gloss: Option<String>` 序列化成 JSON null）。

**修复**（`apps/android/app/src/main/java/io/github/utyoinog/yagamiime/YagamiInputMethodService.java:643`）：

```diff
-                String gloss = item.optString("gloss");
+                String gloss = item.isNull("gloss") ? "" : item.optString("gloss");
```

**验证证据**：
- 复现：输入 `qiu`，第 5 个候选「邱」下方显示 `null`
- 数据侧确认：`邱` 在 `dict.tsv` 有、在 `glossary-en.tsv` 无 → 3807/91919 词条受影响
- 词库哈希比对：App 内 vs APK 内 `59C6c33a…297615` **完全一致**，排除数据损坏
- 修复后：同一坐标裁切对比，`null` 消失，「邱」保留

**同类隐患已排查**：`YagamiInputMethodService:625/666`（`preedit`）和
`ClipboardHistory:46` 的 `optString` 都安全，只有 `gloss` 这一处会踩坑。

### 2.4 新建 iOS 工程（29 个文件）

`D:\work\yagami-ios`，**尚未 git init**。

```
Cargo.toml                  Rust workspace（git 依赖上游 Core，rev=a4e72eb）
project.yml                 XcodeGen 工程描述（唯一真源，.xcodeproj 不入库）
README.md                   构建/安装/启用全流程
NOTICE.md                   来源与修改声明
docs/design.md              设计决策与理由
scripts/preflight.sh        无 Mac 也能跑的预检
.github/workflows/ios.yml   云端 macOS 构建 ← 解决「没有 Mac」的关键
apps/ios/native/            Rust C ABI 壳（7 个 .rs + include/yagami_ios.h）
apps/ios/keyboard/          Swift 键盘扩展（5 个 .swift）
apps/ios/app/               主 App（解压词库、引导启用）
```

---

## 3. 交接方最需要知道的坑

### 3.1 iOS 必须用 macOS + Xcode 构建

**这台 Windows 机器无法构建 iOS。** 解决方案是 GitHub Actions 的免费 macOS runner
（公开仓库免费），工作流已写好。产出未签名 `.ipa`，用户用 Sideloadly 装到 iPhone。

**免费 Apple ID 签名 7 天过期**，需反复重签；长期使用需 $99/年开发者账号。
这是 Apple 限制，工程层面绕不开。

### 3.2 本地 `cargo check` 跑不起来（未解决）

这台机器缺 MSVC 链接器；GNU 工具链的 `dlltool` 在沙箱里 `CreateProcess` 失败。
所以 iOS 的 Rust 代码**只做了语法与格式检查，没做类型检查**：

```powershell
# 可用的验证方式（rustfmt 已装）
$rustfmt = "$env:USERPROFILE\.rustup\toolchains\stable-x86_64-pc-windows-gnu\bin\rustfmt.exe"
& $rustfmt --edition 2024 --check <文件>
```

**真正的编译验证要在 CI 上做。**

### 3.3 上游 `rust-toolchain.toml` 锁 1.96.0

会与本地 stable 冲突，触发工具链重装失败（留下损坏的 `1.96.0-x86_64-pc-windows-msvc`，
目录删不掉，报 `拒绝访问`）。绕开方式：

```powershell
$env:RUSTUP_TOOLCHAIN = "stable"   # 或 stable-x86_64-pc-windows-gnu
```

### 3.4 crates.io 直连返回 403

已配置清华镜像 `C:\Users\ASUS\.cargo\config.toml`。**只影响本机**，CI 走官方源。

### 3.5 编码陷阱（踩过两次）

- 用 PowerShell `Set-Content` 写含中文的文件会**破坏 UTF-8 编码**（变成乱码）。
  我曾因此把上游 `Cargo.toml` 的中文注释写坏，已 `git checkout` 还原。
  **写文件请用 write/edit 工具，不要用 PowerShell 重定向。**
- `D:\dsh\start-dsh.cmd` 是 GBK 编码，用 read 工具会报 `invalid UTF-8`。

### 3.6 Android 与 iOS 的架构差异（改代码前必读）

| | Android | iOS |
|---|---|---|
| 胶水层 | JNI | **C ABI**（`extern "C"`） |
| 产物 | `.so` | **`.a` 静态库**（iOS 禁止 dlopen） |
| 数据共享 | 应用私有目录 | **App Group 容器** |
| 权限 | 零权限 | **必须开「完全访问」** |
| 内存 | 较宽裕 | **约 60 MB 预算** |
| 硬件键盘 | 支持 | **不支持** |
| 学习语言 | 英/日/西 | **只挂英语**（内存所限） |

---

## 4. 上游仓库当前状态（重要）

`D:\work\dsh\yagami-android`，HEAD = `a4e72eb feat(android): 新增剪贴板历史与译词语言设置`

**工作区只有一处改动**（就是 2.3 的修复）：

```
 M apps/android/app/src/main/java/io/github/utyoinog/yagamiime/YagamiInputMethodService.java
```

**未提交、未推送到任何远端。** 我之前为验证临时加的 `apps/ios-native-verify`
已删除，`Cargo.toml` / `Cargo.lock` 已 `git checkout` 还原。

---

## 5. 产物清单与哈希

| 文件 | 大小 | 说明 |
|---|---|---|
| `yagami-ime-android-0.1.6.apk` | 18,850,987 B | 官方原版，SHA256 `305cbde0…b1b60fe` |
| `yagami-ime-android-0.1.6-nullfix.apk` | 18,840,184 B | **修复版，自签名** |

修复版签名信息：
- 证书 `CN=Yagami Local Build, OU=Personal, O=Local, L=Local, ST=Local, C=CN`
- RSA 4096，v2 scheme，`apksigner verify` 通过
- keystore：`D:\work\dsh\yagami-android\apps\android\signing\yagami-local.jks`
  （密码 `yagami-local-2026`，别名 `yagami`，**已被 .gitignore 排除**）

**⚠️ 修复版签名与官方版不同**，装的时候必须先卸载官方版（会清数据），
之后升级都得用这个签名。

---

## 6. 模拟器当前状态

- MuMu 实例运行中，`is_android_started: true`，ADB `127.0.0.1:16384`
- **装的是修复版**（自签名，`lastUpdateTime 2026-10-04 21:02:51`）
- 默认输入法：`io.github.utyoinog.yagamiime/.YagamiInputMethodService`
- 屏幕分辨率已从平板模式（1200x1920）重置回 1080x1920

---

## 7. 已完成 vs 未完成

### 已完成
- [x] 调研青简/Yagami，确认官方无 Android 版
- [x] 修复 MuMu 模拟器启动失败
- [x] 实测 Yagami 全部 README 承诺功能
- [x] 找到并修复 `null` 译词 bug（已验证）
- [x] 排查同类 `optString` 隐患
- [x] 构建并验证自签名 release APK
- [x] 新建完整 iOS 工程（29 文件）
- [x] 验证 iOS 的 Rust 语法、C ABI 一致性、XML/YAML 配置

### 未完成（交接方可能接手）
- [ ] **iOS 工程尚未 git init / 提交 / 推送**
- [ ] **iOS 代码未在 macOS 上编译过**（本地只有语法检查）
- [ ] **Android 修复未提 PR 给上游**
- [ ] 上游仓库改动未提交
- [ ] iOS 的剪贴板历史未实现（Android 有）
- [ ] 两端都缺用户词频持久化（属上游 Core 的 `FrequencyLearner` 未接线）
- [ ] `docs/user/` 用户文档未写（上游有约定：用户可感知的行为改了要同步）

---

## 8. 明确不建议做的事（附理由）

按上游 `docs/contributing.md` 的规矩：**「复现不了的……不提修复」**。

- **「force-stop 后输入法被踢回搜狗」** —— 这是 Android 系统的 IME 管理行为，
  不是 App 能修的。**不建议提 issue。**
- **「`adb shell input keyevent` 不出候选」** —— 无法排除是 `adb input` 注入事件的
  限制而非 App 问题。**证据不足，不提。**

---

## 9. 若继续 iOS 工作，建议顺序

1. `git init` 并首次提交（`.gitignore` 已排除 `.xcodeproj`、`signing/`、词库）
2. 推到 GitHub 公开仓库
3. 触发 `ios.yml`，看 CI 报错并修（**这一步才能暴露真正的编译错误**）
4. 产出 `.ipa` 后，用 Sideloadly 装真机验证
5. 验证通过再考虑提 PR 或买开发者账号

## 10. 环境依赖备忘

本次为验证而新装的软件（原机器没有）：
- **Rust 1.99.0**（`rustup` 装在 `C:\Users\ASUS\.cargo`），
  额外装了 `stable-x86_64-pc-windows-gnu` 工具链与 `rustfmt` 组件
- **清华 crates 镜像**配置（`C:\Users\ASUS\.cargo\config.toml`）
- Android SDK Build-Tools 35.0.1（Gradle 构建时自动装的）

遗留问题：`C:\Users\ASUS\.rustup\toolchains\1.96.0-x86_64-pc-windows-msvc`
是损坏残留，目录删不掉（`拒绝访问`），rustup 元数据里仍列出。不影响使用，
但 `rustup toolchain list` 会显示它。
