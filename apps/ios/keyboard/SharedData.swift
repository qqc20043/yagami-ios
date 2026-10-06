// SharedData.swift
// 键盘扩展与主 App 之间的共享容器约定。
//
// iOS 键盘扩展跑在独立进程，读不到主 App 的 Bundle。词库必须放在
// App Group 共享容器里，由主 App 在首次启动时从自己的 Bundle 解压过去，
// 键盘扩展再从这里读。两边都引用本文件，避免路径写岔。

import Foundation

/// 共享容器的常量。改这里的值必须同步改两个 target 的 entitlements。
enum SharedData {
    /// App Group 标识符。主 App 与键盘扩展的 `.entitlements` 都要声明它。
    static let groupIdentifier = "group.io.github.utyoinog.yagamiime"

    /// 容器内的数据目录名。
    static let directory = "yagami-data"

    /// 词库文件名，与 Android 版 `apps/android/app/build.gradle` 打包的一致。
    static let dictionaryFile = "\(directory)/dict.tsv"

    /// 释义表文件名。iOS 版只挂英语，见 native/src/engine/setup.rs。
    static let glossaryFile = "\(directory)/glossary-en.tsv"

    /// 需要从主 App Bundle 复制到共享容器的数据文件。
    static let bundledFiles = [
        (resource: "dict", extension: "tsv", destination: dictionaryFile),
        (resource: "glossary-en", extension: "tsv", destination: glossaryFile),
    ]

    /// 把 Bundle 内的词库解压到共享容器。已存在且大小一致时跳过。
    ///
    /// - Parameter bundle: 主 App 的 Bundle（键盘扩展不要调用本方法）。
    /// - Throws: 容器不可用，或复制失败。
    static func install(into container: URL, from bundle: Bundle = .main) throws {
        let fileManager = FileManager.default
        let destinationDirectory = container.appendingPathComponent(directory)
        try fileManager.createDirectory(
            at: destinationDirectory,
            withIntermediateDirectories: true
        )

        for file in bundledFiles {
            guard let source = bundle.url(
                forResource: file.resource,
                withExtension: file.extension
            ) else {
                throw SharedDataError.missingResource("\(file.resource).\(file.extension)")
            }
            let destination = container.appendingPathComponent(file.destination)

            // 词库有十几 MB，每次启动都重拷会明显拖慢冷启动。
            if let existing = try? fileManager.attributesOfItem(atPath: destination.path),
               let sourceAttributes = try? fileManager.attributesOfItem(atPath: source.path),
               existing[.size] as? Int64 == sourceAttributes[.size] as? Int64 {
                continue
            }
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: source, to: destination)
        }
    }
}

/// 数据安装可能抛出的错误。
enum SharedDataError: LocalizedError {
    /// Bundle 里缺少随包数据文件。
    case missingResource(String)

    var errorDescription: String? {
        switch self {
        case .missingResource(let name):
            return "Missing data file \(name)"
        }
    }
}
