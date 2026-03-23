import 'dart:io';
import 'package:flutter/material.dart';
import '../models/recipe.dart';

class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;

  const RecipeCard({super.key, required this.recipe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            // Image
            SizedBox(
              width: 100,
              height: 90,
              child: recipe.mainImagePath != null
                  ? Image.file(
                      File(recipe.mainImagePath!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            recipe.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withAlpha(25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        recipe.type,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (recipe.totalTime > 0) ...[
                          Icon(Icons.timer_outlined,
                              size: 14,
                              color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            '${recipe.totalTime} min',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Icon(Icons.restaurant_outlined,
                            size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          '${recipe.portions} porción${recipe.portions > 1 ? 'es' : ''}',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600),
                        ),
                        if (recipe.estimatedCost > 0) ...[
                          const SizedBox(width: 12),
                          Icon(Icons.attach_money,
                              size: 14, color: Colors.grey.shade500),
                          Text(
                            recipe.estimatedCost.toStringAsFixed(0),
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Icon(Icons.chevron_right,
                color: Colors.grey.shade400, size: 20),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey.shade200,
      child:
          Icon(Icons.restaurant, size: 40, color: Colors.grey.shade400),
    );
  }
}
