import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

/// Hace que `image_picker` use el Android Photo Picker del sistema.
///
/// Por defecto el plugin sigue usando `ACTION_GET_CONTENT`, que en Android 13+
/// obliga a declarar `READ_MEDIA_IMAGES`. Google Play rechaza ese permiso
/// cuando el selector del sistema basta —y aquí basta: solo elegimos una foto
/// puntual para una receta—, así que el manifiesto ya no lo declara y esta
/// llamada es lo que mantiene funcionando la selección de imágenes.
///
/// En el resto de plataformas el `is` falla y no hace nada.
void configurePhotoPicker() {
  final implementation = ImagePickerPlatform.instance;
  if (implementation is ImagePickerAndroid) {
    implementation.useAndroidPhotoPicker = true;
  }
}
