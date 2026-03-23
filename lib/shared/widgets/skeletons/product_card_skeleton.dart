import 'package:flutter/material.dart';
import 'shimmer_box.dart';

/// Skeleton that matches the layout of [ProductCard].
class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ShimmerBox(width: 4, height: 52, borderRadius: 4),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ShimmerBox(width: double.infinity, height: 14),
                      ),
                      SizedBox(width: 8),
                      ShimmerBox(width: 36, height: 18, borderRadius: 6),
                    ],
                  ),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      ShimmerBox(width: 7, height: 7, borderRadius: 4),
                      SizedBox(width: 5),
                      ShimmerBox(width: 100, height: 11, borderRadius: 6),
                    ],
                  ),
                  SizedBox(height: 10),
                  ShimmerBox(width: 120, height: 11, borderRadius: 6),
                  SizedBox(height: 6),
                  ShimmerBox(width: double.infinity, height: 5, borderRadius: 4),
                ],
              ),
            ),
            SizedBox(width: 8),
            ShimmerBox(width: 20, height: 20, borderRadius: 4),
          ],
        ),
      ),
    );
  }
}

/// List of [ProductCardSkeleton] for pantry loading state.
class ProductListSkeleton extends StatelessWidget {
  const ProductListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 100),
      itemCount: 7,
      itemBuilder: (_, __) => const ProductCardSkeleton(),
    );
  }
}
