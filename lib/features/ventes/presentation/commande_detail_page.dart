import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/contact.dart';
import '../../../core/format/dates.dart';
import '../../../core/format/montant.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/champ_montant.dart';
import '../../../core/widgets/elements.dart';
import '../../../core/widgets/montant_texte.dart';
import '../../../core/widgets/page_erreur.dart';
import '../../../theme/app_theme.dart';
import '../../boutique/data/boutique_repository.dart';
import '../../boutique/domain/boutique.dart';
import '../../factures/presentation/feuille_facture.dart';
import '../data/ventes_repository.dart';
import '../domain/commande.dart';
import 'actions_commande.dart';
import 'widgets/badges_commande.dart';
import 'widgets/saisie_paiement.dart';

/// Détail d'une vente ou d'une commande.
class CommandeDetailPage extends ConsumerStatefulWidget {
  const CommandeDetailPage({super.key, required this.commandeId, this.proposerFacture = false});

  final String commandeId;

  /// Juste après l'enregistrement : proposer l'envoi de la facture.
  final bool proposerFacture;

  @override
  ConsumerState<CommandeDetailPage> createState() => _CommandeDetailPageState();
}

class _CommandeDetailPageState extends ConsumerState<CommandeDetailPage> {
  bool _enCours = false;
  bool _propositionFaite = false;

  VentesRepository get _repo => ref.read(ventesRepositoryProvider);

  Future<void> _action(Future<void> Function() action, {String? succes}) async {
    setState(() => _enCours = true);
    try {
      await action();
      rafraichirVentes(ref, commandeId: widget.commandeId);
      if (mounted && succes != null) afficherSucces(context, succes);
    } catch (e) {
      if (mounted) afficherErreur(context, e);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  /// Les suppressions sont confirmées avec un bouton couleur d'erreur.
  Future<bool> _confirmer(String titre, String message, String bouton) => confirmer(
        context,
        titre: titre,
        message: message,
        bouton: bouton,
        destructif: true,
      );

  Future<void> _encaisser(Commande c, Boutique b) async {
    final p = await demanderPaiement(context,
        resteAPayer: c.resteAPayer, deviseReference: b.devise, tauxUsdCdf: b.tauxUsdCdf);
    if (p == null) return;
    await _action(
      () => _repo.ajouterPaiement(
          c.id,
          PaiementSaisi(
              montantSaisi: p.montantSaisi, devise: p.devise, mode: p.mode, date: p.date)),
      succes: 'Paiement enregistré.',
    );
  }

  Future<void> _supprimerPaiement(Paiement p, Devise devise) async {
    if (!await _confirmer(
        'Supprimer ce paiement ?',
        '${FormatMontant.formater(p.montant, devise)} du ${FormatDate.court(p.date)} sera retiré.',
        'Supprimer')) {
      return;
    }
    await _action(() => _repo.supprimerPaiement(p.id), succes: 'Paiement supprimé.');
  }

  Future<void> _modifierLivraison(Commande c, Boutique b) async {
    final livraison = await showModalBottomSheet<Livraison>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _FeuilleLivraison(commande: c, boutique: b),
    );
    if (livraison == null) return;
    await _action(() => _repo.modifierLivraison(c.id, livraison),
        succes: 'Livraison mise à jour.');
  }

  Future<void> _supprimer(Commande c) async {
    if (!await _confirmer(
      c.estCommande ? 'Supprimer la commande ?' : 'Supprimer la vente ?',
      'Elle disparaît avec ses paiements et les articles reviennent en stock. '
          'Pour garder une trace, annule-la plutôt.',
      'Supprimer',
    )) {
      return;
    }
    setState(() => _enCours = true);
    try {
      await _repo.supprimer(c.id);
      rafraichirVentes(ref);
      if (!mounted) return;
      afficherSucces(context, 'Supprimée.');
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
    return ref.watch(commandeDetailProvider(widget.commandeId)).when(
          skipLoadingOnRefresh: true,
          loading: () => Scaffold(
              appBar: AppBar(), body: const Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(
            appBar: AppBar(),
            body: PageErreur(
                erreur: e,
                onReessayer: () => ref.invalidate(commandeDetailProvider(widget.commandeId))),
          ),
          data: (d) {
            // Après une vente ou une commande : on propose la facture une fois.
            if (widget.proposerFacture && !_propositionFaite) {
              _propositionFaite = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  ouvrirFeuilleFacture(context, detail: d, boutique: boutique, apresEnregistrement: true);
                }
              });
            }
            return _contenu(context, d, boutique);
          },
        );
  }

