import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format/montant.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/delta_texte.dart';
import '../../../core/widgets/elements.dart';
import '../../../core/widgets/montant_texte.dart';
import '../../../core/widgets/page_erreur.dart';
import '../../../theme/app_theme.dart';
import '../../boutique/data/boutique_repository.dart';
import '../../stock/data/stock_repository.dart';
import '../../ventes/data/ventes_repository.dart';
import '../data/tableau_de_bord_repository.dart';
import '../domain/indicateurs.dart';
import '../domain/periode.dart';
import 'widgets/graphique_mensuel.dart';
import 'widgets/selecteur_periode.dart';
import 'widgets/tuile_indicateur.dart';

/// Statistiques : bénéfice de la période et son évolution, indicateurs,
/// courbe mensuelle, catégories, articles, et bilan depuis l'ouverture.
class TableauDeBordPage extends ConsumerWidget {
  const TableauDeBordPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devise = ref.watch(boutiqueActiveProvider).devise;
    final periode = ref.watch(periodeProvider);
    final indicateurs = ref.watch(indicateursPeriodeProvider);
    // La comparaison est facultative : sans elle, pas de pourcentage.
    final precedents = ref.watch(indicateursPrecedentsProvider).value;

    Future<void> rafraichir() async {
      ref.invalidate(commandesProvider);
      ref.invalidate(articlesProvider);
      await ref.read(indicateursPeriodeProvider.future);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Statistiques')),
      body: RefreshIndicator(
        onRefresh: rafraichir,
        child: ListView(
          padding: const EdgeInsets.only(top: 4, bottom: 24),
          children: [
            const SelecteurPeriode(),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: indicateurs.when(
                skipLoadingOnRefresh: true,
                loading: () => const _SqueletteStats(),
                error: (e, _) => PageErreur(
                    erreur: e, onReessayer: () => ref.invalidate(indicateursPeriodeProvider)),
                data: (i) => _BlocPeriode(
                  periode: periode,
                  indicateurs: i,
                  precedents: precedents,
                  devise: devise,
                ),
              ),
            ),
            const Padding(padding: EdgeInsets.fromLTRB(16, 18, 16, 0), child: _BlocGraphique()),
            const Padding(padding: EdgeInsets.fromLTRB(16, 18, 16, 0), child: _BlocArticles()),
            const Padding(padding: EdgeInsets.fromLTRB(16, 18, 16, 0), child: _BlocActuel()),
          ],
        ),
      ),
    );
  }
}

/// Squelette pendant le chargement des indicateurs.
class _SqueletteStats extends StatelessWidget {
  const _SqueletteStats();

  @override
  Widget build(BuildContext context) {
    return const ExcludeSemantics(
      child: Column(children: [
        Squelette(hauteur: 170, rayon: VallyRadius.lg),
        SizedBox(height: 14),
        Row(children: [
          Expanded(child: Squelette(hauteur: 92, rayon: VallyRadius.md)),
          SizedBox(width: 10),
          Expanded(child: Squelette(hauteur: 92, rayon: VallyRadius.md)),
        ]),
        SizedBox(height: 10),
        Row(children: [
          Expanded(child: Squelette(hauteur: 92, rayon: VallyRadius.md)),
          SizedBox(width: 10),
          Expanded(child: Squelette(hauteur: 92, rayon: VallyRadius.md)),
        ]),
      ]),
    );
  }
}

/// Carte héro de la période + tuiles KPI avec leur variation.
class _BlocPeriode extends StatelessWidget {
  const _BlocPeriode({
    required this.periode,
    required this.indicateurs,
    required this.precedents,
    required this.devise,
  });

  final Periode periode;
  final IndicateursPeriode indicateurs;
  final IndicateursPeriode? precedents;
  final Devise devise;

  double? _var(double Function(IndicateursPeriode) champ) =>
      precedents == null ? null : variation(champ(indicateurs), champ(precedents!));

