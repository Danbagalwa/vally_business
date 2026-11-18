import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/page_erreur.dart';
import '../data/boutique_repository.dart';
import 'bienvenue_page.dart';

/// N'affiche les onglets que si le compte a une boutique.
/// Sinon : écran de bienvenue (créer sa boutique ou attendre d'être ajouté).
class PorteBoutique extends ConsumerWidget {
  const PorteBoutique({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(boutiqueProvider).when(
          data: (boutique) =>
              boutique == null ? const BienvenuePage() : child,
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (erreur, _) => Scaffold(
            body: PageErreur(
              erreur: erreur,
              onReessayer: () => ref.invalidate(boutiqueProvider),
            ),
          ),
        );
  }
}
