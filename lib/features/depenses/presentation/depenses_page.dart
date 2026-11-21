import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format/dates.dart';
import '../../../core/format/montant.dart';
import '../../../core/widgets/carnet.dart';
import '../../../core/widgets/elements.dart';
import '../../../core/widgets/montant_texte.dart';
import '../../../core/widgets/page_erreur.dart';
import '../../../theme/app_theme.dart';
import '../../boutique/data/boutique_repository.dart';
import '../../boutique/domain/boutique.dart';
import '../../tableau_de_bord/data/tableau_de_bord_repository.dart';
import '../../tableau_de_bord/domain/indicateurs.dart';
import '../data/depenses_repository.dart';
import '../domain/mouvement.dart';
import 'widgets/feuilles_depenses.dart';

/// Mes dépenses : le carnet de ton argent à toi, séparé de la boutique.
/// Seul « Me verser un bénéfice » y fait entrer de l'argent de la boutique.
class DepensesPage extends ConsumerStatefulWidget {
  const DepensesPage({super.key});

  @override
  ConsumerState<DepensesPage> createState() => _DepensesPageState();
}

class _DepensesPageState extends ConsumerState<DepensesPage> {
  DateTime _mois = DateTime(DateTime.now().year, DateTime.now().month);

  /// Titre du mois : on y remonte quand on choisit un mois plus bas.
  final _cleMois = GlobalKey();

  DepensesRepository get _repo => ref.read(depensesRepositoryProvider);

  Future<void> _executer(Future<void> Function() action, String succes) async {
    try {
      await action();
      ref.invalidate(mouvementsProvider);
      if (mounted) afficherSucces(context, succes);
    } catch (e) {
      if (mounted) afficherErreur(context, e);
    }
  }

  Future<void> _ajouter(Boutique b) async {
    final saisie = await demanderMouvement(context, boutique: b);
    if (saisie == null) return;
    await _executer(() => _repo.ajouter(saisie),
        saisie.type == TypeMouvement.sortie ? 'Dépense notée.' : 'Entrée notée.');
  }

  Future<void> _verser(Boutique b, double disponible) async {
    final v = await demanderVersement(context, boutique: b, disponible: disponible);
    if (v == null) return;
    await _executer(
      () => _repo.verserBenefice(montantSaisi: v.montantSaisi, devise: v.devise, date: v.date, note: v.note),
      'Bénéfice versé dans Mes dépenses.',
    );
  }

