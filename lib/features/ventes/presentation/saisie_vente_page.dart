import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

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
import '../../stock/domain/article.dart';
import '../../stock/presentation/widgets/photo_article.dart';
import '../data/ventes_repository.dart';
import '../domain/commande.dart';
import '../domain/panier.dart';
import 'actions_commande.dart';
import 'widgets/badges_commande.dart';
import 'widgets/choix_article.dart';
import 'widgets/saisie_paiement.dart';

/// Comment le client règle au moment de la vente / commande.
enum _Reglement {
  tout('Tout payé'),
  avance('Avance'),
  rien('À crédit');

  const _Reglement(this.libelle);

  final String libelle;
}

/// Ligne en cours de saisie : quantité + prix (pré-rempli, modifiable).
class _Ligne {
  _Ligne(this.article, Devise devise)
      : prix = MontantSaisieController(devise: devise, initial: article.prixVenteHabituel);

  final Article article;
  final MontantSaisieController prix;
  int quantite = 1;

  LignePanier enPanier(Boutique b) => LignePanier(
        article: article,
        quantite: quantite,
        prixVendu: prix.enReference(b.devise, b.tauxUsdCdf),
      );
}

/// Nouvelle vente (au comptoir) ou nouvelle commande (à livrer plus tard).
class SaisieVentePage extends ConsumerStatefulWidget {
  const SaisieVentePage({super.key, required this.type});

  final TypeCommande type;

  @override
  ConsumerState<SaisieVentePage> createState() => _SaisieVentePageState();
}

class _SaisieVentePageState extends ConsumerState<SaisieVentePage> {
  final _formKey = GlobalKey<FormState>();
  late final Boutique _boutique = ref.read(boutiqueActiveProvider);
  bool get _commande => widget.type == TypeCommande.commande;

  final _lignes = <_Ligne>[];

  // Client
  Client? _client;
  final _clientNom = TextEditingController();
  final _clientTel = TextEditingController();

