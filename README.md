# NakanoFood

Aplicación móvil Flutter para gestión de despensa, recetas y planificación alimentaria.  

## Módulos

### 📦 Despensa
- Inventario de productos con categorías (Alimentación, Aseo, Hogar + personalizadas)
- Subcategorías por categoría (Carbohidratos, Lácteos, Proteína, Cereales, Frutas, Vegetales, Aceites)
- Valores nutricionales para productos de alimentación (kcal, proteínas, grasas, azúcares, sodio, etc.)
- Control de cantidad actual vs cantidad a mantener
- Indicador visual de stock bajo
- **Ir de Compras**: Lista organizada por áreas/pasillos, priorizando productos bajos
- Marcar productos comprados con cantidad y precio real
- Historial de compras con comparación de carritos
- Cancelar compra sin actualizar inventario

### 🍳 Recetas
- Gestión de recetas con fotos de referencia
- Tipos: Desayuno, Comida Principal, Cena, Snack, Postre, Pastelería, etc.
- Ingredientes vinculados a la despensa (con autocompletado)
- Pasos de preparación numerados
- Notas opcionales
- Verificación de ingredientes disponibles en despensa
- **Recalcular porciones**: ½x, 1x, 2x, 3x
- Costo estimado basado en precios de despensa
- Edición y eliminación de recetas

### 📅 Planificación Alimentaria
- Calendario mensual con marcadores de días planificados
- Categorías de comida: Desayuno, Almuerzo, Cena, Snack (+ personalizadas)
- Horarios y días activos por categoría
- Planificación por texto o vinculando recetas existentes
- **Notificaciones push** configurables por categoría (minutos antes de la hora)
- Gestión completa de categorías personalizadas

## Tecnologías

- Flutter (Material Design 3)
- Riverpod (estado)
- SQLite / sqflite (base de datos local)
- flutter_local_notifications (notificaciones push)
- table_calendar (calendario)
- image_picker (fotos de recetas)

## Instalación

```bash
flutter pub get
flutter run
```

## Estructura del proyecto

```
lib/
├── main.dart                    # Punto de entrada
├── app.dart                     # Navegación principal (bottom nav)
├── core/
│   ├── database/                # DatabaseHelper + esquema SQLite
│   └── theme/                   # Tema Material 3
├── features/
│   ├── pantry/                  # Módulo Despensa
│   ├── recipes/                 # Módulo Recetas
│   └── meal_planning/           # Módulo Planificación
└── shared/widgets/              # Widgets reutilizables
```
