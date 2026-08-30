/// Conversión entre unidades de cocina.
///
/// La despensa guarda "1 paquete" y la receta pide "8 cucharadas": para
/// descontar hay que poder ir de una a otra. Aquí vive todo lo que se puede
/// afirmar sin preguntarle al usuario —lo que es cierto por definición, como
/// que una cucharada son 15 ml— y el buscador que encadena esas equivalencias
/// con las que sí hay que declarar porque dependen del ingrediente: cuánto
/// pesa una taza de harina no se deduce de nada.
///
/// La regla que ordena el archivo: antes que inventar un factor, se devuelve
/// null. Un error de 1000 aquí es la diferencia entre un gramo y un kilo, y se
/// descuenta de la despensa de verdad.
library;

import 'number_input.dart';

/// Magnitud de una unidad. Dos unidades de magnitudes distintas solo se cruzan
/// si alguien declara la equivalencia (densidad, peso por pieza…).
enum UnitKind {
  weight,
  volume,
  count,

  /// Envases y piezas: 'paquete', 'diente', 'rodaja'. No hay nada universal
  /// que decir de ellas; solo valen las equivalencias declaradas.
  opaque,

  /// 'al gusto', 'cantidad necesaria'. No es que falte información: es que no
  /// hay cantidad que descontar, y tratarlo como un error confunde.
  unquantified,
}

// ─── Escalas exactas ─────────────────────────────────────────────────────────
//
// Dentro de una escala la conversión es cierta por definición y nunca se marca
// como estimada.

/// Peso, expresado en gramos.
const _weightScale = <String, double>{
  'mg': 0.001,
  'g': 1.0,
  'kg': 1000.0,
  'oz': 28.349523125,
  'lb': 453.59237,
};

/// Volumen, expresado en mililitros.
///
/// La cuchara y la taza entran aquí porque son medidas definidas, no una
/// apreciación: una cucharada rasa son 15 ml venga de donde venga. La taza se
/// toma como 250 ml, que es lo que mide una taza de medir en español; la "cup"
/// estadounidense son 240 y esa diferencia —un 4%— no cambia ninguna decisión
/// de despensa.
const _volumeScale = <String, double>{
  'ml': 1.0,
  'cucharadita': 5.0,
  'cucharada de postre': 10.0,
  'cl': 10.0,
  'cucharada': 15.0,
  'onza liquida': 29.5735295625,
  'dl': 100.0,
  'taza': 250.0,
  'pinta': 473.176473,
  'cuarto': 946.352946,
  'l': 1000.0,
  'galon': 3785.411784,
};

/// Conteo, expresado en unidades.
const _countScale = <String, double>{
  'unidad': 1.0,
  'par': 2.0,
  'media docena': 6.0,
  'docena': 12.0,
};

const _scales = [_weightScale, _volumeScale, _countScale];

/// Medidas de volumen que se dicen igual pero no miden lo mismo en dos
/// cocinas: un vaso no está definido en ninguna parte.
///
/// Se aceptan —una receta que dice "1 vaso de leche" es una receta real— pero
/// entran como equivalencia estimada, y eso se arrastra hasta la pantalla.
const _approximateVolume = <String, double>{
  'gota': 0.05,
  'pizca': 0.625, // un octavo de cucharadita, que es la convención
  'chorrito': 5.0,
  'chorro': 15.0,
  'cucharon': 60.0,
  'copa': 150.0,
  'punado': 120.0,
  'vaso': 200.0,
  'pocillo': 200.0,
};

/// Envases y piezas. Se listan para poder reconocerlas —singular y plural, y
/// saber que no son una errata—, no porque conviertan.
const _opaqueUnits = <String>{
  'atado',
  'bandeja',
  'barra',
  'bloque',
  'bola',
  'bolsa',
  'botella',
  'cabeza',
  'caja',
  'cubo',
  'cubito',
  'diente',
  'filete',
  'frasco',
  'gajo',
  'grano',
  'hoja',
  'lamina',
  'lata',
  'manojo',
  'mazo',
  'paquete',
  'pastilla',
  'porcion',
  'pote',
  'presa',
  'racimo',
  'rama',
  'ramita',
  'rebanada',
  'rodaja',
  'sobre',
  'tableta',
  'tallo',
  'tarro',
  'tira',
  'trozo',
  'vaina',
};

const _unquantifiedUnits = <String>{
  'al gusto',
  'cantidad necesaria',
  'opcional',
};

