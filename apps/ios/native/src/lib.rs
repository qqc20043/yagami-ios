//! Yagami iOS 的 C ABI 壳：持有平台无关的 Engine，把候选快照以 JSON 交给 Swift。
//!
//! 与 Android 壳（`apps/android/native`）的区别只在胶水层：那边是 JNI，
//! 这边是一组 `extern "C"` 函数 + 手工管理的字符串所有权。Core 的用法完全一致。
//!
//! 所有权约定：返回 `*mut c_char` 的函数交出所有权，调用方必须用
//! [`yagami_string_free`] 释放；传入的 `*const c_char` 一律借用，本层不持有。
//! 所有函数对空指针与无效句柄都返回安全默认值，不 panic 跨过 FFI 边界。

// engine 必须 pub：C ABI 函数签名里的 *mut IosEngine 要求类型可达，
// 否则 private_interfaces 报错。见 engine/mod.rs 的说明。
pub mod engine;
mod snapshot;

use std::ffi::{CStr, CString, c_char};
use std::path::Path;

use engine::IosEngine;

/// 把 Rust 字符串转成调用方拥有的 C 字符串；含内部 NUL 时退化为空串。
fn into_c_string(text: &str) -> *mut c_char {
    match CString::new(text) {
        Ok(value) => value.into_raw(),
        Err(_) => CString::default().into_raw(),
    }
}

/// 借用调用方传来的 C 字符串；空指针或非 UTF-8 返回 `None`。
///
/// SAFETY：调用方保证指针在本次调用期间有效且以 NUL 结尾。
unsafe fn borrow_c_str<'a>(value: *const c_char) -> Option<&'a str> {
    if value.is_null() {
        return None;
    }
    unsafe { CStr::from_ptr(value) }.to_str().ok()
}

/// 从原始句柄取 Engine；句柄为 0 返回 `None`。
///
/// SAFETY：句柄只能来自 [`yagami_engine_create`]，且调用方保证未提前释放。
unsafe fn from_handle<'a>(handle: *mut IosEngine) -> Option<&'a mut IosEngine> {
    if handle.is_null() {
        return None;
    }
    unsafe { handle.as_mut() }
}

/// 创建引擎。
///
/// - `dictionary_path`：`dict.tsv` 或 `dict.qj` 的绝对路径
/// - `glossary_path`：`glossary-en.tsv` 或 `glossary-en.qj` 的绝对路径
///
/// 成功返回非空句柄，失败返回空指针（调用方据此提示用户数据加载失败）。
///
/// # Safety
///
/// 两个路径都必须是有效的、以 NUL 结尾的 UTF-8 C 字符串。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn yagami_engine_create(
    dictionary_path: *const c_char,
    glossary_path: *const c_char,
) -> *mut IosEngine {
    let (Some(dictionary), Some(glossary)) = (unsafe { borrow_c_str(dictionary_path) }, unsafe {
        borrow_c_str(glossary_path)
    }) else {
        return std::ptr::null_mut();
    };
    match IosEngine::open(Path::new(dictionary), Path::new(glossary)) {
        Ok(engine) => Box::into_raw(Box::new(engine)),
        Err(_) => std::ptr::null_mut(),
    }
}

/// 释放引擎。传空指针是安全的空操作。
///
/// # Safety
///
/// `handle` 必须来自 [`yagami_engine_create`]，且只能释放一次。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn yagami_engine_destroy(handle: *mut IosEngine) {
    if !handle.is_null() {
        // SAFETY：句柄由 create 分配，调用方保证只释放一次。
        unsafe { drop(Box::from_raw(handle)) };
    }
}

/// 释放本层返回的字符串。传空指针是安全的空操作。
///
/// # Safety
///
/// `value` 必须来自本模块返回字符串的函数，且只能释放一次。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn yagami_string_free(value: *mut c_char) {
    if !value.is_null() {
        // SAFETY：指针来自 CString::into_raw，调用方保证只释放一次。
        unsafe { drop(CString::from_raw(value)) };
    }
}

/// 送一个字符进输入缓冲。成功返回 1，失败返回 0。
///
/// # Safety
///
/// `handle` 必须来自 [`yagami_engine_create`]。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn yagami_engine_push(handle: *mut IosEngine, character: u32) -> i32 {
    let Some(engine) = (unsafe { from_handle(handle) }) else {
        return 0;
    };
    let Some(character) = char::from_u32(character) else {
        return 0;
    };
    engine.engine.push(character);
    1
}

/// 退格。缓冲因此变空返回 1，否则返回 0（调用方据此决定是否交给系统删字）。
///
/// # Safety
///
/// `handle` 必须来自 [`yagami_engine_create`]。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn yagami_engine_backspace(handle: *mut IosEngine) -> i32 {
    (unsafe { from_handle(handle) }).is_some_and(|engine| engine.engine.backspace()) as i32
}

/// 清空输入缓冲。
///
/// # Safety
///
/// `handle` 必须来自 [`yagami_engine_create`]。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn yagami_engine_clear(handle: *mut IosEngine) {
    if let Some(engine) = unsafe { from_handle(handle) } {
        engine.engine.clear();
    }
}

/// 上屏第 `index` 个候选，返回要插入的文本（调用方负责释放）。
///
/// # Safety
///
/// `handle` 必须来自 [`yagami_engine_create`]。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn yagami_engine_commit(handle: *mut IosEngine, index: i32) -> *mut c_char {
    let text = (unsafe { from_handle(handle) })
        .and_then(|engine| engine.commit(index.max(0) as usize))
        .unwrap_or_default();
    into_c_string(&text)
}

/// 取走未转换的原始拼音（调用方负责释放）。
///
/// # Safety
///
/// `handle` 必须来自 [`yagami_engine_create`]。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn yagami_engine_take_raw(handle: *mut IosEngine) -> *mut c_char {
    let text = (unsafe { from_handle(handle) })
        .map(|engine| engine.engine.take_raw())
        .unwrap_or_default();
    into_c_string(&text)
}

/// 当前候选快照的 JSON（调用方负责释放）。
///
/// 形如 `{"preedit":"shi","candidates":[{"text":"是","gloss":"be · is"}]}`；
/// 无译词时 `gloss` 是 JSON `null`。句柄无效时返回空快照而不是空指针，
/// 让 Swift 侧不必区分「没数据」和「出错」。
///
/// # Safety
///
/// `handle` 必须来自 [`yagami_engine_create`]。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn yagami_engine_snapshot(handle: *mut IosEngine) -> *mut c_char {
    let json = (unsafe { from_handle(handle) })
        .and_then(|engine| serde_json::to_string(&engine.snapshot()).ok())
        .unwrap_or_else(|| "{\"preedit\":\"\",\"candidates\":[]}".to_owned());
    into_c_string(&json)
}

/// 引擎版本号（`CARGO_PKG_VERSION`）。返回值由调用方用 [`yagami_string_free`] 释放。
#[unsafe(no_mangle)]
pub extern "C" fn yagami_engine_version() -> *mut c_char {
    into_c_string(env!("CARGO_PKG_VERSION"))
}
