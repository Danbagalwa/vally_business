import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format/dates.dart';
import '../../../core/format/montant.dart';
import '../../../core/format/texte.dart';
import '../../../core/images.dart';
import '../../../core/rayon.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/carnet.dart';
import '../../../core/widgets/champ_montant.dart';
import '../../../core/widgets/elements.dart';
import '../../../core/widgets/montant_texte.dart';
import '../../../core/widgets/page_erreur.dart';
import '../../../theme/app_theme.dart';
import '../../boutique/data/boutique_repository.dart';
import '../../boutique/domain/boutique.dart';
import '../data/stock_repository.dart';
import '../domain/article.dart';
import 'widgets/feuille_rachat.dart';
import 'widgets/photo_article.dart';

const _categoriesCourantes = [
  'Robe', 'Pantalon', 'Chemise', 'Jupe', 'Ensemble', 'Haut', 'Chaussures',
  'Sac', 'Accessoire',
];

/// Nouvel article (articleId null), ou fiche d'un article : ce qu'il en
/// reste, le racheter, ses achats, et ses informations à corriger.
class ArticleFormPage extends ConsumerWidget {
  const ArticleFormPage({super.key, this.articleId, this.nomPropose});

  final String? articleId;

  /// Nouvel article : nom déjà tapé (depuis la recherche de « Réapprovisionner »).
  final String? nomPropose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (articleId == null) return _Formulaire(article: null, nomPropose: nomPropose);
    return ref.watch(articlesProvider).when(
          skipLoadingOnRefresh: true,
          loading: () => Scaffold(
            appBar: AppBar(),
            body: const ListeSquelette(avecFiltres: false, lignes: 4),
          ),
          error: (e, _) => Scaffold(
            appBar: AppBar(),
            body: PageErreur(erreur: e, onReessayer: () => ref.invalidate(articlesProvider)),
          ),
          data: (articles) {
            final article = articles.where((a) => a.id == articleId).firstOrNull;
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
  const _Formulaire({required this.article, this.nomPropose});

  final Article? article;
  final String? nomPropose;

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
  late Rayon _rayon;

  bool get _parfum => _rayon == Rayon.parfums;

  PhotoCompressee? _nouvellePhoto;
  bool _compression = false;
  bool _photoRetiree = false;
  bool _enCours = false;

  Article? get _article => widget.article;
  bool get _modification => _article != null;

  /// Déjà racheté : quantité et prix ne se corrigent plus ici (historique).
  bool get _achatFige => _article?.dejaRachete ?? false;

  @override
  void initState() {
    super.initState();
    _boutique = ref.read(boutiqueActiveProvider);
    final a = _article;
    _nom = TextEditingController(text: a?.nom ?? widget.nomPropose);
    _categorie = TextEditingController(text: a?.categorie);
    _taille = TextEditingController(text: a?.taille);
    _couleur = TextEditingController(text: a?.couleur);
    _quantite = TextEditingController(text: a?.quantiteAchetee.toString());
    _fournisseur = TextEditingController(text: a?.fournisseur);
    _prixAchat = MontantSaisieController(devise: _boutique.devise, initial: a?.prixAchat);
    _prixVente = MontantSaisieController(devise: _boutique.devise, initial: a?.prixVenteHabituel);
    _dateAppro = a?.dateAppro ?? DateUtils.dateOnly(DateTime.now());
    _pourEnfant = a?.pourEnfant ?? false;
    // Nouvel article : le rayon affiché dans l'appli.
    _rayon = a?.rayon ?? ref.read(rayonProvider);
  }

  @override
  void didUpdateWidget(covariant _Formulaire ancien) {
    super.didUpdateWidget(ancien);
    final avant = ancien.article, apres = widget.article;
    if (avant == null || apres == null) return;
    // Après un rachat (ou son retrait), l'achat a changé en base : on suit.
    if (avant.nbAchats != apres.nbAchats ||
        avant.quantiteAchetee != apres.quantiteAchetee ||
        avant.prixAchat != apres.prixAchat) {
      _quantite.text = '${apres.quantiteAchetee}';
      _prixAchat.afficherDepuisReference(apres.prixAchat,
          reference: _boutique.devise, tauxUsdVersCdf: _boutique.tauxUsdCdf);
      _dateAppro = apres.dateAppro;
      if (_fournisseur.text.trim() == (avant.fournisseur ?? '')) {
        _fournisseur.text = apres.fournisseur ?? '';
      }
    }
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
    final aPhoto = _nouvellePhoto != null || (_article?.photoChemin != null && !_photoRetiree);
    final action = await showModalBottomSheet<_ActionPhoto>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
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
        ]),
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
        source: action == _ActionPhoto.appareil ? ImageSource.camera : ImageSource.gallery,
        // Première réduction à la prise de vue, puis compression WebP.
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );
      if (fichier == null) return;
      setState(() => _compression = true);
      final photo = await compresserPhoto(await fichier.readAsBytes());
      if (!mounted) return;
      setState(() {
        _nouvellePhoto = photo;
        _photoRetiree = false;
      });
    } catch (e) {
      if (mounted) afficherErreur(context, e);
    } finally {
      if (mounted) setState(() => _compression = false);
    }
  }

  Future<void> _choisirDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateAppro,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Date d’achat',
    );
    if (date != null) setState(() => _dateAppro = date);
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enCours = true);
    final repo = ref.read(stockRepositoryProvider);
    final a = _article;
    // En modification, un prix qu'on n'a pas touché ne change pas (pas
    // d'arrondi d'affichage renvoyé en base) ; un article déjà racheté
    // garde l'achat tenu par son historique.
    final saisie = ArticleSaisie(
      nom: _nom.text,
      categorie: _categorie.text,
      taille: _taille.text,
      couleur: _couleur.text,
      quantiteAchetee: _achatFige ? a!.quantiteAchetee : int.parse(_quantite.text.trim()),
      prixAchat: a != null && (_achatFige || !_prixAchat.modifieParUtilisateur)
          ? a.prixAchat
          : _enReference(_prixAchat)!,
      prixVenteHabituel: a != null && !_prixVente.modifieParUtilisateur
          ? a.prixVenteHabituel
          : _enReference(_prixVente)!,
      fournisseur: _fournisseur.text,
      dateAppro: _achatFige ? a!.dateAppro : _dateAppro,
      pourEnfant: _pourEnfant,
      rayon: _rayon,
    );
    try {
      final id = a?.id ?? await repo.ajouter(saisie);
      if (_modification) await repo.modifier(id, saisie);

      if (_nouvellePhoto != null) {
        await repo.remplacerPhoto(
          boutiqueId: _boutique.id,
          articleId: id,
          photo: _nouvellePhoto!,
          ancienChemin: a?.photoChemin,
        );
      } else if (_photoRetiree && a?.photoChemin != null) {
        await repo.retirerPhoto(id, a!.photoChemin!);
      }

      ref.invalidate(articlesProvider);
      if (!mounted) return;
      afficherSucces(context, _modification ? 'Article enregistré.' : 'Article ajouté au stock.');
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
    final ok = await confirmer(
      context,
      titre: 'Supprimer cet article ?',
      message: '« ${article.nom} » sera retiré du stock.',
      bouton: 'Supprimer',
      destructif: true,
    );
    if (!ok || !mounted) return;
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

  /// L'article existe déjà : on le rachète au lieu d'en créer un deuxième.
  /// Un seul article de ce nom : la feuille « Racheter » directement, puis
  /// retour au stock. Plusieurs (tailles) : la page « Réapprovisionner ».
  Future<void> _reapprovisionnerPlutot(List<Article> memes) async {
    if (memes.length == 1) {
      final rachat = await racheterArticle(context, ref, memes.single);
      if (rachat != null && mounted) context.pop();
      return;
    }
    context.pushReplacement('${Routes.reapprovisionner}?q=${Uri.encodeQueryComponent(_nom.text.trim())}');
  }

  /// Erreur de saisie dans le dernier rachat : on le retire, puis on le refait.
  Future<void> _retirerRachat(Achat achat) async {
    final q = achat.quantite;
    final ok = await confirmer(
      context,
      titre: 'Retirer ce rachat ?',
      message: '${q > 1 ? 'Les ${pieces(q)} rachetées' : 'La pièce rachetée'} '
          '${FormatDate.ilYa(achat.date)} ${q > 1 ? 'sortent' : 'sort'} du stock, et le coût '
          'd’une pièce revient à ce qu’il était. Tu pourras refaire le rachat avec les bons chiffres.',
      bouton: 'Retirer',
      destructif: true,
    );
    if (!ok || !mounted) return;
    setState(() => _enCours = true);
    try {
      await ref.read(stockRepositoryProvider).annulerDernierRachat(_article!.id);
      ref.invalidate(articlesProvider);
      if (mounted) afficherSucces(context, 'Rachat retiré.');
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
    final devise = _boutique.devise;
    final dejaVendu = article?.quantiteVendue ?? 0;
    final existants = ref.watch(articlesProvider).value ?? const <Article>[];
    const marge = EdgeInsets.fromLTRB(2, 24, 2, 10);

    return Scaffold(
      appBar: AppBar(
        title: Text(article?.nom ?? 'Nouvel article', maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (_modification)
            IconButton(
              tooltip: 'Supprimer l’article',
              icon: const Icon(Icons.delete_outline),
              onPressed: _enCours ? null : _supprimer,
            ),
        ],
      ),
      bottomNavigationBar: BarreAction(
        libelle: _modification ? 'Enregistrer' : 'Ajouter au stock',
        icone: Icons.check,
        enCours: _enCours || _compression,
        onPressed: _enregistrer,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(VallySpace.s4, 4, VallySpace.s4, VallySpace.s6),
          children: [
            if (article != null) ...[
              _EtatArticle(
                article: article,
                devise: devise,
                onRacheter: _enCours ? null : () => racheterArticle(context, ref, article),
              ),
              const SizedBox(height: 16),
            ] else
              const SizedBox(height: 8),
            Center(child: _photo()),

            // ─── L'article ───
            const TitreSection('L’article', taille: 16, marge: marge),
            // Rayon : habits ou parfums, comptés à part. Figé une fois vendu.
            Text('Rayon',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              for (final r in Rayon.values)
                FiltrePastille(
                  libelle: r.libelle,
                  icone: r.icone,
                  actif: _rayon == r,
                  onTap: () {
                    if (dejaVendu > 0 && r != _rayon) {
                      afficherErreur(context, 'Cet article a déjà été vendu : il reste dans son rayon.');
                      return;
                    }
                    setState(() {
                      _rayon = r;
                      if (r == Rayon.parfums) _pourEnfant = false;
                    });
                  },
                ),
            ]),
            if (!_parfum) ...[
              const SizedBox(height: 16),
              Text('Pour qui ?',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                FiltrePastille(
                  libelle: 'Adulte',
                  actif: !_pourEnfant,
                  onTap: () => setState(() => _pourEnfant = false),
                ),
                FiltrePastille(
                  libelle: 'Enfant',
                  icone: Icons.child_care,
                  actif: _pourEnfant,
                  onTap: () => setState(() => _pourEnfant = true),
                ),
              ]),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _nom,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                  labelText: 'Nom', hintText: _parfum ? 'Ex. : Oud royal' : 'Ex. : Robe pagne fleurie'),
              validator: _obligatoire('Donne un nom à l’article.'),
            ),
            // Nouvel article dont le nom existe déjà : sans doute un rachat.
            if (!_modification)
              ListenableBuilder(
                listenable: _nom,
                builder: (context, _) => _DejaEnStock(
                  nom: _nom.text,
                  articles: existants,
                  onReapprovisionner: _reapprovisionnerPlutot,
                ),
              ),
            const SizedBox(height: VallySpace.s4),
            _ChampAvecSuggestions(
              controller: _categorie,
              label: 'Catégorie',
              suggestions: {
                ...(_parfum ? categoriesParfums : _categoriesCourantes),
                ...categoriesDe(existants.where((a) => a.rayon == _rayon)),
              }.toList(),
              validator: _obligatoire('Choisis une catégorie.'),
            ),
            const SizedBox(height: VallySpace.s4),
            _ChampAvecSuggestions(
              controller: _taille,
              label: _parfum ? 'Contenance' : (_pourEnfant ? 'Taille (âge)' : 'Taille'),
              suggestions: _parfum ? contenancesParfums : (_pourEnfant ? taillesEnfant : taillesAdulte),
              validator: _obligatoire(_parfum ? 'Indique la contenance (ex. : 100 ml).' : 'Indique la taille (ou « Unique »).'),
            ),
            const SizedBox(height: VallySpace.s4),
            TextFormField(
              controller: _couleur,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Couleur (facultatif)'),
            ),

            // ─── L'achat ───
            const TitreSection('L’achat', taille: 16, marge: marge),
            if (_achatFige && article != null) ...[
              _HistoriqueAchats(
                article: article,
                devise: devise,
                onRetirer: _enCours ? null : _retirerRachat,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fournisseur,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Fournisseur habituel (facultatif)',
                  helperText: 'Proposé au prochain rachat.',
                ),
              ),
            ] else ...[
              TextFormField(
                controller: _quantite,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
                decoration: InputDecoration(
                  labelText: _modification ? 'Quantité achetée' : 'Combien en as-tu acheté ?',
                  helperText: _modification
                      ? [
                          if (dejaVendu > 0) 'Déjà vendues ou réservées : $dejaVendu.',
                          'Pour en ajouter, touche « Racheter » en haut.',
                        ].join(' ')
                      : null,
                  helperMaxLines: 2,
                ),
                validator: (v) {
                  final q = int.tryParse(v?.trim() ?? '');
                  if (q == null || q <= 0) return 'Saisis au moins 1 pièce.';
                  if (q < dejaVendu) return 'Tu en as déjà vendu ou réservé $dejaVendu.';
                  return null;
                },
              ),
              const SizedBox(height: VallySpace.s4),
              ChampMontant(
                controller: _prixAchat,
                label: 'Prix d’achat d’une pièce',
                aide: _modification
                    ? 'Tous frais compris. Les ventes déjà faites gardent leur prix.'
                    : 'Tous frais compris : transport, douane, emballage.',
                deviseReference: devise,
                tauxUsdVersCdf: _boutique.tauxUsdCdf,
              ),
              const SizedBox(height: VallySpace.s4),
              TextFormField(
                controller: _fournisseur,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Fournisseur (facultatif)'),
              ),
              const SizedBox(height: VallySpace.s4),
              InkWell(
                onTap: _choisirDate,
                borderRadius: BorderRadius.circular(VallyRadius.sm),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date d’achat',
                    suffixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(FormatDate.jourLong(_dateAppro)),
                ),
              ),
            ],

            // ─── La vente ───
            const TitreSection('La vente', taille: 16, marge: marge),
            ChampMontant(
              controller: _prixVente,
              label: 'Prix de vente habituel',
              aide: 'Proposé à chaque vente, tu pourras le changer.',
              deviseReference: devise,
              tauxUsdVersCdf: _boutique.tauxUsdCdf,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 10),
            ListenableBuilder(
              listenable: Listenable.merge([_prixAchat, _prixVente, _quantite]),
              builder: (context, _) => _Marge(
                // Article racheté : le coût est la moyenne tenue par la base.
                achat: _achatFige ? article!.prixAchat : _enReference(_prixAchat),
                vente: _enReference(_prixVente),
                devise: devise,
                quantite: _modification ? null : int.tryParse(_quantite.text.trim()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photo() {
    const taille = 120.0;
    final Widget image;
    if (_nouvellePhoto != null) {
      image = ClipRRect(
        borderRadius: BorderRadius.circular(VallyRadius.md),
        child: Image.memory(_nouvellePhoto!.octets, width: taille, height: taille, fit: BoxFit.cover),
      );
    } else {
      image = PhotoArticle(chemin: _photoRetiree ? null : _article?.photoChemin, taille: taille);
    }
    final aPhoto = _nouvellePhoto != null || (_article?.photoChemin != null && !_photoRetiree);
    final poids = _nouvellePhoto == null ? null : '${(_nouvellePhoto!.octets.length / 1024).round()} Ko';
    return Column(children: [
      GestureDetector(
        onTap: _compression ? null : _choisirPhoto,
        child: Stack(alignment: Alignment.center, children: [
          image,
          if (_compression)
            const SizedBox.square(dimension: 28, child: CircularProgressIndicator(strokeWidth: 3)),
        ]),
      ),
      TextButton.icon(
        onPressed: _compression ? null : _choisirPhoto,
        icon: const Icon(Icons.photo_camera_outlined),
        label: Text(_compression
            ? 'Compression…'
            : [aPhoto ? 'Changer la photo' : 'Ajouter une photo', ?poids].join(' · ')),
      ),
    ]);
  }

  FormFieldValidator<String> _obligatoire(String message) =>
      (v) => (v == null || v.trim().isEmpty) ? message : null;
}

/// « Tu as déjà cet article » : le nom tapé existe (sans tenir compte des
/// accents ni des majuscules). La taille est rappelée pour juger si c'est
/// le même ou un autre (même robe, autre taille = nouvel article).
class _DejaEnStock extends StatelessWidget {
  const _DejaEnStock({required this.nom, required this.articles, required this.onReapprovisionner});

  final String nom;
  final List<Article> articles;
  final void Function(List<Article> memes) onReapprovisionner;

  @override
  Widget build(BuildContext context) {
    final n = normaliserRecherche(nom.trim());
    if (n.length < 3) return const SizedBox.shrink();
    final memes = articles.where((a) => normaliserRecherche(a.nom.trim()) == n).toList();
    if (memes.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tailles = memes.map((a) => a.taille).toSet().toList();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 4),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(VallyRadius.sm),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(Icons.info_outline, size: 18, color: scheme.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Tu as déjà « ${memes.first.nom} » '
                '(${tailles.length > 1 ? 'tailles' : 'taille'} ${tailles.join(', ')}). '
                'Si c’est le même article, réapprovisionne-le plutôt que d’en créer un deuxième.',
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
              ),
            ),
          ]),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => onReapprovisionner(memes),
              child: const Text('Réapprovisionner'),
            ),
          ),
        ]),
      ),
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

