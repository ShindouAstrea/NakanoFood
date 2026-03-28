import 'package:flutter/material.dart';
import '../models/shopping_session.dart';
import '../../../shared/utils/currency.dart';

String _fmtN(double v) =>
    v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

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
    final colorScheme = theme.colorScheme;
    final isPurchased = item.isPurchased;

    final textColor = isPurchased
        ? colorScheme.onSurface.withAlpha(80)
        : colorScheme.onSurface;

    final subtitleColor = isPurchased
        ? colorScheme.onSurface.withAlpha(60)
        : colorScheme.onSurface.withAlpha(140);

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
          decorationColor: textColor,
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        isPurchased
            ? '${_fmtN(item.actualQuantity ?? item.plannedQuantity)} ${item.unit}'
              ' · Total ${clp(item.totalCost)}'
            : '${_fmtN(item.plannedQuantity)} ${item.unit}'
              '${item.plannedPrice > 0 ? ' · Est. ${clp(item.plannedPrice * item.plannedQuantity)}' : ''}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: subtitleColor,
          decoration: isPurchased ? TextDecoration.lineThrough : null,
          decorationColor: subtitleColor,
        ),
      ),
      trailing: isPurchased ? _PurchasedBadge(item: item) : const _BuyBadge(),
    );
  }
}

class _PurchasedBadge extends StatelessWidget {
  final ShoppingItem item;
  const _PurchasedBadge({required this.item});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Price trend vs planned price (both per-unit)
    IconData? trendIcon;
    Color? trendColor;
    if (item.plannedPrice > 0 && item.actualPrice > 0) {
      final pct =
          (item.actualPrice - item.plannedPrice) / item.plannedPrice * 100;
      if (pct > 2) {
        trendIcon = Icons.trending_up_rounded;
        trendColor = Colors.red.shade500;
      } else if (pct < -2) {
        trendIcon = Icons.trending_down_rounded;
        trendColor = Colors.green.shade600;
      }
    }

    final bgColor = isDark ? Colors.green.withAlpha(30) : Colors.green.shade50;
    final textColor =
        isDark ? Colors.green.shade300 : Colors.green.shade700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trendIcon != null) ...[
            Icon(trendIcon, size: 13, color: trendColor),
            const SizedBox(width: 3),
          ],
          Text(
            clp(item.totalCost),
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _BuyBadge extends StatelessWidget {
  const _BuyBadge();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.primary.withAlpha(18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.primary.withAlpha(60)),
      ),
      child: Text(
        'Comprar',
        style: TextStyle(
          color: colorScheme.primary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
