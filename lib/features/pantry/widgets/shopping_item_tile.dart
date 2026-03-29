import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/shopping_session.dart';
import '../providers/consumption_prediction_provider.dart';
import '../../../shared/utils/currency.dart';

String _fmtN(double v) =>
    v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

class ShoppingItemTile extends ConsumerWidget {
  final ShoppingItem item;
  final VoidCallback onTap;

  const ShoppingItemTile({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isPurchased = item.isPurchased;

    final nameColor = isPurchased
        ? colorScheme.onSurface.withAlpha(70)
        : colorScheme.onSurface;

    final metaColor = isPurchased
        ? colorScheme.onSurface.withAlpha(50)
        : colorScheme.onSurface.withAlpha(130);

    final qtyText = isPurchased
        ? '${_fmtN(item.actualQuantity ?? item.plannedQuantity)} ${item.unit}'
        : '${_fmtN(item.plannedQuantity)} ${item.unit}';

    // Prediction badge (only for unpurchased items)
    final predAsync =
        ref.watch(productPredictionProvider(item.productId));
    final prediction = predAsync.valueOrNull;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Leading — subtle animated check
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isPurchased
                    ? Colors.green.shade500
                    : Colors.transparent,
                border: Border.all(
                  color: isPurchased
                      ? Colors.green.shade500
                      : colorScheme.onSurface.withAlpha(80),
                  width: 1.5,
                ),
              ),
              child: isPurchased
                  ? const Icon(Icons.check_rounded,
                      size: 13, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: nameColor,
                      fontWeight: FontWeight.w500,
                      decoration:
                          isPurchased ? TextDecoration.lineThrough : null,
                      decorationColor: nameColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        qtyText,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: metaColor,
                          decoration: isPurchased
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: metaColor,
                        ),
                      ),
                      if (!isPurchased &&
                          prediction != null &&
                          prediction.urgency != StockUrgency.ok) ...[
                        const SizedBox(width: 6),
                        _UrgencyBadge(prediction: prediction),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Trailing — price only
            _TrailingPrice(item: item, isPurchased: isPurchased),
          ],
        ),
      ),
    );
  }
}

class _UrgencyBadge extends StatelessWidget {
  final ProductPrediction prediction;
  const _UrgencyBadge({required this.prediction});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;

    switch (prediction.urgency) {
      case StockUrgency.critical:
        color = Colors.red.shade600;
        label = prediction.daysUntilEmpty == 0
            ? '¡Agotado!'
            : 'Queda ${prediction.daysUntilEmpty}d';
        break;
      case StockUrgency.warning:
        color = Colors.orange.shade700;
        label = prediction.daysUntilEmpty != null
            ? '~${prediction.daysUntilEmpty}d'
            : 'Stock bajo';
        break;
      case StockUrgency.soon:
        color = Colors.amber.shade700;
        label = '~${prediction.daysUntilEmpty}d';
        break;
      case StockUrgency.ok:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _TrailingPrice extends StatelessWidget {
  final ShoppingItem item;
  final bool isPurchased;

  const _TrailingPrice({required this.item, required this.isPurchased});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (isPurchased) {
      // Show actual cost + optional trend arrow
      IconData? trendIcon;
      Color? trendColor;
      if (item.plannedPrice > 0 && item.actualPrice > 0) {
        final pct =
            (item.actualPrice - item.plannedPrice) / item.plannedPrice * 100;
        if (pct > 2) {
          trendIcon = Icons.arrow_upward_rounded;
          trendColor = Colors.red.shade400;
        } else if (pct < -2) {
          trendIcon = Icons.arrow_downward_rounded;
          trendColor = Colors.green.shade500;
        }
      }

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trendIcon != null) ...[
            Icon(trendIcon, size: 12, color: trendColor),
            const SizedBox(width: 2),
          ],
          Text(
            clp(item.totalCost),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.green.shade600,
            ),
          ),
        ],
      );
    }

    // Unpurchased — show estimated price muted, no badge
    if (item.plannedPrice > 0) {
      return Text(
        clp(item.plannedPrice * item.plannedQuantity),
        style: TextStyle(
          fontSize: 12,
          color: colorScheme.onSurface.withAlpha(100),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