  // Livraison (commande)
  DateTime _dateLivraison = DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 1));
  ModeRemise _mode = ModeRemise.retrait;
  final _adresse = TextEditingController();
  late final MontantSaisieController _frais = MontantSaisieController(devise: _boutique.devise)
    ..addListener(_rafraichir);

  // Paiement
  late _Reglement _reglement = _commande ? _Reglement.rien : _Reglement.tout;
  late final MontantSaisieController _paiement = MontantSaisieController(devise: _boutique.devise);
  ModePaiement _modePaiement = ModePaiement.especes;

  final _note = TextEditingController();
  bool _noteVisible = false;
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  bool _enCours = false;

  @override
  void dispose() {
    for (final l in _lignes) {
      l.prix.dispose();
    }
    for (final c in [_clientNom, _clientTel, _adresse, _note]) {
      c.dispose();
    }
    _frais.dispose();
    _paiement.dispose();
    super.dispose();
  }

  void _rafraichir() {
    if (mounted) setState(() {});
    _suivreTotal();
  }

  double get _fraisLivraison => _commande && _mode == ModeRemise.livraison
      ? (_frais.enReference(_boutique.devise, _boutique.tauxUsdCdf) ?? 0)
      : 0;

  TotauxPanier get _totaux => TotauxPanier.depuis(_lignes.map((l) => l.enPanier(_boutique)));

  double get _aPayer => _totaux.total + _fraisLivraison;

  /// « Tout payé » : le montant suit le total (dans la devise choisie, CDF
  /// ou USD) tant qu'on ne l'a pas modifié à la main. Arrondi vers le haut
  /// pour qu'un paiement en dollars ne laisse jamais quelques francs dus.
  void _suivreTotal() {
    if (_reglement != _Reglement.tout || _paiement.modifieParUtilisateur) return;
    _paiement.afficherDepuisReference(
      _aPayer,
      reference: _boutique.devise,
      tauxUsdVersCdf: _boutique.tauxUsdCdf,
      arrondi: ArrondiDevise.haut,
    );
  }

  Future<void> _ajouterArticle() async {
    final article = await choisirArticle(
      context,
      devise: _boutique.devise,
      dejaChoisis: _lignes.map((l) => l.article.id).toSet(),
    );
    if (article == null) return;
    final ligne = _Ligne(article, _boutique.devise)..prix.addListener(_rafraichir);
    setState(() => _lignes.add(ligne));
    _suivreTotal();
  }

  void _retirer(_Ligne l) {
    setState(() => _lignes.remove(l));
    l.prix.dispose();
    _suivreTotal();
  }

  void _changerReglement(_Reglement r) {
    setState(() {
      _reglement = r;
      _paiement.vider();
    });
    _suivreTotal();
  }

  bool get _aUnClient => _client != null || _clientNom.text.trim().isNotEmpty;

  Future<void> _choisirDateLivraison() async {
    final maintenant = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _dateLivraison,
      firstDate: DateUtils.dateOnly(maintenant),
      lastDate: DateTime(maintenant.year + 2),
      helpText: 'Date de livraison',
    );
    if (d != null) setState(() => _dateLivraison = d);
  }

  Future<void> _choisirDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: _commande ? 'Date de la commande' : 'Date de la vente',
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _enregistrer() async {
    if (_lignes.isEmpty) {
      afficherErreur(context, 'Ajoute au moins un article.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if ((_commande || _reglement != _Reglement.tout) && !_aUnClient) {
      afficherErreur(
          context,
          _commande
              ? 'Indique le client de la commande.'
              : 'Indique le client pour suivre ce qu’il te doit.');
      return;
    }
    setState(() => _enCours = true);
    try {
      final id = await ref.read(ventesRepositoryProvider).creer(
            type: widget.type,
            lignes: _lignes.map((l) => l.enPanier(_boutique)).toList(),
            clientId: _client?.id,
            clientNom: _clientNom.text.trim(),
            clientTelephone: _clientTel.text.trim(),
            date: _date,
            note: _note.text.trim(),
            livraison: _commande
                ? Livraison(
                    date: _dateLivraison,
                    mode: _mode,
                    adresse: _adresse.text.trim(),
                    frais: _fraisLivraison,
                  )
                : null,
            paiement: _reglement == _Reglement.rien
                ? null
                : PaiementSaisi(
                    montantSaisi: _paiement.valeur!,
                    devise: _paiement.devise,
                    mode: _modePaiement,
                    date: _date,
                  ),
          );
      rafraichirVentes(ref);
      if (!mounted) return;
      afficherSucces(context, _commande ? 'Commande enregistrée.' : 'Vente enregistrée.');
      context.pushReplacement(_commande ? Routes.commande(id) : Routes.vente(id));
    } catch (e) {
      if (mounted) afficherErreur(context, e);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final devise = _boutique.devise;
    final totaux = _totaux;

    return Scaffold(
      appBar: AppBar(title: Text(_commande ? 'Nouvelle commande' : 'Nouvelle vente')),
      bottomNavigationBar: BarreAction(
        libelle: _commande ? 'Enregistrer' : 'Encaisser',
        icone: _commande ? Icons.check : Icons.point_of_sale,
        enCours: _enCours,
        onPressed: _enregistrer,
        resume: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Total · ${totaux.nbPieces} pièce${totaux.nbPieces > 1 ? 's' : ''}',
                style: theme.textTheme.bodySmall),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: MontantTexte(_aPayer, devise: devise,
                  style: theme.textTheme.titleMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()])),
            ),
            EquivalentDevise(
                montant: _aPayer, deviseReference: devise, tauxUsdVersCdf: _boutique.tauxUsdCdf),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(VallySpace.s4, VallySpace.s2, VallySpace.s4, VallySpace.s6),
          children: [
            // ─── Articles ───
            EnTeteSection('Articles',
                action: _lignes.isEmpty ? null : 'Ajouter', onAction: _ajouterArticle),
            if (_lignes.isEmpty)
              _AjouterPremierArticle(onTap: _ajouterArticle)
            else
              Card(
                child: Column(children: [
                  for (final (i, l) in _lignes.indexed) ...[
                    if (i > 0) const Divider(),
                    _LigneSaisie(
                      ligne: l,
                      boutique: _boutique,
                      onQuantite: (q) {
                        setState(() => l.quantite = q);
                        _suivreTotal();
                      },
                      onRetirer: () => _retirer(l),
                    ),
                  ],
                ]),
              ),
            if (_lignes.isNotEmpty && (totaux.ecart.abs() >= 0.005 || totaux.benefice != 0))
              Padding(
                padding: const EdgeInsets.only(top: VallySpace.s2, left: 4, right: 4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  TexteAvecMontants([
                    'Bénéfice prévu ',
                    spanMontant(context, totaux.benefice.abs(), devise,
                        sens: totaux.benefice >= 0 ? SensMontant.positif : SensMontant.negatif,
                        gras: true),
                  ]),
                  TexteEcart(ecart: totaux.ecart, devise: devise),
                ]),
              ),
            const SizedBox(height: VallySpace.s6),

            // ─── Client ───
            EnTeteSection('Client',
                sousTitre: _commande
                    ? null
                    : 'Facultatif si le client paie tout de suite'),
            ChampClient(
              nom: _clientNom,
              telephone: _clientTel,
              client: _client,
              obligatoire: _commande,
              onClient: (c) => setState(() => _client = c),
              onChange: () => setState(() {}),
            ),
            const SizedBox(height: VallySpace.s6),

            // ─── Livraison (commande) ───
            if (_commande) ...[
              const EnTeteSection('Livraison'),
              _ChoixDate(
                date: _dateLivraison,
                onDate: (d) => setState(() => _dateLivraison = d),
                onChoisir: _choisirDateLivraison,
              ),
              const SizedBox(height: VallySpace.s4),
              SegmentedButton<ModeRemise>(
                segments: const [
                  ButtonSegment(
                      value: ModeRemise.retrait,
                      icon: Icon(Icons.storefront_outlined, size: 18),
                      label: Text('Retrait')),
                  ButtonSegment(
                      value: ModeRemise.livraison,
                      icon: Icon(Icons.local_shipping_outlined, size: 18),
                      label: Text('Livraison')),
                ],
                selected: {_mode},
                showSelectedIcon: false,
                onSelectionChanged: (s) {
                  setState(() => _mode = s.first);
                  _suivreTotal();
                },
              ),
              if (_mode == ModeRemise.livraison) ...[
                const SizedBox(height: VallySpace.s4),
                TextFormField(
                  controller: _adresse,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Adresse de livraison',
                    prefixIcon: Icon(Icons.place_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Indique où livrer.'
                      : null,
                ),
                const SizedBox(height: VallySpace.s4),
                ChampMontant(
                  controller: _frais,
                  label: 'Frais de livraison',
                  aide: 'Ajoutés à ce que le client paie.',
                  deviseReference: devise,
                  tauxUsdVersCdf: _boutique.tauxUsdCdf,
                  obligatoire: false,
                ),
              ],
              const SizedBox(height: VallySpace.s6),
            ],

            // ─── Paiement ───
            const EnTeteSection('Paiement'),
            SegmentedButton<_Reglement>(
              segments: [
                for (final r in _Reglement.values)
                  ButtonSegment(value: r, label: Text(r.libelle)),
              ],
              selected: {_reglement},
              showSelectedIcon: false,
              onSelectionChanged: (s) => _changerReglement(s.first),
            ),
            if (_reglement == _Reglement.rien)
              Padding(
                padding: const EdgeInsets.only(top: VallySpace.s2),
                child: Text(
                  'Le client paiera plus tard. Tu retrouveras ce qu’il doit '
                  'dans sa fiche client.',
                  style: theme.textTheme.bodySmall,
                ),
              )
            else ...[
              const SizedBox(height: VallySpace.s4),
              ChampMontant(
                controller: _paiement,
                label: _reglement == _Reglement.tout ? 'Montant reçu' : 'Avance reçue',
                deviseReference: devise,
                tauxUsdVersCdf: _boutique.tauxUsdCdf,
                zeroAutorise: false,
              ),
              const SizedBox(height: VallySpace.s2),
              ChoixModePaiement(
                  mode: _modePaiement, onChanged: (m) => setState(() => _modePaiement = m)),
            ],
            const SizedBox(height: VallySpace.s6),

            // ─── Note et date ───
            if (_noteVisible)
              TextFormField(
                controller: _note,
                autofocus: true,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Note'),
              ),
            Wrap(spacing: VallySpace.s2, children: [
              if (!_noteVisible)
                TextButton.icon(
                  onPressed: () => setState(() => _noteVisible = true),
                  icon: const Icon(Icons.sticky_note_2_outlined, size: 18),
                  label: const Text('Ajouter une note'),
                ),
              TextButton.icon(
                onPressed: _choisirDate,
                icon: const Icon(Icons.event_outlined, size: 18),
                label: Text('${_commande ? 'Commande' : 'Vente'} du ${FormatDate.relatif(_date).toLowerCase()}'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _AjouterPremierArticle extends StatelessWidget {
  const _AjouterPremierArticle({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: VallySpace.s6),
          child: Column(children: [
            Icon(Icons.add_shopping_cart, color: theme.colorScheme.primary),
            const SizedBox(height: VallySpace.s2),
            Text('Ajouter un article',
                style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
          ]),
        ),
      ),
    );
  }
}

/// Raccourcis de date : Aujourd'hui, Demain, ou calendrier.
class _ChoixDate extends StatelessWidget {
  const _ChoixDate({required this.date, required this.onDate, required this.onChoisir});

  final DateTime date;
  final ValueChanged<DateTime> onDate;
  final VoidCallback onChoisir;

  @override
  Widget build(BuildContext context) {
    final aujourdhui = DateUtils.dateOnly(DateTime.now());
    final demain = aujourdhui.add(const Duration(days: 1));
    final autre = date != aujourdhui && date != demain;
    return Wrap(spacing: VallySpace.s2, runSpacing: VallySpace.s2, children: [
      ChoiceChip(
        label: const Text('Aujourd’hui'),
        selected: date == aujourdhui,
        onSelected: (_) => onDate(aujourdhui),
      ),
      ChoiceChip(
        label: const Text('Demain'),
        selected: date == demain,
        onSelected: (_) => onDate(demain),
      ),
      ChoiceChip(
        avatar: const Icon(Icons.event, size: 16),
        label: Text(autre ? FormatDate.relatif(date) : 'Autre date'),
        selected: autre,
        onSelected: (_) => onChoisir(),
      ),
    ]);
  }
}

/// Un article : quantité (− / +) et prix vendu modifiable.
class _LigneSaisie extends StatelessWidget {
  const _LigneSaisie({
    required this.ligne,
    required this.boutique,
    required this.onQuantite,
    required this.onRetirer,
  });

  final _Ligne ligne;
  final Boutique boutique;
  final ValueChanged<int> onQuantite;
  final VoidCallback onRetirer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = ligne.article;
    final panier = ligne.enPanier(boutique);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            PhotoArticle(chemin: a.photoChemin, taille: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.nom,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text('${a.description} · ${a.quantiteRestante} en stock',
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ]),
            ),
            IconButton(
              tooltip: 'Retirer',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, size: 20),
              onPressed: onRetirer,
            ),
          ]),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _Quantite(valeur: ligne.quantite, max: a.quantiteRestante, onChanged: onQuantite),
              const SizedBox(width: 12),
              Expanded(
                child: ChampMontant(
                  controller: ligne.prix,
                  label: 'Prix de la pièce',
                  deviseReference: boutique.devise,
                  tauxUsdVersCdf: boutique.tauxUsdCdf,
                ),
              ),
            ]),
          ),
          if (panier.ecart.abs() >= 0.005)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: TexteEcart(ecart: panier.ecart, devise: boutique.devise),
            ),
        ],
      ),
    );
  }
}

