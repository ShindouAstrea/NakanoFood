import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenFoodProduct {
  final String name;
  final double? servingSize;
  final String servingUnit;
  final double? kcal;
  final double? proteins;
  final double? carbs;
  final double? sugars;
  final double? totalFats;
  final double? saturatedFats;
  final double? fiber;
  final double? sodium;

  const OpenFoodProduct({
    required this.name,
    this.servingSize,
    this.servingUnit = 'g',
    this.kcal,
    this.proteins,
    this.carbs,
    this.sugars,
    this.totalFats,
    this.saturatedFats,
    this.fiber,
    this.sodium,
  });
}

class OpenFoodFactsService {
  static const _baseUrl = 'https://world.openfoodfacts.org/api/v2/product';
  static const _fields =
      'product_name,nutriments,serving_size,serving_quantity';

  static Future<OpenFoodProduct?> fetchByBarcode(String barcode) async {
    try {
      final uri =
          Uri.parse('$_baseUrl/$barcode.json?fields=$_fields&lc=es');
      final response =
          await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] != 1) return null;

      final product = data['product'] as Map<String, dynamic>?;
      if (product == null) return null;

      final nutriments =
          product['nutriments'] as Map<String, dynamic>? ?? {};

      double? d(String key) {
        final v = nutriments[key];
        if (v == null) return null;
        return (v as num).toDouble();
      }

      final name = (product['product_name'] as String? ?? '').trim();
      if (name.isEmpty) return null;

      // serving_quantity is numeric, serving_size is a string like "30g"
      final servingQty =
          (product['serving_quantity'] as num?)?.toDouble() ??
              _parseServingSize(product['serving_size'] as String?);

      // sodium in OFF is in g/100g → convert to mg
      final sodiumG = d('sodium_100g');
      final sodiumMg = sodiumG != null ? sodiumG * 1000 : null;

      return OpenFoodProduct(
        name: name,
        servingSize: servingQty,
        servingUnit: 'g',
        kcal: d('energy-kcal_100g'),
        proteins: d('proteins_100g'),
        carbs: d('carbohydrates_100g'),
        sugars: d('sugars_100g'),
        totalFats: d('fat_100g'),
        saturatedFats: d('saturated-fat_100g'),
        fiber: d('fiber_100g'),
        sodium: sodiumMg,
      );
    } catch (_) {
      return null;
    }
  }

  static double? _parseServingSize(String? raw) {
    if (raw == null) return null;
    final match = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(raw);
    if (match == null) return null;
    return double.tryParse(match.group(1)!.replaceAll(',', '.'));
  }
}
