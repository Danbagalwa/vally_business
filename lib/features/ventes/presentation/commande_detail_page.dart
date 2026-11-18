import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format/dates.dart';
import '../../../core/format/montant.dart';
import '../../../core/widgets/montant_texte.dart';
import '../../../core/widgets/page_erreur.dart';
import '../../../theme/app_theme.dart';
import '../../boutique/data/boutique_repository.dart';
import '../../boutique/domain/boutique.dart';
import '../../stock/data/stock_repository.dart';
import '../data/ventes_repository.dart';
import '../domain/commande.dart';
import 'widgets/badges_commande.dart';
import 'widgets/saisie_paiement.dart';

/// Détail d'une commande : articles, totaux, paiements, livraison.
class CommandeDetailPage extends ConsumerStatefulWidget {
  const CommandeDetailPage({super.key, required this.commandeId});

  final String commandeId;

  @override
  ConsumerState<CommandeDetailPage> createState() => _CommandeDetailPageState();
}

class _CommandeDetailPageState extends ConsumerState<CommandeDetailPage> {
  bool _enCours = false;

  VentesRepository get _repo => ref.read(ventesRepositoryProvider);

  /// Après une modification : recharge la commande, la liste et le stock.
  void _rafraichir() {
    ref.invalidate(commandeDetailProvider(widget.commandeId));
    ref.invalidate(commandesProvider);
    ref.invalidate(articlesProvider);
  }

  Future<void> _action(Future<void> Function() action, {String? succes}) async {
    setState(() => _enCours = true);
    try {
      await action();
      _rafraichir();
      if (mounted && succes != null) afficherSucces(context, succes);
    } catch (e) {
      if (mounted) afficherErreur(context, e);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  Future<bool> _confirmer(String titre, String message, String bouton) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titre),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Retour')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(bouton)),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _changerLivraison(Commande c, StatutLivraison statut) async {
    if (statut == c.statutLivraison) return;
    if (statut == StatutLivraison.annulee &&
        !await _confirmer(
          'Annuler cette vente ?',
          'Les articles reviennent en stock et la vente sort de tes bénéfices.'
              '${c.totalPaye > 0 ? ' Pense à rendre l’argent déjà reçu au client.' : ''}',
          'Annuler la vente',
        )) {
      return;
    }
    await _action(
      () => _repo.changerStatutLivraison(c.id, statut),
      succes: switch (statut) {
        StatutLivraison.annulee => 'Vente annulée : le stock est remis.',
        StatutLivraison.livree => 'Vente marquée comme livrée.',
        StatutLivraison.enAttente => 'Vente remise en attente.',
      },
    );
  }

  Future<void> _ajouterPaiement(Commande c, Boutique b) async {
    final p = await demanderPaiement(
      context,
      resteAPayer: c.resteAPayer,
      deviseReference: b.devise,
      tauxUsdCdf: b.tauxUsdCdf,
    );
    if (p == null) return;
    await _action(
      () => _repo.ajouterPaiement(
        c.id,
        PaiementSaisi(
            montantSaisi: p.montantSaisi,
            devise: p.devise,
            mode: p.mode,
            date: p.date),
      ),
      succes: 'Paiement enregistré.',
    );
  }

  Future<void> _supprimerPaiement(Paiement p, Devise devise) async {
    if (!await _confirmer(
      'Supprimer ce paiement ?',
      '${FormatMontant.formater(p.montant, devise)} du ${FormatDate.court(p.date)} '
          'sera retiré de cette vente.',
      'Supprimer',
    )) {
      return;
    }
    await _action(() => _repo.supprimerPaiement(p.id),
        succes: 'Paiement supprimé.');
  }

