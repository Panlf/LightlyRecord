/// 预算模型（`budget` 表单行，`id` 恒为 1，全局单份不分账本）。
class Budget {
  /// 每月预算金额，单位「分」。0 表示未设置。
  final int monthlyAmountMinor;

  /// 是否启用。
  final bool enabled;

  /// 更新时间（UTC epoch ms）。
  final int updatedAt;

  const Budget({
    this.monthlyAmountMinor = 0,
    this.enabled = false,
    this.updatedAt = 0,
  });

  /// 反序列化。
  factory Budget.fromMap(Map<String, Object?> m) => Budget(
        monthlyAmountMinor: m['monthly_amount_minor'] as int? ?? 0,
        enabled: (m['enabled'] as int? ?? 0) == 1,
        updatedAt: m['updated_at'] as int? ?? 0,
      );

  /// 序列化（不含 `id`，DAO 侧固定写 `id = 1`）。
  Map<String, Object?> toMap() => {
        'monthly_amount_minor': monthlyAmountMinor,
        'enabled': enabled ? 1 : 0,
        'updated_at': updatedAt,
      };

  /// 局部拷贝。
  Budget copyWith({
    int? monthlyAmountMinor,
    bool? enabled,
    int? updatedAt,
  }) =>
      Budget(
        monthlyAmountMinor: monthlyAmountMinor ?? this.monthlyAmountMinor,
        enabled: enabled ?? this.enabled,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  String toString() =>
      'Budget($monthlyAmountMinor 分, enabled: $enabled)';
}
