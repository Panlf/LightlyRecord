import 'package:flutter/foundation.dart' show debugPrint;

import '../core/constants.dart';
import '../core/result.dart';
import '../data/dao/book_dao.dart';
import '../data/model/book.dart';

/// 账本业务：列表 + 统计、新建、切换、禁止删默认。
abstract class BookRepository {
  /// 全部账本（未归档优先，按 `sort_order` 升序）。
  Future<List<Book>> list();

  /// 按 id 查询。
  Future<Book?> getById(int id);

  /// 新建账本，返回新 id。
  Future<int> create({
    required String name,
    String iconKey = 'book',
    String iconColor = AppConstants.defaultBookIconColor,
  });

  /// 重命名。
  Future<Result<void>> rename(int id, String name);

  /// 更新图标 / 图标色。
  Future<Result<void>> updateIcon(int id, {String? iconKey, String? iconColor});

  /// 删除账本；`is_default = 1` 时抛 [BusinessException]。
  Future<Result<void>> delete(int id);

  /// 返回默认账本（不存在则创建，播种 / 兜底用）。
  Future<Book> ensureDefault();

  /// 账本总数。
  Future<int> count();

  /// 刷新 `updated_at`。
  Future<void> touch(int id);

  /// 该账本累计支出（分）。
  Future<int> totalExpenseMinor(int bookId);

  /// 该账本交易笔数。
  Future<int> txnCount(int bookId);

  /// 该账本最近一笔交易的 `updated_at`（无交易返回 `null`）。
  Future<int?> lastTxnUpdatedAt(int bookId);
}

/// 基于 [BookDao] 的实现。
class BookRepositoryImpl implements BookRepository {
  /// 注入 DAO。
  const BookRepositoryImpl(this._dao);

  final BookDao _dao;

  @override
  Future<List<Book>> list() => _dao.list();

  @override
  Future<Book?> getById(int id) => _dao.findById(id);

  @override
  Future<int> create({
    required String name,
    String iconKey = 'book',
    String iconColor = AppConstants.defaultBookIconColor,
  }) async {
    final trimmed = name.trim();
    final now = DateTime.now().millisecondsSinceEpoch;
    final sortOrder = await _dao.nextSortOrder();
    return _dao.insert(
      Book(
        id: 0,
        name: trimmed.isEmpty ? '新账本' : trimmed,
        iconKey: iconKey,
        iconColor: iconColor,
        sortOrder: sortOrder,
        isDefault: false,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  @override
  Future<Result<void>> rename(int id, String name) async {
    try {
      final trimmed = name.trim();
      if (trimmed.isEmpty) {
        return Result.fail('账本名称不能为空');
      }
      if (trimmed.length > 20) {
        return Result.fail('账本名称最多 20 个字');
      }
      final book = await _dao.findById(id);
      if (book == null) {
        return Result.fail('账本不存在');
      }
      await _dao.updateName(id, trimmed, DateTime.now().millisecondsSinceEpoch);
      return Result.ok(null);
    } catch (e, s) {
      debugPrint('BookRepository.rename failed: $e\n$s');
      return Result.fail('保存失败，请稍后重试');
    }
  }

  @override
  Future<Result<void>> updateIcon(int id, {String? iconKey, String? iconColor}) async {
    try {
      final book = await _dao.findById(id);
      if (book == null) {
        return Result.fail('账本不存在');
      }
      final nextKey = iconKey ?? book.iconKey;
      final nextColor = iconColor ?? book.iconColor;
      await _dao.updateIcon(
        id,
        nextKey,
        nextColor,
        DateTime.now().millisecondsSinceEpoch,
      );
      return Result.ok(null);
    } catch (e, s) {
      debugPrint('BookRepository.updateIcon failed: $e\n$s');
      return Result.fail('保存失败，请稍后重试');
    }
  }

  @override
  Future<Result<void>> delete(int id) async {
    try {
      final book = await _dao.findById(id);
      if (book == null) {
        return Result.fail('账本不存在');
      }
      if (book.isDefault) {
        return Result.fail('默认账本不可删除');
      }
      await _dao.delete(id);
      return Result.ok(null);
    } catch (e, s) {
      debugPrint('BookRepository.delete failed: $e\n$s');
      return Result.fail('删除失败，请稍后重试');
    }
  }

  @override
  Future<Book> ensureDefault() async {
    final existing = await _dao.findDefault();
    if (existing != null) {
      return existing;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await _dao.insert(
      Book(
        id: 0,
        name: '日常账本',
        iconKey: 'book',
        iconColor: AppConstants.defaultBookIconColor,
        sortOrder: await _dao.nextSortOrder(),
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
    return (await _dao.findById(id))!;
  }

  @override
  Future<int> count() => _dao.count();

  @override
  Future<void> touch(int id) =>
      _dao.touch(id, DateTime.now().millisecondsSinceEpoch);

  @override
  Future<int> totalExpenseMinor(int bookId) => _dao.totalExpenseMinor(bookId);

  @override
  Future<int> txnCount(int bookId) => _dao.txnCount(bookId);

  @override
  Future<int?> lastTxnUpdatedAt(int bookId) => _dao.lastTxnUpdatedAt(bookId);
}
