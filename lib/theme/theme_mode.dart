import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _cle = 'vally.mode_theme';

/// Mode d'affichage : système par défaut, choix mémorisé sur le téléphone.
class ModeThemeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _charger();
    return ThemeMode.system;
  }

  Future<void> _charger() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_cle);
      final mode = ThemeMode.values.where((m) => m.name == code).firstOrNull;
      if (mode != null) state = mode;
    } catch (_) {
      // Préférence illisible : on reste sur le mode système.
    }
  }

  Future<void> choisir(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cle, mode.name);
    } catch (_) {}
  }
}

final modeThemeProvider =
    NotifierProvider<ModeThemeNotifier, ThemeMode>(ModeThemeNotifier.new);

/// Bouton soleil / lune de l'AppBar : passe en clair ou en sombre
/// (à l'opposé de ce qui est affiché).
class BoutonTheme extends ConsumerWidget {
  const BoutonTheme({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sombre = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: sombre ? 'Passer en mode clair' : 'Passer en mode sombre',
      onPressed: () {
        HapticFeedback.selectionClick();
        ref.read(modeThemeProvider.notifier).choisir(sombre ? ThemeMode.light : ThemeMode.dark);
      },
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (enfant, animation) => RotationTransition(
          turns: Tween<double>(begin: 0.75, end: 1).animate(animation),
          child: FadeTransition(opacity: animation, child: enfant),
        ),
        child: Icon(
          sombre ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          key: ValueKey(sombre),
          size: 21,
        ),
      ),
    );
  }
}
