import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format/montant.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/montant_texte.dart';
import '../../../core/widgets/page_erreur.dart';
import '../../../theme/app_theme.dart';
import '../../boutique/data/boutique_repository.dart';
import '../../stock/data/stock_repository.dart';
import '../../ventes/data/ventes_repository.dart';
import '../data/tableau_de_bord_repository.dart';
import '../domain/indicateurs.dart';
import 'widgets/graphique_mensuel.dart';
import 'widgets/selecteur_periode.dart';
import 'widgets/tuile_indicateur.dart';

/// Onglet Tableau de bord : indicateurs de la boutique sur une période,
/// bénéfice disponible, stock, graphique mensuel, articles.
class TableauDeBordPage extends ConsumerWidget {
  const TableauDeBordPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final devise = ref.watch(boutiqueActiveProvider).devise;
    final periode = ref.watch(periodeProvider);
    final indicateurs = ref.watch(indicateursPeriodeProvider);

    Future<void> rafraichir() async {
      ref.invalidate(commandesProvider);
      ref.invalidate(articlesProvider);
      await ref.read(indicateursPeriodeProvider.future);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiques'),

      ),
      body: RefreshIndicator(
        onRefresh: rafraichir,
        child: ListView(
          padding: const EdgeInsets.only(top: VallySpace.s2, bottom: VallySpace.s6),
          children: [
            const SelecteurPeriode(),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  VallySpace.s4, VallySpace.s1, VallySpace.s4, VallySpace.s4),
              child: Text(_majuscule(periode.libelle),
                  style: theme.textTheme.bodySmall),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: VallySpace.s4),
              child: indicateurs.when(
                skipLoadingOnRefresh: true,
                loading: () => const Padding(
                  padding: EdgeInsets.all(VallySpace.s6),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => PageErreur(
                  erreur: e,
                  onReessayer: () => ref.invalidate(indicateursPeriodeProvider),
                ),
                data: (i) => _BlocPeriode(indicateurs: i, devise: devise),
              ),
            ),
            const SizedBox(height: VallySpace.s6),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: VallySpace.s4),
              child: _BlocActuel(),
            ),
            const SizedBox(height: VallySpace.s6),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: VallySpace.s4),
              child: _BlocGraphique(),
            ),
            const SizedBox(height: VallySpace.s6),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: VallySpace.s4),
              child: _BlocArticles(),
            ),
          ],
        ),
      ),
    );
  }

  static String _majuscule(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

/// Bénéfice (chiffre héros) + tuiles de la période.
class _BlocPeriode extends StatelessWidget {
  const _BlocPeriode({required this.indicateurs, required this.devise});

  final IndicateursPeriode indicateurs;
  final Devise devise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final i = indicateurs;
    final sensBenefice = i.benefice > 0
        ? SensMontant.positif
        : (i.benefice < 0 ? SensMontant.negatif : SensMontant.neutre);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(VallySpace.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bénéfice réalisé', style: theme.textTheme.bodySmall),
                const SizedBox(height: VallySpace.s1),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: MontantTexte(i.benefice.abs(),
                      devise: devise,
                      sens: sensBenefice,
                      style: theme.textTheme.displaySmall),
                ),
                const SizedBox(height: VallySpace.s1),
                Text(
                  i.nbCommandes == 0
                      ? 'Aucune vente sur cette période'
                      : '${i.nbCommandes} vente${i.nbCommandes > 1 ? 's' : ''} · '
                          '${i.piecesVendues} pièce${i.piecesVendues > 1 ? 's' : ''} vendue${i.piecesVendues > 1 ? 's' : ''}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: VallySpace.s2),
        RangeeTuiles(
          gauche: TuileIndicateur(
            libelle: 'Total vendu',
            montant: i.chiffreAffaires,
            devise: devise,
            icone: Icons.receipt_long_outlined,
          ),
          droite: TuileIndicateur(
            libelle: 'Encaissé',
            montant: i.totalEncaisse,
            devise: devise,
            sens: SensMontant.positif,
            icone: Icons.payments_outlined,
          ),
        ),
        const SizedBox(height: VallySpace.s2),
        RangeeTuiles(
          gauche: TuileIndicateur(
            libelle: 'Reste dû par les clients',
            montant: i.resteDu,
            devise: devise,
            sens: SensMontant.negatif,
            icone: Icons.timelapse,
          ),
          droite: TuileIndicateur(
            libelle: 'Approvisionné',
            montant: i.totalApprovisionne,
            devise: devise,
            icone: Icons.inventory_2_outlined,
          ),
        ),
        const SizedBox(height: VallySpace.s2),
        RangeeTuiles(
          gauche: TuileIndicateur(
            libelle: 'Au-dessus du prix habituel',
            montant: i.gainAuDessus,
            devise: devise,
            sens: SensMontant.positif,
            icone: Icons.trending_up,
          ),
          droite: TuileIndicateur(
            libelle: 'Remises accordées',
            montant: i.coutRemises,
            devise: devise,
            sens: SensMontant.negatif,
            icone: Icons.sell_outlined,
          ),
        ),
      ],
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
    return ref.watch(indicateursActuelsProvider).when(
          skipLoadingOnRefresh: true,
          loading: () => const SizedBox(
              height: 120, child: Center(child: CircularProgressIndicator())),
          error: (e, _) => PageErreur(
            erreur: e,
            onReessayer: () => ref.invalidate(indicateursActuelsProvider),
          ),
          data: (a) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Depuis l’ouverture', style: theme.textTheme.titleMedium),
              const SizedBox(height: VallySpace.s2),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(VallySpace.s4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Ligne('Bénéfice réalisé',
                          MontantTexte(a.beneficeRealise.abs(),
                              devise: devise,
                              sens: a.beneficeRealise >= 0
                                  ? SensMontant.positif
                                  : SensMontant.negatif)),
                      _Ligne('Déjà versé dans Mes dépenses',
                          MontantTexte(a.beneficeVerse, devise: devise)),
                      const Divider(height: VallySpace.s4),
                      _Ligne(
                        'Bénéfice disponible',
                        MontantTexte(a.beneficeDisponible.abs(),
                            devise: devise,
                            sens: a.beneficeDisponible >= 0
                                ? SensMontant.positif
                                : SensMontant.negatif,
                            style: theme.textTheme.titleMedium),
                      ),
                      const SizedBox(height: VallySpace.s2),
                      OutlinedButton.icon(
                        onPressed: () => context.push(Routes.depenses),
                        icon: const Icon(Icons.account_balance_wallet_outlined),
                        label: const Text('Me verser un bénéfice'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: VallySpace.s2),
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
            ],
          ),
        );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne(this.libelle, this.valeur);

  final String libelle;
  final Widget valeur;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: VallySpace.s1),
        child: Row(children: [
          Expanded(
              child: Text(libelle, style: Theme.of(context).textTheme.bodyMedium)),
          valeur,
        ]),
      );
}