  Widget _contenu(BuildContext context, CommandeDetail d, Boutique boutique) {
    final theme = Theme.of(context);
    final c = d.commande;
    final devise = boutique.devise;

    return Scaffold(
      appBar: AppBar(
        title: Text(c.estCommande ? 'Commande' : 'Vente'),
        actions: [
          IconButton(
            tooltip: 'Facture',
            icon: const Icon(Icons.receipt_long_outlined, size: 21),
            onPressed: () => ouvrirFeuilleFacture(context, detail: d, boutique: boutique),
          ),
          PopupMenuButton<String>(
            tooltip: 'Plus d’actions',
            enabled: !_enCours,
            onSelected: (v) => switch (v) {
              'annuler' => changerStatut(context, ref, c, StatutLivraison.annulee),
              'reactiver' => changerStatut(context, ref, c,
                  c.estCommande ? StatutLivraison.enAttente : StatutLivraison.livree),
              _ => _supprimer(c),
            },
            itemBuilder: (context) => [
              if (!c.annulee)
                PopupMenuItem(
                  value: 'annuler',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.block),
                    title: Text(c.estCommande ? 'Annuler la commande' : 'Annuler la vente'),
                  ),
                )
              else
                const PopupMenuItem(
                  value: 'reactiver',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.undo),
                    title: Text('Réactiver'),
                  ),
                ),
              const PopupMenuItem(
                value: 'supprimer',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_outline),
                  title: Text('Supprimer'),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: c.aEncaisser
          ? BarreAction(
              libelle: 'Encaisser',
              icone: Icons.payments_outlined,
              enCours: _enCours,
              onPressed: () => _encaisser(c, boutique),
              resume: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reste à payer', style: theme.textTheme.bodySmall),
                  MontantTexte(c.resteAPayer,
                      devise: devise,
                      sens: SensMontant.negatif,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                  EquivalentDevise(
                      montant: c.resteAPayer,
                      deviseReference: devise,
                      tauxUsdVersCdf: boutique.tauxUsdCdf),
                ],
              ),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(commandeDetailProvider(widget.commandeId).future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(VallySpace.s4, 0, VallySpace.s4, VallySpace.s6),
          children: [
            if (_enCours) const LinearProgressIndicator(),
            const SizedBox(height: VallySpace.s2),

            // ─── Client ───
            Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                onTap: c.clientId == null ? null : () => context.push(Routes.client(c.clientId!)),
                leading: AvatarInitiales(_initiales(c.clientNom)),
                title: Text(c.nomAffiche),
                subtitle: Text([
                  '${c.estCommande ? 'Commandé' : 'Vendu'} ${FormatDate.relatif(c.date).toLowerCase()}',
                  if (c.clientTelephone != null) c.clientTelephone!,
                ].join(' · ')),
                trailing: c.clientTelephone == null
                    ? null
                    : BoutonsContact(
                        telephone: c.clientTelephone!,
                        message: c.estCommande && c.statutLivraison == StatutLivraison.prete
                            ? 'Bonjour ${c.nomAffiche}, ta commande Vally Business est prête.'
                            : null,
                      ),
              ),
            ),
            if (c.note != null) ...[
              const SizedBox(height: VallySpace.s2),
              Row(children: [
                Icon(Icons.sticky_note_2_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(child: Text(c.note!, style: theme.textTheme.bodyMedium)),
              ]),
            ],

            // ─── Livraison (commande) ───
            if (c.estCommande) ...[
              const SizedBox(height: VallySpace.s6),
              EnTeteSection('Livraison',
                  action: c.aLivrer ? 'Modifier' : null,
                  onAction: () => _modifierLivraison(c, boutique)),
              _CarteLivraison(commande: c, devise: devise),
              if (!c.annulee) ...[
                const SizedBox(height: VallySpace.s2 + VallySpace.s1),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<StatutLivraison>(
                    segments: const [
                      ButtonSegment(value: StatutLivraison.enAttente, label: Text('À préparer')),
                      ButtonSegment(value: StatutLivraison.prete, label: Text('Prête')),
                      ButtonSegment(value: StatutLivraison.livree, label: Text('Livrée')),
                    ],
                    selected: {c.statutLivraison},
                    showSelectedIcon: false,
                    onSelectionChanged: _enCours
                        ? null
                        : (s) => changerStatut(context, ref, c, s.first),
                  ),
                ),
              ],
            ],

            // ─── Articles et totaux ───
            const SizedBox(height: VallySpace.s6),
            EnTeteSection('Articles', sousTitre: c.annulee ? 'Annulée : hors bénéfices et stock rendu' : null),
            Card(
              child: Column(children: [
                for (final (i, l) in d.lignes.indexed) ...[
                  if (i > 0) const Divider(),
                  _LigneArticle(ligne: l, devise: devise),
                ],
                const Divider(),
                _Totaux(commande: c, devise: devise),
              ]),
            ),

            // ─── Paiements ───
            const SizedBox(height: VallySpace.s6),
            EnTeteSection('Paiements',
                sousTitre: d.paiements.isEmpty ? 'Aucun paiement pour l’instant' : null),
            if (d.paiements.isNotEmpty)
              Card(
                child: Column(children: [
                  for (final (i, p) in d.paiements.indexed) ...[
                    if (i > 0) const Divider(indent: 56),
                    _LignePaiement(
                      paiement: p,
                      devise: devise,
                      onSupprimer: _enCours ? null : () => _supprimerPaiement(p, devise),
                    ),
                  ],
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

String _initiales(String? nom) {
  if (nom == null || nom.trim().isEmpty) return '';
  return nom.trim().split(RegExp(r'\s+')).take(2).map((m) => m[0].toUpperCase()).join();
}

class _CarteLivraison extends StatelessWidget {
  const _CarteLivraison({required this.commande, required this.devise});

  final Commande commande;
  final Devise devise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vally = theme.extension<VallyColors>()!;
    final c = commande;
    final retard = c.estEnRetard(DateTime.now());
    final livraison = c.modeRemise == ModeRemise.livraison;
    return Card(
      child: Column(children: [
        ListTile(
          leading: Icon(Icons.event_outlined, color: retard ? vally.attention : null),
          title: Text(c.dateLivraison == null ? '—' : FormatDate.relatif(c.dateLivraison!),
              style: retard ? TextStyle(color: vally.attention) : null),
          subtitle: Text(retard
              ? 'En retard · prévue le ${FormatDate.court(c.dateLivraison!)}'
              : (c.dateLivraison == null ? '' : FormatDate.court(c.dateLivraison!))),
          trailing: PastilleLivraison(statut: c.statutLivraison),
        ),
        const Divider(indent: 56),
        ListTile(
          leading: Icon(livraison ? Icons.local_shipping_outlined : Icons.storefront_outlined),
          title: Text(livraison ? (c.adresseLivraison ?? 'Livraison') : 'Retrait en boutique'),
          subtitle: livraison && c.fraisLivraison > 0
              ? TexteAvecMontants(['Frais de livraison ', spanMontant(context, c.fraisLivraison, devise)])
              : null,
        ),
      ]),
    );
  }
}

class _Totaux extends StatelessWidget {
  const _Totaux({required this.commande, required this.devise});

  final Commande commande;
  final Devise devise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = commande;
    Widget ligne(String libelle, Widget valeur, {bool fort = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(
                child: Text(libelle,
                    style: fort
                        ? theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)
                        : theme.textTheme.bodyMedium)),
            valeur,
          ]),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(children: [
        if (c.fraisLivraison > 0) ...[
          ligne('Articles', MontantTexte(c.totalArticles, devise: devise, style: theme.textTheme.bodyMedium)),
          ligne('Livraison', MontantTexte(c.fraisLivraison, devise: devise, style: theme.textTheme.bodyMedium)),
        ],
        ligne('Total', MontantTexte(c.total, devise: devise), fort: true),
        ligne('Payé',
            MontantTexte(c.totalPaye,
                devise: devise,
                sens: c.totalPaye > 0 ? SensMontant.positif : SensMontant.neutre,
                style: theme.textTheme.bodyMedium)),
        if (!c.annulee && c.resteAPayer > 0)
          ligne('Reste à payer',
              MontantTexte(c.resteAPayer,
                  devise: devise, sens: SensMontant.negatif, style: theme.textTheme.bodyMedium)),
        if (!c.annulee) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TexteAvecMontants([
              c.enCours ? 'Bénéfice prévu ' : 'Bénéfice ',
              spanMontant(context, c.benefice.abs(), devise,
                  sens: c.benefice >= 0 ? SensMontant.positif : SensMontant.negatif, gras: true),
            ]),
          ),
          if (c.enCours)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline, size: 14, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Commande en cours : elle comptera dans tes ventes une fois '
                    'payée en entier ou livrée.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ]),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TexteEcart(ecart: c.ecartPrixHabituel, devise: devise),
          ),
        ],
      ]),
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
    return ListTile(
      title: Text(l.articleNom, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TexteAvecMontants([
          '${l.quantite} × ',
          spanMontant(context, l.prixVendu, devise),
          if (l.articleDescription.isNotEmpty) ' · ${l.articleDescription}',
        ], maxLines: 1),
        TexteEcart(ecart: l.ecart, devise: devise),
      ]),
      trailing: MontantTexte(l.total, devise: devise, style: theme.textTheme.bodyMedium),
    );
  }
}