  Future<void> _ouvrir(Mouvement m, Boutique b) async {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Ce sur quoi on agit, pour ne pas se tromper de ligne.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(children: [
              Expanded(
                child: Text(m.titre,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium),
              ),
              const SizedBox(width: 12),
              MontantTexte(m.montant,
                  devise: b.devise,
                  sens: m.estEntree ? SensMontant.positif : SensMontant.negatif,
                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
            ]),
          ),
          if (!m.depuisBoutique)
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Modifier'),
              onTap: () => Navigator.pop(context, 'modifier'),
            ),
          ListTile(
            leading: Icon(m.depuisBoutique ? Icons.undo : Icons.delete_outline, color: scheme.error),
            title: Text(m.depuisBoutique ? 'Rendre à la boutique' : 'Supprimer',
                style: TextStyle(color: scheme.error)),
            subtitle: m.depuisBoutique
                ? const Text('Le montant redevient disponible dans la boutique.')
                : null,
            onTap: () => Navigator.pop(context, 'supprimer'),
          ),
        ]),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'modifier') {
      final saisie = await demanderMouvement(context, boutique: b, existant: m);
      if (saisie != null) await _executer(() => _repo.modifier(m.id, saisie), 'Modification enregistrée.');
      return;
    }
    // Supprimer se confirme toujours : on ne perd pas une ligne d'un geste.
    final montant = FormatMontant.formater(m.montant, b.devise);
    final ok = await confirmer(
      context,
      titre: m.depuisBoutique
          ? 'Rendre ce versement à la boutique ?'
          : (m.estEntree ? 'Supprimer cette entrée ?' : 'Supprimer cette dépense ?'),
      message: m.depuisBoutique
          ? 'Les $montant sortent de ton carnet et redeviennent disponibles dans la boutique.'
          : '${m.titre}, $montant (${FormatDate.ilYa(m.date)}). Elle sera retirée de ton carnet.',
      bouton: m.depuisBoutique ? 'Rendre à la boutique' : 'Supprimer',
      destructif: true,
    );
    if (!ok || !mounted) return;
    await _executer(() => _repo.supprimer(m.id),
        m.depuisBoutique ? 'Versement rendu à la boutique.' : 'Retiré de ton carnet.');
  }

  /// Change de mois (flèches, ou un mois touché plus bas) et remonte au titre.
  void _allerAuMois(DateTime mois, {bool remonter = false}) {
    HapticFeedback.selectionClick();
    setState(() => _mois = DateTime(mois.year, mois.month));
    if (!remonter) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cible = _cleMois.currentContext;
      if (cible != null && cible.mounted) {
        Scrollable.ensureVisible(cible,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final boutique = ref.watch(boutiqueActiveProvider);
    final devise = boutique.devise;
    final mouvements = ref.watch(mouvementsProvider);
    final benefice = ref.watch(indicateursActuelsProvider);
    final maintenant = DateTime.now();
    final moisCourant = DateTime(maintenant.year, maintenant.month);

    return Scaffold(
      appBar: AppBar(title: const Text('Mes dépenses'), actions: [
        BoutonAjout(
            libelle: 'Ajouter',
            tooltip: 'Noter une dépense ou une entrée',
            onPressed: () => _ajouter(boutique)),
      ]),
      body: mouvements.when(
        skipLoadingOnRefresh: true,
        loading: () => const ListeSquelette(avecFiltres: false),
        error: (e, _) => PageErreur(erreur: e, onReessayer: () => ref.invalidate(mouvementsProvider)),
        data: (tous) {
          final duMoisChoisi = duMois(tous, _mois);
          final bilanMois = Bilan.de(duMoisChoisi);
          final repartition = repartitionSorties(duMoisChoisi);
          final enCours = _mois == moisCourant;

          return RefreshIndicator(
            onRefresh: () {
              ref.invalidate(indicateursActuelsProvider);
              return ref.refresh(mouvementsProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(VallySpace.s4, 4, VallySpace.s4, 32),
              children: [
                _CarteArgent(
                  bilan: tous.isEmpty ? null : Bilan.de(tous),
                  devise: devise,
                  boutique: _Boutique(
                    benefice: benefice,
                    devise: devise,
                    onVerser: (disponible) => _verser(boutique, disponible),
                    onReessayer: () => ref.invalidate(indicateursActuelsProvider),
                  ),
                ),
                if (tous.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 28, 12, 0),
                    child: Text(
                      'Note ici ton argent à toi : ce que tu reçois et ce que tu dépenses. '
                      'Touche + en haut pour commencer.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.4),
                    ),
                  )
                else ...[
                  // ─── Le mois choisi ───
                  TitreSection(
                    _titreMois(_mois, maintenant),
                    key: _cleMois,
                    detail: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        tooltip: 'Mois précédent',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => _allerAuMois(DateTime(_mois.year, _mois.month - 1)),
                      ),
                      IconButton(
                        tooltip: 'Mois suivant',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.chevron_right),
                        onPressed: enCours
                            ? null
                            : () => _allerAuMois(DateTime(_mois.year, _mois.month + 1)),
                      ),
                    ]),
                  ),
                  PhraseAvecChiffres(phraseMois(bilanMois, devise, enCours: enCours)),
                  if (repartition.isNotEmpty) ...[
                    const EnTeteGroupe(titre: 'Où part ton argent'),
                    _Repartition(parts: repartition, devise: devise),
                  ],
                  if (duMoisChoisi.isNotEmpty) ...[
                    EnTeteGroupe(
                      titre: 'Le détail',
                      detail: Text('${duMoisChoisi.length} ligne${duMoisChoisi.length > 1 ? 's' : ''}'),
                    ),
                    _Carnet(
                      mouvements: duMoisChoisi,
                      bilan: bilanMois,
                      devise: devise,
                      onTap: (m) => _ouvrir(m, boutique),
                    ),
                  ],

                  // ─── Les mois d'avant ───
                  const EnTeteGroupe(titre: 'Tes dépenses, mois par mois'),
                  _MoisParMois(
                    devise: devise,
                    moisChoisi: _mois,
                    maintenant: maintenant,
                    onChoisir: (m) => _allerAuMois(m, remonter: true),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// « Novembre », ou « Décembre 2025 » pour une autre année.
String _titreMois(DateTime mois, DateTime maintenant) {
  final t = DateFormat(mois.year == maintenant.year ? 'MMMM' : 'MMMM y', 'fr').format(mois);
  return t[0].toUpperCase() + t.substring(1);
}

SensMontant _sens(double v) =>
    v > 0.005 ? SensMontant.positif : (v < -0.005 ? SensMontant.negatif : SensMontant.neutre);

/// En haut : ce qu'il te reste, puis ce que la boutique peut te verser.
class _CarteArgent extends StatelessWidget {
  const _CarteArgent({required this.bilan, required this.devise, required this.boutique});

  /// Null tant que rien n'est noté : seule la partie boutique s'affiche.
  final Bilan? bilan;
  final Devise devise;
  final Widget boutique;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final vally = theme.extension<VallyColors>()!;
    final b = bilan;
    final aDecouvert = b != null && b.solde < -0.005;
    const tabulaires = [FontFeature.tabularFigures()];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (b != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(aDecouvert ? 'Tu as dépensé plus que reçu' : 'Il te reste',
                  style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '${aDecouvert ? '− ' : ''}${FormatMontant.nombre(b.solde, devise)}'),
                    TextSpan(
                      text: ' ${devise.code}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600, letterSpacing: 0),
                    ),
                  ]),
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontSize: 34,
                    height: 1.05,
                    letterSpacing: -1,
                    fontFeatures: tabulaires,
                    color: aDecouvert ? vally.attention : null,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TexteAvecMontants([
                'Depuis le début : reçu ',
                spanMontant(context, b.entrees, devise,
                    sens: b.entrees > 0.005 ? SensMontant.positif : SensMontant.neutre),
                ', dépensé ',
                spanMontant(context, b.sorties, devise,
                    sens: b.sorties > 0.005 ? SensMontant.negatif : SensMontant.neutre),
                '.',
              ], style: theme.textTheme.bodySmall?.copyWith(fontSize: 12.5)),
            ]),
          ),
          Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ],
        boutique,
      ]),
    );
  }
}

