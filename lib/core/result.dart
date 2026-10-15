/// `Result<T>` 轻量封装 + 业务异常。
///
/// Repository 层统一用 `Result<T>` 表达「成功带值 / 失败带消息」，
/// 避免为了一次参数校验把整条调用链拖进 try/catch。
library;

/// 业务异常：可预期、需要以 Toast 形式反馈给用户的错误。
class BusinessException implements Exception {
  /// 面向用户的中文提示。
  final String message;

  const BusinessException(this.message);

  @override
  String toString() => 'BusinessException: $message';
}

/// 数据库 / 未知异常：统一包裹后由 UI 兜底提示。
class DataException implements Exception {
  /// 面向用户的中文提示。
  final String message;

  /// 原始异常（仅 debug 日志使用）。
  final Object? cause;

  const DataException(this.message, [this.cause]);

  @override
  String toString() => 'DataException: $message${cause == null ? '' : ' ($cause)'}';
}

/// 结果密封类：仅 [Success] 与 [Failure] 两个实现。
sealed class Result<T> {
  const Result();

  /// 是否成功。
  bool get isSuccess => this is Success<T>;

  /// 是否失败。
  bool get isFailure => this is Failure<T>;

  /// 成功时的值；失败时为 `null`。
  T? get valueOrNull => switch (this) {
        Success<T>(:final T value) => value,
        Failure<T>() => null,
      };

  /// 失败时的消息；成功时为 `null`。
  String? get messageOrNull => switch (this) {
        Success<T>() => null,
        Failure<T>(:final String message) => message,
      };

  /// 双分支折叠。
  R when<R>({
    required R Function(T value) success,
    required R Function(String message) failure,
  }) =>
      switch (this) {
        Success<T>(:final T value) => success(value),
        Failure<T>(:final String message) => failure(message),
      };

  /// 成功时执行 [fn] 并返回原结果；失败时原样返回。
  Result<T> onSuccess(void Function(T value) fn) {
    if (this case Success<T>(:final T value)) {
      fn(value);
    }
    return this;
  }

  /// 失败时执行 [fn] 并返回原结果；成功时原样返回。
  Result<T> onFailure(void Function(String message) fn) {
    if (this case Failure<T>(:final String message)) {
      fn(message);
    }
    return this;
  }

  /// 构造成功结果。
  static Result<T> ok<T>(T value) => Success<T>(value);

  /// 构造失败结果。
  static Result<T> fail<T>(String message) => Failure<T>(message);
}

/// 成功结果。
final class Success<T> extends Result<T> {
  /// 成功携带的值。
  final T value;

  const Success(this.value);

  @override
  String toString() => 'Success($value)';
}

/// 失败结果。
final class Failure<T> extends Result<T> {
  /// 失败消息（已本地化，可直接 Toast）。
  final String message;

  const Failure(this.message);

  @override
  String toString() => 'Failure($message)';
}
