import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../providers/meal_planning_provider.dart';
import '../providers/notification_service.dart';
import '../models/meal_category.dart';
import '../../../shared/widgets/empty_state.dart';

const _uuid = Uuid();

const List<String> _dayNames = [
  '', 'Lunes', 'Martes', 'Miércoles', 'Jueves',
  'Viernes', 'Sábado', 'Domingo',
];

const List<Color> _colorOptions = [
  Color(0xFF4CAF50), Color(0xFF2196F3), Color(0xFFFF9800),
  Color(0xFFE91E63), Color(0xFF9C27B0), Color(0xFF00BCD4),
  Color(0xFF795548), Color(0xFF607D8B), Color(0xFFF44336),
  Color(0xFF3F51B5),
];

class ManageCategoriesScreen extends ConsumerWidget {
  const ManageCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(mealCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorías de Comida'),
      ),
      body: categoriesAsync.when(
        data: (categories) => categories.isEmpty
            ? EmptyState(
                icon: Icons.category_outlined,
                title: 'Sin categorías',
                actionLabel: 'Agregar categoría',
                onAction: () =>
                    _showCategoryDialog(context, ref),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: categories.length,
                itemBuilder: (_, i) => _CategoryCard(
                  category: categories[i],
                  onEdit: () =>
                      _showCategoryDialog(context, ref, category: categories[i]),
                  onDelete: categories[i].isCustom
                      ? () => _confirmDelete(context, ref, categories[i])
                      : null,
                ),
              ),
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showCategoryDialog(BuildContext context, WidgetRef ref,
      {MealCategory? category}) async {
    await showDialog(
      context: context,
      builder: (ctx) => _CategoryDialog(
        category: category,
        onSave: (updated) async {
          if (category == null) {
            await ref
                .read(mealCategoriesProvider.notifier)
                .addCategory(updated);
          } else {
            await ref
                .read(mealCategoriesProvider.notifier)
                .updateCategory(updated);
          }
        },
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, MealCategory category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: Text('¿Eliminar "${category.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref
          .read(mealCategoriesProvider.notifier)
          .deleteCategory(category.id);
    }
  }
}

class _CategoryCard extends StatelessWidget {
  final MealCategory category;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const _CategoryCard(
      {required this.category, required this.onEdit, this.onDelete});

  Color _parseColor(String? hex) {
    if (hex == null) return Colors.grey;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(category.color);
    final days = category.daysOfWeek
        .map((d) => d >= 1 && d <= 7 ? _dayNames[d].substring(0, 2) : '')
        .join(', ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(40),
          child: Icon(Icons.restaurant, color: color),
        ),
        title: Text(category.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (category.defaultTime != null)
              Text('Hora: ${category.defaultTime}',
                  style: const TextStyle(fontSize: 12)),
            if (days.isNotEmpty)
              Text('Días: $days', style: const TextStyle(fontSize: 12)),
            if (category.notificationEnabled)
              Text(
                'Notificación: ${category.notificationMinutesBefore} min antes',
                style: TextStyle(
                    fontSize: 12, color: Colors.blue.shade600),
              ),
          ],
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: onEdit),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: Colors.red),
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryDialog extends StatefulWidget {
  final MealCategory? category;
  final Future<void> Function(MealCategory) onSave;

  const _CategoryDialog({this.category, required this.onSave});

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _timeCtrl;
  late TextEditingController _minutesCtrl;
  Color _selectedColor = _colorOptions.first;
  bool _notificationEnabled = false;
  final List<int> _selectedDays = [];

  @override
  void initState() {
    super.initState();
    final cat = widget.category;
    _nameCtrl = TextEditingController(text: cat?.name ?? '');
    _timeCtrl = TextEditingController(text: cat?.defaultTime ?? '');
    _minutesCtrl = TextEditingController(
        text: cat?.notificationMinutesBefore.toString() ?? '15');
    _notificationEnabled = cat?.notificationEnabled ?? false;
    _selectedDays.addAll(cat?.daysOfWeek ?? []);

    if (cat?.color != null) {
      try {
        _selectedColor = Color(
            int.parse(cat!.color.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _timeCtrl.dispose();
    _minutesCtrl.dispose();
    super.dispose();
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.category == null
          ? 'Nueva Categoría'
          : 'Editar Categoría'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration:
                  const InputDecoration(labelText: 'Nombre *'),
              textCapitalization: TextCapitalization.words,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _timeCtrl,
              decoration: const InputDecoration(
                labelText: 'Horario predeterminado (HH:mm)',
                hintText: '08:00',
              ),
              keyboardType: TextInputType.datetime,
            ),
            const SizedBox(height: 12),
            // Color selector
            const Text('Color:',
                style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _colorOptions
                  .map((color) => GestureDetector(
                        onTap: () =>
                            setState(() => _selectedColor = color),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: _selectedColor == color
                                ? Border.all(
                                    color: Colors.black,
                                    width: 2.5)
                                : null,
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            // Days
            const Text('Días activos:',
                style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: List.generate(7, (i) {
                final day = i + 1;
                final dayName = _dayNames[day].substring(0, 2);
                return FilterChip(
                  label: Text(dayName),
                  selected: _selectedDays.contains(day),
                  onSelected: (sel) => setState(() => sel
                      ? _selectedDays.add(day)
                      : _selectedDays.remove(day)),
                );
              }),
            ),
            const SizedBox(height: 12),
            // Notification
            Row(
              children: [
                const Expanded(
                    child: Text('Activar notificación')),
                Switch(
                  value: _notificationEnabled,
                  onChanged: (v) {
                    setState(() => _notificationEnabled = v);
                    if (v) NotificationService.requestPermissions();
                  },
                ),
              ],
            ),
            if (_notificationEnabled) ...[
              TextField(
                controller: _minutesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Minutos antes',
                  suffixText: 'min',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () async {
            if (_nameCtrl.text.trim().isEmpty) return;
            final cat = MealCategory(
              id: widget.category?.id ?? _uuid.v4(),
              name: _nameCtrl.text.trim(),
              defaultTime: _timeCtrl.text.trim().isEmpty
                  ? null
                  : _timeCtrl.text.trim(),
              color: _colorToHex(_selectedColor),
              notificationEnabled: _notificationEnabled,
              notificationMinutesBefore:
                  int.tryParse(_minutesCtrl.text) ?? 15,
              isCustom: widget.category?.isCustom ?? true,
              daysOfWeek: List.from(_selectedDays),
            );
            await widget.onSave(cat);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
