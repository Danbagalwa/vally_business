import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/stock/data/stock_repository.dart';
import '../features/stock/domain/article.dart';
import '../features/ventes/data/ventes_repository.dart';
import '../features/ventes/domain/commande.dart';
import 'widgets/elements.dart';

/// Les deux rayons de la boutique, comptés à part : ventes, bénéfice,
/// stock et dettes se lisent rayon par rayon.
enum Rayon {
  habits('habits', 'Habits', Icons.checkroom_outlined),
  parfums('parfums', 'Parfums', Icons.spa_outlined);

  const Rayon(this.code, this.libelle, this.icone);

  final String code;
  final String libelle;
  final IconData icone;

  /// Valeur absente (base pas encore à jour) : habits.
  static Rayon depuisCode(String? code) => code == 'parfums' ? parfums : habits;
}

const _cle = 'vally.rayon';

/// Rayon affiché dans toute l'appli ; mémorisé sur le téléphone.
class RayonNotifier extends Notifier<Rayon> {
  @override
  Rayon build() {
    _charger();
    return Rayon.habits;
  }

  Future<void> _charger() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final r = prefs.getString(_cle);
      if (r != null) state = Rayon.depuisCode(r);
    } catch (_) {}
  }

  Future<void> choisir(Rayon rayon) async {
    state = rayon;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cle, rayon.code);
    } catch (_) {}
  }
}

final rayonProvider = NotifierProvider<RayonNotifier, Rayon>(RayonNotifier.new);

/// Ventes et commandes du rayon affiché (même état de chargement que
/// commandesProvider : changer de rayon ne recharge rien).
final commandesRayonProvider = Provider<AsyncValue<List<Commande>>>((ref) {
  final rayon = ref.watch(rayonProvider);
  return ref.watch(commandesProvider).whenData((l) => [for (final c in l) if (c.rayon == rayon) c]);
});

/// Articles du rayon affiché.
final articlesRayonProvider = Provider<AsyncValue<List<Article>>>((ref) {
  final rayon = ref.watch(rayonProvider);
  return ref.watch(articlesProvider).whenData((l) => [for (final a in l) if (a.rayon == rayon) a]);
});

/// Bandeau « Habits · Parfums » sous le titre des écrans qui comptent :
/// un toucher fait passer toute l'appli dans l'autre rayon.
class BarreRayon extends ConsumerWidget implements PreferredSizeWidget {
  const BarreRayon({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(46);

  @override
  Widget build(BuildContext context, WidgetRef ref) => const SizedBox(
        height: 46,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: ChoixRayon()),
        ),
      );
}

/// Les deux pastilles « Habits » et « Parfums » (sans marges).
class ChoixRayon extends ConsumerWidget {
  const ChoixRayon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actif = ref.watch(rayonProvider);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (final (i, r) in Rayon.values.indexed) ...[
        if (i > 0) const SizedBox(width: 8),
        FiltrePastille(
          libelle: r.libelle,
          icone: r.icone,
          actif: actif == r,
          onTap: () => ref.read(rayonProvider.notifier).choisir(r),
        ),
      ],
    ]);
  }
}
