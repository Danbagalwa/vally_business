import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format/dates.dart';
import '../../../core/format/montant.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/champ_montant.dart';
import '../../../core/widgets/montant_texte.dart';
import '../../../core/widgets/page_erreur.dart';
import '../../../theme/app_theme.dart';
import '../../boutique/data/boutique_repository.dart';
import '../../boutique/domain/boutique.dart';
import '../../stock/data/stock_repository.dart';
import '../../stock/domain/article.dart';
import '../../stock/presentation/widgets/photo_article.dart';
import '../data/ventes_repository.dart';
import '../domain/commande.dart';
import '../domain/panier.dart';
import 'widgets/badges_commande.dart';
import 'widgets/choix_article.dart';
import 'widgets/saisie_paiement.dart';

/// Ligne en cours de saisie : quantité + prix (pré-rempli, modifiable).
class _Ligne {
  _Ligne(this.article, Devise devise)
      : prix = MontantSaisieController(
            devise: devise, initial: article.prixVenteHabituel);

  final Article article;
  final MontantSaisieController prix;
  int quantite = 1;

  LignePanier enPanier(Boutique b) => LignePanier(
        article: article,
        quantite: quantite,
        prixVendu: prix.enReference(b.devise, b.tauxUsdCdf),
      );
}

/// Nouvelle vente : client, articles (prix modifiable), paiement immédiat.
class NouvelleVentePage extends ConsumerStatefulWidget {
  const NouvelleVentePage({super.key});

  @override
  ConsumerState<NouvelleVentePage> createState() => _NouvelleVentePageState();
}

class _NouvelleVentePageState extends ConsumerState<NouvelleVentePage> {
  final _formKey = GlobalKey<FormState>();
  late final Boutique _boutique = ref.read(boutiqueActiveProvider);

  final _lignes = <_Ligne>[];
  Client? _client;
  final _clientNom = TextEditingController();
  final _clientTel = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateUtils.dateOnly(DateTime.now());

  bool _payeMaintenant = false;
  bool _montantPaiementTouche = false;
  late final MontantSaisieController _paiement =
      MontantSaisieController(devise: _boutique.devise);
  ModePaiement _mode = ModePaiement.especes;

  bool _enCours = false;

  @override
  void initState() {
    super.initState();
    _paiement.texte.addListener(() => _montantPaiementTouche = true);
  }

  @override
  void dispose() {
    for (final l in _lignes) {
      l.prix.dispose();
    }
    _clientNom.dispose();
    _clientTel.dispose();
    _note.dispose();
    _paiement.dispose();
    super.dispose();
  }

  TotauxPanier get _totaux =>
      TotauxPanier.depuis(_lignes.map((l) => l.enPanier(_boutique)));

  Future<void> _ajouterArticle() async {
    final article = await choisirArticle(
      context,
      devise: _boutique.devise,
      dejaChoisis: _lignes.map((l) => l.article.id).toSet(),
    );
    if (article == null) return;
    final ligne = _Ligne(article, _boutique.devise);
    ligne.prix.addListener(_recalculer);
    setState(() => _lignes.add(ligne));
    _recalculer();
  }

  void _retirer(_Ligne l) {
    setState(() => _lignes.remove(l));
    l.prix.dispose();
    _recalculer();
  }

  /// Tant que la personne n'a pas modifié le montant payé, il suit le total.
  void _recalculer() {
    if (!mounted) return;
    setState(() {});
    if (!_montantPaiementTouche) {
      final total = _totaux.total;
      _paiement.devise = _boutique.devise;
      _paiement.texte.text =
          total > 0 ? FormatMontant.pourSaisie(total, _boutique.devise) : '';
      _montantPaiementTouche = false;
    }
  }

