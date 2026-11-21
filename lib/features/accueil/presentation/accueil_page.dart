import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format/dates.dart';
import '../../../core/format/montant.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/montant_texte.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/theme_mode.dart';
import '../../boutique/data/boutique_repository.dart';
import '../../clients/data/clients_repository.dart';
import '../../clients/domain/client_resume.dart';
import '../../stock/data/stock_repository.dart';
import '../../stock/domain/article.dart';
import '../../ventes/data/ventes_repository.dart';
import '../../ventes/domain/commande.dart';
import '../../ventes/presentation/actions_commande.dart';
import '../domain/resume_jour.dart';

/// Accueil : la boutique te parle — ce que tu as vendu, ce qui t'attend,
/// qui te doit de l'argent. Pas de tableau de bord, un carnet.
class AccueilPage extends ConsumerWidget {
  const AccueilPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boutique = ref.watch(boutiqueActiveProvider);
    final devise = boutique.devise;
    final maintenant = DateTime.now();
    final commandes = ref.watch(commandesProvider).value ?? const <Commande>[];
    final clients = ref.watch(clientsResumeProvider).value ?? const <ClientResume>[];
    final articles = ref.watch(articlesProvider).value ?? const <Article>[];

    final jour = ResumePeriode.du(commandes, (d) => DateUtils.isSameDay(d, maintenant));
    final mois = ResumePeriode.du(
        commandes, (d) => d.year == maintenant.year && d.month == maintenant.month);
    final semaine = ventesParJour(commandes, aujourdhui: maintenant);
    final taches = [
      ...filtrerCommandes(commandes, aujourdhui: maintenant, filtre: FiltreCommandes.enRetard),
      ...filtrerCommandes(commandes, aujourdhui: maintenant, filtre: FiltreCommandes.aujourdhui),
    ];
    final debiteurs = clients.where((c) => c.doit).toList()
      ..sort((a, b) => b.totalDu.compareTo(a.totalDu));
    final totalDu = debiteurs.fold<double>(0, (s, c) => s + c.totalDu);
    final presqueEpuises = articles.where((a) => a.stockFaible || a.epuise).toList();

    Future<void> rafraichir() async {
      ref.invalidate(commandesProvider);
      ref.invalidate(articlesProvider);
      await ref.read(commandesProvider.future);
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: rafraichir,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _EnTete(
                date: maintenant,
                nom: boutique.nom,
                phrase: phraseDuJour(ventes: jour.nbVentes, taches: taches.length),
              ),
              const SizedBox(height: 20),
              _CarteJour(
                jour: jour,
                mois: mois,
                semaine: semaine,
                devise: devise,
                onStatistiques: () => context.push(Routes.statistiques),
              ),

              // ─── À faire ───
              _TitreSection(
                'À faire',
                lien: taches.isEmpty ? null : 'Commandes',
                onLien: () => context.go(Routes.commandes),
              ),
              if (taches.isEmpty)
                const _Calme('Rien à préparer ni à livrer aujourd’hui.')
              else
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(children: [
                    for (final (i, c) in taches.take(4).indexed) ...[
                      if (i > 0) const Divider(indent: 56),
                      _Tache(
                        commande: c,
                        devise: devise,
                        maintenant: maintenant,
                        onOuvrir: () => context.push(Routes.commande(c.id)),
                        onAvancer: () {
                          final s = statutSuivant(c.statutLivraison);
                          if (s != null) changerStatut(context, ref, c, s);
                        },
                      ),
                    ],
                    if (taches.length > 4)
                      _LienBasDeCarte(
                        'Voir les ${taches.length} commandes',
                        onTap: () => context.go(Routes.commandes),
                      ),
                  ]),
                ),

