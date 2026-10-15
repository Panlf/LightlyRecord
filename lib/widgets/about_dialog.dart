import 'package:flutter/material.dart';

import '../core/app_config.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_typography.dart';

/// 「关于轻记」弹窗（R22）。
///
/// 6 条功能说明 + `package_info_plus` 真实版本号（失败回落 `AppConfig.fallbackVersion`）。
class AboutDialog {
  const AboutDialog._();

  /// 功能说明条目。
  static const List<(String, String)> _features = [
    ('本地记账', '全部数据只存在本机 SQLite，不上传、不联网'),
    ('收支分类', '9 类支出 / 6 类收入，支持自定义分类与排序'),
    ('日历热力', '按日展示支出热度，点日期看当日明细'),
    ('图表统计', '环形占比、近 6 期柱状、同期对比仪表'),
    ('多账本', '按场景分账本记录，统计跟随当前账本'),
    ('预算提醒', '设置每月预算，超支即时标红'),
  ];

  /// 展示弹窗。
  static Future<void> show(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const _AboutBody(),
    );
  }
}

/// 弹窗主体。
class _AboutBody extends StatelessWidget {
  const _AboutBody();

  /// 版本行 future（类级缓存：一次会话只读一次平台信息）。
  static final Future<String> _versionFuture = AppConfig.versionLine();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    return Dialog(
      backgroundColor: c.card,
      surfaceTintColor: c.card,
      insetPadding: const EdgeInsets.all(AppDimens.dialogMaskPadding),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.dialogRadius),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppDimens.dialogMaxWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 应用图标 + 名称 + 版本
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: c.greenLight,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.account_balance_wallet,
                    size: 28,
                    color: c.greenDeep,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                AppConfig.appName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppTypography.pageTitle,
                  fontWeight: AppTypography.semiBold,
                  color: c.ink,
                ),
              ),
              const SizedBox(height: 4),
              FutureBuilder<String>(
                // 缓存的 future：版本号一次会话只需读一次平台信息，
                // 放在 build 里会随 rebuild 反复读取平台通道
                future: _versionFuture,
                builder: (context, snapshot) {
                  final text = snapshot.data ?? AppConfig.fallbackVersion;
                  return Text(
                    '版本 $text',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: AppTypography.txnNote,
                      color: c.ink3,
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),
              // 6 条功能说明
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (title, desc) in AboutDialog._features)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.only(top: 6, right: 10),
                                decoration: BoxDecoration(
                                  color: c.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                      fontSize: AppTypography.txnNote,
                                      color: c.ink2,
                                      height: 1.5,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: '$title：',
                                        style: TextStyle(
                                          fontWeight: AppTypography.medium,
                                          color: c.ink,
                                        ),
                                      ),
                                      TextSpan(text: desc),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '轻记 · 极简记账，数据归你所有。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppTypography.chip,
                  color: c.ink3,
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.green,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    '知道了',
                    style: TextStyle(
                      fontSize: AppTypography.segLabel,
                      fontWeight: AppTypography.medium,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
