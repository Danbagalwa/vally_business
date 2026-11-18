import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format/montant.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/menu_compte.dart';
import '../../../core/widgets/montant_texte.dart';
import '../../../core/widgets/page_erreur.dart';
import '../../../core/widgets/page_vide.dart';
import '../../../theme/app_theme.dart';
import '../../boutique/data/boutique_repository.dart';
import '../data/ventes_repository.dart';
import '../domain/commande.dart';
import 'widgets/commande_tuile.dart';

/// Onglet Ventes : reste à encaisser, filtres par statut, liste des commandes.
class VentesPage extends ConsumerStatefulWidget {
  const VentesPage({super.key});

  @override
  ConsumerState<VentesPage> createState() => _VentesPageState();
}

class _VentesPageState extends ConsumerState<VentesPage> {
  FiltreVentes _filtre = FiltreVentes.toutes;
  String _recherche = '';

  @override
  Widget build(BuildContext context) {
    final commandes = ref.watch(commandesProvider);
    final devise = ref.watch(boutiqueActiveProvider).devise;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ventes'),
        actions: const [MenuCompte()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.nouvelleVente),
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle vente'),
      ),
      body: commandes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => PageErreur(
          erreur: e,
          onReessayer: () => ref.invalidate(commandesProvider),
        ),
        data: (toutes) {
          if (toutes.isEmpty) {
            return const PageVide(
              icone: Icons.receipt_long_outlined,
              titre: 'Aucune vente pour l’instant',
              message: 'Enregistre ta première vente : choisis les articles, '
                  'ajuste le prix si besoin et note ce que le client a payé.',
            );
          }
          final visibles = filtrerCommandes(toutes,
              filtre: _filtre, recherche: _recherche);
          return RefreshIndicator(
            onRefresh: () => ref.refresh(commandesProvider.future),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                      VallySpace.s4, VallySpace.s2, VallySpace.s4, 0),
                  sliver: SliverList.list(children: [
                    _CarteAEncaisser(commandes: toutes, devise: devise),
                    const SizedBox(height: VallySpace.s4),
                    TextField(
                      onChanged: (v) => setState(() => _recherche = v),
                      decoration: const InputDecoration(
                        hintText: 'Rechercher un client',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: VallySpace.s2),
                  ]),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding:
                          const EdgeInsets.symmetric(horizontal: VallySpace.s4),
                      children: [
                        for (final f in FiltreVentes.values)
                          Padding(
                            padding:
                                const EdgeInsets.only(right: VallySpace.s2),
                            child: FilterChip(
                              label: Text(f.libelle),
                              selected: _filtre == f,
                              showCheckmark: false,
                              onSelected: (_) => setState(() => _filtre = f),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (visibles.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.all(VallySpace.s6),
                    sliver: SliverToBoxAdapter(
                      child: Text('Aucune vente ne correspond.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                        VallySpace.s4, VallySpace.s2, VallySpace.s4, 96),
                    sliver: SliverList.separated(
                      itemCount: visibles.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: VallySpace.s2),
                      itemBuilder: (context, i) => CommandeTuile(
                        commande: visibles[i],
                        devise: devise,
                        onTap: () =>
                            context.push(Routes.commande(visibles[i].id)),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// « Reste à encaisser » : total dû par les clients (ventes non annulées).
class _CarteAEncaisser extends StatelessWidget {
  const _CarteAEncaisser({required this.commandes, required this.devise});

  final List<Commande> commandes;
  final Devise devise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dues = commandes.where((c) => c.aEncaisser).toList();
    final reste = dues.fold<double>(0, (s, c) => s + c.resteAPayer);
    final vally = theme.extension<VallyColors>()!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(VallySpace.s4),
        child: Row(
          children: [
            Icon(reste > 0 ? Icons.timelapse : Icons.check_circle_outline,
                color: reste > 0 ? vally.attention : vally.benefice),
            const SizedBox(width: VallySpace.s4 - VallySpace.s1),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reste à encaisser', style: theme.textTheme.bodySmall),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: reste > 0
                        ? MontantTexte(reste,
                            devise: devise,
                            sens: SensMontant.negatif,
                            style: theme.textTheme.titleMedium?.copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ]))
                        : Text('Tout est encaissé',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(color: vally.benefice)),
                  ),
                ],
              ),
            ),
            if (dues.isNotEmpty)
              Text('${dues.length} vente${dues.length > 1 ? 's' : ''}',
                  style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
