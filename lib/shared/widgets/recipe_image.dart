import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Displays a recipe image from a file path on native, or a placeholder on web
/// (web file system is not available; images require bytes-based storage).
class RecipeImage extends StatelessWidget {
  final String? imagePath;
  final BoxFit fit;
  final Widget Function(ColorScheme) placeholderBuilder;

  const RecipeImage({
    super.key,
    required this.imagePath,
    this.fit = BoxFit.cover,
    required this.placeholderBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (kIsWeb || imagePath == null) {
      return placeholderBuilder(colorScheme);
    }

    return Image.file(
      File(imagePath!),
      fit: fit,
      errorBuilder: (_, __, ___) => placeholderBuilder(colorScheme),
    );
  }
}
