// yagami_ios.h
// Yagami iOS 的 C ABI 声明。
//
// 本文件是 Swift 侧唯一需要知道的接口面。实现与所有权规则在
// apps/ios/native/src/lib.rs——改了那里的函数签名，这里必须同步，
// 否则 Swift 会拿到错误的调用约定（编译器不会报错，运行时才崩）。
//
// 所有权：返回 char* 的函数把所有权交给调用方，必须用 yagami_string_free 释放；
// 传入的 const char* 一律借用，本层不持有。所有函数接受 NULL 句柄并返回安全默认值。

#ifndef YAGAMI_IOS_H
#define YAGAMI_IOS_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Rust 侧 `IosEngine` 的不透明句柄。
typedef struct IosEngine IosEngine;

/// 创建引擎。成功返回非空句柄，失败返回 NULL。
///
/// - Parameters:
///   - dictionary_path: dict.tsv 或 dict.qj 的绝对路径（UTF-8、NUL 结尾）
///   - glossary_path: glossary-en.tsv 或 glossary-en.qj 的绝对路径
IosEngine *yagami_engine_create(const char *dictionary_path, const char *glossary_path);

/// 释放引擎。传 NULL 是安全的空操作。
void yagami_engine_destroy(IosEngine *handle);

/// 释放本库返回的字符串。传 NULL 是安全的空操作。
void yagami_string_free(char *value);

/// 送一个字符进输入缓冲。成功返回 1，失败返回 0。
int32_t yagami_engine_push(IosEngine *handle, uint32_t character);

/// 退格。缓冲因此变空返回 1，否则返回 0。
int32_t yagami_engine_backspace(IosEngine *handle);

/// 清空输入缓冲。
void yagami_engine_clear(IosEngine *handle);

/// 上屏第 index 个候选，返回要插入的文本（调用方负责释放）。
char *yagami_engine_commit(IosEngine *handle, int32_t index);

/// 取走未转换的原始拼音（调用方负责释放）。
char *yagami_engine_take_raw(IosEngine *handle);

/// 当前候选快照的 JSON（调用方负责释放）。
///
/// 形如 `{"preedit":"shi","candidates":[{"text":"是","gloss":"be · is"}]}`。
/// 无译词时 gloss 是 JSON null；句柄为 NULL 时返回空快照而非 NULL。
char *yagami_engine_snapshot(IosEngine *handle);

/// 本库版本号（调用方负责释放）。
char *yagami_engine_version(void);

#ifdef __cplusplus
}
#endif

#endif /* YAGAMI_IOS_H */
