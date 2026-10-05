// KeyboardViewController.swift
// Yagami 键盘扩展：把触摸事件翻译成 Core 的输入，把 Core 的快照画到候选栏。
//
// iOS 键盘扩展与 Android 的 InputMethodService 有几个硬差异，决定了本文件的形状：
//
// 1. 扩展跑在独立进程，内存预算约 60 MB（低端机更少）。词库因此从 App Group
//    共享容器读取，且只挂一种学习语言——见 native/src/engine/setup.rs。
// 2. 扩展不响应硬件按键，只能处理触摸与 `UIKeyInput`；`pressesBegan` 在扩展里
//    不可用，所以没有 Android 版那种「物理键盘」路径。
// 3. `requestSupplementaryLexicon` 与 `documentContextBeforeInput` 只给有限上下文，
//    不能像 Android 那样读整段文字。
// 4. 系统在切换 App 时会重建扩展进程，所以引擎按需惰性加载、可反复创建。

import UIKit

/// Yagami 输入法键盘。
final class KeyboardViewController: UIInputViewController {
    /// 引擎惰性创建：扩展可能被系统反复拉起，构造时机越晚越省内存。
    private var engine: YagamiEngine?

    /// 当前是否为中文模式。与 Android 壳一致，中英切换始终是布尔。
    private var chinese = true

    /// 候选栏与键盘主体。
    private let candidateBar = UIStackView()
    private let keyboardStack = UIStackView()

    /// 拼音显示（组合中的文字）。
    private var preedit = ""

    /// 当前候选。
    private var candidates: [YagamiEngine.Candidate] = []

