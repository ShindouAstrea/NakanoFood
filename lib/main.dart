import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'core/services/photo_picker_setup.dart';
import 'app.dart';

void main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) FlutterNativeSplash.preserve(widgetsBinding: binding);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  configurePhotoPicker();

  try {
    // isOptional: sin él, un .env ausente o vacío deja a dotenv sin
    // inicializar y cualquier lectura posterior lanza.
    await dotenv.load(fileName: '.env', isOptional: true);
  } catch (_) {
    // En producción web las credenciales vienen de --dart-define
  }

  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  // Nada de lo que sigue puede impedir que se pinte algo: el splash nativo
  // está retenido y solo lo libera la primera pantalla. Si esto lanzara, la
  // app quedaría congelada en el splash para siempre, sin ningún mensaje.
  try {
    if (SupabaseConfig.isConfigured) {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.anonKey,
      );
    }
    await initializeDateFormatting('es', null);
  } catch (e, st) {
    debugPrint('[main] fallo de arranque: $e\n$st');
    // Se sigue adelante: la app arranca en modo local, que es mejor que
    // una pantalla azul eterna.
  }

  runApp(
    const ProviderScope(
      child: NakanoFoodApp(),
    ),
  );
}