  @override
  Widget build(BuildContext context) {
    final i = indicateurs;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _CarteHeroPeriode(
        periode: periode,
        indicateurs: i,
        variationBenefice: _var((x) => x.benefice),
        devise: devise,
      ),
      const SizedBox(height: 14),
      const EnTeteSection('Indicateurs'),
      RangeeTuiles(
        gauche: TuileIndicateur(
          libelle: 'Total vendu',
          montant: i.chiffreAffaires,
          devise: devise,
          icone: Icons.receipt_long_outlined,
          variation: _var((x) => x.chiffreAffaires),
        ),
        droite: TuileIndicateur(
          libelle: 'Encaissé',
          montant: i.totalEncaisse,
          devise: devise,
          sens: SensMontant.positif,
          icone: Icons.payments_outlined,
          precision: 'avances comprises',
          variation: _var((x) => x.totalEncaisse),
        ),
      ),
      RangeeTuiles(
        gauche: TuileIndicateur(
          libelle: 'Panier moyen',
          montant: i.panierMoyen,
          devise: devise,
          icone: Icons.shopping_bag_outlined,
          variation: _var((x) => x.panierMoyen),
        ),
        droite: TuileIndicateur(
          libelle: 'Pièces vendues',
          valeurTexte: '${i.piecesVendues}',
          devise: devise,
          icone: Icons.checkroom_outlined,
          variation: _var((x) => x.piecesVendues.toDouble()),
        ),
      ),
      RangeeTuiles(
        gauche: TuileIndicateur(
          libelle: 'Reste dû par les clients',
          montant: i.resteDu,
          devise: devise,
          sens: SensMontant.negatif,
          icone: Icons.timelapse,
          variation: _var((x) => x.resteDu),
          bonQuandHausse: false,
        ),
        droite: TuileIndicateur(
          libelle: 'Approvisionné',
          montant: i.totalApprovisionne,
          devise: devise,
          icone: Icons.inventory_2_outlined,
        ),
      ),
      RangeeTuiles(
        gauche: TuileIndicateur(
          libelle: 'Au-dessus du prix habituel',
          montant: i.gainAuDessus,
          devise: devise,
          sens: SensMontant.positif,
          icone: Icons.trending_up,
          variation: _var((x) => x.gainAuDessus),
        ),
        droite: TuileIndicateur(
          libelle: 'Remises accordées',
          montant: i.coutRemises,
          devise: devise,
          sens: SensMontant.negatif,
          icone: Icons.sell_outlined,
          variation: _var((x) => x.coutRemises),
          bonQuandHausse: false,
        ),
      ),
      if (precedents != null)
        NoteInfo('Pourcentages comparés à ${periode.precedente().libelle}.',
            icone: Icons.compare_arrows),
    ]);
  }
}

/// Carte héro : bénéfice de la période (dégradé de marque, logo en filigrane).
class _CarteHeroPeriode extends StatelessWidget {
  const _CarteHeroPeriode({
    required this.periode,
    required this.indicateurs,
    required this.variationBenefice,
    required this.devise,
  });

  final Periode periode;
  final IndicateursPeriode indicateurs;
  final double? variationBenefice;
  final Devise devise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vally = theme.extension<VallyColors>()!;
    const blanc = Colors.white;
    final blanc80 = blanc.withValues(alpha: 0.8);
    const tabulaires = [FontFeature.tabularFigures()];
    final i = indicateurs;
    final marge = i.margePourcent;

