import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format/dates.dart';
import '../../../core/rayon.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/elements.dart';
import '../../../core/widgets/page_erreur.dart';
import '../../../core/widgets/page_vide.dart';
import '../../../theme/app_theme.dart';
import '../../boutique/data/boutique_repository.dart';
import '../data/ventes_repository.dart';
import '../domain/commande.dart';
import 'actions_commande.dart';
import 'widgets/commande_tuile.dart';

/// Onglet Commandes : à livrer aujourd'hui, en retard, à venir…
/// ou à une date choisie dans le calendrier.
class CommandesPage extends ConsumerStatefulWidget {
  const CommandesPage({super.key});

  @override
  ConsumerState<CommandesPage> createState() => _CommandesPageState();
}

class _CommandesPageState extends ConsumerState<CommandesPage> {
  FiltreCommandes _filtre = FiltreCommandes.aujourdhui;
  DateTime? _jour;
  String _recherche = '';
  bool _rechercheOuverte = false;

  Future<void> _choisirJour() async {
    final maintenant = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _jour ?? maintenant,
      firstDate: DateTime(2020),
      lastDate: DateTime(maintenant.year + 2),
      helpText: 'Commandes à livrer le…',
    );
    if (d != null) setState(() => _jour = d);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final devise = ref.watch(boutiqueActiveProvider).devise;
    final commandes = ref.watch(commandesRayonProvider);
    final aujourdhui = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        bottom: const BarreRayon(),
        title: _rechercheOuverte
            ? TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _recherche = v),
                decoration: const InputDecoration(
                    hintText: 'Client, téléphone ou article', border: InputBorder.none,
                    enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                    filled: false),
              )
            : const Text('Commandes'),
        actions: [
          IconButton(
            tooltip: _rechercheOuverte ? 'Fermer la recherche' : 'Rechercher',
            icon: Icon(_rechercheOuverte ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _rechercheOuverte = !_rechercheOuverte;
              _recherche = '';
            }),
          ),
          IconButton(
            tooltip: 'Choisir une date',
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: _choisirJour,
          ),
          BoutonAjout(libelle: 'Commande', tooltip: 'Nouvelle commande', onPressed: () => context.push(Routes.nouvelleCommande)),
        ],
      ),
      body: commandes.when(
        skipLoadingOnRefresh: true,
        loading: () => const ListeSquelette(avecResume: false, avecFiltres: true),
        error: (e, _) => PageErreur(
            erreur: e, onReessayer: () => ref.invalidate(commandesProvider)),
        data: (toutes) {
          final comptes = compterCommandes(toutes, aujourdhui);
          final liste = filtrerCommandes(toutes,
              aujourdhui: aujourdhui, filtre: _filtre, jour: _jour, recherche: _recherche);
          final aucune = !toutes.any((c) => c.estCommande);
          return RefreshIndicator(
            onRefresh: () => ref.refresh(commandesProvider.future),
            child: CustomScrollView(slivers: [
              SliverToBoxAdapter(
                child: RangeeFiltres(children: [
                  if (_jour != null)
                    InputChip(
                      label: Text('Le ${FormatDate.relatif(_jour!)}'),
                      avatar: const Icon(Icons.event, size: 16),
                      selected: true,
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      onPressed: _choisirJour,
                      onDeleted: () => setState(() => _jour = null),
                      deleteButtonTooltipMessage: 'Retirer la date',
                    ),
                  for (final f in FiltreCommandes.values)
                    FiltrePastille(
                      libelle: f.libelle,
                      actif: _jour == null && _filtre == f,
                      compte: f == FiltreCommandes.livrees || f == FiltreCommandes.annulees
                          ? null
                          : comptes[f],
                      alerte: f == FiltreCommandes.enRetard,
                      onTap: () => setState(() {
                        _filtre = f;
                        _jour = null;
                      }),
                    ),
                ]),
              ),
              if (aucune)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: PageVide(
                    icone: Icons.inventory_outlined,
                    titre: 'Aucune commande pour l’instant',
                    message: 'Une commande, c’est pour plus tard : tu notes la '
                        'date, le retrait ou la livraison, et tu suis sa préparation.',
                  ),
                )
              else if (liste.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.all(VallySpace.s6),
                  sliver: SliverToBoxAdapter(
                    child: Column(children: [
                      Icon(Icons.event_available, size: 32,
                          color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(height: VallySpace.s2),
                      Text(_messageVide(),
                          textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                    ]),
                  ),
                )
              else
                for (final MapEntry(key: jour, value: groupe)
                    in grouperParJour(liste, (c) => c.dateLivraison ?? c.date).entries)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: VallySpace.s4),
                    sliver: SliverList.list(children: [
                      EnTeteGroupe(
                        titre: FormatDate.titreJour(jour, aujourdhui: aujourdhui),
                        alerte: groupe.any((c) => c.estEnRetard(aujourdhui)),
                        detail: Text(
                            '${groupe.length} commande${groupe.length > 1 ? 's' : ''}'),
                      ),
                      for (final c in groupe) ...[
                        CommandeCarte(
                          commande: c,
                          devise: devise,
                          aujourdhui: aujourdhui,
                          onTap: () => context.push(Routes.commande(c.id)),
                          onAvancer: () {
                            final s = statutSuivant(c.statutLivraison);
                            if (s != null) changerStatut(context, ref, c, s);
                          },
                        ),
                        const SizedBox(height: VallySpace.s2),
                      ],
                    ]),
                  ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ]),
          );
        },
      ),
    );
  }

  String _messageVide() {
    if (_jour != null) return 'Aucune commande à livrer ce jour-là.';
    return switch (_filtre) {
      FiltreCommandes.aujourdhui => 'Rien à livrer aujourd’hui.',
      FiltreCommandes.enRetard => 'Aucune commande en retard.',
      FiltreCommandes.aVenir => 'Aucune commande à venir.',
      FiltreCommandes.livrees => 'Aucune commande livrée.',
      FiltreCommandes.annulees => 'Aucune commande annulée.',
    };
  }
}
