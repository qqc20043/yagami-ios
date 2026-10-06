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
        title.text = "Yagami Input Method"
        title.font = .systemFont(ofSize: 28, weight: .semibold)
        title.textAlignment = .center

        statusLabel.font = .systemFont(ofSize: 17)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0

        detailLabel.font = .systemFont(ofSize: 15)
        detailLabel.textColor = .secondaryLabel
        detailLabel.numberOfLines = 0
        detailLabel.text = """
        To enable the keyboard:
        1. Open Settings > General > Keyboard > Keyboards > Add New Keyboard, then pick Yagami
        2. Tap Yagami and turn on "Allow Full Access"
           (the keyboard needs it to read the dictionary from the shared container)
        3. In any text field, touch and hold the globe key, then switch to Yagami

        English glosses appear under each candidate. Tap a candidate or press Space to commit.
        """

        let openSettings = UIButton(type: .system)
        openSettings.setTitle("Open Settings", for: .normal)
        openSettings.titleLabel?.font = .systemFont(ofSize: 17)
        openSettings.addAction(UIAction { _ in
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        }, for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [
            title, statusLabel, detailLabel, openSettings,
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
            statusLabel.text = "Cannot access the shared container"
            statusLabel.textColor = .systemRed
            return
        }
        do {
            try SharedData.install(into: container)
            statusLabel.text = "Data is ready"
            statusLabel.textColor = .systemGreen
        } catch {
            statusLabel.text = "Data installation failed: \(error.localizedDescription)"
            statusLabel.textColor = .systemRed
        }
    }
}
