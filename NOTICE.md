# 来源与修改声明

Yagami iOS 基于 [yagami-Qingjian-android](https://github.com/Utyoin-OG/yagami-Qingjian-android)
修改，而后者又基于 [qingjian-team/qingjian](https://github.com/qingjian-team/qingjian)。
上游起始提交见 android 仓库的 `NOTICE.md`。原项目及各贡献者保留其版权。

本 iOS 衍生项目独立维护，主要修改包括：

- 新增 iOS 平台壳：`UIInputViewController` 键盘扩展与候选栏；
- 新增 C ABI 胶水层（`apps/ios/native`），替代 Android 的 JNI 路径；
- 新增 App Group 共享容器方案，让键盘扩展读到词库；
- 新增 XcodeGen 工程描述与 GitHub Actions 云端 macOS 构建；
- 复用上游平台无关 Core（拼音引擎、词库、释义表）与词库数据。

本项目采用 GPL-3.0-or-later，许可证全文见 [LICENSE](LICENSE)。
本项目按现状提供，不附带任何担保。

随 App 分发的词库和译词表具有各自的来源与许可。再分发时必须保留上游
`assets/lexicon`、`assets/glossary` 中的来源、版权和许可证说明。

Yagami 输入法与 qingjian-team 不存在隶属、授权或官方发布关系，不使用青简官方 Logo。
