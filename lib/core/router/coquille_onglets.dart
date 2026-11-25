import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../rayon.dart';
import '../../features/ventes/domain/commande.dart';

class _Onglet {
  const _Onglet(this.libelle, this.icone, this.iconeActive);

  final String libelle;
  final IconData icone;
  final IconData iconeActive;
}

const _onglets = [
  _Onglet('Accueil', Icons.home_outlined, Icons.home_rounded),
  _Onglet('Ventes', Icons.point_of_sale_outlined, Icons.point_of_sale),
  _Onglet('Commandes', Icons.inventory_2_outlined, Icons.inventory_2),
  _Onglet('Stock', Icons.checkroom_outlined, Icons.checkroom),
  _Onglet('Plus', Icons.more_horiz, Icons.more_horiz),
];

/// Coquille des onglets : barre du bas maison (66 px, pastille animée,
/// badge « à livrer » sur Commandes). Le bouton retour Android ramène
/// d'abord à l'Accueil.
class CoquilleOnglets extends ConsumerWidget {
  const CoquilleOnglets({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _aller(int index) {
    if (index != navigationShell.currentIndex) HapticFeedback.selectionClick();
    navigationShell.goBranch(index,
        // Retaper sur l'onglet actif revient à sa racine.
        initialLocation: index == navigationShell.currentIndex);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commandes = ref.watch(commandesRayonProvider).value ?? const <Commande>[];
    final maintenant = DateTime.now();
    final aTraiter = compterCommandes(commandes, maintenant);
    final aLivrer =
        (aTraiter[FiltreCommandes.aujourdhui] ?? 0) + (aTraiter[FiltreCommandes.enRetard] ?? 0);

    return PopScope(
      canPop: navigationShell.currentIndex == 0,
      onPopInvokedWithResult: (aQuitte, _) {
        if (!aQuitte) _aller(0);
      },
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: BarreOnglets(
          index: navigationShell.currentIndex,
          badges: {2: aLivrer},
          onTap: _aller,
        ),
      ),
    );
  }
}

/// Barre d'onglets maison (aussi utilisée pour les captures d'écran).
class BarreOnglets extends StatelessWidget {
  const BarreOnglets({super.key, required this.index, required this.badges, required this.onTap});

  final int index;
  final Map<int, int> badges;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5))),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 66,
            child: Row(children: [
              for (final (i, o) in _onglets.indexed)
                Expanded(
                  child: _Item(
                    onglet: o,
                    actif: i == index,
                    badge: badges[i] ?? 0,
                    onTap: () => onTap(i),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.onglet, required this.actif, required this.badge, required this.onTap});

  final _Onglet onglet;
  final bool actif;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final couleur = actif ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;
    Widget icone = Icon(actif ? onglet.iconeActive : onglet.icone, size: 22, color: couleur);
    if (badge > 0) {
      icone = Badge(
        label: Text(badge > 9 ? '9+' : '$badge'),
        backgroundColor: scheme.primary,
        textColor: scheme.onPrimary,
        child: icone,
      );
    }
    return Semantics(
      button: true,
      selected: actif,
      label: badge > 0 ? '${onglet.libelle}, $badge à livrer' : onglet.libelle,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            width: actif ? 52 : 40,
            height: 30,
            decoration: BoxDecoration(
              color: actif ? scheme.primary.withValues(alpha: 0.14) : Colors.transparent,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Center(child: icone),
          ),
          const SizedBox(height: 4),
          Text(
            onglet.libelle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10.5,
              fontWeight: actif ? FontWeight.w700 : FontWeight.w500,
              color: couleur,
            ),
          ),
        ]),
      ),
    );
  }
}
