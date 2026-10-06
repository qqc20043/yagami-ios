// SetupViewController.swift
// 引导页：装数据、开键盘、验证。
//
// 对照 Android 版的 SetupActivity——那边也是「先启用输入法、再选中」两步，
// iOS 多了一步「允许完全访问」，而且第 3 步（键盘是否已添加）只能靠用户自己看，
// 系统不提供查询 API。

import UIKit

/// 引导页。
final class SetupViewController: UIViewController {
    private let statusLabel = UILabel()
    private let detailLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        buildLayout()
        installData()
    }

    private func buildLayout() {
        let title = UILabel()
        title.text = "qq 输入法"
        title.font = .systemFont(ofSize: 28, weight: .semibold)
        title.textAlignment = .center

        let attribution = UILabel()
        attribution.text = "by qqc20043"
        attribution.font = .systemFont(ofSize: 13)
        attribution.textColor = .secondaryLabel
        attribution.textAlignment = .center

        statusLabel.font = .systemFont(ofSize: 17)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0

        detailLabel.font = .systemFont(ofSize: 15)
        detailLabel.textColor = .secondaryLabel
        detailLabel.numberOfLines = 0
        detailLabel.text = """
        启用步骤：
        1. 打开「设置 → 通用 → 键盘 → 键盘 → 添加新键盘」，选择 qq
        2. 点进 qq，打开「允许完全访问」
           （键盘扩展需要它才能读取共享容器里的词库）
        3. 在任意输入框长按地球键，切到 qq

        译词会显示在候选下方。点候选或按空格上屏。
        """

        let openSettings = UIButton(type: .system)
        openSettings.setTitle("打开系统设置", for: .normal)
        openSettings.titleLabel?.font = .systemFont(ofSize: 17)
        openSettings.addAction(UIAction { _ in
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        }, for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [
            title, attribution, statusLabel, detailLabel, openSettings,
        ])
        stack.axis = .vertical
        stack.spacing = 20
        stack.alignment = .fill
        view.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    /// 把随包词库解压进共享容器。键盘扩展读的就是这里。
    private func installData() {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: SharedData.groupIdentifier)
        else {
            statusLabel.text = "无法访问共享容器"
            statusLabel.textColor = .systemRed
            return
        }
        do {
            try SharedData.install(into: container)
            statusLabel.text = "数据已就绪"
            statusLabel.textColor = .systemGreen
        } catch {
            statusLabel.text = "数据安装失败：\(error.localizedDescription)"
            statusLabel.textColor = .systemRed
        }
    }
}
