import 'package:intl/intl.dart';

final _clpFmt = NumberFormat.currency(
  locale: 'es_CL',
  symbol: '\$',
  decimalDigits: 0,
);

/// Formatea un valor como pesos chilenos: $1.234.567
String clp(double v) => _clpFmt.format(v.round());