class _Quantite extends StatelessWidget {
  const _Quantite({required this.valeur, required this.max, required this.onChanged});

  final int valeur;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(VallyRadius.sm),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        color: theme.colorScheme.surfaceContainer,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          tooltip: 'Une de moins',
          visualDensity: VisualDensity.compact,
          iconSize: 18,
          icon: const Icon(Icons.remove),
          onPressed: valeur > 1 ? () => onChanged(valeur - 1) : null,
        ),
        SizedBox(
          width: 20,
          child: Text('$valeur',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall,
              semanticsLabel: 'Quantité $valeur'),
        ),
        IconButton(
          tooltip: 'Une de plus',
          visualDensity: VisualDensity.compact,
          iconSize: 18,
          icon: const Icon(Icons.add),
          onPressed: valeur < max ? () => onChanged(valeur + 1) : null,
        ),
      ]),
    );
  }
}

/// Client existant (recherche) ou nouveau client (nom + téléphone).
class ChampClient extends ConsumerStatefulWidget {
  const ChampClient({
    super.key,
    required this.nom,
    required this.telephone,
    required this.client,
    required this.onClient,
    this.onChange,
    this.obligatoire = false,
  });

  final TextEditingController nom;
  final TextEditingController telephone;
  final Client? client;
  final ValueChanged<Client?> onClient;
  final VoidCallback? onChange;
  final bool obligatoire;

