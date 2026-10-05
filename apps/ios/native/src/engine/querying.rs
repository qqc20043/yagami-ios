//! 把 Core 查询结果转换成 Swift UI 使用的只读快照。

use qingjian_core::Candidate;

use crate::snapshot::{Snapshot, SnapshotCandidate};

use super::IosEngine;

impl IosEngine {
    pub(crate) fn candidates(&self) -> Vec<Candidate> {
        self.engine
            .query()
            .map(|query| query.candidates.items)
            .unwrap_or_default()
    }

    /// 上屏第 `index` 个候选，返回要插入的文本；越界返回 `None`。
    ///
    /// 需要 `&mut self`：Core 的 `commit` 会更新学习状态（词频）。
    pub(crate) fn commit(&mut self, index: usize) -> Option<String> {
        let candidate = self.candidates().get(index).cloned()?;
        Some(self.engine.commit(&candidate))
    }

    pub(crate) fn snapshot(&self) -> Snapshot {
        let Ok(mut query) = self.engine.query() else {
            return Snapshot::new(self.engine.composition().typed_text(), Vec::new());
        };
        self.engine.annotate(&mut query.candidates);
        let preedit = query.marked_text();
        let candidates = query
            .candidates
            .items
            .into_iter()
            .take(12)
            .map(|candidate| {
                let gloss = candidate.translation.as_ref().and_then(|translation| {
                    let joined = translation
                        .senses()
                        .iter()
                        .map(|sense| sense.text.as_str())
                        .collect::<Vec<_>>()
                        .join(" · ");
                    (!joined.is_empty()).then_some(joined)
                });
                SnapshotCandidate::new(candidate.text, gloss)
            })
            .collect();
        Snapshot::new(preedit, candidates)
    }
}
