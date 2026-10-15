/// 交易类型枚举：1 支出 / 2 收入 / 3 转账（P2 预留）。
enum TxType {
  /// 支出。
  expense(1),

  /// 收入。
  income(2),

  /// 转账（P2 预留，P0/P1 不出现在宫格）。
  transfer(3);

  /// 入库用的整型编码。
  final int code;

  const TxType(this.code);

  /// 整型编码 → 枚举；未知值退化为 [TxType.expense]。
  static TxType fromCode(int code) =>
      values.firstWhere((e) => e.code == code, orElse: () => TxType.expense);

  /// 是否支出。
  bool get isExpense => this == TxType.expense;

  /// 是否收入。
  bool get isIncome => this == TxType.income;

  /// 是否转账。
  bool get isTransfer => this == TxType.transfer;

  /// 分段控件 / 标题用的中文标签。
  String get label => switch (this) {
        TxType.expense => '支出',
        TxType.income => '收入',
        TxType.transfer => '转账',
      };
}
