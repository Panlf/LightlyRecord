/// 偏好 KV 模型（`pref` 表）。
///
/// 全部值以字符串存储，读取时由调用方按需转型（`PrefRepository.getTyped`）。
class PrefEntry {
  /// 键名。
  final String key;

  /// 值（字符串）。
  final String value;

  /// 更新时间（UTC epoch ms）。
  final int updatedAt;

  const PrefEntry({
    required this.key,
    required this.value,
    required this.updatedAt,
  });

  /// 反序列化。
  factory PrefEntry.fromMap(Map<String, Object?> m) => PrefEntry(
        key: m['key'] as String,
        value: m['value'] as String? ?? '',
        updatedAt: m['updated_at'] as int? ?? 0,
      );

  /// 序列化（不含 `updated_at`，由 DAO 统一写入）。
  Map<String, Object?> toMap() => {
        'key': key,
        'value': value,
      };

  @override
  String toString() => 'PrefEntry($key = $value)';
}
