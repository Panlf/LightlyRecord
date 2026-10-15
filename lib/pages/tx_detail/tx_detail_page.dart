import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date_ext.dart';
import '../../core/format.dart';
import '../../data/model/category.dart';
import '../../data/model/txn.dart';
import '../../data/model/tx_type.dart';
import '../../icons/app_icons.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_typography.dart';
import '../../utils/amount_input.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_segment.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/cat_grid.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/num_keypad.dart';

/// 交易详情 / 编辑 / 删除滑入页（R17，原型未覆盖的原生新增页面）。
///
/// - 查看态：分类图标 / 名称 / 备注 / 金额 / 日期时间 + 「编辑」「删除」；
/// - 编辑态：金额（复用 [AmountInput] 状态机）/ 分类 / 备注 / 日期 / 类型；
/// - 删除：二次确认弹窗，删除后派生指标全部重算（`bumpData()`）。
///
/// 路由约定：`AppRoutes.txDetail` 的 `arguments` 传 `int txnId`。
class TxDetailPage extends StatefulWidget {
  /// 交易 id；`<= 0` 视为无效参数，直接展示错误态。
  const TxDetailPage({required this.txnId, super.key});

  /// 交易 id。
  final int txnId;

  @override
  State<TxDetailPage> createState() => _TxDetailPageState();
}

class _TxDetailPageState extends State<TxDetailPage> {
  final AmountInput _amount = AmountInput();

  Txn? _txn;
  bool _loading = true;
  bool _editing = false;
  bool _saving = false;

