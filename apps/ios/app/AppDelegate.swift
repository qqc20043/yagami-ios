// AppDelegate.swift
// 主 App：负责把随包词库装进 App Group 共享容器，并引导用户启用键盘。
//
// 主 App 本身不输入法，它只做两件事：解压数据、告诉用户去哪开键盘。
// 真正干活的是 KeyboardViewController（键盘扩展 target）。

import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = SetupViewController()
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}
