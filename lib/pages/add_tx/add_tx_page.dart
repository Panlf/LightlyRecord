import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/date_ext.dart';
import '../../data/model/category.dart';
import '../../data/model/tx_type.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_typography.dart';
import '../../utils/amount_input.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_segment.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/cat_grid.dart';
import '../../widgets/num_keypad.dart';

/// 记一笔滑入页。
///
/// 交互规格（对齐原型 `#screen-add` 与架构文档 G1「3 秒记一笔」）：
/// - 三态分段（支出 / 收入 / 转账），**进入即支出态 + 默认分类已选中**；
/// - 金额卡 `¥` + 40px 700 大数字，下方「点击添加备注」+ 日期按钮；
/// - 分类宫格 4 列，随收支态切换；**转账态置灰**，点击 Toast 并回落支出态；
/// - 金额为 0 时 Toast「请输入金额」且不落库；
/// - 保存成功后 `AppState.bumpData()`，首页 / 日历 / 图表三处数字同步刷新。
class AddTxPage extends StatefulWidget {
  const AddTxPage({super.key});

  @override
  State<AddTxPage> createState() => _AddTxPageState();
}

class _AddTxPageState extends State<AddTxPage> {
  final AmountInput _amount = AmountInput();

  TxType _type = TxType.expense;
  List<Category> _categories = const [];
  int? _categoryId;
  String _note = '';
  DateTime _date = today();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCategories());
  }

  /// 载入当前收支态的分类，并默认选中第一个（G1：进入即可直接保存）。
  Future<void> _loadCategories() async {
    final appState = context.read<AppState>();
    // 捕获请求时的类型：in-flight 期间用户又切了收支态，本次结果作废，
    // 否则会出现「收入态宫格里混着支出分类」的错列。
    final type = _type;
    final list = await appState.categoryRepo.listEnabledByType(
      type,
      bookId: appState.bookId,
    );
    if (!mounted) return;
    if (type != _type) return;
    setState(() {
      _categories = list;
      // 已选分类不属于新类型时重置；否则保持（切换收支态后回看不丢选择）
      _categoryId = list.any((c) => c.id == _categoryId)
          ? _categoryId
          : (list.isNotEmpty ? list.first.id : null);
    });
  }

  /// 切换收支态：重置分类选择并重载宫格。
  void _onTypeChanged(TxType type) {
    if (type == _type) return;
    // 转账态：P2 未开放，Toast 后自动回落支出态，DB 绝不产生 type=3 记录。
    if (type.isTransfer) {
      AppToast.show('转账功能暂未开放', error: true);
      return;
    }
    setState(() {
      _type = type;
      _categoryId = null;
    });
    _loadCategories();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: kDatePickerFirst,
      lastDate: kDatePickerLast,
      helpText: '选择日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked == null || !mounted) return;
    setState(() => _date = picked);
  }

  Future<void> _editNote() async {
    final controller = TextEditingController(text: _note);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _NoteDialog(controller: controller),
    );
    // 对话框已关闭，及时释放控制器（避免反复打开备注累积泄漏）
    controller.dispose();
    if (!mounted) return;
    if (result != null) {
      setState(() => _note = result.trim());
    }
  }

  Future<void> _save() async {
    if (_saving) return;

    // 校验 1：金额为 0 → 不落库
    if (_amount.isZero) {
      AppToast.show('请输入金额', error: true);
      return;
    }
    // 校验 2：必须选中分类（宫格为空时兜底）
    final categoryId = _categoryId;
    if (categoryId == null) {
      AppToast.show('请选择分类', error: true);
      return;
    }

    final appState = context.read<AppState>();
    setState(() => _saving = true);

    final result = await appState.txnRepo.add(
      bookId: appState.bookId,
      categoryId: categoryId,
      type: _type,
      amountMinor: _amount.minor,
      note: _note,
      date: _date,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (result.isSuccess) {
      // 写操作完成 → 全局版本号 +1，五个页面一起重算
      appState.bumpData();
      AppToast.show('已保存');
      Navigator.of(context).pop();
    } else {
      AppToast.show(result.messageOrNull ?? '保存失败，请重试', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              saving: _saving,
              onCancel: () => Navigator.of(context).pop(),
              onSave: _save,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 18),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.pageMargin,
                    ),
                    child: AppSegment<TxType>(
                      values: const [
                        TxType.expense,
                        TxType.income,
                        TxType.transfer,
                      ],
                      value: _type,
                      labels: const ['支出', '收入', '转账'],
                      onChanged: _onTypeChanged,
                    ),
                  ),
                  const SizedBox(height: AppDimens.pageGap),
                  _AmountCard(
                    amount: _amount,
                    note: _note,
                    date: _date,
                    onEditNote: _editNote,
                    onPickDate: _pickDate,
                  ),
                  const SizedBox(height: AppDimens.pageGap),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.pageMargin,
                    ),
                    child: Text(
                      '选择分类',
                      style: TextStyle(
                        fontSize: AppTypography.body,
                        color: c.ink2,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimens.cardGap),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.pageMargin,
                    ),
                    child: CatGrid(
                      items: [
                        for (final cat in _categories)
                          CatItem(
                            id: cat.id,
                            name: cat.name,
                            iconKey: cat.iconKey,
                            iconCodepoint: cat.iconCodepoint,
                            colorBg: cat.colorBg,
                            colorStroke: cat.colorStroke,
                          ),
                      ],
                      selectedId: _categoryId,
                      onSelected: (item) =>
                          setState(() => _categoryId = item.id),
                    ),
                  ),
                  const SizedBox(height: AppDimens.pageGap),
                ],
              ),
            ),
            // 键盘固定在底部，不随内容滚动
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.pageMargin,
                0,
                AppDimens.pageMargin,
                12,
              ),
              child: NumKeypad(
                onDigit: (k) => setState(() => _amount.input(k)),
                onBackspace: () => setState(() => _amount.backspace()),
                onDone: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 顶栏：取消 / 标题 / 保存。
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.saving,
    required this.onCancel,
    required this.onSave,
  });

  final bool saving;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.pageMargin),
        child: Row(
          children: [
            GestureDetector(
              onTap: onCancel,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Icon(Icons.chevron_left, size: 17, color: c.ink2),
                  Text(
                    '取消',
                    style: TextStyle(
                      fontSize: AppTypography.segLabel,
                      color: c.ink2,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Text(
              '记一笔',
              style: TextStyle(
                fontSize: 18,
                fontWeight: AppTypography.semiBold,
                color: c.ink,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: saving ? null : onSave,
              behavior: HitTestBehavior.opaque,
              child: Text(
                saving ? '保存中' : '保存',
                style: TextStyle(
                  fontSize: AppTypography.segLabel,
                  fontWeight: AppTypography.semiBold,
                  color: saving ? c.ink3 : c.green,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 金额卡：`¥` + 40px 700 大数字 + 备注按钮 + 日期按钮。
class _AmountCard extends StatelessWidget {
  const _AmountCard({
    required this.amount,
    required this.note,
    required this.date,
    required this.onEditNote,
    required this.onPickDate,
  });

  final AmountInput amount;
  final String note;
  final DateTime date;
  final VoidCallback onEditNote;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.pageMargin),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '¥',
                  style: TextStyle(
                    fontSize: 20,
                    color: c.ink2,
                    fontFamily: AppTypography.numberFontFamily,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  amount.display,
                  style: AppTypography.numberStyle(
                    fontSize: AppTypography.bigAmount,
                    fontWeight: AppTypography.bold,
                    color: c.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _CardAction(
                  icon: Icons.edit_outlined,
                  label: note.trim().isEmpty ? '点击添加备注' : note.trim(),
                  maxLines: 1,
                  onTap: onEditNote,
                ),
                const Spacer(),
                _CardAction(
                  icon: null,
                  label: isSameDay(date, today())
                      ? '今天 ${date.month}月${date.day}日'
                      : '${date.month}月${date.day}日 ${weekdayCn(date)}',
                  onTap: onPickDate,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 金额卡内的文字按钮（备注 / 日期）。
class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.label,
    required this.onTap,
    this.icon,
    this.maxLines,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: c.ink3),
            const SizedBox(width: 4),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              label,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: AppTypography.txnNote,
                color: c.ink3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 备注输入弹窗（自绘，保证主题 Token 生效）。
class _NoteDialog extends StatelessWidget {
  const _NoteDialog({required this.controller});

  final TextEditingController controller;

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
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '添加备注',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppTypography.pageTitle,
                  fontWeight: AppTypography.semiBold,
                  color: c.ink,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: AppConstants.maxNoteLength,
                decoration: InputDecoration(
                  hintText: '选填，最多 ${AppConstants.maxNoteLength} 字',
                  hintStyle: TextStyle(
                    fontSize: AppTypography.body,
                    color: c.ink3,
                  ),
                  filled: true,
                  fillColor: c.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: TextStyle(fontSize: AppTypography.body, color: c.ink),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _DialogButton(
                      label: '取消',
                      foreground: c.ink2,
                      background: c.track,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DialogButton(
                      label: '确定',
                      foreground: AppColors.onGreen,
                      background: c.green,
                      onTap: () =>
                          Navigator.of(context).pop(controller.text.trim()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.foreground,
    required this.background,
    required this.onTap,
  });

  final String label;
  final Color foreground;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: AppTypography.segLabel,
            fontWeight: AppTypography.medium,
            color: foreground,
          ),
        ),
      ),
    );
  }
}