/// Ce que tu gagneras par pièce au prix habituel, dit en une phrase
/// (et sur tout l'achat, pour un nouvel article).
class _Marge extends StatelessWidget {
  const _Marge({required this.achat, required this.vente, required this.devise, this.quantite});

  final double? achat;
  final double? vente;
  final Devise devise;

  /// Nouvel article : « soit 50 000 CDF si tu vends les 10 ».
  final int? quantite;

  @override
  Widget build(BuildContext context) {
    final a = achat, v = vente;
    if (a == null || v == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final vally = theme.extension<VallyColors>()!;
    final marge = v - a;
    final perte = marge < 0;
    final q = quantite;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(top: 1),
        child: Icon(perte ? Icons.warning_amber_rounded : Icons.trending_up,
            size: 18, color: perte ? vally.attention : vally.benefice),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: TexteAvecMontants(
          perte
              ? [
                  'Attention : tu perdrais ',
                  spanMontant(context, -marge, devise, sens: SensMontant.negatif, gras: true),
                  ' par pièce.',
                ]
              : [
                  'Tu gagneras ',
                  spanMontant(context, marge, devise, sens: SensMontant.positif, gras: true),
                  ' par pièce',
                  if (q != null && q > 1) ...[
                    ', soit ',
                    spanMontant(context, marge * q, devise, sens: SensMontant.positif),
                    ' si tu vends les $q',
                  ],
                  '.',
                ],
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
        ),
      ),
    ]);
  }
}