    /// 键盘布局：与 Android 版保持一致的 QWERTY 三行 + 功能行。
    private static let rows = [
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
        ["z", "x", "c", "v", "b", "n", "m"],
    ]

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        buildCandidateBar()
        buildKeyboard()
        loadEngine()
        refresh()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 系统会在切换回本键盘时重新调用；引擎若已被回收则重建。
        if engine == nil {
            loadEngine()
        }
        refresh()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        // 宿主 App 换了输入框、或系统改了文本，组合态就失效了。
        refresh()
    }

    // MARK: - 引擎

    /// 从 App Group 共享容器加载词库与释义表。
    ///
    /// 键盘扩展与主 App 是两个进程，不能用各自的 Bundle 互相读文件；
    /// 词典必须放在 App Group 容器里，由主 App 在首次启动时解压过去。
    private func loadEngine() {
        let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: SharedData.groupIdentifier)
        guard let container else {
            showHint("无法访问共享容器")
            return
        }
        let dictionary = container.appendingPathComponent(SharedData.dictionaryFile)
        let glossary = container.appendingPathComponent(SharedData.glossaryFile)
        guard FileManager.default.fileExists(atPath: dictionary.path),
              FileManager.default.fileExists(atPath: glossary.path)
        else {
            showHint("请先打开 Yagami 完成初始化")
            return
        }
        engine = try? YagamiEngine(dictionary: dictionary, glossary: glossary)
        if engine == nil {
            showHint("词库加载失败")
        }
    }

    // MARK: - 界面

    private func buildCandidateBar() {
        candidateBar.axis = .horizontal
        candidateBar.alignment = .fill
        candidateBar.distribution = .fillProportionally
        candidateBar.spacing = 0
        candidateBar.backgroundColor = UIColor(red: 0.97, green: 0.97, blue: 0.98, alpha: 1)
        candidateBar.heightAnchor.constraint(equalToConstant: 44).isActive = true

        let stack = UIStackView(arrangedSubviews: [candidateBar, keyboardStack])
        stack.axis = .vertical
        stack.distribution = .fill
        view.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.topAnchor),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func buildKeyboard() {
        keyboardStack.axis = .vertical
        keyboardStack.distribution = .fillEqually
        keyboardStack.spacing = 6
        keyboardStack.isLayoutMarginsRelativeArrangement = true
        keyboardStack.layoutMargins = UIEdgeInsets(top: 6, left: 3, bottom: 6, right: 3)

        for row in Self.rows {
            keyboardStack.addArrangedSubview(keyRow(row))
        }
        keyboardStack.addArrangedSubview(functionRow())
    }

    private func keyRow(_ keys: [String]) -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.spacing = 6
        for key in keys {
            row.addArrangedSubview(letterKey(key))
        }
        return row
    }

    private func letterKey(_ letter: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(letter, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 22)
        button.setTitleColor(UIColor(red: 0.09, green: 0.16, blue: 0.13, alpha: 1), for: .normal)
        button.backgroundColor = .white
        button.layer.cornerRadius = 5
        button.addAction(UIAction { [weak self] _ in
            self?.type(letter)
        }, for: .touchUpInside)
        return button
    }

    private func functionRow() -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .fillProportionally
        row.spacing = 6

        row.addArrangedSubview(actionKey("中") { [weak self] in self?.toggleChinese() })
        row.addArrangedSubview(actionKey("⌫") { [weak self] in self?.deleteBackward() })
        row.addArrangedSubview(actionKey("空格", weight: 3) { [weak self] in self?.space() })
        row.addArrangedSubview(actionKey("换行") { [weak self] in self?.newline() })
        row.addArrangedSubview(actionKey("🌐") { [weak self] in self?.advanceToNextInputMode() })
        return row
    }

    private func actionKey(
        _ title: String,
        weight: CGFloat = 1,
        action: @escaping () -> Void
    ) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16)
        button.setTitleColor(UIColor(red: 0.09, green: 0.16, blue: 0.13, alpha: 1), for: .normal)
        button.backgroundColor = UIColor(red: 0.83, green: 0.85, blue: 0.87, alpha: 1)
        button.layer.cornerRadius = 5
        button.widthAnchor.constraint(
            equalTo: view.widthAnchor,
            multiplier: weight / 8
        ).isActive = true
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }

    // MARK: - 输入

    /// 处理一个字母键。
    private func type(_ letter: String) {
        guard chinese, let engine else {
            textDocumentProxy.insertText(letter)
            return
        }
        engine.push(Character(letter))
        refresh()
    }

    /// 空格：有组合时上屏第一候选，否则插入空格。
    private func space() {
        if chinese, !preedit.isEmpty {
            commit(index: 0)
        } else {
            textDocumentProxy.insertText(" ")
        }
    }

    /// 上屏第 index 个候选。
    private func commit(index: Int) {
        guard let engine, candidates.indices.contains(index) else { return }
        let text = engine.commit(index: index)
        if !text.isEmpty {
            textDocumentProxy.insertText(text)
        }
        refresh()
    }

    /// 退格：先退组合，组合空了再交给系统删字。
    private func deleteBackward() {
        guard chinese, let engine, engine.backspace() else {
            textDocumentProxy.deleteBackward()
            refresh()
            return
        }
        refresh()
    }

    /// 换行：有组合时把原始拼音上屏，否则按宿主输入框的动作处理。
    private func newline() {
        guard let engine else {
            textDocumentProxy.insertText("\n")
            return
        }
        if chinese, !preedit.isEmpty {
            let raw = engine.takeRaw()
            textDocumentProxy.insertText(raw)
            refresh()
            return
        }
        textDocumentProxy.insertText("\n")
    }

    /// 中英切换。切换时把未完成的组合按原始拼音上屏，避免丢字。
    private func toggleChinese() {
        if chinese, let engine, !preedit.isEmpty {
            textDocumentProxy.insertText(engine.takeRaw())
        }
        chinese.toggle()
        engine?.clear()
        refresh()
    }

    // MARK: - 候选栏

    /// 按当前引擎状态重画候选栏与拼音行。
    private func refresh() {
        candidateBar.arrangedSubviews.forEach { $0.removeFromSuperview() }

        guard chinese, let engine else {
            showHint("English")
            return
        }
        let snapshot = engine.snapshot()
        preedit = snapshot.preedit
        candidates = snapshot.candidates

        // 组合态交给系统：宿主输入框会显示下划线，与 Android 的 setComposingText 对应。
        if preedit.isEmpty {
            textDocumentProxy.setMarkedText(
                "",
                selectedRange: NSRange(location: 0, length: 0)
            )
        } else {
            textDocumentProxy.setMarkedText(
                preedit,
                selectedRange: NSRange(location: (preedit as NSString).length, length: 0)
            )
        }

        guard !candidates.isEmpty else {
            showHint(preedit.isEmpty ? "输入拼音" : preedit)
            return
        }
        for (index, candidate) in candidates.enumerated() {
            candidateBar.addArrangedSubview(candidateButton(candidate, index: index))
        }
    }

    /// 一个候选按钮：中文在上、译词在下（无译词时只显示中文）。
    private func candidateButton(_ candidate: YagamiEngine.Candidate, index: Int) -> UIButton {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(
            top: 2, leading: 10, bottom: 2, trailing: 10
        )

        let text = NSMutableAttributedString(
            string: candidate.text,
            attributes: [
                .font: UIFont.systemFont(ofSize: 19),
                .foregroundColor: UIColor(red: 0.09, green: 0.16, blue: 0.13, alpha: 1),
            ]
        )
        // gloss 为 nil 说明词库没有这条译词——不画第二行。
        // Android 壳曾把 JSON null 读成字面量 "null" 画了上去，这里靠类型区分。
        if let gloss = candidate.gloss, !gloss.isEmpty {
            text.append(NSAttributedString(
                string: "\n" + gloss,
                attributes: [
                    .font: UIFont.systemFont(ofSize: 11),
                    .foregroundColor: UIColor(red: 0.44, green: 0.45, blue: 0.47, alpha: 1),
                ]
            ))
        }
        configuration.attributedTitle = AttributedString(text)
        configuration.titleAlignment = .center

        let button = UIButton(configuration: configuration)
        button.addAction(UIAction { [weak self] _ in
            self?.commit(index: index)
        }, for: .touchUpInside)
        return button
    }

    private func showHint(_ text: String) {
        var configuration = UIButton.Configuration.plain()
        configuration.title = text
        configuration.baseForegroundColor = .gray
        let label = UIButton(configuration: configuration)
        label.isUserInteractionEnabled = false
        candidateBar.addArrangedSubview(label)
    }
}
