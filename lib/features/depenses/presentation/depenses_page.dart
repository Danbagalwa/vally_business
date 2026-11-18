import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format/dates.dart';
import '../../../core/format/montant.dart';
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

/// Mes dépenses : argent personnel, séparé de la boutique.
/// Seul « Me verser un bénéfice » y fait entrer de l'argent de la boutique.
class DepensesPage extends ConsumerStatefulWidget {
  const DepensesPage({super.key});

  @override
  ConsumerState<DepensesPage> createState() => _DepensesPageState();
}

class _DepensesPageState extends ConsumerState<DepensesPage> {
  DateTime _mois = DateTime(DateTime.now().year, DateTime.now().month);

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
        saisie.type == TypeMouvement.sortie ? 'Sortie enregistrée.' : 'Entrée enregistrée.');
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
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (!m.depuisBoutique)
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Modifier'),
              onTap: () => Navigator.pop(context, 'modifier'),
            ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: Text(m.depuisBoutique ? 'Annuler ce versement' : 'Supprimer'),
            subtitle: m.depuisBoutique ? const Text('Le montant redevient disponible dans la boutique.') : null,
            onTap: () => Navigator.pop(context, 'supprimer'),
          ),
        ]),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'modifier') {
      final saisie = await demanderMouvement(context, boutique: b, existant: m);
      if (saisie != null) await _executer(() => _repo.modifier(m.id, saisie), 'Mouvement modifié.');
    } else {
      await _executer(() => _repo.supprimer(m.id),
          m.depuisBoutique ? 'Versement annulé.' : 'Mouvement supprimé.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final boutique = ref.watch(boutiqueActiveProvider);
    final devise = boutique.devise;
    final mouvements = ref.watch(mouvementsProvider);
    final actuels = ref.watch(indicateursActuelsProvider).value;
    final maintenant = DateTime.now();
    final moisCourant = DateTime(maintenant.year, maintenant.month);

    return Scaffold(
      appBar: AppBar(title: const Text('Mes dépenses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _ajouter(boutique),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: mouvements.when(
        skipLoadingOnRefresh: true,
        loading: () => const ListeSquelette(),
        error: (e, _) => PageErreur(erreur: e, onReessayer: () => ref.invalidate(mouvementsProvider)),
        data: (tous) {
          final total = Bilan.de(tous);
          final duMoisChoisi = duMois(tous, _mois);
          final bilanMois = Bilan.de(duMoisChoisi);
          final repartition = repartitionSorties(duMoisChoisi);
          return RefreshIndicator(
            onRefresh: () => ref.refresh(mouvementsProvider.future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(VallySpace.s4, 0, VallySpace.s4, 96),
              children: [
                _CarteSolde(bilan: total, devise: devise),
                const SizedBox(height: VallySpace.s2),
                _CarteBenefice(
                  actuels: actuels,
                  devise: devise,
                  onVerser: actuels == null || actuels.beneficeDisponible <= 0
                      ? null
                      : () => _verser(boutique, actuels.beneficeDisponible),
                ),
                const SizedBox(height: VallySpace.s4),

                // ─── Mois ───
                Row(children: [
                  IconButton(
                    tooltip: 'Mois précédent',
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setState(() => _mois = DateTime(_mois.year, _mois.month - 1)),
                  ),
                  Expanded(
                    child: Text(_majuscule(DateFormat('MMMM y', 'fr').format(_mois)),
                        textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
                  ),
                  IconButton(
                    tooltip: 'Mois suivant',
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _mois == moisCourant
                        ? null
                        : () => setState(() => _mois = DateTime(_mois.year, _mois.month + 1)),
                  ),
                ]),
                _BilanMois(bilan: bilanMois, devise: devise),

                if (repartition.isNotEmpty) ...[
                  const SizedBox(height: VallySpace.s6),
                  const EnTeteSection('Où part l’argent', sousTitre: 'Sorties du mois par catégorie'),
                  _Repartition(parts: repartition, devise: devise),
                ],

                const SizedBox(height: VallySpace.s6),
                EnTeteSection('Mouvements',
                    sousTitre: duMoisChoisi.isEmpty ? 'Aucun mouvement ce mois-ci' : null),
                for (final MapEntry(key: jour, value: liste)
                    in _parJour(duMoisChoisi).entries) ...[
                  EnTeteGroupe(titre: FormatDate.relatif(jour)),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(children: [
                      for (final (i, m) in liste.indexed) ...[
                        if (i > 0) const Divider(indent: 56),
                        _LigneMouvement(mouvement: m, devise: devise, onTap: () => _ouvrir(m, boutique)),
                      ],
                    ]),
                  ),
                ],

                const SizedBox(height: VallySpace.s6),
                const EnTeteSection('Flux par mois'),
                _FluxMensuel(devise: devise),
              ],
            ),
          );
        },
      ),
    );
  }

  static Map<DateTime, List<Mouvement>> _parJour(List<Mouvement> liste) {
    final g = <DateTime, List<Mouvement>>{};
    for (final m in liste) {
      g.putIfAbsent(FormatDate.jour(m.date), () => []).add(m);
    }
    return g;
  }

  static String _majuscule(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

SensMontant _sens(double v) =>
    v > 0 ? SensMontant.positif : (v < 0 ? SensMontant.negatif : SensMontant.neutre);

class _CarteSolde extends StatelessWidget {
  const _CarteSolde({required this.bilan, required this.devise});

  final Bilan bilan;
  final Devise devise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Solde', style: theme.textTheme.bodySmall),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: MontantTexte(bilan.solde.abs(),
                devise: devise, sens: _sens(bilan.solde), style: theme.textTheme.displaySmall),
          ),
          const SizedBox(height: 2),
          TexteAvecMontants([
            'Entrées ',
            spanMontant(context, bilan.entrees, devise, sens: bilan.entrees > 0 ? SensMontant.positif : SensMontant.neutre),
            '  ·  Sorties ',
            spanMontant(context, bilan.sorties, devise, sens: bilan.sorties > 0 ? SensMontant.negatif : SensMontant.neutre),
          ]),
        ]),
      ),
    );
  }
}

