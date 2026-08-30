import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nakano_food/core/database/database_helper.dart';
import 'package:nakano_food/features/pantry/providers/pantry_provider.dart';
import 'package:nakano_food/features/pantry/providers/shopping_provider.dart';
import 'package:nakano_food/features/pantry/providers/unit_conversion_provider.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Lo que las dos funciones nuevas dejan escrito en SQLite.
///
/// Los otros tests comprueban el cálculo y la pantalla; este comprueba lo
/// único que el usuario verá mañana: la fila del producto y la de la lista.
/// Corre contra una base de datos de verdad, creada con el esquema de la app.
///
/// Van juntas en un archivo a propósito: `flutter test` corre los archivos en
/// paralelo y comparten la misma base, así que separarlas las haría pisarse.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // Base limpia: el archivo sobrevive entre corridas y arrastraría el stock
    // que dejó la anterior.
    await databaseFactory
        .deleteDatabase(join(await getDatabasesPath(), 'nakano_food.db'));
  });

  Future<void> seed({
    required String id,
    required String name,
    required double quantity,
    String unit = 'kg',
    double price = 0,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final then = DateTime(2026, 8, 1).toIso8601String();
    await db.insert('product_categories', {
      'id': 'cat-test',
      'name': 'Prueba',
      'is_custom': 1,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('products', {
      'id': id,
      'name': name,
      'category_id': 'cat-test',
      'unit': unit,
      'current_quantity': quantity,
      'quantity_to_maintain': 2,
      'last_price': price,
      'price_ref_qty': 1,
      'created_at': then,
      'updated_at': then,
      'synced_at': then,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, Object?>> row(String id) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('products', where: 'id = ?', whereArgs: [id]);
    return rows.single;
  }

  ProviderContainer container() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  group('descontar al cocinar', () {
    Future<void> consume(Map<String, double> deltas) async {
      await container()
          .read(productsProvider.notifier)
          .consumeQuantities(deltas);
    }

    test('resta la cantidad consumida y deja la fila pendiente de sync',
        () async {
      await seed(id: 'p-harina', name: 'Harina', quantity: 3);

      await consume({'p-harina': 0.2});

      final harina = await row('p-harina');
      expect(harina['current_quantity'], 2.8);
      // synced_at en null es lo que hace que fullUpload la vuelva a subir.
      expect(harina['synced_at'], isNull);
      expect(
          harina['updated_at'], isNot(DateTime(2026, 8, 1).toIso8601String()));
    });

    test('el stock se queda en cero, nunca en negativo', () async {
      await seed(id: 'p-sal', name: 'Sal', quantity: 0.3);

      await consume({'p-sal': 0.8});

      expect((await row('p-sal'))['current_quantity'], 0);
    });

    test('descuenta varios productos en la misma pasada', () async {
      await seed(id: 'p-arroz', name: 'Arroz', quantity: 2);
      await seed(id: 'p-aceite', name: 'Aceite', quantity: 1.5);

      await consume({'p-arroz': 0.5, 'p-aceite': 0.25});

      expect((await row('p-arroz'))['current_quantity'], 1.5);
      expect((await row('p-aceite'))['current_quantity'], 1.25);
    });

    test('un producto borrado entre medio no rompe el resto del descuento',
        () async {
      await seed(id: 'p-leche', name: 'Leche', quantity: 2);

      await consume({'p-leche': 0.5, 'p-fantasma': 1});

      expect((await row('p-leche'))['current_quantity'], 1.5);
    });

    test('no toca nada con un descuento vacío o en cero', () async {
      await seed(id: 'p-azucar', name: 'Azúcar', quantity: 1);

      await consume(const {});
      await consume({'p-azucar': 0});

      final azucar = await row('p-azucar');
      expect(azucar['current_quantity'], 1);
      // Sigue marcada como sincronizada: no se escribió sobre ella.
      expect(azucar['synced_at'], isNotNull);
    });
  });

  group('agregar a la compra en curso', () {
    setUp(() async {
      final db = await DatabaseHelper.instance.database;
      await db.delete('shopping_sessions');
    });

    test('un producto nuevo entra en la lista ya abierta', () async {
      await seed(id: 'p-arroz', name: 'Arroz', quantity: 1);
      await seed(id: 'p-papas', name: 'Papas', quantity: 0, price: 990);

      final scope = container();
      final notifier = scope.read(activeSessionProvider.notifier);
      await scope.read(activeSessionProvider.future);
      await notifier.startSessionFromPlan({'p-arroz': 1});

      final products = await scope.read(productsProvider.future);
      final papas = products.firstWhere((p) => p.id == 'p-papas');
      final item = await notifier.addProductToSession(papas);

      expect(item, isNotNull);
      expect(item!.productName, 'Papas');
      expect(item.plannedPrice, 990);
      expect(item.categoryName, 'Prueba');

      // Está en lo que ve la pantalla...
      final active = await scope.read(activeSessionProvider.future);
      expect(active!.items.map((i) => i.productId),
          containsAll(['p-arroz', 'p-papas']));

      // ...y en la base, que es lo que sobrevive a cerrar la app.
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('shopping_items',
          where: 'session_id = ?', whereArgs: [active.id]);
      expect(rows, hasLength(2));
    });

    test('no lo agrega dos veces', () async {
      await seed(id: 'p-papas', name: 'Papas', quantity: 0);

      final scope = container();
      final notifier = scope.read(activeSessionProvider.notifier);
      await scope.read(activeSessionProvider.future);
      await notifier.startSessionFromPlan({'p-papas': 1});

      final products = await scope.read(productsProvider.future);
      final papas = products.firstWhere((p) => p.id == 'p-papas');
      final repetido = await notifier.addProductToSession(papas);

      expect(repetido, isNull);
      final active = await scope.read(activeSessionProvider.future);
      expect(active!.items, hasLength(1));
    });

    test('sin compra abierta no hace nada', () async {
      await seed(id: 'p-papas', name: 'Papas', quantity: 0);

      final scope = container();
      final notifier = scope.read(activeSessionProvider.notifier);
      expect(await scope.read(activeSessionProvider.future), isNull);

      final products = await scope.read(productsProvider.future);
      final papas = products.firstWhere((p) => p.id == 'p-papas');
      expect(await notifier.addProductToSession(papas), isNull);
    });
  });

  group('lista de compras desde el plan', () {
    setUp(() async {
      // Cada caso parte sin sesiones: el ON DELETE CASCADE se lleva los ítems.
      final db = await DatabaseHelper.instance.database;
      await db.delete('shopping_sessions');
    });

    test('crea una sesión activa con lo que falta', () async {
      await seed(id: 'p-harina', name: 'Harina', quantity: 0.3, price: 1200);
      await seed(id: 'p-arroz', name: 'Arroz', quantity: 0);

      final session = await container()
          .read(activeSessionProvider.notifier)
          .startSessionFromPlan(
        {'p-harina': 0.7, 'p-arroz': 2},
        notes: 'Plan de comidas · 20 ago – 26 ago',
      );

      expect(session.items, hasLength(2));
      expect(session.notes, contains('Plan de comidas'));

      final harina =
          session.items.firstWhere((i) => i.productId == 'p-harina');
      expect(harina.plannedQuantity, 0.7);
      // El ítem se guarda en la unidad del producto y con su precio y pasillo:
      // el historial tiene que leerse aunque el producto cambie después.
      expect(harina.unit, 'kg');
      expect(harina.plannedPrice, 1200);
      expect(harina.categoryName, 'Prueba');
    });

    test('la sesión y sus ítems quedan en la base', () async {
      await seed(id: 'p-harina', name: 'Harina', quantity: 0);

      final session = await container()
          .read(activeSessionProvider.notifier)
          .startSessionFromPlan({'p-harina': 1});

      final db = await DatabaseHelper.instance.database;
      final sessions = await db.query('shopping_sessions',
          where: 'id = ?', whereArgs: [session.id]);
      final items = await db.query('shopping_items',
          where: 'session_id = ?', whereArgs: [session.id]);

      expect(sessions.single['status'], 'active');
      expect(sessions.single['synced_at'], isNull);
      expect(items, hasLength(1));
      expect(items.single['planned_quantity'], 1);
    });

    test('la pantalla la encuentra como sesión activa', () async {
      await seed(id: 'p-harina', name: 'Harina', quantity: 0);

      final scope = container();
      final created = await scope
          .read(activeSessionProvider.notifier)
          .startSessionFromPlan({'p-harina': 1});

      final active = await scope.read(activeSessionProvider.future);
      expect(active?.id, created.id);
      expect(active?.items, hasLength(1));
    });

    test('ignora cantidades en cero y productos que ya no existen', () async {
      await seed(id: 'p-harina', name: 'Harina', quantity: 0);

      final session = await container()
          .read(activeSessionProvider.notifier)
          .startSessionFromPlan({
        'p-harina': 1,
        'p-arroz': 0,
        'p-fantasma': 3,
      });

      expect(session.items.map((i) => i.productId), ['p-harina']);
    });
  });

  group('declarar una equivalencia de unidad', () {
    test('queda escrita, canonizada y pendiente de sync', () async {
      await seed(id: 'p-eq-azucar', name: 'Azúcar', quantity: 2);
      final scope = container();

      await scope.read(unitConversionsProvider.notifier).declare(
            productId: 'p-eq-azucar',
            fromQty: 1,
            fromUnit: 'Cucharadas', // escrito como venga
            toQty: 14,
            toUnit: 'gr',
          );

      final db = await DatabaseHelper.instance.database;
      final saved = (await db.query('unit_conversions',
              where: 'product_id = ?', whereArgs: ['p-eq-azucar']))
          .single;

      expect(saved['from_unit'], 'cucharada');
      expect(saved['to_unit'], 'g');
      expect(saved['to_qty'], 14);
      expect(saved['synced_at'], isNull);
    });

    test('declararla otra vez corrige, no acumula', () async {
      await seed(id: 'p-eq-harina', name: 'Harina', quantity: 1);
      final scope = container();
      final notifier = scope.read(unitConversionsProvider.notifier);

      await notifier.declare(
          productId: 'p-eq-harina',
          fromQty: 1,
          fromUnit: 'taza',
          toQty: 120,
          toUnit: 'g');
      await scope.read(unitConversionsProvider.future);
      await notifier.declare(
          productId: 'p-eq-harina',
          fromQty: 1,
          fromUnit: 'taza',
          toQty: 130,
          toUnit: 'g');

      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('unit_conversions',
          where: 'product_id = ?', whereArgs: ['p-eq-harina']);

      expect(rows, hasLength(1));
      expect(rows.single['to_qty'], 130);
    });

    test('el conversor la usa, y le gana al catálogo', () async {
      await seed(id: 'p-eq-arroz', name: 'Arroz', unit: 'kg', quantity: 2);
      final scope = container();

      // El catálogo dice 185 g por taza; esta despensa dice 200.
      await scope.read(unitConversionsProvider.notifier).declare(
            productId: 'p-eq-arroz',
            fromQty: 1,
            fromUnit: 'taza',
            toQty: 200,
            toUnit: 'g',
          );
      await scope.read(unitConversionsProvider.future);

      final products = await scope.read(productsProvider.future);
      final arroz = products.firstWhere((p) => p.id == 'p-eq-arroz');
      final amount = arroz.amountInProductUnit(2, 'taza',
          converter: scope.read(unitConverterProvider));

      expect(amount!.value, 0.4); // 2 × 200 g, no 2 × 185
      expect(amount.isEstimate, isFalse);
    });
  });
}