/// Sinónimos y abreviaturas, ya sin acentos ni mayúsculas.
///
/// La clave está normalizada con [normalizeName], así que 'Cucharadita' y
/// 'cucharadita' entran por el mismo sitio. Los plurales regulares no hace
/// falta listarlos: [canonicalUnit] los resuelve solo.
const _synonyms = <String, String>{
  // Peso
  'miligramo': 'mg',
  'mgr': 'mg',
  'gr': 'g',
  'grs': 'g',
  'grm': 'g',
  'gramo': 'g',
  'k': 'kg',
  'kgr': 'kg',
  'kilo': 'kg',
  'kilogramo': 'kg',
  'onza': 'oz',
  'libra': 'lb',
  // Volumen
  'cc': 'ml',
  'mililitro': 'ml',
  'centimetro cubico': 'ml',
  'centilitro': 'cl',
  'decilitro': 'dl',
  'lt': 'l',
  'lts': 'l',
  'litro': 'l',
  'cda': 'cucharada',
  'cdas': 'cucharada',
  'cuchara': 'cucharada',
  'cucharada sopera': 'cucharada',
  'cuchara sopera': 'cucharada',
  'cucharada rasa': 'cucharada',
  'cucharada colmada': 'cucharada',
  'tbsp': 'cucharada',
  'cdta': 'cucharadita',
  'cta': 'cucharadita',
  'tsp': 'cucharadita',
  'cuchara de te': 'cucharadita',
  'cucharada de te': 'cucharadita',
  'cucharadita de te': 'cucharadita',
  'cucharada de cafe': 'cucharadita',
  'cucharadita de cafe': 'cucharadita',
  'cucharada pequena': 'cucharadita',
  'cucharadita rasa': 'cucharadita',
  'cuchara de postre': 'cucharada de postre',
  'cucharada postrera': 'cucharada de postre',
  'cup': 'taza',
  'taza de te': 'taza',
  'taza de medir': 'taza',
  'onza fluida': 'onza liquida',
  'fl oz': 'onza liquida',
  'oz liquida': 'onza liquida',
  'galon americano': 'galon',
  'cucharon sopero': 'cucharon',
  'cazo': 'cucharon',
  'copa de vino': 'copa',
  'vaso de agua': 'vaso',
  'punado grande': 'punado',
  // Conteo
  'u': 'unidad',
  'un': 'unidad',
  'ud': 'unidad',
  'und': 'unidad',
  'uni': 'unidad',
  'pza': 'unidad',
  'pieza': 'unidad',
  'unidad grande': 'unidad',
  'unidad mediana': 'unidad',
  'unidad pequena': 'unidad',
  'media docena': 'media docena',
  // Piezas que se dicen de varias formas
  'loncha': 'rebanada',
  'lonja': 'rebanada',
  'feta': 'rebanada',
  'tajada': 'rebanada',
  'rueda': 'rodaja',
  'sachet': 'sobre',
  'bolsita': 'sobre',
  'ramillete': 'ramita',
  // Sin cantidad
  'a gusto': 'al gusto',
  'a su gusto': 'al gusto',
  'cn': 'cantidad necesaria',
  'c n': 'cantidad necesaria',
  'la necesaria': 'cantidad necesaria',
};

/// Todas las unidades que la app sabe nombrar.
final Set<String> _knownUnits = {
  ..._weightScale.keys,
  ..._volumeScale.keys,
  ..._countScale.keys,
  ..._approximateVolume.keys,
  ..._opaqueUnits,
  ..._unquantifiedUnits,
};

/// Reduce una unidad escrita a mano a su forma canónica.
///
/// Aguanta mayúsculas, acentos, abreviaturas, puntos ('cdta.') y plurales
/// regulares, porque las recetas llegan escritas por el usuario, precargadas,
/// importadas y generadas por IA, y las cuatro escriben distinto.
String canonicalUnit(String unit) {
  final s = normalizeName(unit).replaceAll('.', '').trim();
  if (s.isEmpty) return s;

  final direct = _synonyms[s];
  if (direct != null) return direct;
  if (_knownUnits.contains(s)) return s;

  // Plural regular. Se comprueba contra las unidades conocidas antes de
  // aceptarlo, para no partir palabras que acaban en ese sin ser plurales.
  for (final singular in _depluralize(s)) {
    final synonym = _synonyms[singular];
    if (synonym != null) return synonym;
    if (_knownUnits.contains(singular)) return singular;
  }

  // Unidad que la app no conoce ('bidón', 'cajita'): se deja tal cual, pero se
  // le quita el plural igual, para que 'cajitas' y 'cajita' sean la misma. Sin
  // esto, una receta en plural y una despensa en singular no se cruzan aunque
  // el usuario haya declarado la equivalencia.
  if (s.length > 4 && s.endsWith('s')) return _depluralize(s).last;
  return s;
}

