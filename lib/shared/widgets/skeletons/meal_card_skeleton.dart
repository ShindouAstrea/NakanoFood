import 'package:flutter/material.dart';
import 'shimmer_box.dart';

/// Skeleton that matches the layout of [_MealCard] in MealPlanningScreen.
class MealCardSkeleton extends StatelessWidget {
  const MealCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Leading icon box
            ShimmerBox(width: 44, height: 44, borderRadius: 10),
            SizedBox(width: 16),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 100, height: 13, borderRadius: 6),
                  SizedBox(height: 6),
                  ShimmerBox(width: double.infinity, height: 11, borderRadius: 6),
                  SizedBox(height: 4),
                  ShimmerBox(width: 160, height: 11, borderRadius: 6),
                ],
              ),
            ),
            SizedBox(width: 8),
            // Trailing icons
            Column(
              children: [
                ShimmerBox(width: 20, height: 20, borderRadius: 4),
                SizedBox(height: 8),
                ShimmerBox(width: 20, height: 20, borderRadius: 4),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// List of [MealCardSkeleton] for meal planning loading state.
class MealListSkeleton extends StatelessWidget {
  const MealListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
      itemCount: 4,
      itemBuilder: (_, __) => const MealCardSkeleton(),
    );
  }
}
