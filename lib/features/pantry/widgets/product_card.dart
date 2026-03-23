import 'package:flutter/material.dart';
import '../models/product.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.onDelete,
  });

  Color _parseColor(String? hex) {
    if (hex == null) return Colors.grey;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final catColor = _parseColor(product.categoryColor);
    final isLow = product.isLow;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Category color indicator
              Container(
                width: 4,
                height: 56,
                decoration: BoxDecoration(
                  color: catColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              // Product info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isLow)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: product.isOut
                                  ? Colors.red.shade100
                                  : Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              product.isOut ? 'Agotado' : 'Bajo',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: product.isOut
                                    ? Colors.red.shade700
                                    : Colors.orange.shade700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          product.categoryName ?? '',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: catColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (product.subcategoryName != null) ...[
                          Text(
                            ' · ',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: Colors.grey),
                          ),
                          Text(
                            product.subcategoryName!,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: Colors.grey),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Quantity progress
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${product.currentQuantity.toStringAsFixed(product.currentQuantity == product.currentQuantity.roundToDouble() ? 0 : 1)} / ${product.quantityToMaintain.toStringAsFixed(product.quantityToMaintain == product.quantityToMaintain.roundToDouble() ? 0 : 1)} ${product.unit}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: isLow
                                          ? Colors.orange.shade700
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                  if (product.lastPrice > 0)
                                    Text(
                                      '\$${product.lastPrice.toStringAsFixed(0)}',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: product.quantityToMaintain > 0
                                      ? (product.currentQuantity /
                                              product.quantityToMaintain)
                                          .clamp(0.0, 1.0)
                                      : 0,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    product.isOut
                                        ? Colors.red
                                        : isLow
                                            ? Colors.orange
                                            : Colors.green,
                                  ),
                                  minHeight: 6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
