// YagamiCore.swift
// 对 Rust C ABI 的 Swift 封装。
//
// Rust 侧交出的是裸指针与 C 字符串，所有权规则写在 native/src/lib.rs 的模块头。
// 这一层把那些规则收进一个 Swift 类：调用方只见到 Swift 类型，不碰指针。

import Foundation

/// Rust 的 `IosEngine` 在 Swift 眼里的样子：一个不透明句柄。
///
/// 名字与 C 侧的结构体无关，Swift 只把它当作可持有、可传递的指针。
final class YagamiEngine {
    /// Rust 侧的引擎句柄；为 nil 表示未初始化或已释放。
    private var handle: OpaquePointer?

    /// 一条候选：中文文本 + 可选英文译词。
    struct Candidate: Decodable {
        let text: String

        /// JSON 里是 `null` 时解成 nil，界面据此决定是否画第二行。
        let gloss: String?
    }

    /// 一次查询的快照。
    private struct Snapshot: Decodable {
        let preedit: String

        let candidates: [Candidate]
    }

    /// 打开词库与释义表。任一文件缺失或损坏都会抛错，调用方应提示用户。
    init(dictionary: URL, glossary: URL) throws {
        let handle = dictionary.path.withCString { dictionaryPath in
            glossary.path.withCString { glossaryPath in
                yagami_engine_create(dictionaryPath, glossaryPath)
            }
        }
        guard let handle else {
            throw YagamiError.dataUnavailable
        }
        self.handle = handle
    }

    deinit {
        if let handle {
            yagami_engine_destroy(handle)
        }
    }

    /// 送一个字符进输入缓冲。
    @discardableResult
    func push(_ character: Character) -> Bool {
        guard let handle else { return false }
        return yagami_engine_push(handle, character.unicodeScalars.first?.value ?? 0) == 1
    }

    /// 退格。缓冲因此变空返回 true，否则 false（调用方据此决定是否交给系统删字）。
    @discardableResult
    func backspace() -> Bool {
        guard let handle else { return false }
        return yagami_engine_backspace(handle) == 1
    }

    /// 清空输入缓冲。
    func clear() {
        guard let handle else { return }
        yagami_engine_clear(handle)
    }

    /// 上屏第 index 个候选，返回要插入的文本。
    func commit(index: Int) -> String {
        guard let handle else { return "" }
        return take(yagami_engine_commit(handle, Int32(index)))
    }

    /// 取走未转换的原始拼音。
    func takeRaw() -> String {
        guard let handle else { return "" }
        return take(yagami_engine_take_raw(handle))
    }

    /// 当前快照：拼音显示与候选集合。
    ///
    /// 解析失败时返回空快照而不是抛错：键盘扩展里抛错会让整个键盘消失，
    /// 而「候选暂时空着」是可以接受的降级。
    func snapshot() -> (preedit: String, candidates: [Candidate]) {
        guard let handle else { return ("", []) }
        let json = take(yagami_engine_snapshot(handle))
        guard let data = json.data(using: .utf8),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data)
        else {
            return ("", [])
        }
        return (snapshot.preedit, snapshot.candidates)
    }

    /// 把 Rust 交出的 C 字符串读成 Swift 字符串并释放它。
    private func take(_ pointer: UnsafeMutablePointer<CChar>?) -> String {
        guard let pointer else { return "" }
        defer { yagami_string_free(pointer) }
        return String(cString: pointer)
    }
}

/// 本层可能抛出的错误。
enum YagamiError: LocalizedError {
    /// 词库或释义表加载失败。
    case dataUnavailable

    var errorDescription: String? {
        switch self {
        case .dataUnavailable:
            return "词库加载失败"
        }
    }
}
