import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/recipe.dart';

const _uuid = Uuid();

class RecipeShareService {
  static const _table = 'shared_recipes';
  static const _codeChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

  static SupabaseClient get _db => Supabase.instance.client;

  static String _generateCode() {
    final rand = Random.secure();
    return List.generate(6, (_) => _codeChars[rand.nextInt(_codeChars.length)])
        .join();
  }

  static Map<String, dynamic> _toJson(Recipe recipe) => {
        'name': recipe.name,
        'type': recipe.type,
        'description': recipe.description,
        'portions': recipe.portions,
        'prep_time': recipe.prepTime,
        'cook_time': recipe.cookTime,
        'estimated_cost': recipe.estimatedCost,
        'notes': recipe.notes,
        'ingredients': recipe.ingredients
            .map((i) => {
                  'product_name': i.productName,
                  'quantity': i.quantity,
                  'unit': i.unit,
                })
            .toList(),
        'steps': recipe.steps
            .map((s) => {
                  'step_number': s.stepNumber,
                  'description': s.description,
                })
            .toList(),
      };

  static Recipe _fromJson(Map<String, dynamic> json) {
    final newId = _uuid.v4();
    final now = DateTime.now();

    final ingredients = (json['ingredients'] as List)
        .map((i) => RecipeIngredient(
              id: _uuid.v4(),
              recipeId: newId,
              productName: i['product_name'] as String,
              quantity: (i['quantity'] as num).toDouble(),
              unit: i['unit'] as String,
            ))
        .toList();

    final steps = (json['steps'] as List)
        .map((s) => RecipeStep(
              id: _uuid.v4(),
              recipeId: newId,
              stepNumber: s['step_number'] as int,
              description: s['description'] as String,
            ))
        .toList();

    return Recipe(
      id: newId,
      name: json['name'] as String,
      type: json['type'] as String,
      description: json['description'] as String?,
      portions: json['portions'] as int? ?? 1,
      prepTime: json['prep_time'] as int?,
      cookTime: json['cook_time'] as int?,
      estimatedCost: (json['estimated_cost'] as num?)?.toDouble() ?? 0,
      notes: json['notes'] as String?,
      createdAt: now,
      updatedAt: now,
      ingredients: ingredients,
      steps: steps,
    );
  }

  /// Sube la receta a Supabase y devuelve el código de 6 caracteres.
  static Future<String> shareRecipe(Recipe recipe) async {
    String code;
    // Reintentar hasta obtener un código único
    do {
      code = _generateCode();
      final existing = await _db
          .from(_table)
          .select('code')
          .eq('code', code)
          .maybeSingle();
      if (existing == null) break;
    } while (true);

    await _db.from(_table).insert({
      'code': code,
      'recipe_data': _toJson(recipe),
      'expires_at':
          DateTime.now().add(const Duration(days: 30)).toIso8601String(),
    });

    return code;
  }

  /// Busca una receta por código y la devuelve lista para guardar localmente.
  /// Retorna null si el código no existe o expiró.
  static Future<Recipe?> importByCode(String code) async {
    final row = await _db
        .from(_table)
        .select('recipe_data, expires_at')
        .eq('code', code.toUpperCase().trim())
        .maybeSingle();

    if (row == null) return null;

    final expiresAt = DateTime.parse(row['expires_at'] as String);
    if (DateTime.now().isAfter(expiresAt)) return null;

    return _fromJson(row['recipe_data'] as Map<String, dynamic>);
  }
}
