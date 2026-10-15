import 'package:flutter/foundation.dart' show debugPrint;

import '../core/result.dart';
import '../data/dao/category_dao.dart';
import '../data/model/category.dart';
import '../data/model/tx_type.dart';

/// 分类业务：按类型取、增删改排序、系统分类保护。
abstract class CategoryRepository {
  /// 全部分类。
  Future<List<Category>> list();

  /// 按类型查询（含全局 + 本账本自定义）。
  Future<List<Category>> listByType(TxType type, {int? bookId});

  /// 宫格用：按类型查询且仅启用态。
  Future<List<Category>> listEnabledByType(TxType type, {int? bookId});

  /// 按 id 查询。
  Future<Category?> getById(int id);

  /// 新建自定义分类，返回新 id。
  Future<int> create({
    required String name,
    required TxType type,
    required String iconKey,
    required int iconCodepoint,
    required String colorBg,
    required String colorStroke,
    int? bookId,
  });

  /// 更新分类。
  Future<Result<void>> update(Category category);

  /// 删除分类；`is_system = 1` 时抛 [BusinessException]。
  Future<Result<void>> delete(int id);

  /// 批量重排。
  Future<void> reorder(List<int> orderedIds);
}

/// 基于 [CategoryDao] 的实现。
class CategoryRepositoryImpl implements CategoryRepository {
  /// 注入 DAO。
  const CategoryRepositoryImpl(this._dao);

  final CategoryDao _dao;

  @override
  Future<List<Category>> list() => _dao.list();

  @override
  Future<List<Category>> listByType(TxType type, {int? bookId}) =>
      _dao.listByType(type, bookId: bookId);

  @override
  Future<List<Category>> listEnabledByType(TxType type, {int? bookId}) =>
      _dao.listEnabledByType(type, bookId: bookId);

  @override
  Future<Category?> getById(int id) => _dao.findById(id);

  @override
  Future<int> create({
    required String name,
    required TxType type,
    required String iconKey,
    required int iconCodepoint,
    required String colorBg,
    required String colorStroke,
    int? bookId,
  }) async {
    final trimmed = name.trim();
    final sortOrder = await _dao.nextSortOrder(type);
    return _dao.insert(
      Category(
        id: 0,
        name: trimmed.isEmpty ? '新分类' : trimmed,
        type: type,
        iconKey: iconKey,
        iconCodepoint: iconCodepoint,
        iconFontFamily: 'MaterialIcons',
        colorBg: colorBg,
        colorStroke: colorStroke,
        sortOrder: sortOrder,
        isSystem: false,
        enabled: true,
        bookId: bookId,
      ),
    );
  }

  @override
  Future<Result<void>> update(Category category) async {
    try {
      final trimmed = category.name.trim();
      if (trimmed.isEmpty) {
        return Result.fail('分类名称不能为空');
      }
      if (trimmed.length > 12) {
        return Result.fail('分类名称最多 12 个字');
      }
      final existing = await _dao.findById(category.id);
      if (existing == null) {
        return Result.fail('分类不存在');
      }
      await _dao.update(category.copyWith(name: trimmed));
      return Result.ok(null);
    } catch (e, s) {
      debugPrint('CategoryRepository.update failed: $e\n$s');
      return Result.fail('保存失败，请稍后重试');
    }
  }

  @override
  Future<Result<void>> delete(int id) async {
    try {
      final existing = await _dao.findById(id);
      if (existing == null) {
        return Result.fail('分类不存在');
      }
      if (existing.isSystem) {
        return Result.fail('系统预置分类不可删除');
      }
      final used = await _dao.txnCount(id);
      if (used > 0) {
        return Result.fail('该分类下还有 $used 笔记录，不能删除');
      }
      await _dao.delete(id);
      return Result.ok(null);
    } catch (e, s) {
      debugPrint('CategoryRepository.delete failed: $e\n$s');
      return Result.fail('删除失败，请稍后重试');
    }
  }

  @override
  Future<void> reorder(List<int> orderedIds) async {
    try {
      await _dao.reorder(orderedIds);
    } catch (e, s) {
      debugPrint('CategoryRepository.reorder failed: $e\n$s');
      // 重排失败不致命：顺序未持久化，下次加载仍是旧序
    }
  }
}
