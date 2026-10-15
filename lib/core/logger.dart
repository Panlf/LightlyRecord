import 'package:flutter/foundation.dart';

/// 仅 debug 输出的极简日志。
///
/// release 包内全部静默（`kDebugMode` 为 false），零性能损耗、零隐私泄露。
class Log {
  const Log._();

  /// 调试日志。
  static void d(Object? message) {
    if (kDebugMode) {
      debugPrint('[轻记] $message');
    }
  }

  /// 警告日志。
  static void w(Object? message) {
    if (kDebugMode) {
      debugPrint('[轻记][W] $message');
    }
  }

  /// 错误日志（可附带原始异常与堆栈）。
  static void e(Object? message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[轻记][E] $message'
          '${error == null ? '' : '\n  error: $error'}'
          '${stackTrace == null ? '' : '\n  stack: $stackTrace'}');
    }
  }
}
