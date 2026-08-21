/// Lectura de números escritos a mano en un teclado en español.
///
/// `double.tryParse` solo entiende el punto decimal, pero el teclado numérico
/// en es-CL muestra coma. Escribir "2,5" devolvía null y el valor terminaba
/// cayendo en el fallback (1, 0 o nada) sin ningún aviso: el usuario veía
/// "2,5" en el campo y se guardaba otra cosa.
library;

/// Interpreta [text] como decimal aceptando coma o punto.
///
/// Devuelve null si no hay un número reconocible, para que quien llama pueda
/// avisar en vez de guardar un valor inventado.
double? parseDecimal(String? text) {
  if (text == null) return null;
  final cleaned = text.trim().replaceAll(',', '.');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

/// Igual que [parseDecimal] pero para enteros; tolera que se escriba "4,0".
int? parseInteger(String? text) {
  final value = parseDecimal(text);
  if (value == null) return null;
  return value.round();
}

/// Valida un campo de cantidad de formulario.
///
/// Devuelve el texto de error, o null si es válido. Con [required] en false,
/// un campo vacío se considera correcto.
String? validatePositiveNumber(
  String? text, {
  bool required = true,
  bool allowZero = false,
}) {
  final raw = text?.trim() ?? '';
  if (raw.isEmpty) return required ? 'Requerido' : null;

  final value = parseDecimal(raw);
  if (value == null) return 'Número inválido';
  if (value < 0) return 'No puede ser negativo';
  if (!allowZero && value == 0) return 'Debe ser mayor que 0';
  return null;
}

const _accents = {
  'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a',
  'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
  'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
  'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o',
  'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
  'ñ': 'n', 'ç': 'c',
};

/// Normaliza un nombre para compararlo: sin mayúsculas, sin acentos y sin
/// espacios sobrantes.
///
/// Hace falta porque la app es en español y los nombres se escriben a mano en
/// sitios distintos: "Plátano", "platano" y "plátano " deben cruzarse entre sí.
String normalizeName(String value) {
  final lower = value.trim().toLowerCase();
  final buffer = StringBuffer();
  for (final char in lower.split('')) {
    buffer.write(_accents[char] ?? char);
  }
  // Colapsa espacios internos repetidos
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
}

/// Redondea una cantidad al milésimo.
///
/// La aritmética en coma flotante deja restos: descontar 0,2 kg de 3 kg da
/// 2,8000000000000003, y ese número termina guardado en la despensa y escrito
/// en pantalla. Mil es suficiente para gramos y mililitros, que es el detalle
/// más fino que la app maneja.
double roundQuantity(double value) {
  if (!value.isFinite) return 0;
  // Fuera de este rango no hay cantidad de despensa que signifique algo, y
  // multiplicar por mil antes de redondear se saldría del entero de 64 bits.
  if (value.abs() > 1e12) return value.isNegative ? -1e12 : 1e12;
  return (value * 1000).round() / 1000;
}

/// Escribe una cantidad como se lee en es-CL: sin decimales si es entera, con
/// los mínimos necesarios si no, y con coma.
///
/// Va en pareja con [parseDecimal], que acepta de vuelta tanto la coma como el
/// punto: lo que se muestra en un campo se puede volver a leer de ahí.
String formatQuantity(double value) {
  final rounded = roundQuantity(value);
  final text = rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded
          .toStringAsFixed(3)
          .replaceFirst(RegExp(r'0+$'), '');
  return text.replaceAll('.', ',');
}