/// Candidatos a singular de [s], del más probable al menos.
List<String> _depluralize(String s) {
  final out = <String>[];
  if (s.length > 4 && s.endsWith('es')) out.add(s.substring(0, s.length - 2));
  if (s.length > 3 && s.endsWith('s')) out.add(s.substring(0, s.length - 1));
  return out.isEmpty ? [s] : out;
}

/// Magnitud de una unidad, canonizada o no.
UnitKind unitKind(String unit) {
  final u = canonicalUnit(unit);
  if (_weightScale.containsKey(u)) return UnitKind.weight;
  if (_volumeScale.containsKey(u) || _approximateVolume.containsKey(u)) {
    return UnitKind.volume;
  }
  if (_countScale.containsKey(u)) return UnitKind.count;
  if (_unquantifiedUnits.contains(u)) return UnitKind.unquantified;
  return UnitKind.opaque;
}

/// True si la unidad no expresa una cantidad que se pueda descontar.
bool isUnquantifiedUnit(String unit) => unitKind(unit) == UnitKind.unquantified;

/// Factor exacto entre dos unidades de la misma escala, null si no lo hay.
///
/// `scaleFactor('kg', 'g')` devuelve 1000: un kilo son mil gramos.
double? scaleFactor(String from, String to) {
  if (from == to) return 1;
  for (final scale in _scales) {
    final a = scale[from];
    final b = scale[to];
    if (a != null && b != null) return a / b;
  }
  return null;
}

/// Clave con la que se busca una equivalencia por nombre de ingrediente.
///
/// Es el nombre normalizado y en singular: la despensa dice "Huevos" y el
/// catálogo "huevo", y son lo mismo.
///
/// Se queda en la ese porque es la clave que se guarda, y "azucar" se lee y
/// "azuc" no. El plural en -es lo resuelve la comparación, no la clave.
String ingredientKeyOf(String name) {
  final normalized = normalizeName(name);
  if (normalized.length > 3 && normalized.endsWith('s')) {
    return normalized.substring(0, normalized.length - 1);
  }
  return normalized;
}

/// Lo que comparten el singular y el plural de una palabra.
///
/// El español pluraliza de dos formas y las dos tienen que cruzarse con el
/// catálogo: "papas" → "papa" quitando la ese, y "azúcares" → "azúcar"
/// quitando además la e que queda. No es un lematizador —"tomate" acaba en
/// "tomat"—, y no hace falta que lo sea: solo se comparan dos formas entre
/// sí, y las dos pasan por aquí.
String _stem(String word) {
  var stem = word;
  if (stem.length > 3 && stem.endsWith('s')) {
    stem = stem.substring(0, stem.length - 1);
  }
  if (stem.length > 4 && stem.endsWith('e')) {
    stem = stem.substring(0, stem.length - 1);
  }
  return stem;
}

bool _sameWord(String a, String b) => a == b || _stem(a) == _stem(b);

/// Una equivalencia declarada: "1 cucharada de azúcar son 12 g".
///
/// [productId] la ata a un producto concreto de la despensa; [ingredientKey],
/// a cualquier cosa que se llame así. Con los dos en null vale para todo, que
/// es lo que hace falta cuando la equivalencia no depende del ingrediente.
class UnitRule {
  final String? productId;
  final String? ingredientKey;
  final double fromQty;
  final String fromUnit;
  final double toQty;
  final String toUnit;

  /// El valor es una referencia razonable, no algo que conste. Se propaga a
  /// cualquier conversión que pase por aquí para poder decirlo en pantalla.
  final bool isEstimate;

  const UnitRule({
    this.productId,
    this.ingredientKey,
    required this.fromQty,
    required this.fromUnit,
    required this.toQty,
    required this.toUnit,
    this.isEstimate = false,
  });

  bool get isUsable =>
      fromQty > 0 &&
      toQty > 0 &&
      fromUnit.trim().isNotEmpty &&
      toUnit.trim().isNotEmpty;
}

