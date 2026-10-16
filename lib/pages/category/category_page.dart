import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../data/model/category.dart';
import '../../data/model/tx_type.dart';
import '../../icons/app_icons.dart';
import '../../repository/pref_repository.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_segment.dart';
import '../../widgets/app_switch.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/confirm_dialog.dart';

/// 账本与分类管理滑入页。
///
/// 内容：
/// - 支出 / 收入 / 转账三态分段，宫格展示对应分类；
/// - 自定义分类增删改排序 + 图标 / 颜色选择器（系统分类不可删除）；
/// - 底部「演示数据」区：载入示例 / 清空全部。
///
/// 所有写操作走 [CategoryRepository] / [TxnRepository]，
/// 成功后 `bumpData()` 让全机统计刷新。
class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  TxType _type = TxType.expense;
  List<Category> _categories = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await context.read<AppState>().categoryRepo.listByType(_type);
    if (!mounted) return;
    setState(() {
      _categories = list;
      _loading = false;
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
            // 头部：返回 / 标题 / 占位
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SizedBox(
                height: 44,
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.chevron_left, size: 20),
                      label: const Text('返回'),
                      style: TextButton.styleFrom(
                        foregroundColor: c.ink2,
                        textStyle:
                            const TextStyle(fontSize: AppTypography.segLabel),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '账本与分类',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: AppTypography.semiBold,
                        color: c.ink,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 64),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(
                  left: AppDimens.pageMargin,
                  right: AppDimens.pageMargin,
                  bottom: 24,
                ),
                children: [
                  // 三态分段
                  AppSegment<TxType>(
                    values: const [TxType.expense, TxType.income, TxType.transfer],
                    value: _type,
                    labels: const ['支出', '收入', '转账'],
                    onChanged: (v) {
                      if (v == _type) return;
                      setState(() {
                        _type = v;
                        _loading = true;
                      });
                      _load();
                    },
                  ),
                  const SizedBox(height: AppDimens.pageGap),

                  // 分类宫格
                  AppCard(
                    child: _loading
                        ? const SizedBox(
                            height: 120,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : _categories.isEmpty
                            ? _EmptyTypeHint(type: _type)
                            : _CategoryGrid(
                                categories: _categories,
                                onTap: _onEditCategory,
                                onAdd: _onCreateCategory,
                              ),
                  ),
                  const SizedBox(height: AppDimens.pageGap),

                  // 演示数据区
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '演示数据',
                          style: TextStyle(
                            fontSize: AppTypography.cardTitle,
                            fontWeight: AppTypography.medium,
                            color: c.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '载入近 10 天的示例交易体验完整功能；清空只删交易，不删账本与分类',
                          style: TextStyle(
                            fontSize: AppTypography.txnNote,
                            color: c.ink2,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _DemoButton(
                                label: '载入示例数据',
                                icon: Icons.download_outlined,
                                primary: true,
                                onTap: _onLoadSample,
                              ),
                            ),
                            const SizedBox(width: AppDimens.cardGap),
                            Expanded(
                              child: _DemoButton(
                                label: '清空全部交易',
                                icon: Icons.delete_outline,
                                primary: false,
                                onTap: _onClearAll,
                              ),
                            ),
                          ],
                        ),
                      ],
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

  // ================================================================ 分类管理

  /// 点分类 → 编辑面板（系统分类禁删，其余全可改）。
  Future<void> _onEditCategory(Category category, int index) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _CategoryEditSheet(
          category: category,
          index: index,
          total: _categories.length,
          onRename: (name) => _renameCategory(category, name),
          onChangeIcon: (option) => _updateCategory(
            category.copyWith(iconKey: option.key, iconCodepoint: option.icon.codePoint),
          ),
          onChangeColor: (option) => _updateCategory(
            category.copyWith(
              colorBg: hexLighten(option.hex),
              colorStroke: option.hex,
            ),
          ),
          onToggleEnabled: (enabled) =>
              _updateCategory(category.copyWith(enabled: enabled)),
          onMove: (delta) => _moveCategory(category, index, delta),
          onDelete: category.isSystem ? null : () => _deleteCategory(category),
        );
      },
    );
    // 面板关闭后刷新（禁用态影响宫格置灰）
    _load();
  }

  /// 新建自定义分类。
  Future<void> _onCreateCategory() async {
    final result = await showModalBottomSheet<({String name, AppIconOption icon, AppColorOption color})>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _CategoryCreateSheet(
        type: _type,
        existingNames: _categories.map((c) => c.name).toList(),
      ),
    );
    if (result == null || !mounted) return;

    final id = await context.read<AppState>().categoryRepo.create(
          name: result.name,
          type: _type,
          iconKey: result.icon.key,
          iconCodepoint: result.icon.icon.codePoint,
          // 浅底 + 深字成对入库，与 seed_data 色板结构一致
          colorBg: hexLighten(result.color.hex),
          colorStroke: result.color.hex,
        );
    if (!mounted) return;
    if (id <= 0) {
      AppToast.show('新建分类失败', error: true);
      return;
    }
    AppToast.show('已添加分类「${result.name}」');
    _load();
  }

  Future<void> _renameCategory(Category category, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == category.name) return;
    await _updateCategory(category.copyWith(name: trimmed));
  }

  /// 统一更新入口：仓库校验失败 Toast 原因，成功刷新列表。
  Future<void> _updateCategory(Category next) async {
    final result = await context.read<AppState>().categoryRepo.update(next);
    if (!mounted) return;
    if (result.isFailure) {
      AppToast.show(result.messageOrNull ?? '保存失败', error: true);
      return;
    }
    _load();
  }

  /// 上移 / 下移：重排后整表 reorder。
  Future<void> _moveCategory(Category category, int index, int delta) async {
    final target = index + delta;
    if (target < 0 || target >= _categories.length) return;
    final ids = _categories.map((e) => e.id).toList();
    final moved = ids.removeAt(index);
    ids.insert(target, moved);
    await context.read<AppState>().categoryRepo.reorder(ids);
    if (!mounted) return;
    AppToast.show(delta < 0 ? '已上移' : '已下移');
    _load();
  }

  /// 删除自定义分类（系统分类 / 有记录的分类由仓库层拒绝）。
  Future<void> _deleteCategory(Category category) async {
    final ok = await ConfirmDialog.show(
      context,
      title: '删除分类「${category.name}」？',
      message: '删除后不可恢复',
      confirmLabel: '删除',
    );
    if (!ok || !mounted) return;
    final result = await context.read<AppState>().categoryRepo.delete(category.id);
    if (!mounted) return;
    if (result.isFailure) {
      AppToast.show(result.messageOrNull ?? '删除失败', error: true);
      return;
    }
    AppToast.show('已删除分类「${category.name}」');
    _load();
  }

  // ================================================================ 演示数据

  /// 载入示例数据到当前账本。
  Future<void> _onLoadSample() async {
    final appState = context.read<AppState>();
    final loaded = await appState.prefRepo.sampleLoaded();
    if (loaded) {
      AppToast.show('示例数据已载入，可先「清空全部交易」再重新载入');
      return;
    }
    final inserted = await appState.txnRepo.loadSampleData(appState.bookId);
    if (inserted > 0) {
      await appState.prefRepo.setSampleLoaded(true);
      appState.bumpData();
    }
    if (!mounted) return;
    AppToast.show(inserted > 0 ? '已载入 $inserted 笔示例数据' : '示例数据载入失败');
  }

  /// 清空全部交易（二次确认）。
  Future<void> _onClearAll() async {
    final ok = await ConfirmDialog.show(
      context,
      title: '清空全部交易？',
      message: '将删除所有账本下的全部交易记录，不可恢复',
      confirmLabel: '清空',
    );
    if (!ok || !mounted) return;
    final appState = context.read<AppState>();
    final deleted = await appState.txnRepo.clearAll();
    await appState.prefRepo.setSampleLoaded(false);
    appState.bumpData();
    if (!mounted) return;
    AppToast.show(deleted > 0 ? '已清空 $deleted 笔交易' : '没有可清空的交易');
  }
}

