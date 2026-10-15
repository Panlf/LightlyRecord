import 'package:flutter/material.dart';

import '../core/format.dart';
import '../icons/app_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_typography.dart';

/// 一个分类宫格项。
class CatItem {
  /// 分类 id。
  final int id;

  /// 分类名称。
  final String name;

  /// 图标语义 key。
  final String iconKey;

  /// 图标 codePoint（优先于 [iconKey]）。
  final int? iconCodepoint;

  /// 图标底色 `'#RRGGBB'`。
  final String colorBg;

  /// 图标前景色 `'#RRGGBB'`。
  final String colorStroke;

  const CatItem({
    required this.id,
    required this.name,
    required this.colorBg,
    required this.colorStroke,
    this.iconKey = 'other_out',
    this.iconCodepoint,
  });
}

/// 分类宫格（4 列，选中 2px 主色描边 + 投影）。
class CatGrid extends StatelessWidget {
  /// 分类列表。
  final List<CatItem> items;

  /// 当前选中的分类 id（`null` = 无选中）。
  final int? selectedId;

  /// 选中回调。
  final ValueChanged<CatItem> onSelected;

  /// 列数，默认 4。
  final int columns;

  const CatGrid({
    required this.items,
    required this.onSelected,
    super.key,
    this.selectedId,
    this.columns = AppDimens.catColumns,
  });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: AppDimens.catGap,
        crossAxisSpacing: AppDimens.catGap,
        mainAxisExtent: 78,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final selected = item.id == selectedId;
        return _CatCell(
          item: item,
          selected: selected,
          colors: c,
          onTap: () => onSelected(item),
        );
      },
    );
  }
}

/// 单个分类格。
class _CatCell extends StatelessWidget {
  final CatItem item;
  final bool selected;
  final AppColors colors;
  final VoidCallback onTap;

  const _CatCell({
    required this.item,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final bg = selected ? c.card : hexToColor(item.colorBg);
    final fg = hexToColor(item.colorStroke);
    final icon = item.iconCodepoint != null
        ? AppIcons.fromCodepoint(item.iconCodepoint!)
        : AppIcons.of(item.iconKey);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: AppDimens.catIconSize,
            height: AppDimens.catIconSize,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppDimens.catIconRadius),
              border: Border.all(
                color: selected ? c.green : c.card.withValues(alpha: 0),
                width: AppDimens.catSelectedBorder,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: c.accentShadow,
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 22, color: fg),
          ),
          const SizedBox(height: 6),
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: AppTypography.catName,
              color: c.ink,
            ),
          ),
        ],
      ),
    );
  }
}