class _LignePaiement extends StatelessWidget {
  const _LignePaiement({required this.paiement, required this.devise, required this.onSupprimer});

  final Paiement paiement;
  final Devise devise;
  final VoidCallback? onSupprimer;

  @override
  Widget build(BuildContext context) {
    final p = paiement;
    return ListTile(
      leading: const Icon(Icons.payments_outlined),
      title: MontantTexte(p.montant,
          devise: devise,
          sens: SensMontant.positif,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text([
        FormatDate.relatif(p.date),
        p.mode.libelle,
        if (p.converti)
          '${FormatMontant.formater(p.montantSaisi, p.deviseSaisie)} à ${FormatMontant.formater(p.tauxChange!, Devise.cdf)}',
      ].join(' · ')),
      trailing: IconButton(
        tooltip: 'Supprimer ce paiement',
        icon: const Icon(Icons.delete_outline, size: 20),
        onPressed: onSupprimer,
      ),
    );
  }
}

/// Modifier la date, le mode, l'adresse et les frais d'une commande.
class _FeuilleLivraison extends StatefulWidget {
  const _FeuilleLivraison({required this.commande, required this.boutique});

  final Commande commande;
  final Boutique boutique;

  @override
  State<_FeuilleLivraison> createState() => _FeuilleLivraisonState();
}

class _FeuilleLivraisonState extends State<_FeuilleLivraison> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _date = widget.commande.dateLivraison ?? DateUtils.dateOnly(DateTime.now());
  late ModeRemise _mode = widget.commande.modeRemise ?? ModeRemise.retrait;
  late final _adresse = TextEditingController(text: widget.commande.adresseLivraison);
  late final _frais = MontantSaisieController(
      devise: widget.boutique.devise,
      initial: widget.commande.fraisLivraison > 0 ? widget.commande.fraisLivraison : null);