              // ─── On te doit ───
              _TitreSection(
                'On te doit',
                lien: debiteurs.isEmpty ? null : 'Tout voir',
                onLien: () => context.push('${Routes.clients}?filtre=dettes'),
              ),
              if (debiteurs.isEmpty)
                const _Calme('Personne ne te doit d’argent.')
              else
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(children: [
                    for (final (i, c) in debiteurs.take(3).indexed) ...[
                      if (i > 0) const Divider(indent: 16, endIndent: 16),
                      _LigneDette(
                        client: c,
                        devise: devise,
                        onTap: () => context.push(Routes.client(c.id)),
                      ),
                    ],
                    _TotalDettes(
                      total: totalDu,
                      nbClients: debiteurs.length,
                      devise: devise,
                    ),
                  ]),
                ),

              // ─── Stock ───
              if (presqueEpuises.isNotEmpty) ...[
                const SizedBox(height: 28),
                _NoteStock(
                  articles: presqueEpuises,
                  onTap: () => context.go(Routes.stock),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Date, salutation et phrase du jour, avec les deux actions à droite.
class _EnTete extends StatelessWidget {
  const _EnTete({required this.date, required this.nom, required this.phrase});

  final DateTime date;
  final String nom;
  final String phrase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dateTexte = DateFormat('EEEE d MMMM', 'fr').format(date);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Text(
            dateTexte[0].toUpperCase() + dateTexte.substring(1),
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        IconButton(
          tooltip: 'Statistiques',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.bar_chart_rounded, size: 22),
          onPressed: () => context.push(Routes.statistiques),
        ),
        const BoutonTheme(),
      ]),
      Text(
        '${salutation(date)}, $nom',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.headlineSmall?.copyWith(fontSize: 26, height: 1.15, letterSpacing: -0.6),
      ),
      const SizedBox(height: 8),
      _PhraseAvecChiffres(phrase),
    ]);
  }
}

/// La phrase du jour, avec les nombres mis en gras.
class _PhraseAvecChiffres extends StatelessWidget {
  const _PhraseAvecChiffres(this.phrase);

  final String phrase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.bodyLarge?.copyWith(
        color: theme.colorScheme.onSurfaceVariant, height: 1.4);
    final fort = TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w700);
    final morceaux = <InlineSpan>[];
    phrase.splitMapJoin(
      RegExp(r'\d+'),
      onMatch: (m) {
        morceaux.add(TextSpan(text: m[0], style: fort));
        return '';
      },
      onNonMatch: (t) {
        morceaux.add(TextSpan(text: t));
        return '';
      },
    );
    return Text.rich(TextSpan(children: morceaux), style: base);
  }
}

/// Carte « Aujourd'hui » : ce qui est vendu, le bénéfice, le rythme de la
/// semaine, et les totaux de la semaine et du mois.
class _CarteJour extends StatelessWidget {
  const _CarteJour({
    required this.jour,
    required this.mois,
    required this.semaine,
    required this.devise,
    required this.onStatistiques,
  });

  final ResumePeriode jour;
  final ResumePeriode mois;
  final List<(DateTime, double)> semaine;
  final Devise devise;
  final VoidCallback onStatistiques;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final vally = theme.extension<VallyColors>()!;
    final totalSemaine = semaine.fold<double>(0, (s, p) => s + p.$2);
    const tabulaires = [FontFeature.tabularFigures()];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 16, 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Vendu aujourd’hui',
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: FormatMontant.nombre(jour.totalVendu, devise)),
                      TextSpan(
                        text: ' ${devise.code}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600, letterSpacing: 0),
                      ),
                    ]),
                    style: theme.textTheme.displaySmall
                        ?.copyWith(fontSize: 34, height: 1.05, letterSpacing: -1, fontFeatures: tabulaires),
                  ),
                ),
                const SizedBox(height: 6),
                if (jour.benefice.abs() >= 0.005)
                  Text(
                    '${FormatMontant.formater(jour.benefice.abs(), devise, sens: jour.benefice > 0 ? SensMontant.positif : SensMontant.negatif)} '
                    'de bénéfice',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: jour.benefice > 0 ? vally.benefice : vally.attention,
                      fontWeight: FontWeight.w600,
                      fontFeatures: tabulaires,
                    ),
                  )
                else
                  Text('La journée commence.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
              ]),
            ),
            const SizedBox(width: 12),
            _RythmeSemaine(points: semaine),
          ]),
        ),
        Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.6)),
        InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onStatistiques();
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
            child: Row(children: [
              Expanded(child: _Chiffre('7 derniers jours', totalSemaine, devise)),
              Container(width: 1, height: 28, color: scheme.outlineVariant.withValues(alpha: 0.8)),
              const SizedBox(width: 16),
              Expanded(child: _Chiffre('Ce mois-ci', mois.totalVendu, devise)),
              Icon(Icons.chevron_right, size: 20, color: scheme.onSurfaceVariant),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Chiffre extends StatelessWidget {
  const _Chiffre(this.libelle, this.montant, this.devise);

  final String libelle;
  final double montant;
  final Devise devise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(libelle, style: theme.textTheme.bodySmall),
      const SizedBox(height: 2),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: MontantTexte(montant, devise: devise,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
      ),
    ]);
  }
}