/// Où en est l'article, et le bouton pour le racheter.
class _EtatArticle extends StatelessWidget {
  const _EtatArticle({required this.article, required this.devise, required this.onRacheter});

  final Article article;
  final Devise devise;
  final VoidCallback? onRacheter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final vally = theme.extension<VallyColors>()!;
    final a = article;
    final alerte = a.epuise || a.stockFaible;
    final vendu = a.quantiteVendue;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                // Charte : l'ambre va toujours avec une icône.
                if (alerte) ...[
                  Icon(Icons.warning_amber_rounded, size: 20, color: vally.attention),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    a.epuise ? 'Épuisé' : 'Il en reste ${a.quantiteRestante}',
                    style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 20, color: alerte ? vally.attention : scheme.onSurface),
                  ),
                ),
              ]),
              const SizedBox(height: 2),
              Text(
                'sur ${a.quantiteAchetee} · $vendu vendue${vendu > 1 ? 's' : ''} ou réservée${vendu > 1 ? 's' : ''}',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12.5),
              ),
              if (a.quantiteRestante > 0) ...[
                const SizedBox(height: 2),
                TexteAvecMontants([
                  'En boutique pour ',
                  spanMontant(context, a.valeurStockRestant, devise),
                  ' au prix d’achat',
                ], style: theme.textTheme.bodySmall?.copyWith(fontSize: 12.5)),
              ],
            ]),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: onRacheter,
            // Rose pâle comme les autres actions secondaires.
            style: FilledButton.styleFrom(
              backgroundColor: scheme.primaryContainer,
              foregroundColor: scheme.onPrimaryContainer,
              minimumSize: const Size(64, 40),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Racheter'),
          ),
        ]),
      ),
    );
  }
}

