import '../models/recipe.dart';

/// Recetas predefinidas incluidas en la app.
/// Se usan cuando el usuario no tiene recetas guardadas.
/// Los ingredientes no tienen [productId] ya que no conocemos la despensa del usuario.
List<Recipe> buildDefaultRecipes() {
  int stepId = 0;
  int ingId = 0;

  RecipeStep step(String recipeId, int n, String desc) =>
      RecipeStep(id: 'drs_${stepId++}', recipeId: recipeId, stepNumber: n, description: desc);

  RecipeIngredient ing(String recipeId, String name, double qty, String unit) =>
      RecipeIngredient(id: 'dri_${ingId++}', recipeId: recipeId, productName: name, quantity: qty, unit: unit);

  // ── Lomo a lo Pobre ──────────────────────────────────────────────────────
  const r1 = 'dr_lomo_pobre';
  final lomoPobre = Recipe(
    id: r1,
    name: 'Lomo a lo Pobre',
    type: 'Comida Principal',
    description: 'Plato contundente y sabroso: filete de vacuno sobre papas fritas con cebollas caramelizadas y huevos fritos encima.',
    portions: 2,
    prepTime: 15,
    cookTime: 25,
    notes: 'La cebolla debe quedar bien dorada y dulce. Usa fuego alto para el filete para que quede sellado y jugoso por dentro.',
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
    ingredients: [
      ing(r1, 'Filete o asado de tira', 400, 'g'),
      ing(r1, 'Papas', 4, 'unidad'),
      ing(r1, 'Cebollas grandes', 2, 'unidad'),
      ing(r1, 'Huevos', 2, 'unidad'),
      ing(r1, 'Aceite vegetal', 3, 'cucharada'),
      ing(r1, 'Sal y pimienta', 1, 'pizca'),
    ],
    steps: [
      step(r1, 1, 'Pela y corta las papas en bastones. Fríelas en aceite abundante a 170°C por 8–10 minutos hasta que estén doradas y crujientes. Escurre sobre papel absorbente y sazona con sal.'),
      step(r1, 2, 'Mientras se fríen las papas, corta las cebollas en plumas. Cocínalas en una sartén con aceite a fuego medio-bajo, revolviendo ocasionalmente, por 15 minutos hasta que estén bien doradas y dulces.'),
      step(r1, 3, 'Sazona la carne con sal y pimienta. En una sartén bien caliente con un poco de aceite, sella el filete a fuego alto 2–3 minutos por lado para término medio, o al gusto.'),
      step(r1, 4, 'En la misma sartén o en otra, fríe los huevos al gusto (estrellados o con yema líquida).'),
      step(r1, 5, 'Monta el plato: papas fritas de base, encima la carne, cúbrela con las cebollas caramelizadas y corona con los huevos fritos. Sirve de inmediato.'),
    ],
  );

  // ── Pollo al Horno con Papas ─────────────────────────────────────────────
  const r2 = 'dr_pollo_horno';
  final polloHorno = Recipe(
    id: r2,
    name: 'Pollo al Horno con Papas',
    type: 'Comida Principal',
    description: 'Receta familiar clásica. Pollo jugoso marinado en ajo y hierbas, horneado sobre una cama de papas y cebollas caramelizadas.',
    portions: 4,
    prepTime: 20,
    cookTime: 60,
    notes: 'Para piel más crujiente, deja el pollo sin tapar los últimos 15 minutos de cocción.',
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
    ingredients: [
      ing(r2, 'Pollo entero o trozos', 1200, 'g'),
      ing(r2, 'Papas medianas', 6, 'unidad'),
      ing(r2, 'Cebolla', 2, 'unidad'),
      ing(r2, 'Ajo', 4, 'unidad'),
      ing(r2, 'Aceite de oliva', 3, 'cucharada'),
      ing(r2, 'Limón', 1, 'unidad'),
      ing(r2, 'Orégano seco', 1, 'cucharada'),
      ing(r2, 'Pimentón ahumado', 1, 'cucharadita'),
      ing(r2, 'Sal y pimienta', 1, 'pizca'),
    ],
    steps: [
      step(r2, 1, 'Mezcla el aceite de oliva, ajo machacado, jugo de limón, orégano, pimentón, sal y pimienta para hacer la marinada.'),
      step(r2, 2, 'Frota el pollo con la marinada por todos lados, incluyendo bajo la piel. Deja reposar al menos 30 minutos (o toda la noche en el refrigerador).'),
      step(r2, 3, 'Precalienta el horno a 200°C. Pela y corta las papas en gajos. Corta las cebollas en plumas.'),
      step(r2, 4, 'En una fuente de horno, coloca las papas y cebollas como base. Sazona con sal, aceite y orégano.'),
      step(r2, 5, 'Coloca el pollo encima de las verduras. Cubre con papel aluminio.'),
      step(r2, 6, 'Hornea 45 minutos tapado. Destapa y cocina 15 minutos más hasta que el pollo esté dorado y las papas blandas.'),
    ],
  );

  // ── Churrasco Italiano ───────────────────────────────────────────────────
  const r3 = 'dr_churrasco';
  final churrascoItaliano = Recipe(
    id: r3,
    name: 'Churrasco Italiano',
    type: 'Snack',
    description: 'El sándwich chileno más popular. Bistec fino en pan marraqueta con palta cremosa, tomate y mayonesa. Rápido, contundente y delicioso.',
    portions: 2,
    prepTime: 10,
    cookTime: 10,
    notes: 'El secreto está en golpear bien la carne para que quede muy delgada y se cocine rápido. La palta debe estar madura.',
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
    ingredients: [
      ing(r3, 'Filete o posta negra', 300, 'g'),
      ing(r3, 'Pan marraqueta', 2, 'unidad'),
      ing(r3, 'Palta madura', 1, 'unidad'),
      ing(r3, 'Tomate', 1, 'unidad'),
      ing(r3, 'Mayonesa', 2, 'cucharada'),
      ing(r3, 'Sal y pimienta', 1, 'pizca'),
      ing(r3, 'Aceite vegetal', 1, 'cucharada'),
    ],
    steps: [
      step(r3, 1, 'Corta la carne en filetes finos y aplánalos con el mazo de cocina hasta que queden muy delgados. Sazona con sal y pimienta.'),
      step(r3, 2, 'Aplasta la palta con un tenedor, sazona con sal y limón si tienes.'),
      step(r3, 3, 'Corta el tomate en rodajas finas.'),
      step(r3, 4, 'Calienta una sartén o plancha a fuego alto con un poco de aceite. Cocina la carne 1 minuto por lado, debe quedar bien dorada.'),
      step(r3, 5, 'Abre el pan y arma el sándwich: mayonesa en la base, carne, tomate y palta encima. Sirve de inmediato.'),
    ],
  );

  // ── Tallarines a la Bolognesa ────────────────────────────────────────────
  const r4 = 'dr_bolognesa';
  final bolognesa = Recipe(
    id: r4,
    name: 'Tallarines a la Bolognesa',
    type: 'Comida Principal',
    description: 'Pasta clásica con salsa de carne molida y tomate, cocinada a fuego lento para que los sabores se intensifiquen.',
    portions: 4,
    prepTime: 10,
    cookTime: 40,
    notes: 'Cuanto más tiempo se cocina la salsa a fuego bajo, más sabrosa queda. Guarda un poco del agua de cocción de la pasta para ajustar la consistencia.',
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
    ingredients: [
      ing(r4, 'Tallarines o espagueti', 400, 'g'),
      ing(r4, 'Carne molida', 400, 'g'),
      ing(r4, 'Tomates maduros o salsa de tomate', 500, 'g'),
      ing(r4, 'Cebolla', 1, 'unidad'),
      ing(r4, 'Ajo', 3, 'unidad'),
      ing(r4, 'Zanahoria', 1, 'unidad'),
      ing(r4, 'Aceite de oliva', 2, 'cucharada'),
      ing(r4, 'Orégano', 1, 'cucharadita'),
      ing(r4, 'Sal y pimienta', 1, 'pizca'),
      ing(r4, 'Queso rallado', 50, 'g'),
    ],
    steps: [
      step(r4, 1, 'Pica finamente la cebolla, el ajo y la zanahoria. Sofríe en aceite de oliva a fuego medio por 5 minutos hasta que estén blandos.'),
      step(r4, 2, 'Sube el fuego y agrega la carne molida. Cocina revolviendo hasta que pierda el color rosado, unos 5–7 minutos.'),
      step(r4, 3, 'Agrega el tomate picado o la salsa de tomate, el orégano, sal y pimienta. Mezcla bien.'),
      step(r4, 4, 'Baja el fuego al mínimo y cocina la salsa tapada por 25–30 minutos, revolviendo ocasionalmente.'),
      step(r4, 5, 'Mientras, cocina la pasta en agua hirviendo con sal según las instrucciones del paquete, hasta que esté al dente. Reserva 1 taza del agua de cocción.'),
      step(r4, 6, 'Escurre la pasta y mézclala con la salsa. Si está muy espesa, agrega un poco del agua reservada. Sirve con queso rallado encima.'),
    ],
  );

  // ── Queque de Plátano ────────────────────────────────────────────────────
  const r5 = 'dr_queque_platano';
  final queque = Recipe(
    id: r5,
    name: 'Queque de Plátano',
    type: 'Pastelería',
    description: 'Queque húmedo y esponjoso ideal para aprovechar los plátanos maduros. Fácil de preparar y perfecto para el desayuno o la once.',
    portions: 8,
    prepTime: 15,
    cookTime: 50,
    notes: 'Cuanto más maduro esté el plátano, más dulce y húmedo quedará el queque. Puedes agregar nueces o chips de chocolate a la mezcla.',
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
    ingredients: [
      ing(r5, 'Plátanos maduros', 3, 'unidad'),
      ing(r5, 'Harina', 200, 'g'),
      ing(r5, 'Azúcar', 150, 'g'),
      ing(r5, 'Huevos', 2, 'unidad'),
      ing(r5, 'Mantequilla derretida', 80, 'g'),
      ing(r5, 'Polvos de hornear', 1, 'cucharadita'),
      ing(r5, 'Esencia de vainilla', 1, 'cucharadita'),
      ing(r5, 'Sal', 1, 'pizca'),
    ],
    steps: [
      step(r5, 1, 'Precalienta el horno a 175°C. Enmantequilla y enharina un molde de queque de 22 cm.'),
      step(r5, 2, 'Aplasta los plátanos con un tenedor hasta obtener un puré. Deben quedar algunos grumos pequeños.'),
      step(r5, 3, 'En un bol, bate los huevos con el azúcar hasta que estén espumosos. Agrega la mantequilla derretida (fría) y la vainilla.'),
      step(r5, 4, 'Incorpora el puré de plátano y mezcla bien.'),
      step(r5, 5, 'Agrega la harina tamizada con los polvos de hornear y la sal. Mezcla solo hasta integrar, sin sobrebatir.'),
      step(r5, 6, 'Vierte en el molde preparado y hornea 45–50 minutos. Comprueba con un palillo: debe salir limpio. Deja enfriar antes de desmoldar.'),
    ],
  );

  // ── Huevos Revueltos con Tomate y Cebolla ────────────────────────────────
  const r6 = 'dr_huevos_revueltos';
  final huevos = Recipe(
    id: r6,
    name: 'Huevos Revueltos con Tomate',
    type: 'Desayuno',
    description: 'Desayuno rápido y nutritivo. Huevos revueltos cremosos con sofrito de cebolla, tomate y orégano. Listo en 10 minutos.',
    portions: 2,
    prepTime: 5,
    cookTime: 10,
    notes: 'El truco para huevos cremosos es cocinarlos a fuego bajo y retirarlos antes de que estén completamente cuajados, ya que siguen cocinándose fuera del fuego.',
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
    ingredients: [
      ing(r6, 'Huevos', 4, 'unidad'),
      ing(r6, 'Tomate', 1, 'unidad'),
      ing(r6, 'Cebolla', 1, 'unidad'),
      ing(r6, 'Aceite de oliva', 1, 'cucharada'),
      ing(r6, 'Orégano', 1, 'pizca'),
      ing(r6, 'Sal y pimienta', 1, 'pizca'),
    ],
    steps: [
      step(r6, 1, 'Pica la cebolla en cubos pequeños y el tomate en cubos medianos, quitándole las semillas.'),
      step(r6, 2, 'Calienta el aceite en una sartén a fuego medio. Sofríe la cebolla 3 minutos hasta que esté translúcida.'),
      step(r6, 3, 'Agrega el tomate y el orégano. Cocina 2 minutos más hasta que el tomate suelte su jugo.'),
      step(r6, 4, 'Bate los huevos con sal y pimienta. Reduce el fuego al mínimo y agrega los huevos a la sartén.'),
      step(r6, 5, 'Revuelve suavemente con una espátula, dibujando ochos lentos, durante 2–3 minutos. Retira del fuego cuando aún estén ligeramente brillantes. Sirve de inmediato.'),
    ],
  );

  // ── Arroz con Leche ──────────────────────────────────────────────────────
  const r7 = 'dr_arroz_leche';
  final arrozLeche = Recipe(
    id: r7,
    name: 'Arroz con Leche',
    type: 'Postre',
    description: 'Postre clásico chileno y latinoamericano. Arroz cremoso cocinado en leche con canela y vainilla, servido frío con canela en polvo.',
    portions: 6,
    prepTime: 5,
    cookTime: 40,
    notes: 'Agítalo ocasionalmente al enfriar para evitar que se forme costra. Queda más rico al día siguiente.',
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
    ingredients: [
      ing(r7, 'Arroz grano corto', 200, 'g'),
      ing(r7, 'Leche entera', 1, 'L'),
      ing(r7, 'Azúcar', 100, 'g'),
      ing(r7, 'Rama de canela', 1, 'unidad'),
      ing(r7, 'Esencia de vainilla', 1, 'cucharadita'),
      ing(r7, 'Canela en polvo', 1, 'cucharadita'),
      ing(r7, 'Cáscara de limón', 1, 'unidad'),
    ],
    steps: [
      step(r7, 1, 'Lava el arroz con agua fría hasta que el agua salga clara. Escurre bien.'),
      step(r7, 2, 'En una olla a fuego medio, calienta la leche con la rama de canela, la cáscara de limón y la vainilla hasta que hierva levemente.'),
      step(r7, 3, 'Agrega el arroz y reduce el fuego a bajo. Cocina revolviendo frecuentemente para evitar que se pegue, unos 30–35 minutos.'),
      step(r7, 4, 'Cuando el arroz esté cremoso y la mezcla haya espesado, agrega el azúcar. Mezcla bien y cocina 5 minutos más.'),
      step(r7, 5, 'Retira la rama de canela y la cáscara de limón. Vierte en moldes o tazones.'),
      step(r7, 6, 'Deja enfriar a temperatura ambiente y luego refrigera. Sirve frío espolvoreado con canela en polvo.'),
    ],
  );

  // ── Ensalada Chilena ─────────────────────────────────────────────────────
  const r8 = 'dr_ensalada_chilena';
  final ensaladaChilena = Recipe(
    id: r8,
    name: 'Ensalada Chilena',
    type: 'Ensalada',
    description: 'La ensalada más popular de Chile. Tomate y cebolla con cilantro, aliñada simplemente con aceite, sal y limón.',
    portions: 4,
    prepTime: 15,
    cookTime: 0,
    notes: 'Lava la cebolla en agua con sal para suavizar su sabor picante antes de mezclar.',
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
    ingredients: [
      ing(r8, 'Tomates maduros', 4, 'unidad'),
      ing(r8, 'Cebolla morada o blanca', 1, 'unidad'),
      ing(r8, 'Cilantro fresco', 1, 'sobre'),
      ing(r8, 'Aceite de oliva', 2, 'cucharada'),
      ing(r8, 'Limón', 1, 'unidad'),
      ing(r8, 'Sal', 1, 'pizca'),
    ],
    steps: [
      step(r8, 1, 'Corta la cebolla en plumas finas. Ponla en un bol con agua y una pizca de sal por 10 minutos para suavizarla. Escurre bien.'),
      step(r8, 2, 'Corta los tomates en gajos o cubos medianos. Colócalos en un bol.'),
      step(r8, 3, 'Agrega la cebolla escurrida y el cilantro picado al gusto.'),
      step(r8, 4, 'Aliña con aceite de oliva, jugo de limón y sal. Mezcla suavemente.'),
      step(r8, 5, 'Sirve de inmediato o deja reposar 5 minutos para que los sabores se integren.'),
    ],
  );

  return [lomoPobre, polloHorno, churrascoItaliano, bolognesa, queque, huevos, arrozLeche, ensaladaChilena];
}
