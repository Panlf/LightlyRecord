import '../data/dao/book_dao.dart';
import '../data/dao/budget_dao.dart';
import '../data/dao/category_dao.dart';
import '../data/dao/pref_dao.dart';
import '../data/dao/txn_dao.dart';
import '../data/db/app_database.dart';
import '../repository/book_repository.dart';
import '../repository/budget_repository.dart';
import '../repository/category_repository.dart';
import '../repository/pref_repository.dart';
import '../repository/stats_repository.dart';
import '../repository/txn_repository.dart';

/// 手写 ServiceLocator：持有 DB 与各 Repository 单例。
///
/// 分层单向：`pages → state → repository → dao → db`。
/// UI 层只允许拿到 Repository，**禁止**直接接触 DAO / Database。
class AppLocator {
  const AppLocator._();

  static bool _ready = false;

  /// 是否已完成初始化。
  static bool get isReady => _ready;

  /// DAO（内部使用，不对外暴露）。
  static BookDao? _bookDao;
  static CategoryDao? _categoryDao;
  static TxnDao? _txnDao;
  static BudgetDao? _budgetDao;
  static PrefDao? _prefDao;

  /// 账本 Repository。
  static BookRepository? bookRepository;

  /// 分类 Repository。
  static CategoryRepository? categoryRepository;

  /// 交易 Repository。
  static TxnRepository? txnRepository;

  /// 派生指标 Repository。
  static StatsRepository? statsRepository;

  /// 预算 Repository。
  static BudgetRepository? budgetRepository;

  /// 偏好 Repository。
  static PrefRepository? prefRepository;

  /// 串起 DB → DAO → Repository。
  ///
  /// 幂等：重复调用只会复用已初始化的实例。
  ///
  /// Repository 字段从 `late final` 改为可空：`reset()` 后能重新
  /// `init()`（late final 二次赋值会抛 LateInitializationError），
  /// 否则「关库 → 再开库」的测试 / 热重置路径直接崩。
  static Future<void> init() async {
    if (_ready) {
      return;
    }
    final db = await AppDatabase.instance;

    _bookDao = BookDao(db);
    _categoryDao = CategoryDao(db);
    _txnDao = TxnDao(db);
    _budgetDao = BudgetDao(db);
    _prefDao = PrefDao(db);

    bookRepository = BookRepositoryImpl(_bookDao!);
    categoryRepository = CategoryRepositoryImpl(_categoryDao!);
    txnRepository = TxnRepositoryImpl(_txnDao!, _categoryDao!);
    statsRepository = StatsRepositoryImpl(
      txnDao: _txnDao!,
      budgetDao: _budgetDao!,
      bookDao: _bookDao!,
    );
    budgetRepository = BudgetRepositoryImpl(_budgetDao!);
    prefRepository = PrefRepositoryImpl(_prefDao!);

    _ready = true;
  }

  /// 关闭数据库连接并复位（仅测试 / 注销场景）。
  static Future<void> reset() async {
    await AppDatabase.close();
    _ready = false;
    _bookDao = null;
    _categoryDao = null;
    _txnDao = null;
    _budgetDao = null;
    _prefDao = null;
    bookRepository = null;
    categoryRepository = null;
    txnRepository = null;
    statsRepository = null;
    budgetRepository = null;
    prefRepository = null;
  }
}