class _BlocGraphique extends ConsumerWidget {
  const _BlocGraphique();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devise = ref.watch(boutiqueActiveProvider).devise;
    return ref.watch(commandesProvider).when(
          skipLoadingOnRefresh: true,
          loading: () => const SizedBox(
              height: 240, child: Center(child: CircularProgressIndicator())),
          error: (e, _) => PageErreur(
            erreur: e,
            onReessayer: () => ref.invalidate(commandesProvider),
          ),
          data: (commandes) => GraphiqueMensuel(
            points: parMois(commandes, aujourdhui: DateTime.now()),
            devise: devise,
          ),
        );
  }
}

/// Les plus vendus (période) et ceux qui ne partent pas (stock actuel).
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Les plus vendus', style: theme.textTheme.titleMedium),
        Text('Sur la période choisie', style: theme.textTheme.bodySmall),
        const SizedBox(height: VallySpace.s2),
        vendus.when(
          skipLoadingOnRefresh: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => PageErreur(
              erreur: e, onReessayer: () => ref.invalidate(articlesVendusProvider)),
          data: (liste) {
            if (liste.isEmpty) {
              return Text('Aucun article vendu sur cette période.',
                  style: theme.textTheme.bodyMedium);
            }
            final top = liste.take(5).toList();
            final max = top.first.quantite;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(VallySpace.s4),
                child: Column(
                  children: [
                    for (final a in top)
                      _BarreArticle(article: a, max: max, devise: devise),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: VallySpace.s6),
        Text('Ne partent pas', style: theme.textTheme.titleMedium),
        Text('En stock, aucune vente depuis plus de 30 jours',
            style: theme.textTheme.bodySmall),
        const SizedBox(height: VallySpace.s2),
        stock.when(
          skipLoadingOnRefresh: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => PageErreur(
              erreur: e, onReessayer: () => ref.invalidate(articlesProvider)),
          data: (articles) {
            final lents =
                articlesQuiNePartentPas(articles, aujourdhui: aujourdhui);
            if (lents.isEmpty) {
              return Row(children: [
                Icon(Icons.check_circle_outline, size: 18, color: vally.benefice),
                const SizedBox(width: VallySpace.s2),
                Expanded(
                  child: Text('Tout ton stock tourne bien.',
                      style: theme.textTheme.bodyMedium),
                ),
              ]);
            }
            return Card(
              child: Column(
                children: [
                  for (final a in lents)
                    ListTile(
                      leading: Icon(Icons.hourglass_bottom, color: vally.attention),
                      title: Text(a.nom,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '${a.quantiteRestante} en stock · '
                        '${a.derniereVente == null ? 'jamais vendu' : 'dernière vente'} '
                        'il y a ${joursSansVente(a, aujourdhui)} jours',
                      ),
                      trailing: MontantTexte(a.valeurStockRestant,
                          devise: devise, style: theme.textTheme.bodyMedium),
                      onTap: () => context.push(Routes.article(a.id)),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Barre horizontale proportionnelle à la quantité vendue.
class _BarreArticle extends StatelessWidget {
  const _BarreArticle({required this.article, required this.max, required this.devise});

  final ArticleVendu article;
  final int max;
  final Devise devise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vally = theme.extension<VallyColors>()!;
    final part = max == 0 ? 0.0 : article.quantite / max;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: VallySpace.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(article.nom,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            Text('${article.quantite} vendue${article.quantite > 1 ? 's' : ''}',
                style: theme.textTheme.bodySmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ]),
          const SizedBox(height: VallySpace.s1),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: part,
              minHeight: 8,
              color: vally.graphique,
              backgroundColor: theme.colorScheme.outlineVariant,
            ),
          ),
          const SizedBox(height: VallySpace.s1),
          Row(children: [
            Text(article.description, style: theme.textTheme.bodySmall),
            const Spacer(),
            MontantTexte(article.benefice.abs(),
                devise: devise,
                sens: article.benefice >= 0
                    ? SensMontant.positif
                    : SensMontant.negatif,
                style: theme.textTheme.bodySmall),
          ]),
        ],
      ),
    );
  }
}