    Widget sousBloc(String titre, String valeur) => Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              color: blanc.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(VallyRadius.r14),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(color: blanc80, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(valeur,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: blanc, fontWeight: FontWeight.w800, fontFeatures: tabulaires)),
              ),
            ]),
          ),
        );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(VallyRadius.lg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [vally.heroDebut, vally.heroFin],
        ),
        boxShadow: [
          BoxShadow(color: vally.heroDebut.withValues(alpha: 0.28), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: Stack(children: [
        Positioned(
          top: -40,
          right: -40,
          child: ExcludeSemantics(
            child: Opacity(
              opacity: 0.09,
              child: Image.asset('assets/icon/app_icon_monochrome.png', width: 200, height: 200, color: blanc),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('BÉNÉFICE · ${periode.libelle.toUpperCase()}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: blanc80, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                FormatMontant.formater(i.benefice.abs(), devise,
                    sens: i.benefice > 0
                        ? SensMontant.positif
                        : (i.benefice < 0 ? SensMontant.negatif : SensMontant.neutre)),
                style: theme.textTheme.displaySmall
                    ?.copyWith(color: blanc, fontSize: 32, letterSpacing: -1, fontFeatures: tabulaires),
              ),
            ),
            if (variationBenefice != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: blanc.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(VallyRadius.lg),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  DeltaTexte(variationBenefice, surFonce: true),
                  Flexible(
                    child: Text(' vs période précédente',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(color: blanc80)),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 14),
            Row(children: [
              sousBloc('Ventes', '${i.nbCommandes}'),
              const SizedBox(width: 8),
              sousBloc('Total vendu', FormatMontant.formater(i.chiffreAffaires, devise)),
              const SizedBox(width: 8),
              sousBloc('Marge',
                  marge == null ? '—' : '${marge.round()} %'),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _BlocGraphique extends ConsumerWidget {
  const _BlocGraphique();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devise = ref.watch(boutiqueActiveProvider).devise;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const EnTeteSection('Évolution'),
      ref.watch(commandesProvider).when(
            skipLoadingOnRefresh: true,
            loading: () => const Squelette(hauteur: 260, rayon: VallyRadius.md),
            error: (e, _) => PageErreur(erreur: e, onReessayer: () => ref.invalidate(commandesProvider)),
            data: (commandes) => GraphiqueMensuel(
              points: parMois(commandes, aujourdhui: DateTime.now()),
              devise: devise,
            ),
          ),
    ]);
  }
}

/// Catégories, articles les plus vendus (période) et ceux qui ne partent pas.
class _BlocArticles extends ConsumerWidget {
  const _BlocArticles();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final vally = theme.extension<VallyColors>()!;
    final devise = ref.watch(boutiqueActiveProvider).devise;
    final vendus = ref.watch(articlesVendusProvider);
    final stock = ref.watch(articlesProvider);
    final aujourdhui = DateTime.now();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ...vendus.when(
        skipLoadingOnRefresh: true,
        loading: () => [const Squelette(hauteur: 140, rayon: VallyRadius.md)],
        error: (e, _) => [PageErreur(erreur: e, onReessayer: () => ref.invalidate(articlesVendusProvider))],
        data: (liste) {
          if (liste.isEmpty) {
            return [
              const EnTeteSection('Les plus vendus'),
              const NoteInfo('Aucun article vendu sur cette période.', icone: Icons.checkroom_outlined),
            ];
          }
          final categories = parCategorie(liste);
          final top = liste.take(5).toList();
          return [
            if (categories.length > 1) ...[
              const EnTeteSection('Par catégorie', sousTitre: 'Part du total vendu'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                  child: Column(children: [
                    for (final c in categories)
                      _Barre(
                        titre: c.categorie,
                        detail: '${c.quantite} pièce${c.quantite > 1 ? 's' : ''}',
                        part: c.part,
                        droite: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('${(c.part * 100).round()} %  ',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                          MontantTexte(c.chiffreAffaires, devise: devise, style: theme.textTheme.bodyMedium),
                        ]),
                      ),
                  ]),
                ),
              ),
              const SizedBox(height: 18),
            ],
            const EnTeteSection('Les plus vendus', sousTitre: 'Sur la période choisie'),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                child: Column(children: [
                  for (final (rang, a) in top.indexed)
                    _Barre(
                      rang: rang + 1,
                      titre: a.nom,
                      detail: a.description,
                      part: top.first.quantite == 0 ? 0 : a.quantite / top.first.quantite,
                      droite: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('${a.quantite} vendue${a.quantite > 1 ? 's' : ''}',
                            style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontFeatures: const [FontFeature.tabularFigures()])),
                        MontantTexte(a.benefice.abs(),
                            devise: devise,
                            sens: a.benefice >= 0 ? SensMontant.positif : SensMontant.negatif,
                            style: theme.textTheme.bodySmall),
                      ]),
                    ),
                ]),
              ),
            ),
          ];
        },
      ),
      const SizedBox(height: 18),
      const EnTeteSection('Ne partent pas', sousTitre: 'En stock, aucune vente depuis plus de 30 jours'),
      stock.when(
        skipLoadingOnRefresh: true,
        loading: () => const Squelette(hauteur: 120, rayon: VallyRadius.md),
        error: (e, _) => PageErreur(erreur: e, onReessayer: () => ref.invalidate(articlesProvider)),
        data: (articles) {
          final lents = articlesQuiNePartentPas(articles, aujourdhui: aujourdhui);
          if (lents.isEmpty) {
            return const NoteInfo('Tout ton stock tourne bien.', icone: Icons.check_circle_outline);
          }
          return Card(
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              for (final (i, a) in lents.indexed) ...[
                if (i > 0) const Divider(indent: 62),
                ListTile(
                  leading: TuileIcone(Icons.hourglass_bottom, taille: 34, couleur: vally.attention),
                  title: Text(a.nom, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${a.quantiteRestante} en stock · '
                    '${a.derniereVente == null ? 'jamais vendu' : 'dernière vente'} '
                    'il y a ${joursSansVente(a, aujourdhui)} j',
                  ),
                  trailing: MontantTexte(a.valeurStockRestant, devise: devise, style: theme.textTheme.bodyMedium),
                  onTap: () => context.push(Routes.article(a.id)),
                ),
              ],
            ]),
          );
        },
      ),
    ]);
  }
}

