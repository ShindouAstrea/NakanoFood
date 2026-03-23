import 'package:flutter/material.dart';
import 'shimmer_box.dart';

/// Skeleton that matches the layout of [RecipeCard].
class RecipeCardSkeleton extends StatelessWidget {
  const RecipeCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 110,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image placeholder
            ShimmerBox(width: 100, height: double.infinity, borderRadius: 0),
            // Info
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(12, 12, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ShimmerBox(width: double.infinity, height: 14),
                    SizedBox(height: 4),
                    ShimmerBox(width: 150, height: 12),
                    SizedBox(height: 10),
                    ShimmerBox(width: 60, height: 20, borderRadius: 20),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        ShimmerBox(width: 50, height: 11, borderRadius: 4),
                        SizedBox(width: 10),
                        ShimmerBox(width: 50, height: 11, borderRadius: 4),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(right: 8),
              child: Align(
                alignment: Alignment.center,
                child: ShimmerBox(width: 20, height: 20, borderRadius: 4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// List of [RecipeCardSkeleton] for recipe loading state.
class RecipeListSkeleton extends StatelessWidget {
  const RecipeListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: 6,
      itemBuilder: (_, __) => const RecipeCardSkeleton(),
    );
  }
}
