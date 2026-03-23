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
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: sessions.length,
            itemBuilder: (_, i) => _SessionCard(session: sessions[i]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

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
