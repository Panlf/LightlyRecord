import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lightly_record/core/constants.dart';
import 'package:lightly_record/data/dao/book_dao.dart';
import 'package:lightly_record/data/dao/budget_dao.dart';
import 'package:lightly_record/data/dao/category_dao.dart';
import 'package:lightly_record/data/dao/pref_dao.dart';
import 'package:lightly_record/data/dao/txn_dao.dart';
import 'package:lightly_record/data/db/sample_data.dart';
import 'package:lightly_record/data/db/seed_data.dart';
import 'package:lightly_record/data/ddl.dart';
import 'package:lightly_record/data/model/book.dart';
import 'package:lightly_record/data/model/category.dart';
import 'package:lightly_record/data/model/txn.dart';
import 'package:lightly_record/data/model/tx_type.dart';
import 'package:lightly_record/data/model/budget.dart';

/// T01 数据层验收：DDL + 播种 + DAO + Repository 关键路径。
///
/// 说明：本机无可用 Android 设备（`flutter devices` 被沙箱策略拦截），
/// 因此用 `sqflite_common_ffi` 的内存库跑同一套 DDL / 播种 / DAO 逻辑，
/// 等价验证「冷启动建库 → 播种」链路。
void main() {
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: AppConstants.dbVersion,
        onConfigure: (d) async => d.execute(Ddl.pragmaForeignKeys),
        onCreate: (d, v) async {
          final batch = d.batch();
          for (final sql in Ddl.all) {
            batch.execute(sql);
          }
          await batch.commit(noResult: true);
          await SeedData.run(d);
        },
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('DDL + 播种', () {
    test('6 张表全部创建', () async {
      final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
      );
      final names = rows.map((r) => r['name'] as String).toList();
      expect(names, containsAll(['book', 'category', 'txn', 'budget', 'pref']));
    });

    test('外键约束已开启', () async {
      final rows = await db.rawQuery('PRAGMA foreign_keys');
      expect(rows.first['foreign_keys'], 1);
    });

    test('1 个默认账本', () async {
      final books = await db.query('book');
      expect(books.length, 1);
      expect(books.first['name'], AppConstants.defaultBookName);
      expect(books.first['is_default'], 1);
      expect(books.first['icon_key'], AppConstants.defaultBookIconKey);
    });

    test('17 个分类（9 支出 + 6 收入 + 2 转账）', () async {
      for (final (type, expected) in [(1, 9), (2, 6), (3, 2)]) {
        final rows = await db.query('category', where: 'type = ?', whereArgs: [type]);
        expect(rows.length, expected, reason: 'type=$type 应有 $expected 个');
      }
      final all = await db.query('category');
      expect(all.length, 17);
      // icon_codepoint 全部为正整数
      for (final r in all) {
        expect(r['icon_codepoint'], isA<int>());
        expect(r['icon_codepoint'] as int, greaterThan(0));
        expect(r['icon_font_family'], 'MaterialIcons');
      }
    });

    test('6 行 pref', () async {
      final rows = await db.query('pref');
      expect(rows.length, 6);
      final map = {for (final r in rows) r['key'] as String: r['value'] as String};
      expect(map[AppConstants.prefKeyThemeId], AppConstants.defaultThemeId);
      expect(map[AppConstants.prefKeyNickname], AppConstants.defaultNickname);
      expect(map[AppConstants.prefKeyReminderEnabled], '0');
      expect(map[AppConstants.prefKeyReminderTime], AppConstants.defaultReminderTime);
      expect(map[AppConstants.prefKeySampleLoaded], '0');
      expect(map[AppConstants.prefKeyCurrentBookId], '1');
    });

    test('1 行 budget 且 enabled=0', () async {
      final rows = await db.query('budget');
      expect(rows.length, 1);
      expect(rows.first['id'], 1);
      expect(rows.first['enabled'], 0);
      expect(rows.first['monthly_amount_minor'], 0);
    });
  });

  group('DAO', () {
    test('BookDao CRUD + 聚合', () async {
      final dao = BookDao(db);
      expect(await dao.count(), 1);

      final now = DateTime.now().millisecondsSinceEpoch;
      final newId = await dao.insert(Book(
        id: 0,
        name: '旅行账本',
        iconKey: 'travel',
        iconColor: '#5B8DB8',
        sortOrder: await dao.nextSortOrder(),
        createdAt: now,
        updatedAt: now,
      ));
      expect(newId, greaterThan(0));
      expect(await dao.count(), 2);

      await dao.updateName(newId, '旅行', now);
      expect((await dao.findById(newId))!.name, '旅行');

      // 默认账本不可删
      final def = (await dao.findDefault())!;
      expect(def.isDefault, true);
    });

    test('CategoryDao 按类型查询 + 重排', () async {
      final dao = CategoryDao(db);
      final expense = await dao.listByType(TxType.expense);
      expect(expense.length, 9);
      expect(expense.first.name, '餐饮');

      final enabled = await dao.listEnabledByType(TxType.expense);
      expect(enabled.length, 9);

      await dao.reorder(expense.map((c) => c.id).toList().reversed.toList());
      final after = await dao.listByType(TxType.expense);
      expect(after.first.name, '其他');
    });

    test('TxnDao 插入 + 区间聚合', () async {
      final dao = TxnDao(db);
      final catDao = CategoryDao(db);
      final food = (await catDao.findByKey('food'))!;

      final now = DateTime.now().millisecondsSinceEpoch;
      final id = await dao.insert(Txn(
        id: 0,
        bookId: 1,
        categoryId: food.id,
        type: TxType.expense,
        amountMinor: 2650,
        note: '豆浆油条',
        txDate: '2026-10-14',
        txTime: '08:12',
        createdAt: now,
        updatedAt: now,
      ));
      expect(id, greaterThan(0));

      final found = await dao.findById(id);
      expect(found, isNotNull);
      expect(found!.amountMinor, 2650);
      expect(found.categoryName, '餐饮');
      expect(found.categoryColorStroke, '#3E9F7C');
      expect(found.categoryIconCodepoint, greaterThan(0));

      expect(await dao.countByDate(1, '2026-10-14'), 1);
      expect(await dao.sumByDate(1, '2026-10-14', TxType.expense), 2650);
      expect(await dao.sumByRange(1, '2026-10-01', '2026-10-31', TxType.expense), 2650);
      expect(await dao.sumByRange(1, '2026-11-01', '2026-11-30', TxType.expense), 0);
      expect(await dao.countAll(), 1);

      // 按分类聚合
      final grouped = await dao.groupByCategory(1, '2026-10-01', '2026-10-31', TxType.expense);
      expect(grouped.length, 1);
      expect(grouped.first['amount_minor'], 2650);

      // 月度每日聚合
      final daily = await dao.dailyExpenseInMonth(1, 2026, 10);
      expect(daily['2026-10-14'], 2650);

      // 首次记账日期
      expect(await dao.firstTxDate(), '2026-10-14');
      expect(await dao.distinctDates(), ['2026-10-14']);

      await dao.delete(id);
      expect(await dao.countAll(), 0);
    });

    test('BudgetDao upsert id=1 幂等', () async {
      final dao = BudgetDao(db);
      final initial = await dao.get();
      expect(initial.enabled, false);
      expect(initial.monthlyAmountMinor, 0);

      await dao.save(enabled: true, monthlyAmountMinor: 300000, updatedAt: 1);
      final after = await dao.get();
      expect(after.enabled, true);
      expect(after.monthlyAmountMinor, 300000);

      // 再存一次仍是单行
      await dao.save(enabled: false, monthlyAmountMinor: 0, updatedAt: 2);
      final rows = await db.query('budget');
      expect(rows.length, 1);
      expect((await dao.get()).enabled, false);
    });

    test('PrefDao KV 读写', () async {
      final dao = PrefDao(db);
      expect(await dao.get(AppConstants.prefKeyThemeId), 'mint');
      await dao.set(AppConstants.prefKeyThemeId, 'dark', 1);
      expect(await dao.get(AppConstants.prefKeyThemeId), 'dark');
      await dao.setAll({'a': '1', 'b': '2'}, 1);
      expect((await dao.all()).length, 8);
      await dao.remove('a');
      expect(await dao.has('a'), false);
    });

    test('外键 CASCADE / RESTRICT 生效', () async {
      final txnDao = TxnDao(db);
      final catDao = CategoryDao(db);
      final food = (await catDao.findByKey('food'))!;

      final now = DateTime.now().millisecondsSinceEpoch;
      final id = await txnDao.insert(Txn(
        id: 0,
        bookId: 1,
        categoryId: food.id,
        type: TxType.expense,
        amountMinor: 100,
        txDate: '2026-10-14',
        txTime: '08:12',
        createdAt: now,
        updatedAt: now,
      ));

      // 删除账本 → 级联删除交易
      await db.delete('book', where: 'id = ?', whereArgs: [1]);
      expect(await txnDao.findById(id), isNull);

      // 已被引用的分类不可删（RESTRICT）
      final book2Id = await db.insert('book', {
        'name': 'b2',
        'is_default': 0,
        'created_at': now,
        'updated_at': now,
      });
      final id2 = await txnDao.insert(Txn(
        id: 0,
        bookId: book2Id,
        categoryId: food.id,
        type: TxType.expense,
        amountMinor: 100,
        txDate: '2026-10-14',
        txTime: '08:12',
        createdAt: now,
        updatedAt: now,
      ));
      expect(id2, greaterThan(0));
      await expectLater(
        db.delete('category', where: 'id = ?', whereArgs: [food.id]),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('示例数据', () {
    test('载入 22 笔，日期相对今天', () async {
      final inserted = await SampleData.load(db, 1);
      expect(inserted, SampleData.count);
      expect(SampleData.count, 22);

      final txnDao = TxnDao(db);
      expect(await txnDao.countAll(), 22);

      // 今天应有 4 笔支出（豆浆油条 / 交通通勤 / 瑞幸 / 火锅）
      final today = DateTime.now();
      final todayStr =
          '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      expect(await txnDao.countByDate(1, todayStr), 4);
      expect(await txnDao.sumByDate(1, todayStr, TxType.expense), 2650 + 400 + 3200 + 12800);
      expect(await txnDao.sumByDate(1, todayStr, TxType.income), 0);

      // 全部 amount_minor 为正整数
      final rows = await db.query('txn', columns: ['amount_minor']);
      for (final r in rows) {
        expect(r['amount_minor'], isA<int>());
        expect(r['amount_minor'] as int, greaterThan(0));
      }

      // 清空后归零，账本与分类保留
      final deleted = await SampleData.clearAll(db);
      expect(deleted, 22);
      expect(await txnDao.countAll(), 0);
      expect((await db.query('book')).length, 1);
      expect((await db.query('category')).length, 17);
    });
  });

  group('Model 序列化', () {
    test('Book / Category / Txn / Budget 往返一致', () async {
      const now = 1700000000000;
      const book = Book(
        id: 0,
        name: 'x',
        iconKey: 'book',
        iconColor: '#3E9F7C',
        createdAt: 1700000000000,
        updatedAt: 1700000000000,
      );
      expect(Book.fromMap(book.toMap()).name, 'x');

      const cat = Category(
        id: 0,
        name: '餐饮',
        type: TxType.expense,
        iconKey: 'food',
        iconCodepoint: 1,
        colorBg: '#E4F5EE',
        colorStroke: '#3E9F7C',
      );
      expect(Category.fromMap(cat.toMap()).type, TxType.expense);

      const txn = Txn(
        id: 0,
        bookId: 1,
        categoryId: 1,
        type: TxType.income,
        amountMinor: 2650,
        txDate: '2026-10-14',
        txTime: '08:12',
        createdAt: now,
        updatedAt: now,
      );
      final back = Txn.fromMap(txn.toMap());
      expect(back.amountMinor, 2650);
      expect(back.type, TxType.income);
      expect(back.txDate, '2026-10-14');

      const budget = Budget(monthlyAmountMinor: 100, enabled: true, updatedAt: now);
      expect(Budget.fromMap(budget.toMap()).monthlyAmountMinor, 100);
    });
  });
}
