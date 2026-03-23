import 'package:flutter/material.dart';
import '../models/shopping_session.dart';

class ShoppingItemTile extends StatelessWidget {
  final ShoppingItem item;
  final VoidCallback onTap;

  const ShoppingItemTile({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPurchased = item.isPurchased;

    return ListTile(
      onTap: onTap,
      leading: Checkbox(
        value: isPurchased,
        onChanged: (_) => onTap(),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      title: Text(
        item.productName,
        style: theme.textTheme.bodyMedium?.copyWith(
          decoration: isPurchased ? TextDecoration.lineThrough : null,
          color: isPurchased ? Colors.grey : null,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        isPurchased
            ? '${(item.actualQuantity ?? item.plannedQuantity).toStringAsFixed(1)} ${item.unit} · \$${item.actualPrice > 0 ? item.actualPrice.toStringAsFixed(0) : item.plannedPrice.toStringAsFixed(0)}'
            : '${item.plannedQuantity.toStringAsFixed(item.plannedQuantity == item.plannedQuantity.roundToDouble() ? 0 : 1)} ${item.unit}${item.plannedPrice > 0 ? ' · Est. \$${item.plannedPrice.toStringAsFixed(0)}' : ''}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: isPurchased ? Colors.grey.shade400 : Colors.grey.shade600,
          decoration: isPurchased ? TextDecoration.lineThrough : null,
        ),
      ),
      trailing: isPurchased
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '\$${item.totalCost.toStringAsFixed(0)}',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Comprar',
                style: TextStyle(
                  color: Colors.blue.shade600,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),
    );
  }
}
