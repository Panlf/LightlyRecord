import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 应用配置：包名、版本兜底、示例数据开关键名。
///
/// `package_info_plus` 在 Web/桌面端可能不可用，因此所有取值都提供兜底常量，
/// 保证 `AppConfig.version()` 永不抛异常。
class AppConfig {
  const AppConfig._();

  /// 应用展示名。
  static const String appName = '轻记';

  /// 应用英文标识（用于导出文件名等）。
  static const String appSlug = 'lightly_record';

  /// Android applicationId / 包名。
  static const String packageName = 'com.lightly.record';

  /// 版本名兜底值（读取失败时使用）。
  static const String fallbackVersion = '1.0.0';

  /// 版本号兜底值。
  static const String fallbackBuildNumber = '1';

  /// 关于页文案中的「交互原型」标识（不得出现在正式包中）。
  static const String prototypeTag = '原型演示';

  /// 读取真实版本信息；失败时回落到兜底常量。
  ///
  /// 返回 `(versionName, buildNumber)`。
  static Future<(String, String)> resolvedVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final version = info.version.trim();
      final build = info.buildNumber.trim();
      return (
        version.isEmpty ? fallbackVersion : version,
        build.isEmpty ? fallbackBuildNumber : build,
      );
    } catch (e, s) {
      debugPrint('AppConfig.resolvedVersion failed: $e\n$s');
      return (fallbackVersion, fallbackBuildNumber);
    }
  }

  /// 「关于轻记」弹窗标题下方的版本行，如 `1.0.0 (1)`。
  static Future<String> versionLine() async {
    final (v, b) = await resolvedVersion();
    return b.isEmpty || b == '1' ? v : '$v ($b)';
  }
}
