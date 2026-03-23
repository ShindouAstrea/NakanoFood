import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final currentAccent = ref.watch(accentColorProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // ── Avatar ──────────────────────────────────────────────────────
          Center(
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.primary.withAlpha(20),
                    border: Border.all(
                      color: colorScheme.primary.withAlpha(60),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.person_outline_rounded,
                    size: 44,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Invitado',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Inicia sesión para sincronizar tus datos',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withAlpha(120),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Login card (próximamente) ────────────────────────────────────
          _SectionCard(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: colorScheme.tertiary.withAlpha(30),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Próximamente',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.tertiary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Icon(Icons.cloud_sync_outlined,
                        size: 40,
                        color: colorScheme.onSurface.withAlpha(60)),
                    const SizedBox(height: 10),
                    Text(
                      'Sincronización en la nube',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Accede a tus recetas y despensa desde cualquier dispositivo',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withAlpha(120),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.login_rounded),
                        label: const Text('Iniciar sesión'),
                        style: ElevatedButton.styleFrom(
                          disabledBackgroundColor:
                              colorScheme.onSurface.withAlpha(20),
                          disabledForegroundColor:
                              colorScheme.onSurface.withAlpha(80),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Apariencia ───────────────────────────────────────────────────
          const _SectionLabel(label: 'Apariencia'),
          const SizedBox(height: 8),

          // Tema claro / oscuro / sistema
          _SectionCard(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _OptionTitle(
                      icon: Icons.brightness_6_rounded,
                      label: 'Tema',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _ThemeButton(
                          label: 'Sistema',
                          icon: Icons.brightness_auto_rounded,
                          selected: themeMode == ThemeMode.system,
                          onTap: () => ref
                              .read(themeModeProvider.notifier)
                              .setMode(ThemeMode.system),
                        ),
                        const SizedBox(width: 8),
                        _ThemeButton(
                          label: 'Claro',
                          icon: Icons.light_mode_rounded,
                          selected: themeMode == ThemeMode.light,
                          onTap: () => ref
                              .read(themeModeProvider.notifier)
                              .setMode(ThemeMode.light),
                        ),
                        const SizedBox(width: 8),
                        _ThemeButton(
                          label: 'Oscuro',
                          icon: Icons.dark_mode_rounded,
                          selected: themeMode == ThemeMode.dark,
                          onTap: () => ref
                              .read(themeModeProvider.notifier)
                              .setMode(ThemeMode.dark),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Color de énfasis
          _SectionCard(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _OptionTitle(
                      icon: Icons.palette_rounded,
                      label: 'Color de énfasis',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Afecta botones, iconos activos, textos interactivos y más',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withAlpha(110),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Color grid
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: accentOptions.map((opt) {
                        final isSelected =
                            currentAccent.toARGB32() == opt.color.toARGB32();
                        return _ColorSwatch(
                          option: opt,
                          selected: isSelected,
                          onTap: () => ref
                              .read(accentColorProvider.notifier)
                              .setColor(opt.color),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    // Selected color preview
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withAlpha(12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: colorScheme.primary.withAlpha(40)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _selectedName(currentAccent),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '#${colorScheme.primary.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurface.withAlpha(100),
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Acerca de ────────────────────────────────────────────────────
          const _SectionLabel(label: 'Acerca de'),
          const SizedBox(height: 8),
          const _SectionCard(
            children: [
              _InfoTile(
                icon: Icons.info_outline_rounded,
                label: 'Versión',
                value: '1.0.0',
              ),
              Divider(height: 1, indent: 52),
              _InfoTile(
                icon: Icons.restaurant_menu_rounded,
                label: 'NakanoFood',
                value: 'Gestión alimentaria',
              ),
            ],
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  String _selectedName(Color color) {
    for (final opt in accentOptions) {
      if (opt.color.toARGB32() == color.toARGB32()) return opt.name;
    }
    return 'Personalizado';
  }
}

// ── Color swatch ────────────────────────────────────────────────────────────

class _ColorSwatch extends StatelessWidget {
  final AccentOption option;
  final bool selected;
  final VoidCallback onTap;

  const _ColorSwatch({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: option.name,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: option.color,
            shape: BoxShape.circle,
            border: selected
                ? Border.all(
                    color: Theme.of(context).colorScheme.onSurface,
                    width: 2.5,
                  )
                : null,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: option.color.withAlpha(120),
                      blurRadius: 8,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          child: selected
              ? const Icon(Icons.check_rounded,
                  color: Colors.white, size: 20)
              : null,
        ),
      ),
    );
  }
}

// ── Helpers ─────────────────────────────────────────────────────────────────

class _OptionTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  const _OptionTitle({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _ThemeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? colorScheme.primary.withAlpha(20)
                : colorScheme.onSurface.withAlpha(10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? colorScheme.primary
                  : colorScheme.onSurface.withAlpha(30),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 22,
                color: selected
                    ? colorScheme.primary
                    : colorScheme.onSurface.withAlpha(120),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.onSurface.withAlpha(150),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(120),
            ),
          ),
        ],
      ),
    );
  }
}
