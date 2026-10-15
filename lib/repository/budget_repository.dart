import '../core/constants.dart';
import '../core/result.dart';
import '../data/dao/budget_dao.dart';
import '../data/model/budget.dart';

/// 预算读取与保存（全局单份）。
abstract class BudgetRepository {
  /// 读取预算；不存在则返回 `enabled = false` 的默认值。
  Future<Budget> get();

  /// 保存预算。
  ///
  /// 校验：启用时金额必须 > 0；金额上限 `9,999,999.99` 元
  /// （与金额键盘 7 位整数上限一致，防脏大值把进度条 / 格式化冲爆）。
  Future<Result<void>> save({
    required bool enabled,
    required int monthlyAmountMinor,
  });
}

/// 基于 [BudgetDao] 的实现。
class BudgetRepositoryImpl implements BudgetRepository {
  /// 注入 DAO。
  const BudgetRepositoryImpl(this._dao);

  final BudgetDao _dao;

  @override
  Future<Budget> get() => _dao.get();

  @override
  Future<Result<void>> save({
    required bool enabled,
    required int monthlyAmountMinor,
  }) async {
    if (enabled && monthlyAmountMinor <= 0) {
      return Result.fail('请输入有效的每月预算');
    }
    if (monthlyAmountMinor < 0) {
      return Result.fail('请输入有效的每月预算');
    }
    if (monthlyAmountMinor > AppConstants.maxAmountMinor) {
      return Result.fail('每月预算不能超过 ${AppConstants.maxAmountMinor ~/ AppConstants.minorPerYuan} 元');
    }
    await _dao.save(
      enabled: enabled,
      monthlyAmountMinor: monthlyAmountMinor,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    return Result.ok(null);
  }
}