  // 编辑态临时值
  TxType _type = TxType.expense;
  List<Category> _categories = const [];
  int? _categoryId;
  String _note = '';
  DateTime _date = today();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final appState = context.read<AppState>();
    final txn = await appState.txnRepo.getById(widget.txnId);
    if (!mounted) return;
    setState(() {
      _txn = txn;
      _loading = false;
    });
  }

  /// 进入编辑态：把当前交易灌入表单。
  void _startEdit() {
    final txn = _txn;
    if (txn == null) return;
    setState(() {
      _editing = true;
      _type = txn.type;
      _categoryId = txn.categoryId;
      _note = txn.note;
      _date = parseYmd(txn.txDate);
      _amount.setMinor(txn.amountMinor);
    });
    _loadCategories();
  }

  void _cancelEdit() {
    setState(() => _editing = false);
  }

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
      if (!list.any((c) => c.id == _categoryId)) {
        _categoryId = list.isNotEmpty ? list.first.id : null;
      }
    });
  }

  void _onTypeChanged(TxType type) {
    if (type == _type) return;
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
    final txn = _txn;
    if (txn == null || _saving) return;

    if (_amount.isZero) {
      AppToast.show('请输入金额', error: true);
      return;
    }
    final categoryId = _categoryId;
    if (categoryId == null) {
      AppToast.show('请选择分类', error: true);
      return;
    }

    final appState = context.read<AppState>();
    setState(() => _saving = true);

    final result = await appState.txnRepo.update(
      txn.copyWith(
        categoryId: categoryId,
        type: _type,
        amountMinor: _amount.minor,
        note: _note,
        txDate: ymd(_date),
      ),
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (result.isSuccess) {
      appState.bumpData();
      AppToast.show('已保存');
      await _load();
      if (!mounted) return;
      setState(() => _editing = false);
    } else {
      AppToast.show(result.messageOrNull ?? '保存失败，请重试', error: true);
    }
  }

  Future<void> _delete() async {
    final txn = _txn;
    if (txn == null) return;

    final confirmed = await ConfirmDialog.showDelete(context);
    if (!confirmed || !mounted) return;

    final appState = context.read<AppState>();
    final result = await appState.txnRepo.delete(txn.id);
    if (!mounted) return;

    if (result.isSuccess) {
      appState.bumpData();
      AppToast.show('已删除');
      Navigator.of(context).pop();
    } else {
      AppToast.show(result.messageOrNull ?? '删除失败，请重试', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _txn == null
                ? _NotFound(onRetry: _load)
                : _editing
                    ? _buildEditor(c)
                    : _buildDetail(c),
      ),
    );
  }

  // ---------------------------------------------------------------- 查看态

  Widget _buildDetail(AppColors c) {
    final txn = _txn!;
    final date = parseYmd(txn.txDate);

    return Column(
      children: [
        _TopBar(
          title: '交易详情',
          saving: false,
          onCancel: () => Navigator.of(context).pop(),
          onSave: null,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.pageMargin,
              8,
              AppDimens.pageMargin,
              24,
            ),
            children: [
              AppCard(
                child: Column(
                  children: [
                    Container(
                      width: AppDimens.catIconSize,
                      height: AppDimens.catIconSize,
                      decoration: BoxDecoration(
                        color: hexToColor(txn.categoryColorBg ??
                            AppConstantsLike.defaultCategoryColorBg),
                        borderRadius:
                            BorderRadius.circular(AppDimens.catIconRadius),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        AppIcons.fromCodepoint(
                          txn.categoryIconCodepoint ?? 0,
                        ),
                        size: 22,
                        color: hexToColor(txn.categoryColorStroke ??
                            AppConstantsLike.defaultCategoryColorStroke),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      txn.categoryName ?? '未分类',
                      style: TextStyle(
                        fontSize: AppTypography.pageTitle,
                        fontWeight: AppTypography.semiBold,
                        color: c.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      fmtSigned(txn.amountMinor, txn.type),
                      style: AppTypography.numberStyle(
                        fontSize: 30,
                        fontWeight: AppTypography.bold,
                        color: txn.type.isIncome ? c.green : c.red,
                      ),
                    ),
                    if (txn.note.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        txn.note.trim(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: AppTypography.body,
                          color: c.ink2,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Divider(color: c.line, height: 1),
                    const SizedBox(height: 14),
                    _InfoRow(
                      label: '类型',
                      value: txn.type.label,
                      colors: c,
                    ),
                    const SizedBox(height: 10),
                    _InfoRow(
                      label: '日期',
                      value: '${date.year}年${date.month}月${date.day}日 ${weekdayCn(date)}',
                      colors: c,
                    ),
                    const SizedBox(height: 10),
                    _InfoRow(
                      label: '时间',
                      value: txn.txTime,
                      colors: c,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimens.pageGap),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: '编辑',
                      background: c.green,
                      foreground: AppColors.onGreen,
                      icon: Icons.edit_outlined,
                      onTap: _startEdit,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionButton(
                      label: '删除',
                      background: AppColors.redLight,
                      foreground: AppColors.redDeep,
                      icon: Icons.delete_outline,
                      onTap: _delete,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- 编辑态

  Widget _buildEditor(AppColors c) {
    return Column(
      children: [
        _TopBar(
          title: '编辑记录',
          saving: _saving,
          onCancel: _cancelEdit,
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
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.pageMargin,
                ),
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
                            _amount.display,
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
                            label: _note.trim().isEmpty ? '点击添加备注' : _note.trim(),
                            onTap: _editNote,
                          ),
                          const Spacer(),
                          _CardAction(
                            label: isSameDay(_date, today())
                                ? '今天 ${_date.month}月${_date.day}日'
                                : '${_date.month}月${_date.day}日 ${weekdayCn(_date)}',
                            onTap: _pickDate,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
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
                  onSelected: (item) => setState(() => _categoryId = item.id),
                ),
              ),
              const SizedBox(height: AppDimens.pageGap),
            ],
          ),
        ),
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
    );
  }
}

/// 分类数据色兜底（与 `core/constants.dart` 同源，避免本文件直接写色值）。
class AppConstantsLike {
  const AppConstantsLike._();

  /// 分类图标底色兜底。
  static const String defaultCategoryColorBg = '#EEF2F0';

  /// 分类图标前景兜底。
  static const String defaultCategoryColorStroke = '#9DB3A9';
}

/// 详情态的一行「标签 / 值」。
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.colors,
  });

  final String label;
  final String value;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: AppTypography.body, color: c.ink2),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: AppTypography.body,
            fontWeight: AppTypography.medium,
            color: c.ink,
          ),
        ),
      ],
    );
  }
}

/// 查看态的大按钮（编辑 / 删除）。
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData icon;
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: AppTypography.segLabel,
                fontWeight: AppTypography.medium,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 顶栏：取消 / 标题 / 保存（保存为 null 时右侧留空）。
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.saving,
    required this.onCancel,
    required this.onSave,
  });

  final String title;
  final bool saving;
  final VoidCallback onCancel;
  final VoidCallback? onSave;

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
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: AppTypography.semiBold,
                color: c.ink,
              ),
            ),
            const Spacer(),
            if (onSave != null)
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
              )
            else
              const SizedBox(width: 40),
          ],
        ),
      ),
    );
  }
}

/// 金额卡内的文字按钮。
class _CardAction extends StatelessWidget {
  const _CardAction({required this.label, required this.onTap, this.icon});

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

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
              maxLines: 1,
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

/// 备注输入弹窗。
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
                maxLength: 50,
                decoration: InputDecoration(
                  hintText: '选填，最多 50 字',
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

/// 交易不存在（已被删除 / id 非法）。
class _NotFound extends StatelessWidget {
  const _NotFound({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    return Column(
      children: [
        const SizedBox(height: 44),
        Text(
          '记录不存在或已被删除',
          style: TextStyle(fontSize: AppTypography.body, color: c.ink2),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: onRetry,
          style: FilledButton.styleFrom(
            backgroundColor: c.green,
            foregroundColor: AppColors.onGreen,
          ),
          child: const Text('重试'),
        ),
      ],
    );
  }
}