  @override
  void dispose() {
    _adresse.dispose();
    _frais.dispose();
    super.dispose();
  }

  Future<void> _choisirDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 2),
      helpText: 'Date de livraison',
    );
    if (d != null) setState(() => _date = d);
  }

  void _valider() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      Livraison(
        date: _date,
        mode: _mode,
        adresse: _adresse.text.trim(),
        frais: _frais.enReference(widget.boutique.devise, widget.boutique.tauxUsdCdf) ?? 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          VallySpace.s4, 0, VallySpace.s4, VallySpace.s4 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Livraison', style: theme.textTheme.titleMedium),
            const SizedBox(height: VallySpace.s4),
            OutlinedButton.icon(
              onPressed: _choisirDate,
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text('${FormatDate.relatif(_date)} · ${FormatDate.court(_date)}'),
            ),
            const SizedBox(height: VallySpace.s4),
            SegmentedButton<ModeRemise>(
              segments: const [
                ButtonSegment(value: ModeRemise.retrait, label: Text('Retrait')),
                ButtonSegment(value: ModeRemise.livraison, label: Text('Livraison')),
              ],
              selected: {_mode},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            if (_mode == ModeRemise.livraison) ...[
              const SizedBox(height: VallySpace.s4),
              TextFormField(
                controller: _adresse,
                decoration: const InputDecoration(
                    labelText: 'Adresse de livraison', prefixIcon: Icon(Icons.place_outlined)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Indique où livrer.' : null,
              ),
              const SizedBox(height: VallySpace.s4),
              ChampMontant(
                controller: _frais,
                label: 'Frais de livraison',
                deviseReference: widget.boutique.devise,
                tauxUsdVersCdf: widget.boutique.tauxUsdCdf,
                obligatoire: false,
              ),
            ],
            const SizedBox(height: VallySpace.s6),
            FilledButton(onPressed: _valider, child: const Text('Enregistrer')),
          ],
        ),
      ),
    );
  }
}
