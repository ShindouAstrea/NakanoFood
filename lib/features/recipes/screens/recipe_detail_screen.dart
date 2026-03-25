import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/recipe_provider.dart';
import '../models/recipe.dart';
import '../services/recipe_share_service.dart';
import 'add_edit_recipe_screen.dart';


class RecipeDetailScreen extends ConsumerStatefulWidget {
  final String recipeId;

  const RecipeDetailScreen({super.key, required this.recipeId});

  @override
  ConsumerState<RecipeDetailScreen> createState() =>
      _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  double _portionMultiplier = 1.0;
  final List<double> _multipliers = [0.5, 1.0, 2.0, 3.0];

  @override
  Widget build(BuildContext context) {
    final recipeAsync =
        ref.watch(recipeWithAvailabilityProvider(widget.recipeId));
    final theme = Theme.of(context);

    return Scaffold(
      body: recipeAsync.when(
        data: (recipe) => _buildDetail(context, recipe, theme),
        loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator())),
        error: (e, _) =>
            Scaffold(body: Center(child: Text('Error: $e'))),
      ),
    );
  }

  Widget _buildDetail(
      BuildContext context, Recipe recipe, ThemeData theme) {
    final missingIngredients = recipe.ingredients
        .where((i) => i.isAvailable == false)
        .toList();

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: recipe.mainImagePath != null ? 250 : 120,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            title: Text(
              recipe.name,
              style: const TextStyle(
                color: Colors.white,
                shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
              ),
            ),
            background: (!kIsWeb && recipe.mainImagePath != null)
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(File(recipe.mainImagePath!),
                          fit: BoxFit.cover),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black54],
                          ),
                        ),
                      ),
                    ],
                  )
                : Container(color: theme.colorScheme.primary),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.share_outlined, color: Colors.white),
              tooltip: 'Compartir receta',
              onPressed: () => _showShareSheet(context, recipe),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.white),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      AddEditRecipeScreen(recipe: recipe),
                ),
              ).then((_) {
                ref.invalidate(recipesProvider);
                ref.invalidate(
                    recipeWithAvailabilityProvider(widget.recipeId));
              }),
            ),
            IconButton(
              icon:
                  const Icon(Icons.delete_outline, color: Colors.white),
              onPressed: () => _confirmDelete(context, ref, recipe),
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type & stats
                Row(
                  children: [
                    Chip(
                      label: Text(recipe.type),
                      backgroundColor: theme.colorScheme.primary
                          .withAlpha(30),
                      labelStyle: TextStyle(
                          color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: 8),
                    if (recipe.totalTime > 0)
                      _InfoChip(
                          icon: Icons.timer_outlined,
                          label: '${recipe.totalTime} min'),
                    const SizedBox(width: 8),
                    _InfoChip(
                        icon: Icons.people_outline,
                        label: '${recipe.portions} porc.'),
                    if (recipe.estimatedCost > 0) ...[
                      const SizedBox(width: 8),
                      _InfoChip(
                          icon: Icons.attach_money,
                          label:
                              '\$${recipe.estimatedCost.toStringAsFixed(0)}'),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                // Missing ingredients warning
                if (missingIngredients.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: Colors.red.shade700, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Ingredientes insuficientes',
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ...missingIngredients.map((ing) => Text(
                              '• ${ing.productName}: necesitas ${(ing.quantity * _portionMultiplier).toStringAsFixed(1)} ${ing.unit}, disponible ${ing.availableQuantity?.toStringAsFixed(1) ?? 'N/A'}',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.red.shade600),
                            )),
                      ],
                    ),
                  ),
                if (missingIngredients.isNotEmpty)
                  const SizedBox(height: 12),

                // Portion multiplier
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Recalcular porciones',
                            style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(
                          children: _multipliers
                              .map((m) => Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 2),
                                      child: ChoiceChip(
                                        label: Text(
                                          m == 0.5
                                              ? '½x'
                                              : '${m.toInt()}x',
                                          style: const TextStyle(
                                              fontSize: 13),
                                        ),
                                        selected:
                                            _portionMultiplier == m,
                                        onSelected: (_) => setState(
                                            () =>
                                                _portionMultiplier = m),
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Porciones: ${(recipe.portions * _portionMultiplier).toStringAsFixed(_portionMultiplier == 0.5 ? 1 : 0)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Description
                if (recipe.description != null) ...[
                  const _SectionHeader(title: 'Descripción'),
                  Text(recipe.description!,
                      style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 16),
                ],

                // Ingredients
                _SectionHeader(
                    title:
                        'Ingredientes (${recipe.ingredients.length})'),
                const SizedBox(height: 8),
                ...recipe.ingredients.map((ing) => _IngredientRow(
                      ingredient: ing,
                      multiplier: _portionMultiplier,
                    )),
                const SizedBox(height: 16),

                // Steps
                if (recipe.steps.isNotEmpty) ...[
                  _SectionHeader(
                      title: 'Preparación (${recipe.steps.length} pasos)'),
                  const SizedBox(height: 8),
                  ...recipe.steps
                      .map((step) => _StepCard(step: step)),
                  const SizedBox(height: 16),
                ],

                // Notes
                if (recipe.notes != null) ...[
                  const _SectionHeader(title: 'Notas'),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lightbulb_outline,
                            color: Colors.amber.shade700, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            recipe.notes!,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(
                                    color: Colors.amber.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Additional images
                if (recipe.imagePaths.length > 1) ...[
                  const _SectionHeader(title: 'Fotos'),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: recipe.imagePaths.length,
                      itemBuilder: (_, i) => Container(
                        width: 120,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          image: kIsWeb
                              ? null
                              : DecorationImage(
                                  image: FileImage(File(recipe.imagePaths[i])),
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showShareSheet(BuildContext context, Recipe recipe) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.tag_rounded),
              title: const Text('Compartir con código'),
              subtitle: const Text('Genera un código de 6 caracteres'),
              onTap: () {
                Navigator.pop(context);
                _shareWithCode(context, recipe);
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_outlined),
              title: const Text('Compartir como texto'),
              subtitle: const Text('Por WhatsApp u otras apps'),
              onTap: () {
                Navigator.pop(context);
                _shareAsText(recipe);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _shareWithCode(BuildContext context, Recipe recipe) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Generando código...'),
          ],
        ),
      ),
    );

    try {
      final code = await RecipeShareService.shareRecipe(recipe);
      if (!context.mounted) return;
      Navigator.pop(context); // cierra loading

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Código generado'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Comparte este código para que otros importen la receta:'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  code,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Válido por 30 días',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.share_outlined, size: 18),
              label: const Text('Compartir'),
              onPressed: () {
                Navigator.pop(ctx);
                Share.share(
                  'Te comparto la receta "${recipe.name}" en NakanoFood 🍽️\n\nCódigo: $code\n\nÁbrela desde Recetas → Importar receta.',
                  subject: recipe.name,
                );
              },
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al generar el código. ¿Tienes conexión?')),
      );
    }
  }

  void _shareAsText(Recipe recipe) {
    final buf = StringBuffer();

    buf.writeln('🍽️ *${recipe.name}*');

    final meta = <String>[];
    if (recipe.type.isNotEmpty) meta.add('📂 ${recipe.type}');
    if (recipe.totalTime > 0) meta.add('⏱️ ${recipe.totalTime} min');
    meta.add('👥 ${(recipe.portions * _portionMultiplier).toStringAsFixed(_portionMultiplier == 0.5 ? 1 : 0)} porciones');
    buf.writeln(meta.join('  |  '));

    if (recipe.description != null) {
      buf.writeln();
      buf.writeln('📝 *Descripción*');
      buf.writeln(recipe.description);
    }

    if (recipe.ingredients.isNotEmpty) {
      buf.writeln();
      buf.writeln('🛒 *Ingredientes*');
      for (final ing in recipe.ingredients) {
        final qty = ing.quantity * _portionMultiplier;
        final qtyStr = qty == qty.roundToDouble()
            ? qty.toInt().toString()
            : qty.toStringAsFixed(1);
        buf.writeln('• ${ing.productName}: $qtyStr ${ing.unit}');
      }
    }

    if (recipe.steps.isNotEmpty) {
      buf.writeln();
      buf.writeln('👨‍🍳 *Preparación*');
      for (final step in recipe.steps) {
        buf.writeln('${step.stepNumber}. ${step.description}');
      }
    }

    if (recipe.notes != null) {
      buf.writeln();
      buf.writeln('📌 *Notas*');
      buf.writeln(recipe.notes);
    }

    buf.writeln();
    buf.write('Compartido desde NakanoFood 🥗');

    Share.share(buf.toString(), subject: recipe.name);
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Recipe recipe) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Receta'),
        content: Text(
            '¿Eliminar "${recipe.name}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(recipesProvider.notifier).deleteRecipe(recipe.id);
      if (context.mounted) Navigator.pop(context);
    }
  }
}

class _IngredientRow extends StatelessWidget {
  final RecipeIngredient ingredient;
  final double multiplier;

  const _IngredientRow(
      {required this.ingredient, required this.multiplier});

  @override
  Widget build(BuildContext context) {
    final adjustedQty = ingredient.quantity * multiplier;
    final available = ingredient.availableQuantity;
    final isAvailable = ingredient.isAvailable;

    Color dotColor;
    if (isAvailable == null) {
      dotColor = Colors.grey;
    } else if (isAvailable && available != null && available >= adjustedQty) {
      dotColor = Colors.green;
    } else {
      dotColor = Colors.red;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              ingredient.productName,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            '${adjustedQty.toStringAsFixed(adjustedQty == adjustedQty.roundToDouble() ? 0 : 1)} ${ingredient.unit}',
            style: TextStyle(
                color: Colors.grey.shade700, fontWeight: FontWeight.w500),
          ),
          if (isAvailable == false && available != null) ...[
            const SizedBox(width: 6),
            Icon(Icons.warning_amber_rounded,
                size: 16, color: Colors.red.shade400),
          ],
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final RecipeStep step;
  const _StepCard({required this.step});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${step.stepNumber}',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(step.description,
                  style: const TextStyle(fontSize: 14, height: 1.4)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(label,
              style:
                  TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}