/// Ce que la boutique peut te verser : le bénéfice des ventes payées en
/// entier, moins ce qui t'a déjà été versé. Le reste attend les clients.
class _Boutique extends StatelessWidget {
  const _Boutique({
    required this.benefice,
    required this.devise,
    required this.onVerser,
    required this.onReessayer,
  });

  final AsyncValue<IndicateursActuels> benefice;
  final Devise devise;
  final void Function(double disponible) onVerser;
  final VoidCallback onReessayer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final petit = theme.textTheme.bodySmall?.copyWith(fontSize: 12.5);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 16),
      child: benefice.when(
        skipLoadingOnRefresh: true,
        loading: () => const ExcludeSemantics(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Squelette(largeur: 170),
            SizedBox(height: 8),
            Squelette(largeur: 110, hauteur: 18),
          ]),
        ),
        // Plus de barre qui tourne sans fin : on dit ce qui se passe.
        error: (e, _) => Row(children: [
          Expanded(child: Text('Impossible de lire le bénéfice de la boutique.', style: petit)),
          TextButton(onPressed: onReessayer, child: const Text('Réessayer')),
        ]),
        data: (a) {
          final disponible = a.beneficeDisponible;
          final peutVerser = disponible > 0.005;
          final enAttente = a.beneficeRealise - a.beneficeEncaisse;
          final details = [
            if (a.beneficeVerse > 0.005) 'Déjà versé : ${FormatMontant.formater(a.beneficeVerse, devise)}.',
            if (enAttente > 0.005)
              'Encore ${FormatMontant.formater(enAttente, devise)} quand tes clients auront tout payé.',
          ].join(' ');
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(peutVerser ? 'La boutique peut te verser' : 'Rien à te verser pour l’instant',
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                  if (peutVerser) ...[
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: MontantTexte(disponible,
                          devise: devise,
                          sens: SensMontant.positif,
                          style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ]),
              ),
              if (peutVerser) ...[
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onVerser(disponible);
                  },
                  // Rose pâle, comme le « + » : présent sans crier.
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.primaryContainer,
                    foregroundColor: scheme.onPrimaryContainer,
                    minimumSize: const Size(64, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text('Me verser'),
                ),
              ],
            ]),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(details, style: petit?.copyWith(height: 1.35)),
            ],
          ]);
        },
      ),
    );
  }
}

/// Où part l'argent du mois : une barre par catégorie, la plus grosse d'abord.
class _Repartition extends StatelessWidget {
  const _Repartition({required this.parts, required this.devise});

  final List<PartCategorie> parts;
  final Devise devise;

  @override
  Widget build(BuildContext context) {
    final max = parts.first.montant;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(children: [
          for (final p in parts)
            _LigneBarre(
              libelle: p.categorie,
              montant: p.montant,
              devise: devise,
              valeur: max == 0 ? 0 : p.montant / max,
              pourcentage: (p.part * 100).round(),
            ),
        ]),
      ),
    );
  }
}

/// Une ligne avec sa barre : libellé, montant, et une barre proportionnelle
/// (une seule couleur, celle des graphiques). Touchable si [onTap] est donné.
class _LigneBarre extends StatelessWidget {
  const _LigneBarre({
    required this.libelle,
    required this.montant,
    required this.devise,
    required this.valeur,
    this.pourcentage,
    this.actif = false,
    this.onTap,
  });

  final String libelle;
  final double montant;
  final Devise devise;

  /// Longueur de la barre, entre 0 et 1.
  final double valeur;
  final int? pourcentage;