/// 分类宫格（4 列）：现有分类 + 末尾「+」新增瓦片。
class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.categories,
    required this.onTap,
    required this.onAdd,
  });

  final List<Category> categories;
  final void Function(Category, int) onTap;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '共 ${categories.length} 个分类 · 点分类可编辑，长按拖动以外的调整在面板内完成',
          style: TextStyle(
            fontSize: AppTypography.txnNote,
            color: c.ink3,
          ),
        ),
        const SizedBox(height: AppDimens.cardGap),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: categories.length + 1,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: AppDimens.catColumns,
            mainAxisSpacing: AppDimens.catGap,
            crossAxisSpacing: AppDimens.catGap,
          ),
          itemBuilder: (context, index) {
            if (index == categories.length) {
              return _AddTile(onTap: onAdd);
            }
            final category = categories[index];
            return _CategoryTile(
              category: category,
              onTap: () => onTap(category, index),
            );
          },
        ),
      ],
    );
  }
}

/// 分类瓦片：图标（数据色）+ 名称；停用态置灰。
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.onTap});

  final Category category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final bg = hexToColor(category.colorBg);
    final stroke = hexToColor(category.colorStroke);
    final opacity = category.enabled ? 1.0 : 0.4;

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: opacity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: AppDimens.catIconSize,
              height: AppDimens.catIconSize,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(AppDimens.catIconRadius),
              ),
              alignment: Alignment.center,
              child: Icon(
                AppIcons.fromCodepoint(category.iconCodepoint, category.iconFontFamily),
                size: 22,
                color: stroke,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: AppTypography.catName,
                color: c.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 「+」新增瓦片。
class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: AppDimens.catIconSize,
            height: AppDimens.catIconSize,
            decoration: BoxDecoration(
              color: c.track,
              borderRadius: BorderRadius.circular(AppDimens.catIconRadius),
              border: Border.all(color: c.dashed, width: 1.5),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.add, size: 22, color: c.green),
          ),
          const SizedBox(height: 6),
          Text(
            '新增',
            style: TextStyle(
              fontSize: AppTypography.catName,
              color: c.ink2,
            ),
          ),
        ],
      ),
    );
  }
}