  Future<void> _choisirDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Date de la vente',
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _enregistrer() async {
    if (_lignes.isEmpty) {
      afficherErreur(context, 'Ajoute au moins un article à la vente.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enCours = true);
    try {
      final id = await ref.read(ventesRepositoryProvider).creer(
            lignes: _lignes.map((l) => l.enPanier(_boutique)).toList(),
            clientId: _client?.id,
            clientNom: _clientNom.text.trim(),
            clientTelephone: _clientTel.text.trim(),
            date: _date,
            note: _note.text.trim(),
            paiement: _payeMaintenant
                ? PaiementSaisi(
                    montantSaisi: _paiement.valeur!,
                    devise: _paiement.devise,
                    mode: _mode,
                    date: _date,
                  )
                : null,
          );
      ref.invalidate(commandesProvider);
      ref.invalidate(articlesProvider);
      if (!mounted) return;
      afficherSucces(context, 'Vente enregistrée.');
      context.pushReplacement(Routes.commande(id));
    } catch (e) {
      if (mounted) afficherErreur(context, e);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totaux = _totaux;
    final devise = _boutique.devise;

    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle vente')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(VallySpace.s4),
          children: [
            _Titre('Client'),
            _ChampClient(
              nom: _clientNom,
              telephone: _clientTel,
              client: _client,
              onClient: (c) => setState(() => _client = c),
            ),
            const SizedBox(height: VallySpace.s4),
            OutlinedButton.icon(
              onPressed: _choisirDate,
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text('Vente du ${FormatDate.court(_date)}'),
            ),
            const SizedBox(height: VallySpace.s6),
            _Titre('Articles'),
            for (final l in _lignes) ...[
              _CarteLigne(
                ligne: l,
                boutique: _boutique,
                onQuantite: (q) {
                  setState(() => l.quantite = q);
                  _recalculer();
                },
                onRetirer: () => _retirer(l),
              ),
              const SizedBox(height: VallySpace.s2),
            ],
            OutlinedButton.icon(
              onPressed: _ajouterArticle,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un article'),
            ),
            if (_lignes.isNotEmpty) ...[
              const SizedBox(height: VallySpace.s4),
              _CarteTotaux(totaux: totaux, devise: devise),
            ],
            const SizedBox(height: VallySpace.s6),
            _Titre('Paiement'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Le client paie maintenant'),
              subtitle: const Text('Tout ou une avance. Tu pourras ajouter '
                  'd’autres paiements plus tard.'),
              value: _payeMaintenant,
              onChanged: (v) => setState(() => _payeMaintenant = v),
            ),
            if (_payeMaintenant) ...[
              const SizedBox(height: VallySpace.s2),
              ChampMontant(
                controller: _paiement,
                label: 'Montant reçu',
                deviseReference: devise,
                tauxUsdVersCdf: _boutique.tauxUsdCdf,
                zeroAutorise: false,
              ),
              const SizedBox(height: VallySpace.s4),
              ChoixModePaiement(
                  mode: _mode, onChanged: (m) => setState(() => _mode = m)),
            ],
            const SizedBox(height: VallySpace.s6),
            TextFormField(
              controller: _note,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Note (facultatif)',
                  hintText: 'Ex. : livrer samedi'),
            ),
            const SizedBox(height: VallySpace.s6),
            FilledButton(
              onPressed: _enCours ? null : _enregistrer,
              child: _enCours
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Enregistrer la vente'),
            ),
            const SizedBox(height: VallySpace.s6),
          ],
        ),
      ),
    );
  }
}

class _Titre extends StatelessWidget {
  const _Titre(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: VallySpace.s2),
        child: Text(texte, style: Theme.of(context).textTheme.titleMedium),
      );
}

/// Client existant (recherche) ou nouveau client (nom + téléphone).
/// Vide = client de passage.
class _ChampClient extends ConsumerStatefulWidget {
  const _ChampClient({
    required this.nom,
    required this.telephone,
    required this.client,
    required this.onClient,
  });

  final TextEditingController nom;
  final TextEditingController telephone;
  final Client? client;
  final ValueChanged<Client?> onClient;

  @override
  ConsumerState<_ChampClient> createState() => _ChampClientState();
}

