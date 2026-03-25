import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/services/image_storage_service.dart';

/// Displays a recipe image from a Supabase Storage URL, a local file path,
/// or a placeholder when neither is available.
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

    if (imagePath == null) return placeholderBuilder(colorScheme);

    if (ImageStorageService.isRemoteUrl(imagePath!)) {
      return Image.network(
        imagePath!,
        fit: fit,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : placeholderBuilder(colorScheme),
        errorBuilder: (_, __, ___) => placeholderBuilder(colorScheme),
      );
    }

    if (kIsWeb) return placeholderBuilder(colorScheme);

    return Image.file(
      File(imagePath!),
      fit: fit,
      errorBuilder: (_, __, ___) => placeholderBuilder(colorScheme),
    );
  }
}
