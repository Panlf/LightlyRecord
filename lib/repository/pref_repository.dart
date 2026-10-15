import '../core/constants.dart';
import '../data/dao/pref_dao.dart';

/// 偏好读写（主题 / 当前账本 / 昵称 / 提醒开关）。
abstract class PrefRepository {
  /// 读取字符串。
  Future<String?> get(String key);

  /// 写入字符串。
  Future<void> set(String key, String value);

  /// 读取并转型；缺失或解析失败返回 [fallback]。
  Future<T> getTyped<T>(String key, T fallback);

  /// 读取 int。
  Future<int> getInt(String key, int fallback);

  /// 读取 bool。
  Future<bool> getBool(String key, bool fallback);

  /// 全部 KV。
  Future<Map<String, String>> all();
}

/// 基于 [PrefDao] 的实现。
class PrefRepositoryImpl implements PrefRepository {
  /// 注入 DAO。
  const PrefRepositoryImpl(this._dao);

  final PrefDao _dao;

  @override
  Future<String?> get(String key) => _dao.get(key);

  @override
  Future<void> set(String key, String value) =>
      _dao.set(key, value, DateTime.now().millisecondsSinceEpoch);

  @override
  Future<T> getTyped<T>(String key, T fallback) async {
    final raw = await _dao.get(key);
    if (raw == null) return fallback;
    return _cast<T>(raw, fallback);
  }

  @override
  Future<int> getInt(String key, int fallback) async {
    final raw = await _dao.get(key);
    if (raw == null) return fallback;
    return int.tryParse(raw.trim()) ?? fallback;
  }

  @override
  Future<bool> getBool(String key, bool fallback) async {
    final raw = await _dao.get(key);
    if (raw == null) return fallback;
    final v = raw.trim().toLowerCase();
    return v == '1' || v == 'true';
  }

  @override
  Future<Map<String, String>> all() => _dao.all();

  /// 字符串 → 目标类型；失败回落 [fallback]。
  T _cast<T>(String raw, T fallback) {
    if (T == int) {
      return (int.tryParse(raw.trim()) ?? fallback) as T;
    }
    if (T == double) {
      return (double.tryParse(raw.trim()) ?? fallback) as T;
    }
    if (T == bool) {
      final v = raw.trim().toLowerCase();
      final parsed = v == '1' || v == 'true';
      return (fallback is bool ? parsed : fallback) as T;
    }
    if (T == String) {
      return raw as T;
    }
    return fallback;
  }
}

/// 偏好 key 的语义化访问（避免业务代码里散落字符串字面量）。
extension PrefRepositoryX on PrefRepository {
  /// 当前主题 id。
  Future<String> themeId() =>
      get(AppConstants.prefKeyThemeId).then((v) => v ?? AppConstants.defaultThemeId);

  /// 写入当前主题 id。
  Future<void> setThemeId(String id) => set(AppConstants.prefKeyThemeId, id);

  /// 当前账本 id（无记录返回 `null`）。
  Future<int?> currentBookId() async {
    final raw = await get(AppConstants.prefKeyCurrentBookId);
    if (raw == null) return null;
    return int.tryParse(raw.trim());
  }

  /// 写入当前账本 id。
  Future<void> setCurrentBookId(int id) =>
      set(AppConstants.prefKeyCurrentBookId, '$id');

  /// 昵称。
  Future<String> nickname() => get(AppConstants.prefKeyNickname)
      .then((v) => (v == null || v.trim().isEmpty) ? AppConstants.defaultNickname : v);

  /// 写入昵称。
  Future<void> setNickname(String name) => set(AppConstants.prefKeyNickname, name.trim());

  /// 示例数据是否已载入。
  Future<bool> sampleLoaded() => getBool(AppConstants.prefKeySampleLoaded, false);

  /// 置位 / 复位示例数据标记。
  Future<void> setSampleLoaded(bool loaded) =>
      set(AppConstants.prefKeySampleLoaded, loaded ? '1' : '0');
}
