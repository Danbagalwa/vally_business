import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format/dates.dart';
import '../../../core/format/montant.dart';
import '../../../core/widgets/champ_montant.dart';
import '../../../core/widgets/elements.dart';
import '../../../core/widgets/montant_texte.dart';
import '../../../core/widgets/page_erreur.dart';
import '../../../theme/app_theme.dart';
import '../../boutique/data/boutique_repository.dart';
import '../../boutique/domain/boutique.dart';
import '../data/stock_repository.dart';
import '../domain/article.dart';
import 'widgets/photo_article.dart';

const _categoriesCourantes = [
  'Robe', 'Pantalon', 'Chemise', 'Jupe', 'Ensemble', 'Haut', 'Chaussures',
  'Sac', 'Accessoire',
];

/// Ajout (articleId null) ou modification d'un article.
class ArticleFormPage extends ConsumerWidget {
  const ArticleFormPage({super.key, this.articleId});

  final String? articleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (articleId == null) return const _Formulaire(article: null);
    return ref.watch(articlesProvider).when(
          loading: () => const Scaffold(
              body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(
            appBar: AppBar(),
            body: PageErreur(
                erreur: e,
                onReessayer: () => ref.invalidate(articlesProvider)),
          ),
          data: (articles) {
            final article =
                articles.where((a) => a.id == articleId).firstOrNull;
            if (article == null) {
              return Scaffold(
                appBar: AppBar(),
                body: const Center(child: Text('Cet article n’existe plus.')),
              );
            }
            return _Formulaire(article: article);
          },
        );
  }
}

enum _ActionPhoto { appareil, galerie, retirer }

class _Formulaire extends ConsumerStatefulWidget {
  const _Formulaire({required this.article});

  final Article? article;

  @override
  ConsumerState<_Formulaire> createState() => _FormulaireState();
}

class _FormulaireState extends ConsumerState<_Formulaire> {
  final _formKey = GlobalKey<FormState>();
  late final Boutique _boutique;
  late final TextEditingController _nom, _categorie, _taille, _couleur,
      _quantite, _fournisseur;
  late final MontantSaisieController _prixAchat, _prixVente;
  late DateTime _dateAppro;
  late bool _pourEnfant;

  Uint8List? _nouvellePhoto;
  bool _photoRetiree = false;
  bool _enCours = false;

  Article? get _article => widget.article;
  bool get _modification => _article != null;

  @override
  void initState() {
    super.initState();
    _boutique = ref.read(boutiqueActiveProvider);
    final a = _article;
    _nom = TextEditingController(text: a?.nom);
    _categorie = TextEditingController(text: a?.categorie);
    _taille = TextEditingController(text: a?.taille);
    _couleur = TextEditingController(text: a?.couleur);
    _quantite = TextEditingController(text: a?.quantiteAchetee.toString());
    _fournisseur = TextEditingController(text: a?.fournisseur);
    _prixAchat = MontantSaisieController(
        devise: _boutique.devise, initial: a?.prixAchat);
    _prixVente = MontantSaisieController(
        devise: _boutique.devise, initial: a?.prixVenteHabituel);
    _dateAppro = a?.dateAppro ?? DateUtils.dateOnly(DateTime.now());
    _pourEnfant = a?.pourEnfant ?? false;
  }

  @override
  void dispose() {
    for (final c in [_nom, _categorie, _taille, _couleur, _quantite, _fournisseur]) {
      c.dispose();
    }
    _prixAchat.dispose();
    _prixVente.dispose();
    super.dispose();
  }

  double? _enReference(MontantSaisieController c) =>
      c.enReference(_boutique.devise, _boutique.tauxUsdCdf);

