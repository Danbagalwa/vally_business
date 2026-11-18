import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format/montant.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/elements.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/theme_mode.dart';
import '../../boutique/data/boutique_repository.dart';
import '../../clients/data/clients_repository.dart';
import '../../clients/presentation/clients_page.dart';
import '../../stock/data/stock_repository.dart';
import '../../ventes/data/ventes_repository.dart';
import '../../ventes/domain/commande.dart';
import '../../ventes/presentation/actions_commande.dart';
import '../../ventes/presentation/widgets/commande_tuile.dart';
import '../domain/resume_jour.dart';

/// Accueil : l'essentiel du jour en un coup d'œil.
class AccueilPage extends ConsumerWidget {
  const AccueilPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final boutique = ref.watch(boutiqueActiveProvider);
    final devise = boutique.devise;
    final aujourdhui = DateTime.now();
    final commandes = ref.watch(commandesProvider).value ?? const <Commande>[];
    final clients = ref.watch(clientsResumeProvider).value ?? const [];
    final articles = ref.watch(articlesProvider).value ?? const [];

    final jour = ResumePeriode.du(commandes, (d) => _memeJour(d, aujourdhui));
    final mois = ResumePeriode.du(
        commandes, (d) => d.year == aujourdhui.year && d.month == aujourdhui.month);
    final aLivrer = filtrerCommandes(commandes,
        aujourdhui: aujourdhui, filtre: FiltreCommandes.aujourdhui);
    final enRetard = filtrerCommandes(commandes,
        aujourdhui: aujourdhui, filtre: FiltreCommandes.enRetard);
    final debiteurs = clients.where((c) => c.doit).toList()
      ..sort((a, b) => b.totalDu.compareTo(a.totalDu));
    final bientotEpuises = articles.where((a) => a.stockFaible || a.epuise).length;

