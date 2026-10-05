//! 一次查询的拼音显示与候选集合。

use serde::Serialize;

use super::SnapshotCandidate;

#[derive(Serialize)]
pub(crate) struct Snapshot {
    preedit: String,

    candidates: Vec<SnapshotCandidate>,
}

impl Snapshot {
    pub(crate) fn new(preedit: String, candidates: Vec<SnapshotCandidate>) -> Self {
        Self {
            preedit,
            candidates,
        }
    }
}