class _ChampClientState extends ConsumerState<_ChampClient> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nom = widget.nom;
    final telephone = widget.telephone;
    final client = widget.client;
    final onClient = widget.onClient;
    final theme = Theme.of(context);
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
              nom.clear();
              onClient(null);
            },
          ),
        ),
      );
    }
    final clients = ref.watch(clientsProvider).value ?? const <Client>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RawAutocomplete<Client>(
          textEditingController: nom,
          focusNode: _focus,
          displayStringForOption: (c) => c.nom,
          optionsBuilder: (saisie) {
            final r = saisie.text.trim().toLowerCase();
            if (r.isEmpty) return const Iterable<Client>.empty();
            return clients.where((c) =>
                c.nom.toLowerCase().contains(r) ||
                (c.telephone ?? '').contains(r));
          },
          onSelected: onClient,
          fieldViewBuilder: (context, controleur, focus, onSoumis) =>
              TextFormField(
            controller: controleur,
            focusNode: focus,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nom du client',
              helperText: 'Laisse vide pour un client de passage.',
              prefixIcon: Icon(Icons.person_search_outlined),
            ),
          ),
          optionsViewBuilder: (context, onChoisi, options) => Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(VallyRadius.sm),
              color: theme.colorScheme.surfaceContainer,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240, maxWidth: 400),
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [
                    for (final c in options)
                      ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(c.nom),
                        subtitle: c.telephone == null ? null : Text(c.telephone!),
                        onTap: () => onChoisi(c),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        ListenableBuilder(
          listenable: nom,
          builder: (context, _) => nom.text.trim().isEmpty
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: VallySpace.s4),
                  child: TextFormField(
                    controller: telephone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Téléphone (facultatif)',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

/// Un article de la vente : quantité (− / +) et prix vendu modifiable.
class _CarteLigne extends StatelessWidget {
  const _CarteLigne({
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
    final max = a.quantiteRestante;
    final panier = ligne.enPanier(boutique);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(VallySpace.s4 - VallySpace.s1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                PhotoArticle(chemin: a.photoChemin, taille: 44),
                const SizedBox(width: VallySpace.s4 - VallySpace.s1),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.nom,
                          style: theme.textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text('${a.description} · $max en stock',
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Retirer de la vente',
                  icon: const Icon(Icons.close),
                  onPressed: onRetirer,
                ),
              ],
            ),
            const SizedBox(height: VallySpace.s4 - VallySpace.s1),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Quantite(
                  valeur: ligne.quantite,
                  max: max,
                  onChanged: onQuantite,
                ),
                const SizedBox(width: VallySpace.s4 - VallySpace.s1),
                Expanded(
                  child: ChampMontant(
                    controller: ligne.prix,
                    label: 'Prix vendu (pièce)',
                    deviseReference: boutique.devise,
                    tauxUsdVersCdf: boutique.tauxUsdCdf,
                  ),
                ),
              ],
            ),
            const SizedBox(height: VallySpace.s2),
            TexteEcart(ecart: panier.ecart, devise: boutique.devise),
          ],
        ),
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
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(VallyRadius.sm),
        border: Border.all(color: theme.colorScheme.outline),
        color: theme.colorScheme.surfaceContainer,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Une de moins',
            icon: const Icon(Icons.remove),
            onPressed: valeur > 1 ? () => onChanged(valeur - 1) : null,
          ),
          Text('$valeur',
              style: theme.textTheme.titleSmall,
              semanticsLabel: 'Quantité $valeur'),
          IconButton(
            tooltip: 'Une de plus',
            icon: const Icon(Icons.add),
            onPressed: valeur < max ? () => onChanged(valeur + 1) : null,
          ),
        ],
      ),
    );
  }
}

/// Total, bénéfice prévu et écart avec les prix habituels.
class _CarteTotaux extends StatelessWidget {
  const _CarteTotaux({required this.totaux, required this.devise});

  final TotauxPanier totaux;
  final Devise devise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget ligne(String libelle, Widget valeur) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Expanded(child: Text(libelle, style: theme.textTheme.bodyMedium)),
              valeur,
            ],
          ),
        );
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(VallySpace.s4),
        child: Column(
          children: [
            ligne(
              'Total (${totaux.nbPieces} pièce${totaux.nbPieces > 1 ? 's' : ''})',
              MontantTexte(totaux.total,
                  devise: devise, style: theme.textTheme.titleMedium),
            ),
            ligne(
              'Bénéfice prévu',
              MontantTexte(totaux.benefice.abs(),
                  devise: devise,
                  sens: totaux.benefice >= 0
                      ? SensMontant.positif
                      : SensMontant.negatif),
            ),
            if (totaux.ecart.abs() >= 0.005)
              Align(
                alignment: Alignment.centerRight,
                child: TexteEcart(ecart: totaux.ecart, devise: devise),
              ),
          ],
        ),
      ),
    );
  }
}
