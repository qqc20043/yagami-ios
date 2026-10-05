//! 从 App Bundle 内的数据文件装配 iOS Engine。

use std::path::Path;

use qingjian_core::{Engine, Language};
use qingjian_dictionary::Dictionary;
use qingjian_translate::Glossary;

use super::IosEngine;

impl IosEngine {
    /// 打开词库与释义表。
    ///
    /// 学习语言固定英语：iOS 键盘扩展的内存预算只有几十 MB，
    /// 同时挂三种释义表会让「装得下」变成靠运气。换语言是改这里的 `Language`，
    /// 与 Android 壳的 `AppSettings.glossaryAsset` 同一处决策。
    pub(crate) fn open(dictionary: &Path, glossary: &Path) -> Result<Self, String> {
        let dictionary = Dictionary::from_path(dictionary).map_err(|error| error.to_string())?;
        let glossary =
            Glossary::from_path(Language::English, glossary).map_err(|error| error.to_string())?;
        Ok(Self {
            engine: Engine::new(dictionary).with_translator(Box::new(glossary)),
        })
    }
}