  Future<void> _choisirPhoto() async {
    final aPhoto = _nouvellePhoto != null ||
        (_article?.photoChemin != null && !_photoRetiree);
    final action = await showModalBottomSheet<_ActionPhoto>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(context, _ActionPhoto.appareil),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.pop(context, _ActionPhoto.galerie),
            ),
            if (aPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Retirer la photo'),
                onTap: () => Navigator.pop(context, _ActionPhoto.retirer),
              ),
          ],
        ),
      ),
    );
    if (action == null) return;
    if (action == _ActionPhoto.retirer) {
      setState(() {
        _nouvellePhoto = null;
        _photoRetiree = true;
      });
      return;
    }
    try {
      final fichier = await ImagePicker().pickImage(
        source: action == _ActionPhoto.appareil
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 80,
      );
      if (fichier == null) return;
      final octets = await fichier.readAsBytes();
      setState(() {
        _nouvellePhoto = octets;
        _photoRetiree = false;
      });
    } catch (e) {
      if (mounted) afficherErreur(context, e);
    }
  }

  Future<void> _choisirDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateAppro,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Date d’approvisionnement',
    );
    if (date != null) setState(() => _dateAppro = date);
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enCours = true);
    final repo = ref.read(stockRepositoryProvider);
    final saisie = ArticleSaisie(
      nom: _nom.text,
      categorie: _categorie.text,
      taille: _taille.text,
      couleur: _couleur.text,
      quantiteAchetee: int.parse(_quantite.text.trim()),
      prixAchat: _enReference(_prixAchat)!,
      prixVenteHabituel: _enReference(_prixVente)!,
      fournisseur: _fournisseur.text,
      dateAppro: _dateAppro,
      pourEnfant: _pourEnfant,
    );
    try {
      final id = _article?.id ?? await repo.ajouter(saisie);
      if (_modification) await repo.modifier(id, saisie);

      if (_nouvellePhoto != null) {
        await repo.remplacerPhoto(
          boutiqueId: _boutique.id,
          articleId: id,
          octets: _nouvellePhoto!,
          ancienChemin: _article?.photoChemin,
        );
      } else if (_photoRetiree && _article?.photoChemin != null) {
        await repo.retirerPhoto(id, _article!.photoChemin!);
      }

      ref.invalidate(articlesProvider);
      if (!mounted) return;
      afficherSucces(context,
          _modification ? 'Article enregistré.' : 'Article ajouté au stock.');
      context.pop();
    } catch (e) {
      // Si l'article a été créé mais pas la photo, la liste doit le montrer.
      ref.invalidate(articlesProvider);
      if (mounted) afficherErreur(context, e);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  Future<void> _supprimer() async {
    final article = _article!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cet article ?'),
        content: Text('« ${article.nom} » sera retiré du stock.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _enCours = true);
    try {
      await ref.read(stockRepositoryProvider).supprimer(article);
      ref.invalidate(articlesProvider);
      if (!mounted) return;
      afficherSucces(context, 'Article supprimé.');
      context.pop();
    } catch (e) {
      if (mounted) afficherErreur(context, e);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final article = _article;

    return Scaffold(
      appBar: AppBar(
        title: Text(_modification ? 'Modifier l’article' : 'Nouvel article'),
        actions: [
          if (_modification)
            IconButton(
              tooltip: 'Supprimer',
              icon: const Icon(Icons.delete_outline),
              onPressed: _enCours ? null : _supprimer,
            ),
        ],
      ),
      bottomNavigationBar: BarreAction(
        libelle: _modification ? 'Enregistrer' : 'Ajouter au stock',
        icone: Icons.check,
        enCours: _enCours,
        onPressed: _enregistrer,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(VallySpace.s4, VallySpace.s2, VallySpace.s4, VallySpace.s6),
          children: [
            if (article != null) ...[
              _CarteVentes(article: article, devise: _boutique.devise),
              const SizedBox(height: VallySpace.s4),
            ],
            Center(child: _photo(theme)),
            const SizedBox(height: VallySpace.s4),
            _Section('Article'),
            Card(
              child: SwitchListTile(
                value: _pourEnfant,
                onChanged: (v) => setState(() => _pourEnfant = v),
                secondary: const Icon(Icons.child_care),
                title: const Text('Article pour enfant'),
                subtitle: Text(_pourEnfant ? 'Tailles en âge (2 ans, 6-12 mois…)' : 'Adulte'),
              ),
            ),
            const SizedBox(height: VallySpace.s4),
            TextFormField(
              controller: _nom,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                  labelText: 'Nom', hintText: 'Ex. : Robe pagne fleurie'),
              validator: _obligatoire('Donne un nom à l’article.'),
            ),
            const SizedBox(height: VallySpace.s4),
            _ChampAvecSuggestions(
              controller: _categorie,
              label: 'Catégorie',
              suggestions: {
                ..._categoriesCourantes,
                ...categoriesDe(ref.read(articlesProvider).value ?? const []),
              }.toList(),
              validator: _obligatoire('Choisis une catégorie.'),
            ),
            const SizedBox(height: VallySpace.s4),
            _ChampAvecSuggestions(
              controller: _taille,
              label: 'Taille',
              suggestions: _pourEnfant ? taillesEnfant : taillesAdulte,
              validator: _obligatoire('Indique la taille (ou « Unique »).'),
            ),
            const SizedBox(height: VallySpace.s4),
            TextFormField(
              controller: _couleur,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration:
                  const InputDecoration(labelText: 'Couleur (facultatif)'),
            ),
            const SizedBox(height: VallySpace.s6),
            _Section('Achat'),
            TextFormField(
              controller: _quantite,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                  fontFeatures: [FontFeature.tabularFigures()]),
              decoration: InputDecoration(
                labelText: 'Quantité achetée',
                helperText: article != null && article.quantiteVendue > 0
                    ? 'Déjà vendu : ${article.quantiteVendue}'
                    : null,
              ),
              validator: (v) {
                final q = int.tryParse(v?.trim() ?? '');
                if (q == null || q <= 0) return 'Saisis au moins 1 pièce.';
                if (article != null && q < article.quantiteVendue) {
                  return 'Tu en as déjà vendu ${article.quantiteVendue}.';
                }
                return null;
              },
            ),
            const SizedBox(height: VallySpace.s4),
            ChampMontant(
              controller: _prixAchat,
              label: 'Prix d’achat unitaire',
              aide: 'Tous frais compris : transport, douane, emballage.',
              deviseReference: _boutique.devise,
              tauxUsdVersCdf: _boutique.tauxUsdCdf,
            ),
            const SizedBox(height: VallySpace.s4),
            TextFormField(
              controller: _fournisseur,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration:
                  const InputDecoration(labelText: 'Fournisseur (facultatif)'),
            ),
            const SizedBox(height: VallySpace.s4),
            InkWell(
              onTap: _choisirDate,
              borderRadius: BorderRadius.circular(VallyRadius.sm),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date d’approvisionnement',
                  suffixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(FormatDate.court(_dateAppro)),
              ),
            ),
            const SizedBox(height: VallySpace.s6),
            _Section('Vente'),
            ChampMontant(
              controller: _prixVente,
              label: 'Prix de vente habituel',
              aide: 'Pré-rempli à chaque vente, tu pourras le changer.',
              deviseReference: _boutique.devise,
              tauxUsdVersCdf: _boutique.tauxUsdCdf,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: VallySpace.s2),
            ListenableBuilder(
              listenable: Listenable.merge([_prixAchat, _prixVente]),
              builder: (context, _) => _Marge(
                achat: _enReference(_prixAchat),
                vente: _enReference(_prixVente),
                devise: _boutique.devise,
              ),
            ),
            const SizedBox(height: VallySpace.s6),
          ],
        ),
      ),
    );
  }

  Widget _photo(ThemeData theme) {
    const taille = 120.0;
    final Widget image;
    if (_nouvellePhoto != null) {
      image = ClipRRect(
        borderRadius: BorderRadius.circular(VallyRadius.md),
        child: Image.memory(_nouvellePhoto!,
            width: taille, height: taille, fit: BoxFit.cover),
      );
    } else {
      image = PhotoArticle(
        chemin: _photoRetiree ? null : _article?.photoChemin,
        taille: taille,
      );
    }
    return Column(
      children: [
        GestureDetector(onTap: _choisirPhoto, child: image),
        TextButton.icon(
          onPressed: _choisirPhoto,
          icon: const Icon(Icons.photo_camera_outlined),
          label: const Text('Photo (facultatif)'),
        ),
      ],
    );
  }

  FormFieldValidator<String> _obligatoire(String message) =>
      (v) => (v == null || v.trim().isEmpty) ? message : null;
}