    Future<void> rafraichir() async {
      ref.invalidate(commandesProvider);
      ref.invalidate(articlesProvider);
      await ref.read(commandesProvider.future);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(boutique.nom),
        actions: [
          IconButton(
            tooltip: 'Statistiques',
            icon: const Icon(Icons.insights_outlined),
            onPressed: () => context.push(Routes.statistiques),
          ),
          const BoutonTheme(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: rafraichir,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // ─── Carte héro : l'essentiel du jour ───
            _CarteHero(
              date: aujourdhui,
              jour: jour,
              mois: mois,
              aLivrer: aLivrer.length + enRetard.length,
              devise: devise,
              onLivraisons: () => context.go(Routes.commandes),
              onMois: () => context.push(Routes.statistiques),
            ),

            // ─── Livraisons ───
            const SizedBox(height: VallySpace.s6),
            EnTeteSection(
              'À livrer aujourd’hui',
              action: 'Commandes',
              onAction: () => context.go(Routes.commandes),
            ),
            if (enRetard.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: VallySpace.s2),
                child: _Alerte(
                  texte: '${enRetard.length} commande${enRetard.length > 1 ? 's' : ''} en retard',
                  onTap: () => context.go(Routes.commandes),
                ),
              ),
            if (aLivrer.isEmpty)
              Text('Rien à livrer aujourd’hui.', style: theme.textTheme.bodyMedium)
            else
              for (final c in aLivrer.take(3)) ...[
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

            // ─── Dettes ───
            const SizedBox(height: VallySpace.s4),
            EnTeteSection(
              'Ils te doivent',
              action: debiteurs.isEmpty ? null : 'Tout voir',
              onAction: () => context.push('${Routes.clients}?filtre=dettes'),
            ),
            if (debiteurs.isEmpty)
              Text('Personne ne te doit rien.', style: theme.textTheme.bodyMedium)
            else
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(children: [
                  for (final (i, c) in debiteurs.take(3).indexed) ...[
                    if (i > 0) const Divider(indent: 68),
                    ClientTuile(
                      client: c,
                      devise: devise,
                      onTap: () => context.push(Routes.client(c.id)),
                    ),
                  ],
                ]),
              ),

            // ─── Stock ───
            if (bientotEpuises > 0) ...[
              const SizedBox(height: VallySpace.s6),
              _Alerte(
                texte: '$bientotEpuises article${bientotEpuises > 1 ? 's' : ''} épuisé'
                    '${bientotEpuises > 1 ? 's' : ''} ou presque',
                icone: Icons.inventory_2_outlined,
                onTap: () => context.go(Routes.stock),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static bool _memeJour(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

}

/// Carte héro : dégradé de marque, logo en filigrane, ventes du jour en
/// grand, et la tuile qui demande une action (à livrer) mise en avant.
class _CarteHero extends StatelessWidget {
  const _CarteHero({
    required this.date,
    required this.jour,
    required this.mois,
    required this.aLivrer,
    required this.devise,
    required this.onLivraisons,
    required this.onMois,
  });

  final DateTime date;
  final ResumePeriode jour;
  final ResumePeriode mois;
  final int aLivrer;
  final Devise devise;
  final VoidCallback onLivraisons;
  final VoidCallback onMois;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vally = theme.extension<VallyColors>()!;
    const blanc = Colors.white;
    final blanc80 = blanc.withValues(alpha: 0.8);
    final tabulaires = const [FontFeature.tabularFigures()];

    Widget sousBloc({required String titre, required String valeur, VoidCallback? onTap, bool action = false}) {
      final fond = action ? vally.heroAction : blanc.withValues(alpha: 0.12);
      final encre = action ? vally.heroSurAction : blanc;
      return Expanded(
        child: Material(
          color: fond,
          borderRadius: BorderRadius.circular(VallyRadius.r14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(titre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: action ? encre : blanc80, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(valeur,
                      style: theme.textTheme.titleSmall?.copyWith(
                          color: encre, fontWeight: FontWeight.w800, fontFeatures: tabulaires)),
                ),
              ]),
            ),
          ),
        ),
      );
    }

    final benefice = jour.benefice;
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
          BoxShadow(
            color: vally.heroDebut.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(children: [
        // Logo en filigrane, débordant du coin haut-droit.
        Positioned(
          top: -40,
          right: -40,
          child: ExcludeSemantics(
            child: Opacity(
              opacity: 0.09,
              child: Image.asset('assets/icon/app_icon_monochrome.png',
                  width: 210, height: 210, color: blanc),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(DateFormat('EEEE d MMMM', 'fr').format(date).toUpperCase(),
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: blanc80, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
            const SizedBox(height: 8),
            Text('Vendu aujourd’hui', style: theme.textTheme.bodySmall?.copyWith(color: blanc80)),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                FormatMontant.formater(jour.totalVendu, devise),
                style: theme.textTheme.displaySmall?.copyWith(
                    color: blanc, fontSize: 32, letterSpacing: -1, fontFeatures: tabulaires),
              ),
            ),
            Text(
              '${jour.nbVentes} vente${jour.nbVentes > 1 ? 's' : ''}'
              '${benefice.abs() >= 0.005 ? ' · bénéfice ${FormatMontant.formater(benefice.abs(), devise, sens: benefice > 0 ? SensMontant.positif : SensMontant.negatif)}' : ''}',
              style: theme.textTheme.bodySmall?.copyWith(color: blanc80, fontFeatures: tabulaires),
            ),
            const SizedBox(height: 14),
            Row(children: [
              sousBloc(
                titre: 'Vendu ce mois-ci',
                valeur: FormatMontant.formater(mois.totalVendu, devise),
                onTap: onMois,
              ),
              const SizedBox(width: 8),
              sousBloc(
                titre: aLivrer > 0 ? 'À livrer' : 'Livraisons',
                valeur: aLivrer > 0
                    ? '$aLivrer commande${aLivrer > 1 ? 's' : ''}'
                    : 'Rien aujourd’hui',
                onTap: onLivraisons,
                action: aLivrer > 0,
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _Alerte extends StatelessWidget {
  const _Alerte({required this.texte, required this.onTap, this.icone = Icons.warning_amber_rounded});

  final String texte;
  final VoidCallback onTap;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vally = theme.extension<VallyColors>()!;
    return Material(
      color: vally.attention.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(VallyRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(VallyRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            Icon(icone, size: 18, color: vally.attention),
            const SizedBox(width: 8),
            Expanded(
              child: Text(texte,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: vally.attention, fontWeight: FontWeight.w600)),
            ),
            Icon(Icons.chevron_right, size: 18, color: vally.attention),
          ]),
        ),
      ),
    );
  }
}