  @override
  ConsumerState<ChampClient> createState() => _ChampClientState();
}

class _ChampClientState extends ConsumerState<ChampClient> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final client = widget.client;
    if (client != null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.person_outline),
          title: Text(client.nom),
          subtitle: client.telephone == null ? null : Text(client.telephone!),
          trailing: IconButton(
            tooltip: 'Changer de client',
            icon: const Icon(Icons.close),
            onPressed: () {
              widget.nom.clear();
              widget.onClient(null);
            },
          ),
        ),
      );
    }
    final clients = ref.watch(clientsProvider).value ?? const <Client>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      RawAutocomplete<Client>(
        textEditingController: widget.nom,
        focusNode: _focus,
        displayStringForOption: (c) => c.nom,
        optionsBuilder: (saisie) {
          final r = saisie.text.trim().toLowerCase();
          if (r.isEmpty) return const Iterable<Client>.empty();
          return clients.where((c) =>
              c.nom.toLowerCase().contains(r) || (c.telephone ?? '').contains(r));
        },
        onSelected: widget.onClient,
        fieldViewBuilder: (context, controleur, focus, _) => TextFormField(
          controller: controleur,
          focusNode: focus,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => widget.onChange?.call(),
          decoration: InputDecoration(
            labelText: widget.obligatoire ? 'Nom du client' : 'Nom du client (facultatif)',
            prefixIcon: const Icon(Icons.person_search_outlined),
          ),
          validator: widget.obligatoire
              ? (v) => (v == null || v.trim().isEmpty) ? 'Indique le client.' : null
              : null,
        ),
        optionsViewBuilder: (context, onChoisi, options) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(VallyRadius.sm),
            color: theme.colorScheme.surfaceContainer,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 400),
              child: ListView(shrinkWrap: true, padding: EdgeInsets.zero, children: [
                for (final c in options)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.person_outline),
                    title: Text(c.nom),
                    subtitle: c.telephone == null ? null : Text(c.telephone!),
                    onTap: () => onChoisi(c),
                  ),
              ]),
            ),
          ),
        ),
      ),
      ListenableBuilder(
        listenable: widget.nom,
        builder: (context, _) => widget.nom.text.trim().isEmpty
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.only(top: VallySpace.s2 + VallySpace.s1),
                child: TextFormField(
                  controller: widget.telephone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Téléphone (facultatif)',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
              ),
      ),
    ]);
  }
}