/// 某类型无分类时的提示（转账态走这里）。
class _EmptyTypeHint extends StatelessWidget {
  const _EmptyTypeHint({required this.type});

  final TxType type;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return SizedBox(
      height: 120,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.of('transfer'), size: 30, color: c.ink3),
            const SizedBox(height: 8),
            Text(
              type == TxType.transfer ? '转账功能暂未开放，无需选择分类' : '暂无分类',
              style: TextStyle(
                fontSize: AppTypography.txnNote,
                color: c.ink3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 演示数据按钮（主 / 次两种样式）。
class _DemoButton extends StatelessWidget {
  const _DemoButton({
    required this.label,
    required this.icon,
    required this.primary,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final color = primary ? c.green : c.red;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: primary ? color : c.card,
          borderRadius: BorderRadius.circular(AppDimens.segItemRadius),
          border: primary ? null : Border.all(color: c.line),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 17,
              color: primary ? AppColors.onGreen : color,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: AppTypography.segSmLabel,
                fontWeight: AppTypography.medium,
                color: primary ? AppColors.onGreen : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 分类编辑面板：名称 + 图标选择 + 颜色选择 + 启用开关 + 移动 / 删除。
class _CategoryEditSheet extends StatefulWidget {
  const _CategoryEditSheet({
    required this.category,
    required this.index,
    required this.total,
    required this.onRename,
    required this.onChangeIcon,
    required this.onChangeColor,
    required this.onToggleEnabled,
    required this.onMove,
    this.onDelete,
  });

  final Category category;
  final int index;
  final int total;
  final Future<void> Function(String) onRename;
  final Future<void> Function(AppIconOption) onChangeIcon;
  final Future<void> Function(AppColorOption) onChangeColor;
  final Future<void> Function(bool) onToggleEnabled;
  final Future<void> Function(int) onMove;

  /// 系统分类为 null（不显示删除入口）。
  final Future<void> Function()? onDelete;

  @override
  State<_CategoryEditSheet> createState() => _CategoryEditSheetState();
}

class _CategoryEditSheetState extends State<_CategoryEditSheet> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.category.name);

  /// 面板本地选中态：滑入页是独立路由，父级 setState 不会传导进来，
  /// 若不在这里持有状态，切换图标 / 颜色后高亮不动（用户以为没生效）。
  late String _iconKey;
  late String _colorStroke;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    _iconKey = widget.category.iconKey;
    _colorStroke = widget.category.colorStroke;
    _enabled = widget.category.enabled;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// 应用改名（有变化才写库）。
  Future<void> _applyRename() async {
    final next = _nameController.text.trim();
    if (next.isEmpty || next == widget.category.name) return;
    await widget.onRename(next);
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    return SafeArea(
      child: Container(
        // 底部补键盘高度：面板带输入框，键盘弹出时不遮住底部操作按钮
        padding: EdgeInsets.fromLTRB(
          AppDimens.cardPadding,
          AppDimens.cardPadding,
          AppDimens.cardPadding,
          AppDimens.cardPadding + MediaQuery.viewInsetsOf(context).bottom,
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppDimens.cardRadius),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.track2,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppDimens.pageGap),
              // 名称
              TextField(
                controller: _nameController,
                maxLength: 12,
                style: TextStyle(
                  fontSize: AppTypography.segLabel,
                  fontWeight: AppTypography.semiBold,
                  color: c.ink,
                ),
                cursorColor: c.green,
                onSubmitted: widget.onRename,
                decoration:
                    AppDialog.fieldDecoration(context, labelText: '分类名称'),
              ),
              const SizedBox(height: AppDimens.pageGap),

              // 图标选择
              Text('图标', style: _sectionStyle(c)),
              const SizedBox(height: 8),
              _OptionGrid(
                options: AppIcons.optionsFor(
                  widget.category.type == TxType.income,
                ),
                selectedKey: _iconKey,
                itemBuilder: (option, selected) => Container(
                  // 必须显式给尺寸：外层 Center 让 Container 退化成 hug 内部
                  // 图标，背景圆框就刚好把图标紧包住（见 AppDimens.optionChipSize）。
                  width: AppDimens.optionChipSize,
                  height: AppDimens.optionChipSize,
                  decoration: BoxDecoration(
                    color: selected ? c.greenLight : c.track,
                    borderRadius:
                        BorderRadius.circular(AppDimens.optionChipRadius),
                    border: selected ? Border.all(color: c.green) : null,
                  ),
                  alignment: Alignment.center,
                  child: Icon(option.icon,
                      size: AppDimens.optionChipGlyph,
                      color: selected ? c.green : c.ink2),
                ),
                onTap: (option) {
                  // 先本地换高亮（即时反馈），再落库
                  setState(() => _iconKey = option.key);
                  widget.onChangeIcon(option);
                },
              ),
              const SizedBox(height: AppDimens.pageGap),

              // 颜色选择
              Text('颜色', style: _sectionStyle(c)),
              const SizedBox(height: 8),
              _OptionGrid(
                options: AppIcons.colorPalette,
                selectedKey: _colorStroke,
                itemBuilder: (option, selected) => Container(
                  width: AppDimens.optionChipSize,
                  height: AppDimens.optionChipSize,
                  decoration: BoxDecoration(
                    color: hexToColor(option.hex),
                    shape: BoxShape.circle,
                    border: selected
                        ? Border.all(color: c.ink, width: 2)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: selected
                      ? const Icon(Icons.check, size: 16, color: AppColors.onGreen)
                      : null,
                ),
                onTap: (option) {
                  setState(() => _colorStroke = option.hex);
                  widget.onChangeColor(option);
                },
              ),
              const SizedBox(height: AppDimens.pageGap),

              // 启用开关（AppSwitch 与预算页同一规格）
              Row(
                children: [
                  Text('在记账页显示', style: _sectionStyle(c)),
                  const Spacer(),
                  AppSwitch(
                    value: _enabled,
                    onChanged: (v) {
                      setState(() => _enabled = v);
                      widget.onToggleEnabled(v);
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.pageGap),

              // 移动 / 删除
              Row(
                children: [
                  _SheetAction(
                    icon: Icons.arrow_upward,
                    label: '上移',
                    enabled: widget.index > 0,
                    onTap: () => widget.onMove(-1),
                  ),
                  const SizedBox(width: 8),
                  _SheetAction(
                    icon: Icons.arrow_downward,
                    label: '下移',
                    enabled: widget.index < widget.total - 1,
                    onTap: () => widget.onMove(1),
                  ),
                  const Spacer(),
                  if (widget.onDelete != null)
                    _SheetAction(
                      icon: Icons.delete_outline,
                      label: '删除',
                      color: c.red,
                      onTap: widget.onDelete,
                    ),
                ],
              ),
              const SizedBox(height: AppDimens.pageGap),
              // 完成：应用未保存的改名并收起面板
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.green,
                    foregroundColor: AppColors.onGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimens.segItemRadius),
                    ),
                  ),
                  onPressed: () async {
                    await _applyRename();
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  },
                  child: const Text(
                    '完成',
                    style: TextStyle(
                      fontSize: AppTypography.segLabel,
                      fontWeight: AppTypography.semiBold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _sectionStyle(AppColors c) => TextStyle(
        fontSize: AppTypography.txnNote,
        fontWeight: AppTypography.medium,
        color: c.ink2,
      );
}

/// 新建分类面板：名称 + 图标 + 颜色，确认后回传结果。
class _CategoryCreateSheet extends StatefulWidget {
  const _CategoryCreateSheet({required this.type, required this.existingNames});

  final TxType type;

  /// 当前类型下已有分类名（重名前置校验用）。
  final List<String> existingNames;

  @override
  State<_CategoryCreateSheet> createState() => _CategoryCreateSheetState();
}

class _CategoryCreateSheetState extends State<_CategoryCreateSheet> {
  final TextEditingController _nameController = TextEditingController();
  // 默认选中本类型候选集的第一项（支出不会落到「工资」上去）
  late AppIconOption _icon =
      AppIcons.optionsFor(widget.type == TxType.income).first;
  AppColorOption _color = AppIcons.colorPalette.first;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    return SafeArea(
      child: Container(
        // 底部补键盘高度：面板带输入框，键盘弹出时不遮住「创建分类」按钮
        padding: EdgeInsets.fromLTRB(
          AppDimens.cardPadding,
          AppDimens.cardPadding,
          AppDimens.cardPadding,
          AppDimens.cardPadding + MediaQuery.viewInsetsOf(context).bottom,
        ),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppDimens.cardRadius),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.track2,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppDimens.pageGap),
              Text(
                '新建${widget.type.label}分类',
                style: TextStyle(
                  fontSize: AppTypography.cardTitle,
                  fontWeight: AppTypography.semiBold,
                  color: c.ink,
                ),
              ),
              const SizedBox(height: AppDimens.pageGap),
              TextField(
                controller: _nameController,
                autofocus: true,
                maxLength: 12,
                style: TextStyle(
                  fontSize: AppTypography.segLabel,
                  fontWeight: AppTypography.semiBold,
                  color: c.ink,
                ),
                cursorColor: c.green,
                decoration:
                    AppDialog.fieldDecoration(context, hintText: '分类名称'),
              ),
              const SizedBox(height: AppDimens.pageGap),
              Text('图标', style: TextStyle(
                fontSize: AppTypography.txnNote,
                fontWeight: AppTypography.medium,
                color: c.ink2,
              )),
              const SizedBox(height: 8),
              _OptionGrid(
                options: AppIcons.optionsFor(widget.type == TxType.income),
                selectedKey: _icon.key,
                itemBuilder: (option, selected) => Container(
                  // 同上：固定尺寸才能让背景框比图标大一圈
                  width: AppDimens.optionChipSize,
                  height: AppDimens.optionChipSize,
                  decoration: BoxDecoration(
                    color: selected ? c.greenLight : c.track,
                    borderRadius:
                        BorderRadius.circular(AppDimens.optionChipRadius),
                    border: selected ? Border.all(color: c.green) : null,
                  ),
                  alignment: Alignment.center,
                  child: Icon(option.icon,
                      size: AppDimens.optionChipGlyph,
                      color: selected ? c.green : c.ink2),
                ),
                onTap: (option) => setState(() => _icon = option),
              ),
              const SizedBox(height: AppDimens.pageGap),
              Text('颜色', style: TextStyle(
                fontSize: AppTypography.txnNote,
                fontWeight: AppTypography.medium,
                color: c.ink2,
              )),
              const SizedBox(height: 8),
              _OptionGrid(
                options: AppIcons.colorPalette,
                selectedKey: _color.hex,
                itemBuilder: (option, selected) => Container(
                  width: AppDimens.optionChipSize,
                  height: AppDimens.optionChipSize,
                  decoration: BoxDecoration(
                    color: hexToColor(option.hex),
                    shape: BoxShape.circle,
                    border: selected
                        ? Border.all(color: c.ink, width: 2)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: selected
                      ? const Icon(Icons.check, size: 16, color: AppColors.onGreen)
                      : null,
                ),
                onTap: (option) => setState(() => _color = option),
              ),
              const SizedBox(height: AppDimens.pageGap),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.green,
                    foregroundColor: AppColors.onGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimens.segItemRadius),
                    ),
                  ),
                onPressed: () {
                  // 前置校验：空名 / 重名（同类型内）直接拦截
                  final name = _nameController.text.trim();
                  if (name.isEmpty) {
                    AppToast.show('请输入分类名称', error: true);
                    return;
                  }
                  if (widget.existingNames.contains(name)) {
                    AppToast.show('已存在同名分类「$name」', error: true);
                    return;
                  }
                  Navigator.pop(
                    context,
                    (name: name, icon: _icon, color: _color),
                  );
                },
                  child: const Text(
                    '创建分类',
                    style: TextStyle(
                      fontSize: AppTypography.segLabel,
                      fontWeight: AppTypography.semiBold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// 通用选项网格（图标 / 颜色选择器共用）。
class _OptionGrid<T> extends StatelessWidget {
  const _OptionGrid({
    required this.options,
    required this.selectedKey,
    required this.itemBuilder,
    required this.onTap,
  });

  final List<T> options;
  final String? selectedKey;
  final Widget Function(T option, bool selected) itemBuilder;
  final ValueChanged<T> onTap;

  @override
  Widget build(BuildContext context) {
    String? keyOf(T option) => switch (option) {
          AppIconOption(:final key) => key,
          AppColorOption(:final hex) => hex,
          _ => null,
        };

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: options.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final option = options[index];
        final selected = keyOf(option) == selectedKey;
        return GestureDetector(
          onTap: () => onTap(option),
          child: Center(child: itemBuilder(option, selected)),
        );
      },
    );
  }
}

/// 面板操作按钮（上移 / 下移 / 删除；onTap 为 null 时置灰）。
class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    this.color,
    this.enabled = true,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color? color;
  final bool enabled;

  /// 点击回调；null 时按钮置灰不可点。
  final Future<void> Function()? onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final effective = color ?? c.ink;
    final clickable = enabled && onTap != null;
    return InkWell(
      onTap: clickable ? () => onTap!() : null,
      borderRadius: BorderRadius.circular(AppDimens.segItemRadius),
      child: Opacity(
        opacity: clickable ? 1 : 0.35,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: c.track,
            borderRadius: BorderRadius.circular(AppDimens.segItemRadius),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: effective),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: AppTypography.segSmLabel,
                  fontWeight: AppTypography.medium,
                  color: effective,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