/// Bénéfice de la boutique : encaissé, déjà versé, disponible, en attente.
class _CarteBenefice extends StatelessWidget {
  const _CarteBenefice({required this.actuels, required this.devise, required this.onVerser});

  final IndicateursActuels? actuels;
  final Devise devise;
  final VoidCallback? onVerser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = actuels;
    final enAttente = a == null ? 0.0 : (a.beneficeRealise - a.beneficeEncaisse);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.storefront_outlined, size: 18, color: theme.colorScheme.onPrimaryContainer),
            const SizedBox(width: 6),
            Expanded(
              child: Text('Bénéfice de la boutique',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onPrimaryContainer)),
            ),
          ]),
          const SizedBox(height: VallySpace.s2),
          if (a == null)
            const LinearProgressIndicator()
          else ...[
            TexteAvecMontants([
              'Disponible ',
              spanMontant(context, a.beneficeDisponible.abs(), devise,
                  sens: _sens(a.beneficeDisponible), gras: true),
            ], style: theme.textTheme.titleMedium),
            TexteAvecMontants([
              'Déjà versé ',
              spanMontant(context, a.beneficeVerse, devise),
              if (enAttente > 0.005) ...[
                '  ·  En attente de paiement ',
                spanMontant(context, enAttente, devise),
              ],
            ]),
          ],
          const SizedBox(height: VallySpace.s2 + VallySpace.s1),
          FilledButton.icon(
            onPressed: onVerser,
            icon: const Icon(Icons.south_west, size: 18),
            label: const Text('Me verser un bénéfice'),
          ),
        ]),
      ),
    );
  }
}

class _BilanMois extends StatelessWidget {
  const _BilanMois({required this.bilan, required this.devise});

