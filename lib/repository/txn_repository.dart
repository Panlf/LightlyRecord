import 'package:flutter/foundation.dart' show debugPrint;

import '../core/date_ext.dart';
import '../core/result.dart';
import '../data/dao/category_dao.dart';
import '../data/dao/txn_dao.dart';
import '../data/db/sample_data.dart';
import '../data/model/txn.dart';
import '../data/model/tx_type.dart';

/// 交易业务：记一笔（校验）、编辑、删除、按日查询。
abstract class TxnRepository {
  /// 记一笔。返回 [Result<int>]（新 id）。
  ///
  /// 校验：`amountMinor > 0`、分类存在、`type != transfer`。
  Future<Result<int>> add({
    required int bookId,
    required int categoryId,
    required TxType type,
    required int amountMinor,
    required String note,
    required DateTime date,
    DateTime? time,
  });

  /// 编辑（R17）。
  Future<Result<void>> update(Txn txn);

  /// 删除（硬删，P2 无回收站）。
  Future<Result<void>> delete(int id);

  /// 详情（R17）。
  Future<Txn?> getById(int id);

  /// 按日明细（含分类关联）。
  Future<List<Txn>> listByDate(int bookId, String date);

  /// 闭区间明细（含分类关联）。
  Future<List<Txn>> listByRange(int bookId, String from, String to);

  /// 闭区间某类型金额合计（分）。
  Future<int> sumByRange(int bookId, String from, String to, TxType type);

  /// 我的页：全账本总笔数。
  Future<int> globalCountAll();

  /// 全库交易（导出用）。
  Future<List<Txn>> listAll();

  /// 清空全部交易（演示数据「清空全部数据」用），返回删除条数。
  Future<int> clearAll();

  /// 载入示例数据到指定账本，返回插入条数。
  Future<int> loadSampleData(int bookId);
}

/// 基于 [TxnDao] 的实现。
class TxnRepositoryImpl implements TxnRepository {
  /// 注入 DAO。
  const TxnRepositoryImpl(this._txnDao, this._categoryDao);

  final TxnDao _txnDao;
  final CategoryDao _categoryDao;

  @override
  Future<Result<int>> add({
    required int bookId,
    required int categoryId,
    required TxType type,
    required int amountMinor,
    required String note,
    required DateTime date,
    DateTime? time,
  }) async {
    try {
      if (type.isTransfer) {
        return Result.fail('转账功能暂未开放');
      }
      if (amountMinor <= 0) {
        return Result.fail('请输入金额');
      }
      final category = await _categoryDao.findById(categoryId);
      if (category == null) {
        return Result.fail('分类不存在，请重新选择');
      }
      if (category.type != type) {
        return Result.fail('分类与收支类型不匹配');
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final txn = Txn(
        id: 0,
        bookId: bookId,
        categoryId: categoryId,
        type: type,
        amountMinor: amountMinor,
        note: note.trim(),
        txDate: ymd(date),
        txTime: _hmOf(time),
        createdAt: now,
        updatedAt: now,
      );
      final id = await _txnDao.insert(txn);
      return Result.ok(id);
    } catch (e, s) {
      debugPrint('TxnRepository.add failed: $e\n$s');
      return Result.fail('保存失败，请稍后重试');
    }
  }

  @override
  Future<Result<void>> update(Txn txn) async {
    try {
      if (txn.amountMinor <= 0) {
        return Result.fail('请输入金额');
      }
      if (txn.type.isTransfer) {
        return Result.fail('转账功能暂未开放');
      }
      final category = await _categoryDao.findById(txn.categoryId);
      if (category == null) {
        return Result.fail('分类不存在，请重新选择');
      }
      if (category.type != txn.type) {
        return Result.fail('分类与收支类型不匹配');
      }
      final existing = await _txnDao.findById(txn.id);
      if (existing == null) {
        return Result.fail('记录不存在或已被删除');
      }
      await _txnDao.update(txn.copyWith(updatedAt: DateTime.now().millisecondsSinceEpoch));
      return Result.ok(null);
    } catch (e, s) {
      debugPrint('TxnRepository.update failed: $e\n$s');
      return Result.fail('保存失败，请稍后重试');
    }
  }

  @override
  Future<Result<void>> delete(int id) async {
    try {
      final existing = await _txnDao.findById(id);
      if (existing == null) {
        return Result.fail('记录不存在或已被删除');
      }
      await _txnDao.delete(id);
      return Result.ok(null);
    } catch (e, s) {
      debugPrint('TxnRepository.delete failed: $e\n$s');
      return Result.fail('删除失败，请稍后重试');
    }
  }

  @override
  Future<Txn?> getById(int id) => _txnDao.findById(id);

  @override
  Future<List<Txn>> listByDate(int bookId, String date) =>
      _txnDao.listByDate(bookId, date);

  @override
  Future<List<Txn>> listByRange(int bookId, String from, String to) =>
      _txnDao.listByRange(bookId, from, to);

  @override
  Future<int> sumByRange(int bookId, String from, String to, TxType type) =>
      _txnDao.sumByRange(bookId, from, to, type);

  @override
  Future<int> globalCountAll() => _txnDao.countAll();

  @override
  Future<List<Txn>> listAll() => _txnDao.listAll();

  @override
  Future<int> clearAll() => SampleData.clearAll(_txnDao.executor);

  @override
  Future<int> loadSampleData(int bookId) =>
      SampleData.load(_txnDao.executor, bookId);

  /// `DateTime` → `'HH:mm'`；缺省取当前时间。
  String _hmOf(DateTime? t) {
    final d = t ?? DateTime.now();
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
