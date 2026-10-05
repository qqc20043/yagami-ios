//! 候选快照中的单项文本与可选译词。

use serde::Serialize;

/// 一条候选。
///
/// `gloss` 用 `Option` 而不是空串：JSON 里「没有译词」与「译词是空串」
/// 是两件事，Swift 侧靠 `null` 判断是否绘制第二行。Android 壳曾在这里
/// 踩过坑——`org.json` 的 `optString` 把 JSON null 读成字面量 "null"，
/// 候选栏就显示了「null」。Swift 的 `Decodable` 把 JSON null 映射到
/// `String?` 的 `nil`，不会有这个问题。
#[derive(Serialize)]
pub(crate) struct SnapshotCandidate {
    text: String,

    gloss: Option<String>,
}

impl SnapshotCandidate {
    pub(crate) fn new(text: String, gloss: Option<String>) -> Self {
        Self { text, gloss }
    }
}