/// Les achats de l'article, le plus récent d'abord, avec ce qu'une pièce
/// coûte en moyenne. Le dernier rachat peut être retiré (erreur de saisie).
class _HistoriqueAchats extends ConsumerWidget {
  const _HistoriqueAchats({required this.article, required this.devise, required this.onRetirer});

  final Article article;
  final Devise devise;
  final void Function(Achat)? onRetirer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final petit = theme.textTheme.bodySmall?.copyWith(fontSize: 12.5);
    return ref.watch(achatsArticleProvider(article.id)).when(
          skipLoadingOnRefresh: true,
          loading: () => const Squelette(hauteur: 140, rayon: VallyRadius.md),
          error: (e, _) => Text('Impossible de charger les achats de cet article.', style: petit),
          data: (achats) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(children: [
                for (final (i, x) in achats.indexed) ...[
                  if (i > 0) const TraitRegistre(retrait: _LigneAchat.retraitTexte),
                  _LigneAchat(
                    achat: x,
                    devise: devise,
                    // Seul le rachat le plus récent se retire.
                    onRetirer: i == 0 && x.estRachat && onRetirer != null ? () => onRetirer!(x) : null,
                  ),
                ],
                PiedDeCarte(libelle: 'Investi en tout', montant: article.totalApprovisionne, devise: devise),
              ]),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: TexteAvecMontants([
                'Une pièce te revient en moyenne à ',
                spanMontant(context, article.prixAchat, devise, gras: true),
                '. C’est ce coût qui compte pour le bénéfice des prochaines ventes.',
              ], maxLines: 3, style: theme.textTheme.bodySmall?.copyWith(fontSize: 12.5, height: 1.35)),
            ),
          ]),
        );
  }
}