class _Section extends StatelessWidget {
  const _Section(this.titre);

  final String titre;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: VallySpace.s2 + VallySpace.s1),
      child: Text(titre, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

/// Champ texte avec des pastilles de suggestions en dessous.
class _ChampAvecSuggestions extends StatelessWidget {
  const _ChampAvecSuggestions({
    required this.controller,
    required this.label,
    required this.suggestions,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final List<String> suggestions;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: controller,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(labelText: label),
            validator: validator,
          ),
          const SizedBox(height: VallySpace.s2),
          Wrap(
            spacing: VallySpace.s2,
            runSpacing: VallySpace.s2,
            children: [
              for (final s in suggestions)
                ChoiceChip(
                  label: Text(s),
                  selected: controller.text.trim() == s,
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => controller.text = s,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// « Marge prévue : + 5 000 CDF par pièce » (ou vente à perte).
class _Marge extends StatelessWidget {
  const _Marge({required this.achat, required this.vente, required this.devise});

  final double? achat;
  final double? vente;
  final Devise devise;

  @override
  Widget build(BuildContext context) {
    if (achat == null || vente == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final vally = theme.extension<VallyColors>()!;
    final marge = vente! - achat!;
    final perte = marge < 0;
    return Row(
      children: [
        Icon(perte ? Icons.warning_amber_rounded : Icons.trending_up,
            size: 18, color: perte ? vally.attention : vally.benefice),
        const SizedBox(width: VallySpace.s2),
        Text(perte ? 'Vente à perte : ' : 'Marge prévue : ',
            style: theme.textTheme.bodyMedium),
        MontantTexte(marge.abs(),
            devise: devise,
            sens: perte ? SensMontant.negatif : SensMontant.positif,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        Text(' par pièce', style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

/// En modification : ce que l'article a déjà rapporté.
class _CarteVentes extends StatelessWidget {
  const _CarteVentes({required this.article, required this.devise});

  final Article article;
  final Devise devise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget bloc(String libelle, Widget valeur) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(libelle, style: theme.textTheme.bodySmall),
              const SizedBox(height: VallySpace.s1),
              FittedBox(fit: BoxFit.scaleDown, child: valeur),
            ],
          ),
        );
    final chiffres = theme.textTheme.titleSmall;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(VallySpace.s4),
        child: Row(
          children: [
            bloc('Vendu', Text('${article.quantiteVendue}', style: chiffres)),
            bloc('Restant', Text('${article.quantiteRestante}', style: chiffres)),
            bloc('Valeur restante',
                MontantTexte(article.valeurStockRestant, devise: devise)),
          ],
        ),
      ),
    );
  }
}
