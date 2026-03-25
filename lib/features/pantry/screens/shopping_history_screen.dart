import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/shopping_provider.dart';
import '../models/shopping_session.dart';
import '../../../shared/widgets/empty_state.dart';

String _fmtN(double v) =>
    v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

class ShoppingHistoryScreen extends ConsumerWidget {
  const ShoppingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(sessionsHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Compras'),
      ),
      body: historyAsync.when(
        data: (sessions) {
          if (sessions.isEmpty) {
            return const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Sin historial de compras',
              subtitle: 'Las compras completadas aparecerán aquí',
            );
          }
          final completed = sessions
              .where((s) => s.status == ShoppingStatus.completed)
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: sessions.length + (completed.isNotEmpty ? 1 : 0),
            itemBuilder: (_, i) {
              if (i == 0 && completed.isNotEmpty) {
                return _SpendingChart(sessions: completed);
              }
              final session = sessions[completed.isNotEmpty ? i - 1 : i];
              return _SessionCard(session: session);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

// ─── Gráfico de gasto mensual ─────────────────────────────────────────────────

class _SpendingChart extends StatelessWidget {
  final List<ShoppingSession> sessions;
  const _SpendingChart({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    // Agrupar por mes (últimos 6 meses)
    final now = DateTime.now();
    final months = List.generate(6, (i) {
      final d = DateTime(now.year, now.month - (5 - i));
      return d;
    });

    final monthlyTotals = {
      for (final m in months)
        DateTime(m.year, m.month): 0.0,
    };

    for (final s in sessions) {
      final key = DateTime(s.createdAt.year, s.createdAt.month);
      if (monthlyTotals.containsKey(key)) {
        monthlyTotals[key] = monthlyTotals[key]! + s.calculatedTotal;
      }
    }

    final values = monthlyTotals.values.toList();
    final maxVal = values.fold(0.0, (a, b) => b > a ? b : a);
    final totalGasto = values.fold(0.0, (a, b) => a + b);

    // Gasto promedio solo de meses con compras
    final mesesConCompras = values.where((v) => v > 0).length;
    final promedio = mesesConCompras > 0 ? totalGasto / mesesConCompras : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gasto mensual',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _StatBadge(
                  label: 'Total 6 meses',
                  value: '\$${totalGasto.toStringAsFixed(0)}',
                  color: primary,
                ),
                const SizedBox(width: 8),
                _StatBadge(
                  label: 'Promedio/mes',
                  value: '\$${promedio.toStringAsFixed(0)}',
                  color: theme.colorScheme.secondary,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 130,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: monthlyTotals.entries.map((entry) {
                  final month = entry.key;
                  final value = entry.value;
                  final ratio = maxVal > 0 ? value / maxVal : 0.0;
                  final isCurrentMonth =
                      month.year == now.year && month.month == now.month;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (value > 0)
                            Text(
                              '\$${value >= 1000 ? '${(value / 1000).toStringAsFixed(1)}k' : value.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: isCurrentMonth
                                    ? primary
                                    : theme.colorScheme.onSurface
                                        .withAlpha(160),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          const SizedBox(height: 3),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOut,
                            height: value > 0 ? (ratio * 80).clamp(6, 80) : 4,
                            decoration: BoxDecoration(
                              color: isCurrentMonth
                                  ? primary
                                  : value > 0
                                      ? primary.withAlpha(120)
                                      : theme.colorScheme.surfaceContainerHighest,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            DateFormat('MMM', 'es').format(month),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isCurrentMonth
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isCurrentMonth
                                  ? primary
                                  : theme.colorScheme.onSurface.withAlpha(140),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatBadge(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 10, color: color.withAlpha(180))),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ],
      ),
    );
  }
}

// ─── Session card ─────────────────────────────────────────────────────────────

class _SessionCard extends StatelessWidget {
  final ShoppingSession session;
  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final df = DateFormat('dd/MM/yyyy HH:mm');
    final isCancelled = session.status == ShoppingStatus.cancelled;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: isCancelled
              ? Colors.red.shade50
              : Colors.green.shade50,
          child: Icon(
            isCancelled ? Icons.cancel_outlined : Icons.check_circle_outline,
            color: isCancelled ? Colors.red : Colors.green,
          ),
        ),
        title: Text(
          df.format(session.createdAt),
          style: theme.textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          isCancelled
              ? 'Compra cancelada'
              : '${session.purchasedCount} productos · \$${session.calculatedTotal.toStringAsFixed(0)}',
          style: TextStyle(
            color: isCancelled ? Colors.red.shade400 : Colors.grey.shade600,
          ),
        ),
        children: [
          if (!isCancelled && session.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  ...session.items
                      .where((i) => i.isPurchased)
                      .map((item) => _SessionItemTile(item: item)),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Total: \$${session.calculatedTotal.toStringAsFixed(0)}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SessionItemTile extends StatelessWidget {
  final ShoppingItem item;
  const _SessionItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final qty = item.actualQuantity ?? item.plannedQuantity;
    final price = item.actualPrice > 0 ? item.actualPrice : item.plannedPrice;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.check, size: 14, color: Colors.green.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(item.productName,
                style: const TextStyle(fontSize: 13)),
          ),
          Text(
            '${_fmtN(qty)} ${item.unit}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(width: 12),
          Text(
            '\$${(qty * price).toStringAsFixed(0)}',
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
