import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format/dates.dart';
import '../../../core/format/montant.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/elements.dart';
import '../../../core/widgets/montant_texte.dart';
import '../../../core/widgets/page_erreur.dart';
import '../../../core/widgets/page_vide.dart';
import '../../../theme/app_theme.dart';
import '../../boutique/data/boutique_repository.dart';
import '../data/ventes_repository.dart';
import '../domain/commande.dart';
import 'widgets/commande_tuile.dart';

/// Onglet Ventes : ventes au comptoir, regroupées par jour.
class VentesPage extends ConsumerStatefulWidget {
  const VentesPage({super.key});

  @override
  ConsumerState<VentesPage> createState() => _VentesPageState();
}

class _VentesPageState extends ConsumerState<VentesPage> {
  FiltreVentes _filtre = FiltreVentes.toutes;
  String _recherche = '';
  bool _rechercheOuverte = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final devise = ref.watch(boutiqueActiveProvider).devise;
    final commandes = ref.watch(commandesProvider);

    return Scaffold(
      appBar: AppBar(
        title: _rechercheOuverte
            ? TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _recherche = v),
                decoration: const InputDecoration(
                    hintText: 'Client ou téléphone', border: InputBorder.none,
                    enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                    filled: false),
              )
            : const Text('Ventes'),
        actions: [
          IconButton(
            tooltip: _rechercheOuverte ? 'Fermer la recherche' : 'Rechercher',
            icon: Icon(_rechercheOuverte ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _rechercheOuverte = !_rechercheOuverte;
              _recherche = '';
            }),
          ),
          BoutonAjout(libelle: 'Vente', tooltip: 'Nouvelle vente', onPressed: () => context.push(Routes.nouvelleVente)),
        ],
      ),
      body: commandes.when(
        skipLoadingOnRefresh: true,
        loading: () => const ListeSquelette(),
        error: (e, _) => PageErreur(
            erreur: e, onReessayer: () => ref.invalidate(commandesProvider)),
        data: (toutes) {
          final ventes = filtrerVentes(toutes, filtre: _filtre, recherche: _recherche);
          final aucune = toutes.every((c) => c.estCommande);
          return RefreshIndicator(
            onRefresh: () => ref.refresh(commandesProvider.future),
            child: CustomScrollView(slivers: [
              SliverToBoxAdapter(
                child: RangeeFiltres(children: [
                  for (final f in FiltreVentes.values)
                    FiltrePastille(
                      libelle: f.libelle,
                      actif: _filtre == f,
                      onTap: () => setState(() => _filtre = f),
                    ),
                ]),
              ),
              if (aucune)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: PageVide(
                    icone: Icons.point_of_sale_outlined,
                    titre: 'Aucune vente pour l’instant',
                    message: 'Une vente, c’est au comptoir : le client paie et '
                        'repart avec ses articles. Pour livrer plus tard, '
                        'crée plutôt une commande.',
                  ),
                )
              else if (ventes.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.all(VallySpace.s6),
                  sliver: SliverToBoxAdapter(
                    child: Text('Aucune vente ne correspond.',
                        textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                  ),
                )
              else
                for (final MapEntry(key: jour, value: liste)
                    in grouperParJour(ventes, (c) => c.date).entries)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: VallySpace.s4),
                    sliver: SliverList.list(children: [
                      EnTeteGroupe(
                        titre: FormatDate.relatif(jour),
                        detail: _TotalJour(ventes: liste, devise: devise),
                      ),
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(children: [
                          for (final (i, v) in liste.indexed) ...[
                            if (i > 0) const Divider(indent: 68),
                            VenteTuile(
                              vente: v,
                              devise: devise,
                              onTap: () => context.push(Routes.vente(v.id)),
                            ),
                          ],
                        ]),
                      ),
                    ]),
                  ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ]),
          );
        },
      ),
    );
  }
}

class _TotalJour extends StatelessWidget {
  const _TotalJour({required this.ventes, required this.devise});

  final List<Commande> ventes;
  final Devise devise;

  @override
  Widget build(BuildContext context) {
    final valides = ventes.where((v) => !v.annulee);
    final total = valides.fold<double>(0, (s, v) => s + v.total);
    final n = valides.length;
    final style = Theme.of(context).textTheme.labelMedium;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text('$n vente${n > 1 ? 's' : ''} · ', style: style),
      MontantTexte(total, devise: devise, style: style),
    ]);
  }
}
