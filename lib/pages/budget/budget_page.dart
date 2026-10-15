import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_switch.dart';
import '../../widgets/app_toast.dart';

/// 预算管理滑入页。
///
/// 行为对齐原型 `#screen-budget`：
/// - 开关默认关；启用后才展开金额输入；
/// - 保存走 [BudgetRepository]（启用时金额必须 > 0，校验失败
///   Toast 仓库给出的文案且不关闭页面）；
/// - 保存成功 `bumpData()` 让首页预算卡立即显隐。
class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key});

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  bool _enabled = false;
  bool _loading = true;
  bool _saving = false;
  final TextEditingController _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  /// 回显已保存的预算（失败按默认关闭处理）。
  Future<void> _load() async {
    final budget = await context.read<AppState>().budgetRepo.get();
    if (!mounted) return;
    setState(() {
      _enabled = budget.enabled;
      _loading = false;
      if (budget.monthlyAmountMinor > 0) {
        _amountController.text = fmtMoney(budget.monthlyAmountMinor);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // 头部：取消 / 标题 / 保存
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SizedBox(
                height: 44,
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.chevron_left, size: 20),
                      label: const Text('取消'),
                      style: TextButton.styleFrom(
                        foregroundColor: c.ink2,
                        textStyle: const TextStyle(
                          fontSize: AppTypography.segLabel,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '预算管理',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: AppTypography.semiBold,
                        color: c.ink,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _saving ? null : _onSave,
                      child: Text(
                        '保存',
                        style: TextStyle(
                          fontSize: AppTypography.segLabel,
                          fontWeight: AppTypography.semiBold,
                          color: _saving ? c.ink3 : c.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.only(
                        left: AppDimens.pageMargin,
                        right: AppDimens.pageMargin,
                        bottom: 24,
                      ),
                      children: [
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '启用预算管理',
                                          style: TextStyle(
                                            fontSize: AppTypography.cardTitle,
                                            fontWeight: AppTypography.medium,
                                            color: c.ink,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '默认关闭；启用后明细页才会展示预算统计',
                                          style: TextStyle(
                                            fontSize: AppTypography.txnNote,
                                            color: c.ink2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  AppSwitch(
                                    value: _enabled,
                                    onChanged: (v) =>
                                        setState(() => _enabled = v),
                                  ),
                                ],
                              ),
                              if (_enabled) ...[
                                const SizedBox(height: 16),
                                Text(
                                  '每月预算（元）',
                                  style: TextStyle(
                                    fontSize: AppTypography.txnNote,
                                    color: c.ink2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _AmountField(controller: _amountController),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: AppDimens.pageGap),
                        Text(
                          '启用后，明细页将展示本月预算进度、已用与剩余金额，超支时红色提醒',
                          style: TextStyle(
                            fontSize: AppTypography.txnNote,
                            color: c.ink3,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 保存：金额解析 → 仓库校验 → 落库 → bumpData → 关闭。
  Future<void> _onSave() async {
    final input = _amountController.text.trim();
    final minor = _enabled ? parseYuanToMinor(input) : 0;

    setState(() => _saving = true);
    final result = await context
        .read<AppState>()
        .budgetRepo
        .save(enabled: _enabled, monthlyAmountMinor: minor);
    if (!mounted) return;
    setState(() => _saving = false);

    if (result.isFailure) {
      // 校验失败：Toast 仓库文案，停留在本页
      AppToast.show(result.messageOrNull ?? '保存失败', error: true);
      return;
    }
    // 首页预算卡立即显隐
    context.read<AppState>().bumpData();
    AppToast.show(_enabled ? '预算已保存' : '预算已关闭');
    Navigator.pop(context);
  }
}

/// 预算金额输入行（¥ 前缀 + 数字键盘）。
class _AmountField extends StatelessWidget {
  const _AmountField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: c.track,
        borderRadius: BorderRadius.circular(AppDimens.segRadius),
      ),
      child: Row(
        children: [
          Text(
            '¥',
            style: TextStyle(
              fontSize: AppTypography.budgetInput,
              color: c.ink2,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                // 只放行数字与至多一个小数点（拦掉负号 / 字母 / 多点）
                FilteringTextInputFormatter.allow(RegExp('[0-9.]')),
                LengthLimitingTextInputFormatter(10),
              ],
              style: TextStyle(
                fontSize: AppTypography.budgetInput,
                fontWeight: AppTypography.semiBold,
                color: c.ink,
              ),
              cursorColor: c.green,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: '0.00',
                hintStyle: TextStyle(
                  fontSize: AppTypography.budgetInput,
                  color: c.ink3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