/// Una equivalencia lista para el buscador: 1 [from] son [factor] [to].
class UnitEdge {
  final String from;
  final String to;
  final double factor;
  final bool isEstimate;

  /// Cuánto vale la palabra de quien la declaró. 0 es el producto concreto,
  /// que gana siempre; 3, el catálogo general, que es el último recurso.
  final int priority;

  const UnitEdge({
    required this.from,
    required this.to,
    required this.factor,
    this.isEstimate = false,
    this.priority = 0,
  });

  UnitEdge get inverse => UnitEdge(
        from: to,
        to: from,
        factor: 1 / factor,
        isEstimate: isEstimate,
        priority: priority,
      );
}

/// El resultado de una conversión, con la advertencia pegada al número.
///
/// [isEstimate] no es decorativo: separa "tu despensa tiene 500 g" de "tu
/// despensa tiene unos 500 g", y quien lo muestra decide cómo decirlo.
class UnitAmount {
  final double value;
  final bool isEstimate;

  const UnitAmount(this.value, {this.isEstimate = false});

  @override
  String toString() => '${isEstimate ? '≈' : ''}$value';
}

const int _priorityProduct = 0;
const int _priorityIngredient = 1;
const int _priorityBuiltIn = 2;
const int _priorityCatalog = 3;

/// Convierte entre unidades encadenando lo que se sabe.
///
/// Sustituye a la escalera de tres pasos que había antes, que solo llegaba a
/// "producto → unidad base → métrica" y por eso se quedaba corta en cuanto
/// aparecía una cuchara. Aquí las equivalencias son aristas de un grafo
/// diminuto —una docena de nodos— y la conversión es el camino entre dos.
///
/// Entre varios caminos posibles gana, por este orden: el que usa menos
/// equivalencias estimadas, el que se apoya en quien más sabe del ingrediente,
/// y el más corto. Así "1 paquete = 1 kg" declarado por el usuario le gana al
/// catálogo, y el catálogo solo entra cuando no hay nada mejor.
class UnitConverter {
  final List<UnitRule> rules;

  const UnitConverter(this.rules);

  static const UnitConverter empty = UnitConverter([]);

  UnitConverter withRules(List<UnitRule> extra) =>
      UnitConverter([...rules, ...extra]);

  /// Pasa [quantity] de [from] a [to], o null si no se puede afirmar.
  ///
  /// [productId] y [ingredientKey] acotan qué equivalencias declaradas
  /// aplican: las de otro producto no pintan nada aquí. [extraEdges] es para
  /// lo que el propio producto declara en su ficha (el tamaño del envase).
  UnitAmount? convert(
    double quantity, {
    required String from,
    required String to,
    String? productId,
    String? ingredientKey,
    List<UnitEdge> extraEdges = const [],
  }) {
    final start = canonicalUnit(from);
    final goal = canonicalUnit(to);

    // Sin una cantidad de la que hablar no hay nada que convertir, y devolver
    // un número sería peor que devolver "no se sabe".
    if (unitKind(start) == UnitKind.unquantified ||
        unitKind(goal) == UnitKind.unquantified) {
      return null;
    }

    final direct = scaleFactor(start, goal);
    if (direct != null) return UnitAmount(quantity * direct);

    final edges = _edgesFor(
      productId: productId,
      ingredientKey: ingredientKey,
      extraEdges: extraEdges,
    );
    if (edges.isEmpty) return null;

    final path = _search(start, goal, edges);
    if (path == null) return null;
    return UnitAmount(quantity * path.factor, isEstimate: path.estimates > 0);
  }

  /// Búsqueda de coste uniforme sobre las unidades.
  ///
  /// El grafo es minúsculo, así que la frontera es una lista ordenada: montar
  /// un heap para diez nodos cuesta más de leer que de ejecutar.
  _Path? _search(String start, String goal, List<UnitEdge> edges) {
    final frontier = <_Path>[_Path(start, 1, 0, 0, 0)];
    final best = <String, List<int>>{};

    while (frontier.isNotEmpty) {
      frontier.sort(_cheaperFirst);
      final current = frontier.removeAt(0);

      final reach = scaleFactor(current.unit, goal);
      if (reach != null) {
        return _Path(goal, current.factor * reach, current.estimates,
            current.priority, current.hops);
      }

      // Una cadena de más de cuatro equivalencias ya no es una conversión,
      // es una casualidad aritmética. Y de paso corta los ciclos.
      if (current.hops >= 4) continue;

      for (final edge in edges) {
        final bridge = scaleFactor(current.unit, edge.from);
        if (bridge == null) continue;

        final next = _Path(
          edge.to,
          current.factor * bridge * edge.factor,
          current.estimates + (edge.isEstimate ? 1 : 0),
          current.priority + edge.priority,
          current.hops + 1,
        );
        if (!next.factor.isFinite || next.factor == 0) continue;

        final seen = best[next.unit];
        if (seen != null && _compare(seen, next.cost) <= 0) continue;
        best[next.unit] = next.cost;
        frontier.add(next);
      }
    }
    return null;
  }

