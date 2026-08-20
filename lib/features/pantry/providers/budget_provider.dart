import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shopping_provider.dart';

/// Presupuesto mensual de compras.
///
/// Vive solo en el dispositivo: es una preferencia personal, no un dato del
/// inventario, así que no se sincroniza ni ocupa una tabla.
const _budgetKey = 'monthly_budget';

class MonthlyBudgetNotifier extends AsyncNotifier<double?> {
  @override
  Future<double?> build() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getDouble(_budgetKey);
    // 0 o negativo significa "sin presupuesto": se normaliza a null para que
    // la UI tenga un único caso vacío que atender.
    return (value != null && value > 0) ? value : null;
  }

  /// Guarda el presupuesto. Pasar null o un valor no positivo lo elimina.
  Future<void> setBudget(double? amount) async {
    final prefs = await SharedPreferences.getInstance();
    if (amount == null || amount <= 0) {
      await prefs.remove(_budgetKey);
      state = const AsyncData(null);
      return;
    }
    await prefs.setDouble(_budgetKey, amount);
    state = AsyncData(amount);
  }
}

final monthlyBudgetProvider =
    AsyncNotifierProvider<MonthlyBudgetNotifier, double?>(
  MonthlyBudgetNotifier.new,
);

/// Gasto del mes en curso, sumando las compras ya finalizadas.
final currentMonthSpendingProvider = FutureProvider<double>((ref) async {
  final sessions = await ref.watch(sessionsHistoryProvider.future);
  final now = DateTime.now();
  return sessions
      .where((s) {
        final date = s.completedAt ?? s.createdAt;
        return date.year == now.year && date.month == now.month;
      })
      .fold<double>(0, (sum, s) => sum + s.calculatedTotal);
});

/// Estado del presupuesto del mes, listo para pintar.
class BudgetStatus {
  final double budget;
  final double spent;

  const BudgetStatus({required this.budget, required this.spent});

  /// Proporción consumida. Puede pasar de 1 si se superó.
  double get ratio => budget > 0 ? spent / budget : 0;

  int get percentUsed => (ratio * 100).round();

  bool get isExceeded => spent > budget;

  /// Cuánto se pasó del presupuesto; 0 si aún no se superó.
  double get exceededBy => isExceeded ? spent - budget : 0;

  /// Cuánto queda disponible; 0 si ya se superó.
  double get remaining => isExceeded ? 0 : budget - spent;

  /// Avisa antes de pasarse, no solo después.
  bool get isNearLimit => !isExceeded && ratio >= 0.8;
}

/// Null cuando no hay presupuesto definido.
final budgetStatusProvider = FutureProvider<BudgetStatus?>((ref) async {
  final budget = await ref.watch(monthlyBudgetProvider.future);
  if (budget == null) return null;
  final spent = await ref.watch(currentMonthSpendingProvider.future);
  return BudgetStatus(budget: budget, spent: spent);
});
