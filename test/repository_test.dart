import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lightly_record/core/constants.dart';
import 'package:lightly_record/core/date_ext.dart';
import 'package:lightly_record/data/dao/book_dao.dart';
import 'package:lightly_record/data/dao/budget_dao.dart';
import 'package:lightly_record/data/dao/category_dao.dart';
import 'package:lightly_record/data/dao/txn_dao.dart';
import 'package:lightly_record/data/ddl.dart';
import 'package:lightly_record/data/db/seed_data.dart';
import 'package:lightly_record/data/model/txn.dart';
import 'package:lightly_record/data/model/tx_type.dart';
import 'package:lightly_record/repository/book_repository.dart';
import 'package:lightly_record/repository/budget_repository.dart';
import 'package:lightly_record/repository/category_repository.dart';
import 'package:lightly_record/repository/stats_repository.dart';
import 'package:lightly_record/repository/txn_repository.dart';

/// 条目 6（阶段 1 排查）：Repository 校验分支 + 日历选中日回归测试。
///
/// 基建与 [data_layer_test] 一致：sqflite_common_ffi 内存库跑同一套
/// DDL + SeedData，每个 test 独立库（setUp 重建），互不污染。
/// 断言消息一律用 `Result.messageOrNull` 精确比对仓库文案。
void main() {
  late Database db;
  late TxnDao txnDao;
  late CategoryDao categoryDao;
  late BookDao bookDao;
  late BudgetDao budgetDao;

  late TxnRepositoryImpl txnRepo;
  late BookRepositoryImpl bookRepo;
  late BudgetRepositoryImpl budgetRepo;
  late CategoryRepositoryImpl categoryRepo;
  late StatsRepositoryImpl statsRepo;

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

    txnDao = TxnDao(db);
    categoryDao = CategoryDao(db);
    bookDao = BookDao(db);
    budgetDao = BudgetDao(db);

    txnRepo = TxnRepositoryImpl(txnDao, categoryDao);
    bookRepo = BookRepositoryImpl(bookDao);
    budgetRepo = BudgetRepositoryImpl(budgetDao);
    categoryRepo = CategoryRepositoryImpl(categoryDao);
    statsRepo = StatsRepositoryImpl(
      txnDao: txnDao,
      budgetDao: budgetDao,
      bookDao: bookDao,
    );
  });

  tearDown(() async {
    await db.close();
  });

  /// seed 首个支出分类「餐饮」（icon_key = food，id = 1）。
  Future<int> foodCategoryId() async =>
      (await categoryDao.findByKey('food'))!.id;

  /// 记一笔合法支出，返回新 id（供 update / delete 用例复用）。
  Future<int> addValidExpense({
    int bookId = 1,
    int amountMinor = 2650,
    String note = '测试',
  }) async {
    final result = await txnRepo.add(
      bookId: bookId,
      categoryId: await foodCategoryId(),
      type: TxType.expense,
      amountMinor: amountMinor,
      note: note,
      date: DateTime(2026, 10, 15),
      time: DateTime(2026, 10, 15, 9, 5),
    );
    expect(result.isSuccess, true, reason: '前置：合法入参应成功（${result.messageOrNull}）');
    return result.valueOrNull!;
  }

  group('TxnRepository.add 校验链', () {
    test('transfer 类型拒绝且不落库', () async {
      final result = await txnRepo.add(
        bookId: 1,
        categoryId: 16, // seed 的转账分类「账户互转」
        type: TxType.transfer,
        amountMinor: 100,
        note: '',
        date: DateTime(2026, 10, 15),
      );

      expect(result.isFailure, true);
      expect(result.messageOrNull, '转账功能暂未开放');
      expect(await txnRepo.globalCountAll(), 0, reason: '拒绝后不得落库');
    });

    test('金额 0 / 负数 → 请输入金额', () async {
      final catId = await foodCategoryId();

      final zero = await txnRepo.add(
        bookId: 1,
        categoryId: catId,
        type: TxType.expense,
        amountMinor: 0,
        note: '',
        date: DateTime(2026, 10, 15),
      );
      expect(zero.isFailure, true);
      expect(zero.messageOrNull, '请输入金额');

      final negative = await txnRepo.add(
        bookId: 1,
        categoryId: catId,
        type: TxType.expense,
        amountMinor: -100,
        note: '',
        date: DateTime(2026, 10, 15),
      );
      expect(negative.isFailure, true);
      expect(negative.messageOrNull, '请输入金额');
      expect(await txnRepo.globalCountAll(), 0);
    });

    test('分类不存在 → 分类不存在，请重新选择', () async {
      final result = await txnRepo.add(
        bookId: 1,
        categoryId: 99999,
        type: TxType.expense,
        amountMinor: 100,
        note: '',
        date: DateTime(2026, 10, 15),
      );

      expect(result.isFailure, true);
      expect(result.messageOrNull, '分类不存在，请重新选择');
    });

    test('分类类型不匹配（用支出分类记收入）', () async {
      final result = await txnRepo.add(
        bookId: 1,
        categoryId: await foodCategoryId(), // 支出分类
        type: TxType.income,
        amountMinor: 100,
        note: '',
        date: DateTime(2026, 10, 15),
      );

      expect(result.isFailure, true);
      expect(result.messageOrNull, '分类与收支类型不匹配');
    });

    test('合法入参 → ok，金额/日期/时间/备注 trim 落库正确', () async {
      final id = await addValidExpense(note: '  豆浆油条  ');

      expect(id, greaterThan(0));
      expect(await txnRepo.globalCountAll(), 1);

      final txn = (await txnRepo.getById(id))!;
      expect(txn.amountMinor, 2650);
      expect(txn.txDate, '2026-10-15');
      expect(txn.txTime, '09:05');
      expect(txn.note, '豆浆油条', reason: '备注应 trim 后落库');
      expect(txn.type, TxType.expense);
      expect(txn.categoryName, '餐饮');
    });

    test('不传 time → txTime 为 HH:mm 形态（取当前时间）', () async {
      final result = await txnRepo.add(
        bookId: 1,
        categoryId: await foodCategoryId(),
        type: TxType.expense,
        amountMinor: 100,
        note: '',
        date: DateTime(2026, 10, 15),
      );

      expect(result.isSuccess, true);
      final txn = (await txnRepo.getById(result.valueOrNull!))!;
      expect(RegExp(r'^\d{2}:\d{2}$').hasMatch(txn.txTime), true,
          reason: 'txTime 应为 HH:mm 形态，实际 ${txn.txTime}');
    });
  });

  group('TxnRepository.update / delete', () {
    test('update 不存在的记录 → 记录不存在或已被删除', () async {
      final txn = Txn(
        id: 99999,
        bookId: 1,
        categoryId: await foodCategoryId(),
        type: TxType.expense,
        amountMinor: 100,
        txDate: '2026-10-15',
        createdAt: 0,
        updatedAt: 0,
      );

      final result = await txnRepo.update(txn);
      expect(result.isFailure, true);
      expect(result.messageOrNull, '记录不存在或已被删除');
    });

    test('delete 不存在的记录 → 记录不存在或已被删除', () async {
      final result = await txnRepo.delete(99999);
      expect(result.isFailure, true);
      expect(result.messageOrNull, '记录不存在或已被删除');
    });

    test('update 成功改金额；金额 0 / transfer 拒绝', () async {
      final id = await addValidExpense();

      // 合法更新：改金额
      final txn = (await txnRepo.getById(id))!;
      final ok = await txnRepo.update(txn.copyWith(amountMinor: 1000));
      expect(ok.isSuccess, true, reason: ok.messageOrNull);
      expect((await txnRepo.getById(id))!.amountMinor, 1000);

      // 金额 0 拒绝
      final zero = await txnRepo.update(txn.copyWith(amountMinor: 0));
      expect(zero.isFailure, true);
      expect(zero.messageOrNull, '请输入金额');

      // transfer 拒绝
      final transfer = await txnRepo.update(txn.copyWith(type: TxType.transfer));
      expect(transfer.isFailure, true);
      expect(transfer.messageOrNull, '转账功能暂未开放');
    });

    test('delete 成功后笔数减一；再删一次失败', () async {
      final id = await addValidExpense();
      expect(await txnRepo.globalCountAll(), 1);

      final result = await txnRepo.delete(id);
      expect(result.isSuccess, true, reason: result.messageOrNull);
      expect(await txnRepo.globalCountAll(), 0);

      final again = await txnRepo.delete(id);
      expect(again.isFailure, true);
      expect(again.messageOrNull, '记录不存在或已被删除');
    });
  });

  group('BookRepository', () {
    test('rename 空名 / 21 字拒绝，20 字边界通过', () async {
      final empty = await bookRepo.rename(1, '   ');
      expect(empty.isFailure, true);
      expect(empty.messageOrNull, '账本名称不能为空');

      final tooLong = await bookRepo.rename(1, 'a' * 21);
      expect(tooLong.isFailure, true);
      expect(tooLong.messageOrNull, '账本名称最多 20 个字');

      final boundary = await bookRepo.rename(1, 'a' * 20);
      expect(boundary.isSuccess, true, reason: boundary.messageOrNull);
      expect((await bookRepo.getById(1))!.name, 'a' * 20);
    });

    test('rename 不存在的账本 → 账本不存在', () async {
      final result = await bookRepo.rename(99999, 'x');
      expect(result.isFailure, true);
      expect(result.messageOrNull, '账本不存在');
    });

    test('默认账本不可删除', () async {
      final result = await bookRepo.delete(1); // seed id=1 为默认账本
      expect(result.isFailure, true);
      expect(result.messageOrNull, '默认账本不可删除');
      expect(await bookRepo.count(), 1, reason: '删除失败不得减少账本');
    });

    test('create / rename / delete 非默认账本全链路', () async {
      final newId = await bookRepo.create(name: '  旅行账本  ');
      expect(newId, greaterThan(0));
      expect(await bookRepo.count(), 2);
      expect((await bookRepo.getById(newId))!.name, '旅行账本', reason: '应 trim');
      expect((await bookRepo.getById(newId))!.isDefault, false);

      final renamed = await bookRepo.rename(newId, '旅行');
      expect(renamed.isSuccess, true, reason: renamed.messageOrNull);
      expect((await bookRepo.getById(newId))!.name, '旅行');

      final deleted = await bookRepo.delete(newId);
      expect(deleted.isSuccess, true, reason: deleted.messageOrNull);
      expect(await bookRepo.count(), 1);
      expect(await bookRepo.getById(newId), isNull);
    });

    test('create 空白名退化为「新账本」', () async {
      final id = await bookRepo.create(name: '   ');
      expect((await bookRepo.getById(id))!.name, '新账本');
    });

    test('touch / totalExpenseMinor / txnCount 数值正确', () async {
      final book = (await bookRepo.getById(1))!;
      final id = await addValidExpense(amountMinor: 2650);

      expect(await bookRepo.txnCount(1), 1);
      expect(await bookRepo.totalExpenseMinor(1), 2650);
      expect(await bookRepo.lastTxnUpdatedAt(1), isNotNull);
      expect((await txnRepo.getById(id))!.createdAt,
          greaterThanOrEqualTo(book.createdAt));

      await bookRepo.touch(1);
      expect((await bookRepo.getById(1))!.updatedAt,
          greaterThanOrEqualTo(book.createdAt), reason: 'touch 后 updated_at 前移');
    });
  });

  group('BudgetRepository.save', () {
    test('enabled=true + 金额 0 → 请输入有效的每月预算', () async {
      final result = await budgetRepo.save(enabled: true, monthlyAmountMinor: 0);
      expect(result.isFailure, true);
      expect(result.messageOrNull, '请输入有效的每月预算');
    });

    test('金额负数 → 拒绝（enabled 真假两种形态）', () async {
      final enabled = await budgetRepo.save(enabled: true, monthlyAmountMinor: -1);
      expect(enabled.isFailure, true);
      expect(enabled.messageOrNull, '请输入有效的每月预算');

      final disabled = await budgetRepo.save(enabled: false, monthlyAmountMinor: -1);
      expect(disabled.isFailure, true);
      expect(disabled.messageOrNull, '请输入有效的每月预算');
    });

    test('金额超过 maxAmountMinor → 每月预算不能超过 9999999 元', () async {
      final result = await budgetRepo.save(
        enabled: true,
        monthlyAmountMinor: AppConstants.maxAmountMinor + 1,
      );
      expect(result.isFailure, true);
      expect(
        result.messageOrNull,
        '每月预算不能超过 '
        '${AppConstants.maxAmountMinor ~/ AppConstants.minorPerYuan} 元',
      );
    });

    test('上限边界值（maxAmountMinor）通过', () async {
      final result = await budgetRepo.save(
        enabled: true,
        monthlyAmountMinor: AppConstants.maxAmountMinor,
      );
      expect(result.isSuccess, true, reason: result.messageOrNull);

      final budget = await budgetRepo.get();
      expect(budget.monthlyAmountMinor, AppConstants.maxAmountMinor);
      expect(budget.enabled, true);
    });

    test('enabled=false + 金额 0 → ok（关闭预算），且 upsert 保持单行', () async {
      final first = await budgetRepo.save(enabled: true, monthlyAmountMinor: 300000);
      expect(first.isSuccess, true, reason: first.messageOrNull);

      final second = await budgetRepo.save(enabled: false, monthlyAmountMinor: 0);
      expect(second.isSuccess, true, reason: second.messageOrNull);

      final budget = await budgetRepo.get();
      expect(budget.enabled, false);
      expect(budget.monthlyAmountMinor, 0);

      final rows = await db.query('budget');
      expect(rows.length, 1, reason: 'budget 表恒单行（id = 1）');
    });
  });

  group('CategoryRepository.delete 保护', () {
    test('系统预置分类不可删除（seed 全部 17 个均 isSystem=1）', () async {
      final foodId = await foodCategoryId();
      final result = await categoryRepo.delete(foodId);
      expect(result.isFailure, true);
      expect(result.messageOrNull, '系统预置分类不可删除');
      expect(await categoryRepo.getById(foodId), isNotNull);
    });

    test('有交易的自定义分类 → 拒绝并提示笔数', () async {
      final catId = await categoryRepo.create(
        name: '宠物',
        type: TxType.expense,
        iconKey: 'pet',
        iconCodepoint: 0xE000,
        colorBg: '#EEF2F0',
        colorStroke: '#9DB3A9',
      );

      await txnRepo.add(
        bookId: 1,
        categoryId: catId,
        type: TxType.expense,
        amountMinor: 5000,
        note: '猫粮',
        date: DateTime(2026, 10, 15),
      );

      final result = await categoryRepo.delete(catId);
      expect(result.isFailure, true);
      expect(result.messageOrNull, '该分类下还有 1 笔记录，不能删除');
      expect(await categoryRepo.getById(catId), isNotNull);
    });

    test('无交易的自定义分类可删除', () async {
      final catId = await categoryRepo.create(
        name: '临时',
        type: TxType.income,
        iconKey: 'tmp',
        iconCodepoint: 0xE000,
        colorBg: '#EEF2F0',
        colorStroke: '#9DB3A9',
      );

      final result = await categoryRepo.delete(catId);
      expect(result.isSuccess, true, reason: result.messageOrNull);
      expect(await categoryRepo.getById(catId), isNull);
    });

    test('删除不存在的分类 → 分类不存在', () async {
      final result = await categoryRepo.delete(99999);
      expect(result.isFailure, true);
      expect(result.messageOrNull, '分类不存在');
    });
  });

  group('StatsRepository.calendarMonth 选中日回归', () {
    final today = DateTime(2026, 10, 15);

    test('显式 selected 落在本月 → cells 仅该日 isSelected，selectedDay 一致', () async {
      final selected = DateTime(2026, 10, 8);
      final month = await statsRepo.calendarMonth(1, 2026, 10, today,
          selected: selected);

      expect(month.year, 2026);
      expect(month.month, 10);
      expect(month.cells.length, 42);

      final picked = month.cells.where((c) => c.isSelected).toList();
      expect(picked.length, 1, reason: '42 格中应恰有一个选中格');
      expect(ymd(picked.first.date), '2026-10-08');
      expect(month.selectedDay.date, '2026-10-08');
    });

    test('不传 selected 且今天在本月 → 选中今天', () async {
      final month = await statsRepo.calendarMonth(1, 2026, 10, today);

      expect(month.selectedDay.date, '2026-10-15');
      final picked = month.cells.where((c) => c.isSelected).toList();
      expect(picked.length, 1);
      expect(ymd(picked.first.date), '2026-10-15');
      expect(picked.first.isToday, true);
    });

    test('不传 selected 且今天不在本月 → 选中本月 1 号', () async {
      final month = await statsRepo.calendarMonth(1, 2026, 11, today);

      expect(month.selectedDay.date, '2026-11-01');
      final picked = month.cells.where((c) => c.isSelected).toList();
      expect(picked.length, 1);
      expect(ymd(picked.first.date), '2026-11-01');
    });

    test('selected 不在本年本月 → 忽略，退化为今天（今天在本月）', () async {
      final month = await statsRepo.calendarMonth(1, 2026, 10, today,
          selected: DateTime(2026, 9, 20));

      expect(month.selectedDay.date, '2026-10-15');
    });

    test('selected 年份不符 → 忽略，退化为本月 1 号', () async {
      final month = await statsRepo.calendarMonth(1, 2026, 11, today,
          selected: DateTime(2025, 11, 20));

      expect(month.selectedDay.date, '2026-11-01');
    });

    test('42 格网格对齐：2026-10 首格为 9/28（周一），月末格含 11/1 补位', () async {
      final month = await statsRepo.calendarMonth(1, 2026, 10, today);

      // 2026-10-01 是周四 → gridStart = 2026-09-28（周一）
      expect(ymd(month.cells.first.date), '2026-09-28');
      expect(month.cells.first.inMonth, false);
      expect(ymd(month.cells.last.date), '2026-11-01');
      expect(month.cells.last.inMonth, false);

      final inMonth = month.cells.where((c) => c.inMonth).length;
      expect(inMonth, 31, reason: '10 月有 31 天落在网格内');
    });

    test('选中日明细与当日交易一致（含收支汇总）', () async {
      await addValidExpense(amountMinor: 2650); // 2026-10-15
      final month = await statsRepo.calendarMonth(1, 2026, 10, today);

      expect(month.selectedDay.date, '2026-10-15');
      expect(month.selectedDay.expense, 2650);
      expect(month.selectedDay.income, 0);
      expect(month.selectedDay.txns.length, 1);
      expect(month.selectedDay.txns.first.amountMinor, 2650);
    });
  });
}