  /// Las equivalencias que aplican a este ingrediente, en los dos sentidos.
  List<UnitEdge> _edgesFor({
    String? productId,
    String? ingredientKey,
    List<UnitEdge> extraEdges = const [],
  }) {
    // En los dos sentidos: una equivalencia sirve tanto para saber si alcanza
    // ("2 paquetes son 2 kg") como para descontar ("200 g son 0,2 paquetes"),
    // y la segunda es justo la que mueve el stock.
    final edges = <UnitEdge>[];
    for (final edge in extraEdges) {
      edges.add(edge);
      edges.add(edge.inverse);
    }

    for (final entry in _approximateVolume.entries) {
      edges.add(UnitEdge(
        from: entry.key,
        to: 'ml',
        factor: entry.value,
        isEstimate: true,
        priority: _priorityBuiltIn,
      ));
      edges.add(UnitEdge(
        from: 'ml',
        to: entry.key,
        factor: 1 / entry.value,
        isEstimate: true,
        priority: _priorityBuiltIn,
      ));
    }

    final key = ingredientKey == null ? null : ingredientKeyOf(ingredientKey);
    // Entre las reglas que cruzan por nombre parcial gana la más específica:
    // para "leche de coco" vale más lo que se sepa del coco que de la leche.
    var contained = <UnitRule>[];
    var containedLength = 0;

    for (final rule in rules) {
      if (!rule.isUsable) continue;

      final int priority;
      if (rule.productId != null) {
        if (rule.productId != productId) continue;
        priority = _priorityProduct;
      } else if (rule.ingredientKey != null) {
        if (key == null) continue;
        final ruleKey = ingredientKeyOf(rule.ingredientKey!);
        if (_sameName(key, ruleKey)) {
          priority = _priorityIngredient;
        } else if (_mentions(key, ruleKey)) {
          if (ruleKey.length > containedLength) {
            containedLength = ruleKey.length;
            contained = [rule];
          } else if (ruleKey.length == containedLength) {
            contained.add(rule);
          }
          continue;
        } else {
          continue;
        }
      } else {
        priority = _priorityCatalog;
      }

      edges.addAll(_edgesOf(rule, priority));
    }

    for (final rule in contained) {
      edges.addAll(_edgesOf(rule, _priorityCatalog));
    }

    return edges;
  }

  List<UnitEdge> _edgesOf(UnitRule rule, int priority) {
    final edge = UnitEdge(
      from: canonicalUnit(rule.fromUnit),
      to: canonicalUnit(rule.toUnit),
      factor: rule.toQty / rule.fromQty,
      isEstimate: rule.isEstimate,
      priority: priority,
    );
    return [edge, edge.inverse];
  }

  /// True si los dos nombres son el mismo ingrediente escrito distinto.
  static bool _sameName(String a, String b) {
    if (a == b) return true;
    final left = a.split(' ');
    final right = b.split(' ');
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (!_sameWord(left[i], right[i])) return false;
    }
    return true;
  }

  /// True si [name] menciona [word] como palabra suelta.
  ///
  /// Suelta, y no en cualquier posición: "sal" no debe cruzarse con "salsa",
  /// que pesan cosas muy distintas.
  static bool _mentions(String name, String word) {
    if (word.isEmpty) return false;
    return name.split(' ').any((part) => _sameWord(part, word));
  }

  static int _cheaperFirst(_Path a, _Path b) => _compare(a.cost, b.cost);

  static int _compare(List<int> a, List<int> b) {
    for (var i = 0; i < a.length && i < b.length; i++) {
      final diff = a[i].compareTo(b[i]);
      if (diff != 0) return diff;
    }
    return 0;
  }
}

class _Path {
  final String unit;
  final double factor;
  final int estimates;
  final int priority;
  final int hops;

  const _Path(this.unit, this.factor, this.estimates, this.priority, this.hops);

  List<int> get cost => [estimates, priority, hops];
}
