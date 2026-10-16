import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/avatar_store.dart';

/// 圆形头像：有本地头像文件时显示图片，否则显示默认人像占位。
///
/// 我的页（56px）与今日页页头（36px）共用同一组件，两处头像永远一致。
/// 文件丢失 / 解码失败一律回落到占位，绝不抛异常。
class UserAvatar extends StatelessWidget {
  /// 构造头像。
  const UserAvatar({
    required this.size,
    this.path,
    super.key,
    this.iconSize,
  });

  /// 直径。
  final double size;

  /// 本地头像文件路径（`null` / 空 / 死链 → 占位）。
  final String? path;

  /// 占位图标尺寸；默认 `size * 0.5`。
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final valid = AvatarStore.exists(path);

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      child: valid
          ? Image.file(
              File(path!),
              fit: BoxFit.cover,
              width: size,
              height: size,
              // 文件被外部删掉 / 解码失败 → 回落占位，不让红框炸出来
              errorBuilder: (_, __, ___) => _placeholder(c),
            )
          : _placeholder(c),
    );
  }

  Widget _placeholder(AppColors c) => Container(
        color: c.greenLight,
        alignment: Alignment.center,
        child: Icon(
          Icons.person_outline,
          size: iconSize ?? size * 0.5,
          color: c.greenDeep,
        ),
      );
}
