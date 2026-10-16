import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 头像本地存储。
///
/// 相册选中的图片一律**复制**到应用私有目录后再持久化路径：
/// - 相册里的原图可能被用户删除 / 移入回收站，直接存原路径会变死链；
/// - Android 10+ 分区存储下，跨会话再访问相册 URI 需要重新授权。
///
/// 私有目录固定一个文件名 `avatar.jpg`，替换即覆盖，不累积垃圾文件。
class AvatarStore {
  const AvatarStore._();

  /// 私有目录下的固定文件名。
  static const String fileName = 'avatar.jpg';

  /// 把 [source] 复制进私有目录，返回可持久化的绝对路径；失败返回 `null`。
  static Future<String?> save(String source) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final target = File(p.join(dir.path, fileName));
      // 先删后拷：避免同名文件被占用时 copy 抛异常
      // （existsSync：这里是启动/换头像路径上的一次性检查，
      //  走同步 API 比 async 版本快一个数量级）
      if (target.existsSync()) {
        await target.delete();
      }
      final copied = await File(source).copy(target.path);
      return copied.path;
    } catch (e) {
      debugPrint('AvatarStore.save failed: $e');
      return null;
    }
  }

  /// 删除已保存的头像文件（不存在时静默返回）。
  static Future<void> clear() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final target = File(p.join(dir.path, fileName));
      if (target.existsSync()) {
        await target.delete();
      }
    } catch (e) {
      debugPrint('AvatarStore.clear failed: $e');
    }
  }

  /// [path] 是否指向一个真实存在的文件（空值 / 死链一律 false）。
  static bool exists(String? path) =>
      path != null && path.isNotEmpty && File(path).existsSync();
}
