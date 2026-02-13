class DashboardVisibilityConfig {
  final bool showIncomeExpense;
  final bool showBudget;

  const DashboardVisibilityConfig({
    this.showIncomeExpense = true,
    this.showBudget = true,
  });

  DashboardVisibilityConfig copyWith({
    bool? showIncomeExpense,
    bool? showBudget,
  }) {
    return DashboardVisibilityConfig(
      showIncomeExpense: showIncomeExpense ?? this.showIncomeExpense,
      showBudget: showBudget ?? this.showBudget,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'showIncomeExpense': showIncomeExpense,
      'showBudget': showBudget,
    };
  }

  factory DashboardVisibilityConfig.fromMap(Map<String, dynamic> map) {
    return DashboardVisibilityConfig(
      showIncomeExpense: map['showIncomeExpense'] ?? true,
      showBudget: map['showBudget'] ?? true,
    );
  }
}