/// Ligne avec barre de proportion (catégorie ou article).
class _Barre extends StatelessWidget {
  const _Barre({required this.titre, required this.part, required this.droite, this.detail, this.rang});

  final String titre;
  final String? detail;
  final double part;
  final Widget droite;
  final int? rang;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vally = theme.extension<VallyColors>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (rang != null) ...[
          SizedBox(
            width: 22,
            child: Text('$rang',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800, color: theme.colorScheme.primary)),
          ),
        ],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(titre,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (detail != null && detail!.isNotEmpty)
                    Text(detail!, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
              const SizedBox(width: 8),
              droite,
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: part.clamp(0, 1),
                minHeight: 6,
                color: vally.graphique,
                backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.06),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// Depuis l'ouverture : bénéfice disponible et valeur du stock.
class _BlocActuel extends ConsumerWidget {
  const _BlocActuel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final devise = ref.watch(boutiqueActiveProvider).devise;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const EnTeteSection('Depuis l’ouverture'),
      ref.watch(indicateursActuelsProvider).when(
            skipLoadingOnRefresh: true,
            loading: () => const Squelette(hauteur: 200, rayon: VallyRadius.md),
            error: (e, _) =>
                PageErreur(erreur: e, onReessayer: () => ref.invalidate(indicateursActuelsProvider)),
            data: (a) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _Ligne('Bénéfice réalisé',
                        MontantTexte(a.beneficeRealise.abs(),
                            devise: devise,
                            sens: a.beneficeRealise >= 0 ? SensMontant.positif : SensMontant.negatif,
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                    _Ligne('dont encaissé (ventes payées)',
                        MontantTexte(a.beneficeEncaisse.abs(), devise: devise, style: theme.textTheme.bodyMedium)),
                    _Ligne('Déjà versé dans Mes dépenses',
                        MontantTexte(a.beneficeVerse, devise: devise, style: theme.textTheme.bodyMedium)),
                    const Divider(height: 20),
                    _Ligne(
                      'Bénéfice disponible',
                      MontantTexte(a.beneficeDisponible.abs(),
                          devise: devise,
                          sens: a.beneficeDisponible >= 0 ? SensMontant.positif : SensMontant.negatif,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      fort: true,
                    ),
                    const SizedBox(height: 10),
                    FilledButton.tonalIcon(
                      onPressed: () => context.push(Routes.depenses),
                      icon: const Icon(Icons.south_west, size: 18),
                      label: const Text('Me verser un bénéfice'),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 10),
              RangeeTuiles(
                gauche: TuileIndicateur(
                  libelle: 'Valeur du stock restant',
                  montant: a.valeurStockRestant,
                  devise: devise,
                  icone: Icons.inventory_2_outlined,
                  precision: '${a.piecesEnStock} pièce${a.piecesEnStock > 1 ? 's' : ''}',
                ),
                droite: TuileIndicateur(
                  libelle: 'Reste dû (toutes ventes)',
                  montant: a.resteDu,
                  devise: devise,
                  sens: SensMontant.negatif,
                  icone: Icons.timelapse,
                ),
              ),
            ]),
          ),
    ]);
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne(this.libelle, this.valeur, {this.fort = false});

  final String libelle;
  final Widget valeur;
  final bool fort;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(
          child: Text(libelle,
              style: fort
                  ? theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)
                  : theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ),
        valeur,
      ]),
    );
  }
}