  /// Ligne en cours (le mois ouvert) : libellé en rose.
  final bool actif;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final vally = theme.extension<VallyColors>()!;
    final contenu = Padding(
      padding: EdgeInsets.fromLTRB(16, 8, onTap == null ? 16 : 10, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(libelle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: actif ? scheme.primary : null,
                  fontWeight: actif ? FontWeight.w600 : null,
                )),
          ),
          if (pourcentage != null) ...[
            Text('$pourcentage %',
                style: theme.textTheme.bodySmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
            const SizedBox(width: 10),
          ],
          MontantTexte(montant,
              devise: devise, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          if (onTap != null) ...[
            const SizedBox(width: 2),
            Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
          ],
        ]),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: valeur.clamp(0, 1).toDouble(),
            minHeight: 5,
            color: vally.graphique,
            backgroundColor: scheme.onSurface.withValues(alpha: 0.06),
          ),
        ),
      ]),
    );
    return onTap == null ? contenu : InkWell(onTap: onTap, child: contenu);
  }
}

/// La page du mois dans le carnet : une ligne par entrée ou dépense, la date
/// écrite une seule fois par jour, et ce qu'il reste du mois en bas.
class _Carnet extends StatelessWidget {
  const _Carnet({
    required this.mouvements,
    required this.bilan,
    required this.devise,
    required this.onTap,
  });

  final List<Mouvement> mouvements;
  final Bilan bilan;
  final Devise devise;
  final void Function(Mouvement) onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        for (final (i, m) in mouvements.indexed) ...[
          if (i > 0)
            // Même jour : trait court, aligné sur le texte ; nouveau jour : trait entier.
            TraitRegistre(
                retrait: DateUtils.isSameDay(mouvements[i - 1].date, m.date) ? _LigneCarnet.retraitTexte : 16),
          _LigneCarnet(
            mouvement: m,
            devise: devise,
            afficherDate: i == 0 || !DateUtils.isSameDay(mouvements[i - 1].date, m.date),
            onTap: () => onTap(m),
          ),
        ],
        PiedDeCarte(
          libelle: 'Reste du mois',
          montant: bilan.solde.abs(),
          devise: devise,
          sens: _sens(bilan.solde),
        ),
      ]),
    );
  }
}

class _LigneCarnet extends StatelessWidget {
  const _LigneCarnet({
    required this.mouvement,
    required this.devise,
    required this.afficherDate,
    required this.onTap,
  });

  /// Début du texte (16 + colonne de la date 44).
  static const retraitTexte = 60.0;
  static final _jourSemaine = DateFormat('EEE', 'fr');

  final Mouvement mouvement;
  final Devise devise;
  final bool afficherDate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final m = mouvement;
    final details = m.details;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // La date, une fois par jour, comme dans un cahier.
          SizedBox(
            width: 44,
            child: afficherDate
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${m.date.day}',
                        style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()])),
                    Text(_jourSemaine.format(m.date), style: theme.textTheme.bodySmall),
                  ])
                : null,
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Text(m.titre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 12),
                MontantTexte(m.montant,
                    devise: devise,
                    sens: m.estEntree ? SensMontant.positif : SensMontant.negatif,
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
              ]),
              if (details != null) ...[
                const SizedBox(height: 2),
                Text(details,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 12.5, color: scheme.onSurfaceVariant)),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Ce que tu as dépensé chacun des six derniers mois, en barres ; toucher un
/// mois l'ouvre plus haut (avec ce que tu as reçu et ce qu'il en reste).
class _MoisParMois extends ConsumerWidget {
  const _MoisParMois({
    required this.devise,
    required this.moisChoisi,
    required this.maintenant,
    required this.onChoisir,
  });

  final Devise devise;
  final DateTime moisChoisi;
  final DateTime maintenant;
  final void Function(DateTime mois) onChoisir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final petit = theme.textTheme.bodySmall?.copyWith(fontSize: 12.5);
    return ref.watch(fluxMensuelProvider).when(
          skipLoadingOnRefresh: true,
          loading: () => const Squelette(hauteur: 120, rayon: VallyRadius.md),
          error: (e, _) => Text('Impossible de charger les mois précédents.', style: petit),
          data: (mois) {
            final six = mois.take(6).toList();
            if (six.isEmpty) return const SizedBox.shrink();
            final max = six.fold<double>(0, (m, f) => f.sorties > m ? f.sorties : m);
            return Card(
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(children: [
                  for (final f in six)
                    _LigneBarre(
                      libelle: _titreMois(f.mois, maintenant),
                      montant: f.sorties,
                      devise: devise,
                      valeur: max == 0 ? 0 : f.sorties / max,
                      actif: f.mois.year == moisChoisi.year && f.mois.month == moisChoisi.month,
                      onTap: () => onChoisir(f.mois),
                    ),
                ]),
              ),
            );
          },
        );
  }
}