class _LigneAchat extends StatelessWidget {
  const _LigneAchat({required this.achat, required this.devise, required this.onRetirer});

  /// Début du texte (16 + colonne de la date 44).
  static const retraitTexte = 60.0;
  static final _mois = DateFormat('MMM', 'fr');

  final Achat achat;
  final Devise devise;
  final VoidCallback? onRetirer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final x = achat;
    final petit = theme.textTheme.bodySmall?.copyWith(fontSize: 12.5);
    final details = [
      x.estRachat ? 'Rachat' : 'Premier achat',
      if (x.fournisseur != null && x.fournisseur!.trim().isNotEmpty) x.fournisseur!.trim(),
      if (x.deviseSaisie != null && x.tauxChange != null && x.montantSaisi != null)
        '${FormatMontant.formater(x.montantSaisi!, x.deviseSaisie!)} au taux de '
            '${FormatMontant.formater(x.tauxChange!, Devise.cdf)}',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // La date, comme dans un cahier.
        SizedBox(
          width: 44,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${x.date.day}',
                style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()])),
            Text(_mois.format(x.date), style: theme.textTheme.bodySmall),
          ]),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: TexteAvecMontants([
                  '${pieces(x.quantite)} à ',
                  spanMontant(context, x.prixAchat, devise),
                ], style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 12),
              MontantTexte(x.total,
                  devise: devise, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 2),
            Text(details, maxLines: 2, overflow: TextOverflow.ellipsis, style: petit),
            if (onRetirer != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onRetirer,
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.error,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(48, 36),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.undo, size: 16),
                  label: const Text('Retirer ce rachat'),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}