  Future<void> _supprimerCommande(Commande c) async {
    if (!await _confirmer(
      'Supprimer cette vente ?',
      'Elle disparaît avec ses paiements et les articles reviennent en stock. '
          'Pour garder une trace, annule-la plutôt.',
      'Supprimer',
    )) {
      return;
    }
    setState(() => _enCours = true);
    try {
      await _repo.supprimer(c.id);
      ref.invalidate(commandesProvider);
      ref.invalidate(articlesProvider);
      if (!mounted) return;
      afficherSucces(context, 'Vente supprimée.');
      context.pop();
    } catch (e) {
      if (mounted) afficherErreur(context, e);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final boutique = ref.watch(boutiqueActiveProvider);
    final detail = ref.watch(commandeDetailProvider(widget.commandeId));

    return detail.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Vente')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Vente')),
        body: PageErreur(
          erreur: e,
          onReessayer: () =>
              ref.invalidate(commandeDetailProvider(widget.commandeId)),
        ),
      ),
      data: (d) => _contenu(context, d, boutique),
    );
  }

  Widget _contenu(BuildContext context, CommandeDetail d, Boutique boutique) {
    final theme = Theme.of(context);
    final c = d.commande;
    final devise = boutique.devise;

    return Scaffold(
      appBar: AppBar(
        title: Text(c.nomAffiche),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Plus',
            enabled: !_enCours,
            onSelected: (_) => _supprimerCommande(c),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'supprimer',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_outline),
                  title: Text('Supprimer la vente'),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: c.aEncaisser
          ? FloatingActionButton.extended(
              onPressed: _enCours ? null : () => _ajouterPaiement(c, boutique),
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Ajouter un paiement'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () =>
            ref.refresh(commandeDetailProvider(widget.commandeId).future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              VallySpace.s4, VallySpace.s2, VallySpace.s4, 96),
          children: [
            if (_enCours) const LinearProgressIndicator(),
            Text(
              [
                'Vente du ${FormatDate.court(c.date)}',
                if (c.clientTelephone != null) c.clientTelephone!,
              ].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
            if (c.note != null) ...[
              const SizedBox(height: VallySpace.s2),
              Row(children: [
                Icon(Icons.sticky_note_2_outlined,
                    size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: VallySpace.s1),
                Expanded(child: Text(c.note!, style: theme.textTheme.bodyMedium)),
              ]),
            ],
            const SizedBox(height: VallySpace.s4),

            // ─── Livraison ───
            Text('Livraison', style: theme.textTheme.titleMedium),
            const SizedBox(height: VallySpace.s2),
            SegmentedButton<StatutLivraison>(
              segments: [
                for (final s in StatutLivraison.values)
                  ButtonSegment(value: s, label: Text(s.libelle)),
              ],
              selected: {c.statutLivraison},
              showSelectedIcon: false,
              onSelectionChanged: _enCours
                  ? null
                  : (s) => _changerLivraison(c, s.first),
            ),
            const SizedBox(height: VallySpace.s6),

            // ─── Totaux ───
            _CarteTotaux(commande: c, devise: devise),
            const SizedBox(height: VallySpace.s6),

            // ─── Articles ───
            Text('Articles', style: theme.textTheme.titleMedium),
            const SizedBox(height: VallySpace.s2),
            Card(
              child: Column(
                children: [
                  for (final (i, l) in d.lignes.indexed) ...[
                    if (i > 0) const Divider(),
                    _LigneArticle(ligne: l, devise: devise),
                  ],
                ],
              ),
            ),
            const SizedBox(height: VallySpace.s6),

            // ─── Paiements ───
            Text('Paiements', style: theme.textTheme.titleMedium),
            const SizedBox(height: VallySpace.s2),
            if (d.paiements.isEmpty)
              Text('Aucun paiement pour l’instant.',
                  style: theme.textTheme.bodyMedium)
            else
              Card(
                child: Column(
                  children: [
                    for (final (i, p) in d.paiements.indexed) ...[
                      if (i > 0) const Divider(),
                      _LignePaiement(
                        paiement: p,
                        devise: devise,
                        onSupprimer: _enCours
                            ? null
                            : () => _supprimerPaiement(p, devise),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CarteTotaux extends StatelessWidget {
  const _CarteTotaux({required this.commande, required this.devise});

  final Commande commande;
  final Devise devise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = commande;
    Widget ligne(String libelle, Widget valeur) => Padding(
          padding: const EdgeInsets.symmetric(vertical: VallySpace.s1),
          child: Row(children: [
            Expanded(child: Text(libelle, style: theme.textTheme.bodyMedium)),
            valeur,
          ]),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(VallySpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: MontantTexte(c.total,
                      devise: devise,
                      style: theme.textTheme.displaySmall
                          ?.copyWith(fontSize: 32)),
                ),
              ),
              BadgePaiement(commande: c, devise: devise),
            ]),
            const SizedBox(height: VallySpace.s2),
            const Divider(),
            ligne('Déjà payé',
                MontantTexte(c.totalPaye,
                    devise: devise,
                    sens: c.totalPaye > 0
                        ? SensMontant.positif
                        : SensMontant.neutre)),
            if (!c.annulee)
              ligne('Reste à payer',
                  c.resteAPayer > 0
                      ? MontantTexte(c.resteAPayer,
                          devise: devise, sens: SensMontant.negatif)
                      : MontantTexte(0, devise: devise)),
            ligne(
              c.annulee ? 'Bénéfice (vente annulée, non compté)' : 'Bénéfice',
              MontantTexte(c.benefice.abs(),
                  devise: devise,
                  sens: c.annulee
                      ? SensMontant.neutre
                      : (c.benefice >= 0
                          ? SensMontant.positif
                          : SensMontant.negatif)),
            ),
            if (c.ecartPrixHabituel.abs() >= 0.005)
              Align(
                alignment: Alignment.centerRight,
                child: TexteEcart(ecart: c.ecartPrixHabituel, devise: devise),
              ),
          ],
        ),
      ),
    );
  }
}

class _LigneArticle extends StatelessWidget {
  const _LigneArticle({required this.ligne, required this.devise});

  final LigneCommande ligne;
  final Devise devise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = ligne;
    return Padding(
      padding: const EdgeInsets.all(VallySpace.s4 - VallySpace.s1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.articleNom,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600)),
                if (l.articleDescription.isNotEmpty)
                  Text(l.articleDescription, style: theme.textTheme.bodySmall),
                const SizedBox(height: VallySpace.s1),
                Row(children: [
                  Text('${l.quantite} × ', style: theme.textTheme.bodySmall),
                  MontantTexte(l.prixVendu,
                      devise: devise, style: theme.textTheme.bodySmall),
                ]),
                TexteEcart(ecart: l.ecart, devise: devise),
              ],
            ),
          ),
          MontantTexte(l.total, devise: devise),
        ],
      ),
    );
  }
}

class _LignePaiement extends StatelessWidget {
  const _LignePaiement({
    required this.paiement,
    required this.devise,
    required this.onSupprimer,
  });

  final Paiement paiement;
  final Devise devise;
  final VoidCallback? onSupprimer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = paiement;
    final details = [
      FormatDate.court(p.date),
      p.mode.libelle,
      if (p.converti)
        '${FormatMontant.formater(p.montantSaisi, p.deviseSaisie)} '
            'au taux de ${FormatMontant.formater(p.tauxChange!, Devise.cdf)}',
    ].join(' · ');
    return ListTile(
      leading: const Icon(Icons.payments_outlined),
      title: MontantTexte(p.montant, devise: devise, sens: SensMontant.positif),
      subtitle: Text(details, style: theme.textTheme.bodySmall),
      trailing: IconButton(
        tooltip: 'Supprimer ce paiement',
        icon: const Icon(Icons.delete_outline),
        onPressed: onSupprimer,
      ),
    );
  }
}
