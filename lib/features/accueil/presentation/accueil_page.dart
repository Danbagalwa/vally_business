import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format/montant.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/elements.dart';
import '../../../core/widgets/montant_texte.dart';
import '../../../theme/app_theme.dart';
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
        ],
      ),
      body: RefreshIndicator(
        onRefresh: rafraichir,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(VallySpace.s4, 0, VallySpace.s4, VallySpace.s6),
          children: [
            Text(_majuscule(DateFormat('EEEE d MMMM', 'fr').format(aujourdhui)),
                style: theme.textTheme.bodySmall),
            const SizedBox(height: VallySpace.s4),

            // ─── Raccourcis ───
            Row(children: [
              Expanded(
                child: _Raccourci(
                  icone: Icons.point_of_sale_outlined,
                  libelle: 'Nouvelle vente',
                  onTap: () => context.push(Routes.nouvelleVente),
                ),
              ),
              const SizedBox(width: VallySpace.s2),
              Expanded(
                child: _Raccourci(
                  icone: Icons.inventory_outlined,
                  libelle: 'Nouvelle commande',
                  onTap: () => context.push(Routes.nouvelleCommande),
                ),
              ),
            ]),
            const SizedBox(height: VallySpace.s6),

            // ─── Aujourd'hui / ce mois ───
            Row(children: [
              Expanded(child: _CarteResume(titre: 'Aujourd’hui', resume: jour, devise: devise)),
              const SizedBox(width: VallySpace.s2),
              Expanded(
                child: _CarteResume(
                  titre: _majuscule(DateFormat('MMMM', 'fr').format(aujourdhui)),
                  resume: mois,
                  devise: devise,
                  onTap: () => context.push(Routes.statistiques),
                ),
              ),
            ]),

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

  static String _majuscule(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _Raccourci extends StatelessWidget {
  const _Raccourci({required this.icone, required this.libelle, required this.onTap});

  final IconData icone;
  final String libelle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(VallyRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(children: [
            Icon(icone, color: theme.colorScheme.onPrimaryContainer, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(libelle,
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: theme.colorScheme.onPrimaryContainer),
                  maxLines: 2),
            ),
          ]),
        ),
      ),
    );
  }
}

class _CarteResume extends StatelessWidget {
  const _CarteResume({required this.titre, required this.resume, required this.devise, this.onTap});

  final String titre;
  final ResumePeriode resume;
  final Devise devise;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = resume;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titre, style: theme.textTheme.labelMedium),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: MontantTexte(r.totalVendu, devise: devise, style: theme.textTheme.titleMedium
                  ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
            ),
            Text('${r.nbVentes} vente${r.nbVentes > 1 ? 's' : ''}', style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(children: [
                Text('Bénéfice ', style: theme.textTheme.bodySmall),
                MontantTexte(r.benefice.abs(),
                    devise: devise,
                    sens: r.benefice > 0
                        ? SensMontant.positif
                        : (r.benefice < 0 ? SensMontant.negatif : SensMontant.neutre),
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
        ),
      ),
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