/// Sept petites barres : le rythme des ventes de la semaine, aujourd'hui
/// en couleur, les autres jours atténués. Un jour sans vente garde un
/// petit trait, pour qu'on voie qu'il existe.
class _RythmeSemaine extends StatelessWidget {
  const _RythmeSemaine({required this.points});

  final List<(DateTime, double)> points;

  static final _initiale = DateFormat('EEEEE', 'fr');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final max = points.fold<double>(0, (m, p) => p.$2 > m ? p.$2 : m);
    const hauteur = 52.0;
    final dernier = points.length - 1;

    return Semantics(
      label: 'Ventes des 7 derniers jours',
      excludeSemantics: true,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          height: hauteur,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (final (i, p) in points.indexed) ...[
              if (i > 0) const SizedBox(width: 5),
              Container(
                width: 9,
                height: max == 0 ? 3 : (p.$2 / max * hauteur).clamp(3, hauteur),
                decoration: BoxDecoration(
                  color: i == dernier ? scheme.primary : scheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 5),
        Row(children: [
          for (final (i, p) in points.indexed) ...[
            if (i > 0) const SizedBox(width: 5),
            SizedBox(
              width: 9,
              child: Text(
                _initiale.format(p.$1).toUpperCase(),
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 9.5,
                  fontWeight: i == dernier ? FontWeight.w700 : FontWeight.w500,
                  color: i == dernier ? scheme.onSurface : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ]),
      ]),
    );
  }
}

/// Titre de section en phrase (pas en majuscules), lien aligné à droite.
class _TitreSection extends StatelessWidget {
  const _TitreSection(this.titre, {this.lien, this.onLien});

  final String titre;
  final String? lien;
  final VoidCallback? onLien;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 10),
      child: Row(children: [
        Expanded(
          child: Text(titre, style: theme.textTheme.titleLarge?.copyWith(fontSize: 18)),
        ),
        if (lien != null)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onLien,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              child: Text(lien!,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
            ),
          ),
      ]),
    );
  }
}

/// Quand il n'y a rien : une phrase calme, sans carte.
class _Calme extends StatelessWidget {
  const _Calme(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vally = theme.extension<VallyColors>()!;
    return Row(children: [
      Icon(Icons.check_rounded, size: 18, color: vally.benefice),
      const SizedBox(width: 8),
      Expanded(
        child: Text(texte,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ),
    ]);
  }
}

/// Une commande à traiter, écrite comme une tâche. Le rond à gauche la fait
/// avancer d'une étape (à préparer → prête → livrée).
class _Tache extends StatelessWidget {
  const _Tache({
    required this.commande,
    required this.devise,
    required this.maintenant,
    required this.onOuvrir,
    required this.onAvancer,
  });

