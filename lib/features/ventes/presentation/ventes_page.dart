import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format/dates.dart';
import '../../../core/format/montant.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/carnet.dart';
import '../../../core/widgets/elements.dart';
import '../../../core/widgets/page_erreur.dart';
import '../../../core/widgets/page_vide.dart';
import '../../../theme/app_theme.dart';
import '../../boutique/data/boutique_repository.dart';
import '../data/ventes_repository.dart';
import '../domain/commande.dart';
import 'widgets/commande_tuile.dart';

/// Onglet Ventes : le cahier de caisse. Une page par jour, une ligne par
/// vente (heure, client, montant), et le total du jour en bas.
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
        loading: () => const ListeSquelette(avecResume: false, avecFiltres: true),
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
                    child: Text(_messageVide(),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ),
                )
              else
                for (final MapEntry(key: jour, value: liste)
                    in grouperParJour(ventes, (c) => c.date).entries)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: VallySpace.s4),
                    sliver: SliverList.list(children: [
                      EnTeteGroupe(titre: FormatDate.titreJour(jour)),
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(children: [
                          for (final (i, v) in liste.indexed) ...[
                            if (i > 0) const TraitRegistre(),
                            VenteTuile(
                              vente: v,
                              devise: devise,
                              onTap: () => context.push(Routes.vente(v.id)),
                            ),
                          ],
                          ?_piedDuJour(liste, devise),
                        ]),
                      ),
                    ]),
                  ),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ]),
          );
        },
      ),
    );
  }

  /// Bas de la page du jour : le total vendu, ou ce qu'il reste à encaisser
  /// quand on ne regarde que les ventes non payées.
  Widget? _piedDuJour(List<Commande> liste, Devise devise) {
    switch (_filtre) {
      case FiltreVentes.toutes:
        final valides = liste.where((v) => !v.annulee).toList();
        if (valides.isEmpty) return null;
        final n = valides.length;
        return PiedDeCarte(
          libelle: 'Total · $n vente${n > 1 ? 's' : ''}',
          montant: valides.fold<double>(0, (s, v) => s + v.total),
          devise: devise,
        );
      case FiltreVentes.nonPayees:
        return PiedDeCarte(
          libelle: 'Reste à encaisser',
          montant: liste.fold<double>(0, (s, v) => s + v.resteAPayer),
          devise: devise,
          sens: SensMontant.negatif,
        );
      case FiltreVentes.annulees:
        return null;
    }
  }

  String _messageVide() {
    if (_recherche.trim().isNotEmpty) return 'Aucune vente ne correspond à ta recherche.';
    return switch (_filtre) {
      FiltreVentes.toutes => 'Aucune vente ne correspond.',
      FiltreVentes.nonPayees => 'Toutes tes ventes sont payées.',
      FiltreVentes.annulees => 'Aucune vente annulée.',
    };
  }
}
