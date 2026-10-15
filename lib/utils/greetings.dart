import '../core/constants.dart';

/// 按时段问候语（早 / 上午 / 中午 / 下午 / 晚上）。
///
/// 与原型页头「下午好，清风」的句式保持一致：`<时段>好，<昵称>`。
class Greetings {
  const Greetings._();

  /// 早上（05:00 ~ 08:59）。
  static const String morning = '早上';

  /// 上午（09:00 ~ 11:59）。
  static const String forenoon = '上午';

  /// 中午（12:00 ~ 13:59）。
  static const String noon = '中午';

  /// 下午（14:00 ~ 17:59）。
  static const String afternoon = '下午';

  /// 晚上（18:00 ~ 次日 04:59）。
  static const String evening = '晚上';

  /// 由小时数推导时段。
  ///
  /// [hour] 取 `DateTime.now().hour`（0~23）；越界值按晚上处理。
  static String periodOf(int hour) {
    if (hour >= 5 && hour < 9) return morning;
    if (hour >= 9 && hour < AppConstants.noonHour) return forenoon;
    if (hour >= AppConstants.noonHour && hour < 14) return noon;
    if (hour >= 14 && hour < 18) return afternoon;
    return evening;
  }

  /// 当前时机的问候语，如 `'下午好，清风'`。
  ///
  /// [nickname] 为空时省略逗号与昵称，只返回 `'下午好'`。
  static String now([String? nickname]) {
    final period = periodOf(DateTime.now().hour);
    final name = (nickname ?? '').trim();
    return name.isEmpty ? '$period好' : '$period好，$name';
  }
}