  final Bilan bilan;
  final Devise devise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget bloc(String libelle, double montant, SensMontant sens) => Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(libelle, style: theme.textTheme.bodySmall),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: MontantTexte(montant,
                      devise: devise,
                      sens: montant.abs() < 0.005 ? SensMontant.neutre : sens,
                      style: theme.textTheme.titleSmall),
                ),
              ]),
            ),
          ),
        );
    return Row(children: [
      bloc('Entrées', bilan.entrees, SensMontant.positif),
      const SizedBox(width: 6),
      bloc('Sorties', bilan.sorties, SensMontant.negatif),
      const SizedBox(width: 6),
      bloc('Solde du mois', bilan.solde.abs(), _sens(bilan.solde)),
    ]);
  }
}

/// Barres horizontales : une seule série (couleur graphique), libellés en texte.
class _Repartition extends StatelessWidget {
  const _Repartition({required this.parts, required this.devise});

  final List<PartCategorie> parts;
  final Devise devise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vally = theme.extension<VallyColors>()!;
    final max = parts.first.montant;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(children: [
          for (final p in parts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(p.categorie,
                        style: theme.textTheme.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  Text('${(p.part * 100).round()} %  ',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                  MontantTexte(p.montant, devise: devise, style: theme.textTheme.bodyMedium),
                ]),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: max == 0 ? 0 : p.montant / max,
                    minHeight: 6,
                    color: vally.graphique,
                    backgroundColor: theme.colorScheme.outlineVariant,
                  ),
                ),
              ]),
            ),
        ]),
      ),
    );
  }
}

class _LigneMouvement extends StatelessWidget {
  const _LigneMouvement({required this.mouvement, required this.devise, required this.onTap});

  final Mouvement mouvement;
  final Devise devise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vally = theme.extension<VallyColors>()!;
    final m = mouvement;
    final details = [
      if (m.depuisBoutique) 'Versé depuis la boutique',
      if (m.note != null) m.note!,
      if (m.tauxChange != null)
        '${FormatMontant.formater(m.montantSaisi, m.deviseSaisie)} à ${FormatMontant.formater(m.tauxChange!, Devise.cdf)}',
    ];
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: (m.estEntree ? vally.benefice : vally.attention).withValues(alpha: 0.12),
        child: Icon(
          m.depuisBoutique
              ? Icons.storefront_outlined
              : (m.estEntree ? Icons.arrow_downward : Icons.arrow_upward),
          size: 18,
          color: m.estEntree ? vally.benefice : vally.attention,
        ),
      ),
      title: Text(m.categorie, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: details.isEmpty ? null : Text(details.join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: MontantTexte(m.montant,
          devise: devise,
          sens: m.estEntree ? SensMontant.positif : SensMontant.negatif,
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
    );
  }
}

/// Tableau des derniers mois : entrées, sorties, solde du mois.
class _FluxMensuel extends ConsumerWidget {
  const _FluxMensuel({required this.devise});

  final Devise devise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ref.watch(fluxMensuelProvider).when(
          skipLoadingOnRefresh: true,
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Flux indisponible.', style: theme.textTheme.bodySmall),
          data: (mois) {
            if (mois.isEmpty) {
              return Text('Les mois apparaîtront après ton premier mouvement.',
                  style: theme.textTheme.bodySmall);
            }
            final petit = theme.textTheme.bodySmall;
            return Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                child: Column(children: [
                  for (final (i, f) in mois.take(6).indexed) ...[
                    if (i > 0) const Divider(height: 12),
                    Row(children: [
                      Expanded(
                        flex: 3,
                        child: Text(DateFormat('MMM y', 'fr').format(f.mois), style: theme.textTheme.bodyMedium),
                      ),
                      Expanded(
                        flex: 4,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          MontantTexte(f.entrees,
                              devise: devise,
                              sens: f.entrees > 0 ? SensMontant.positif : SensMontant.neutre,
                              style: petit),
                          MontantTexte(f.sorties,
                              devise: devise,
                              sens: f.sorties > 0 ? SensMontant.negatif : SensMontant.neutre,
                              style: petit),
                        ]),
                      ),
                      Expanded(
                        flex: 4,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: MontantTexte(f.solde.abs(),
                                devise: devise,
                                sens: _sens(f.solde),
                                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                    ]),
                  ],
                ]),
              ),
            );
          },
        );
  }
}
