class BudgetModel {
  final double budgetLimit;
  final double spentAmount;

  BudgetModel({required this.budgetLimit, required this.spentAmount});

  // Logika kalkulasi otomatis
  double get remaining => budgetLimit - spentAmount;
  double get percentageLeft => budgetLimit > 0 ? remaining / budgetLimit : 0.0;

  factory BudgetModel.fromJson(Map<String, dynamic> json) {
    return BudgetModel(
      budgetLimit: (json['budget_limit'] ?? 0).toDouble(),
      spentAmount: (json['spent_amount'] ?? 0).toDouble(),
    );
  }
}