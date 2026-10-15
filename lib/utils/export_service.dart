import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show compute, debugPrint;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/format.dart';
import '../core/result.dart';
import '../data/model/book.dart';
import '../data/model/category.dart';
import '../data/model/txn.dart';

/// 数据导出服务（R21）。
///
/// 职责边界：
/// - **纯格式化**：CSV / JSON 字符串生成，数据由调用方（我的页）经
///   Repository 取好后传入，本类不碰 DAO / Database；
/// - **文件落盘**：`getExternalStorageDirectory()` 取目录，
///   序列化 + 写盘放进 `compute` isolate，1000 笔以上不 ANR；
/// - **分享**：`share_plus` 系统分享面板，失败由调用方降级为
///   Toast 展示文件路径。
class ExportService {
  const ExportService._();

  /// 导出文件子目录名（对齐架构文档 §11 A7）。
  static const String exportDirName = 'export';

  // ================================================================ CSV

  /// 生成导出内容（CSV 或 JSON），**在 isolate 中执行**。
  ///
  /// 1000 笔以上的序列化放到后台 isolate，避免阻塞 UI 造成卡顿/ANR
  /// （架构文档 §T05 验收要点）。
  static Future<String> buildContent({
    required String format,
    required List<Book> books,
    required List<Category> categories,
    required List<Txn> txns,
  }) {
    return compute(
      _buildContentIsolate,
      _BuildRequest(
        format: format,
        books: books,
        categories: categories,
        txns: txns,
      ),
    );
  }

  /// isolate 入口：按格式分发到具体构建器。
  static String _buildContentIsolate(_BuildRequest req) {
    return switch (req.format) {
      'csv' => _buildCsv(
          books: req.books,
          categories: req.categories,
          txns: req.txns,
        ),
      _ => _buildJson(
          books: req.books,
          categories: req.categories,
          txns: req.txns,
        ),
    };
  }

  /// 生成 CSV 文本（UTF-8 带 BOM，保证 Excel 打开中文不乱码）。
  ///
  /// 列：日期, 时间, 类型, 分类, 账本, 金额(元), 备注。
  /// 金额 = 分 / 100 保留 2 位；字段按 RFC 4180 转义。
  static String _buildCsv({
    required List<Book> books,
    required List<Category> categories,
    required List<Txn> txns,
  }) {
    final bookNames = {for (final b in books) b.id: b.name};
    final catNames = {for (final c in categories) c.id: c.name};

    final buffer = StringBuffer('\uFEFF');
    buffer.writeln('日期,时间,类型,分类,账本,金额(元),备注');
    for (final t in txns) {
      final type = t.type.label;
      final category = catNames[t.categoryId] ?? '未分类';
      final book = bookNames[t.bookId] ?? '未知账本';
      final yuan = fmtMoney(t.amountMinor);
      buffer.writeln(
        '${_csvCell(t.txDate)},${_csvCell(t.txTime)},${_csvCell(type)},'
        '${_csvCell(category)},${_csvCell(book)},${_csvCell(yuan)},${_csvCell(t.note)}',
      );
    }
    return buffer.toString();
  }

  /// CSV 单元格转义。
  ///
  /// 两层防护：
  /// 1. RFC 4180：含逗号 / 引号 / 换行时整体加双引号，内部引号翻倍；
  /// 2. **公式注入防护**：以 `=` `+` `-` `@` 或制表/回车开头的文本
  ///    （典型如备注 `=1+1`）前置单引号，防止 Excel / WPS 当公式执行。
  static String _csvCell(String raw) {
    if (raw.isEmpty) return '';
    var value = raw;
    if (_formulaLeaders.contains(value[0])) {
      value = "'$value";
    }
    final needQuote = value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    if (!needQuote) return value;
    return '"${value.replaceAll('"', '""')}"';
  }

  /// 公式注入危险首字符（CSV 注入的标准防护集）。
  static const String _formulaLeaders = '=+-@\t\r';

  // ================================================================ JSON

  /// 生成 JSON 文本。
  ///
  /// 结构：`{app, exportedAt, books, categories, txns}`；
  /// 金额统一为 2 位小数字符串（元），避免浮点误差。
  static String _buildJson({
    required List<Book> books,
    required List<Category> categories,
    required List<Txn> txns,
  }) {
    final payload = <String, dynamic>{
      'app': '轻记',
      'exportedAt': DateTime.now().toIso8601String(),
      'books': books
          .map((b) => <String, dynamic>{
                'id': b.id,
                'name': b.name,
                'iconKey': b.iconKey,
                'iconColor': b.iconColor,
                'isDefault': b.isDefault,
              })
          .toList(),
      'categories': categories
          .map((c) => <String, dynamic>{
                'id': c.id,
                'name': c.name,
                'type': c.type.label,
                'colorBg': c.colorBg,
                'colorStroke': c.colorStroke,
                'isSystem': c.isSystem,
              })
          .toList(),
      'txns': txns
          .map((t) => <String, dynamic>{
                'id': t.id,
                'bookId': t.bookId,
                'categoryId': t.categoryId,
                'type': t.type.label,
                'amountYuan': fmtMoney(t.amountMinor),
                'note': t.note,
                'date': t.txDate,
                'time': t.txTime,
              })
          .toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  // ================================================================ 落盘 / 分享

  /// 保存到外部存储并返回文件绝对路径。
  ///
  /// 目录：`<外部存储>/Android/data/<包名>/files/export/`；
  /// 写盘在 isolate 执行，大批量数据不卡 UI。
  static Future<Result<String>> saveToFile(
    String fileName,
    String content,
  ) async {
    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) return Result.fail('无法访问外部存储目录');
      final exportDir = Directory('${dir.path}/$exportDirName');
      if (!exportDir.existsSync()) {
        exportDir.createSync(recursive: true);
      }
      final path = '${exportDir.path}/$fileName';
      await compute(_writeFileIsolate, _FileWrite(path, content));
      return Result.ok(path);
    } catch (e, s) {
      debugPrint('ExportService.saveToFile failed: $e\n$s');
      return Result.fail('导出失败，请检查存储空间后重试');
    }
  }

  /// 调起系统分享面板；失败返回 false（调用方降级 Toast 路径）。
  static Future<bool> shareFile(String path) async {
    try {
      await Share.shareXFiles([XFile(path)]);
      return true;
    } catch (e, s) {
      debugPrint('ExportService.shareFile failed: $e\n$s');
      return false;
    }
  }

  /// 默认导出文件名，如 `轻记导出_20261015_1632.csv`。
  static String defaultFileName(String ext) {
    final now = DateTime.now();
    final stamp = '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
    return '轻记导出_$stamp.$ext';
  }
}

/// isolate 写盘请求（compute 入参必须是可传 isolate 的简单对象）。
class _FileWrite {
  const _FileWrite(this.path, this.content);

  final String path;
  final String content;
}

/// isolate 构建请求（格式 + 三张表的数据快照）。
class _BuildRequest {
  const _BuildRequest({
    required this.format,
    required this.books,
    required this.categories,
    required this.txns,
  });

  final String format;
  final List<Book> books;
  final List<Category> categories;
  final List<Txn> txns;
}

/// isolate 入口：写文件并返回路径；失败抛异常由外层兜底。
Future<String> _writeFileIsolate(_FileWrite request) async {
  final file = File(request.path);
  await file.writeAsString(request.content);
  return file.path;
}