  final Commande commande;
  final Devise devise;
  final DateTime maintenant;
  final VoidCallback onOuvrir;
  final VoidCallback onAvancer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final vally = theme.extension<VallyColors>()!;
    final c = commande;
    final retard = c.estEnRetard(maintenant);
    final joursRetard = c.dateLivraison == null
        ? 0
        : DateUtils.dateOnly(maintenant).difference(DateUtils.dateOnly(c.dateLivraison!)).inDays;
    final livraison = c.modeRemise == ModeRemise.livraison;
    final details = [
      if (retard)
        'En retard de $joursRetard jour${joursRetard > 1 ? 's' : ''}'
      else if (c.dateLivraison != null)
        FormatDate.relatif(c.dateLivraison!, aujourdhui: maintenant),
      livraison ? (c.adresseLivraison ?? 'Livraison') : 'Retrait en boutique',
    ].join(' · ');

    return InkWell(
      onTap: onOuvrir,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
        child: Row(children: [
          _CaseACocher(
            tooltip: c.statutLivraison == StatutLivraison.enAttente ? 'Marquer prête' : 'Marquer livrée',
            onTap: onAvancer,
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tacheCommande(c),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                TexteAvecMontants(
                  [
                    details,
                    // Reste à payer : ambre avec « − » (charte).
                    if (c.resteAPayer > 0) ...[
                      ' · reste ',
                      spanMontant(context, c.resteAPayer, devise, sens: SensMontant.negatif),
                    ],
                  ],
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12.5,
                    color: retard ? vally.attention : scheme.onSurfaceVariant,
                    fontWeight: retard ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Rond à cocher (zone de toucher de 48 px).
class _CaseACocher extends StatelessWidget {
  const _CaseACocher({required this.tooltip, required this.onTap});

  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      icon: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: scheme.outline, width: 1.6),
        ),
      ),
    );
  }
}

/// Une ligne du cahier des dettes : nom à gauche, montant à droite.
class _LigneDette extends StatelessWidget {
  const _LigneDette({required this.client, required this.devise, required this.onTap});

  final ClientResume client;
  final Devise devise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = client;
    final depuis = c.dernierAchat == null ? null : 'dernier achat ${FormatDate.ilYa(c.dernierAchat!)}';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.nom,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
              if (depuis != null) ...[
                const SizedBox(height: 2),
                Text(depuis, style: theme.textTheme.bodySmall?.copyWith(fontSize: 12.5)),
              ],
            ]),
          ),
          const SizedBox(width: 12),
          MontantTexte(c.totalDu,
              devise: devise,
              sens: SensMontant.negatif,
              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

/// Pied du cahier des dettes : le total et le nombre de clients.
class _TotalDettes extends StatelessWidget {
  const _TotalDettes({required this.total, required this.nbClients, required this.devise});

  final double total;
  final int nbClients;
  final Devise devise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      color: scheme.onSurface.withValues(alpha: 0.03),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(children: [
        Expanded(
          child: Text('Total · $nbClients client${nbClients > 1 ? 's' : ''}',
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
        ),
        MontantTexte(total,
            devise: devise,
            sens: SensMontant.negatif,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// Lien en bas d'une carte (« Voir les 6 commandes »).
class _LienBasDeCarte extends StatelessWidget {
  const _LienBasDeCarte(this.texte, {required this.onTap});

  final String texte;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(56, 12, 16, 14),
        child: Row(children: [
          Expanded(
            child: Text(texte,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
          ),
          Icon(Icons.chevron_right, size: 18, color: theme.colorScheme.primary),
        ]),
      ),
    );
  }
}

/// Rappel discret du stock presque épuisé.
class _NoteStock extends StatelessWidget {
  const _NoteStock({required this.articles, required this.onTap});

  final List<Article> articles;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final vally = theme.extension<VallyColors>()!;
    final noms = articles.take(2).map((a) => a.nom).join(' et ');
    final autres = articles.length > 2 ? ' et ${articles.length - 2} autre${articles.length > 3 ? 's' : ''}' : '';
    return Material(
      color: scheme.onSurface.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(VallyRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(VallyRadius.sm),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(Icons.inventory_2_outlined, size: 18, color: vally.attention),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: 'Bientôt en rupture : ',
                      style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600)),
                  TextSpan(text: '$noms$autres.'),
                ]),
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
          ]),
        ),
      ),
    );
  }
}
