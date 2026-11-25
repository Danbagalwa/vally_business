import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format/montant.dart';
import '../../../core/rayon.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/carnet.dart';
import '../../../core/widgets/elements.dart';
import '../../../core/widgets/page_erreur.dart';
import '../../../core/widgets/page_vide.dart';
import '../../../theme/app_theme.dart';
import '../../boutique/data/boutique_repository.dart';
import '../data/stock_repository.dart';
import '../domain/article.dart';
import 'widgets/article_tuile.dart';
import 'widgets/choix_ajout.dart';
import 'widgets/feuille_rachat.dart';

/// Onglet Stock : l'inventaire. Une phrase pour le résumé, les articles
/// épuisés ou presque en premier, puis le reste de la boutique.
class StockPage extends ConsumerStatefulWidget {
  const StockPage({super.key});

  @override
  ConsumerState<StockPage> createState() => _StockPageState();
}

class _StockPageState extends ConsumerState<StockPage> {
  String _recherche = '';
  bool _rechercheOuverte = false;
  String? _categorie;
  Public _public = Public.tous;

  /// « + » : deux chemins séparés, nouvel article ou réapprovisionnement.
  /// Sans aucun article, il n'y a rien à racheter : directement le nouvel article.
  Future<void> _ajouter() async {
    final aDesArticles = (ref.read(articlesRayonProvider).value ?? const []).isNotEmpty;
    if (!aDesArticles) {
      context.push(Routes.nouvelArticle);
      return;
    }
    final choix = await choisirAjout(context);
    if (!mounted || choix == null) return;
    context.push(choix == ChoixAjout.nouvelArticle ? Routes.nouvelArticle : Routes.reapprovisionner);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final articles = ref.watch(articlesRayonProvider);
    final devise = ref.watch(boutiqueActiveProvider).devise;

    return Scaffold(
      appBar: AppBar(
        bottom: const BarreRayon(),
        title: _rechercheOuverte
            ? TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _recherche = v),
                decoration: const InputDecoration(
                    hintText: 'Rechercher un article', border: InputBorder.none,
                    enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                    filled: false),
              )
            : const Text('Stock'),
        actions: [
          IconButton(
            tooltip: _rechercheOuverte ? 'Fermer la recherche' : 'Rechercher',
            icon: Icon(_rechercheOuverte ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _rechercheOuverte = !_rechercheOuverte;
              _recherche = '';
            }),
          ),
          BoutonAjout(libelle: 'Ajouter', tooltip: 'Ajouter au stock', onPressed: _ajouter),
        ],
      ),
      body: articles.when(
        skipLoadingOnRefresh: true,
        loading: () => const ListeSquelette(avecResume: false, avecPhrase: true, avecFiltres: true),
        error: (e, _) =>
            PageErreur(erreur: e, onReessayer: () => ref.invalidate(articlesProvider)),
        data: (tous) {
          if (tous.isEmpty) {
            final parfums = ref.read(rayonProvider) == Rayon.parfums;
            return PageVide(
              icone: parfums ? Icons.spa_outlined : Icons.checkroom_outlined,
              titre: parfums ? 'Aucun parfum pour l’instant' : 'Aucun article pour l’instant',
              message: parfums
                  ? 'Touche + pour ajouter ton premier parfum : il sera compté à part des habits.'
                  : 'Ajoute ton premier article pour suivre ton stock et ce que tu as investi.',
            );
          }
          final categories = categoriesDe(tous.where(_public.garde));
          final categorie = categories.contains(_categorie) ? _categorie : null;
          final visibles = filtrerArticles(tous,
              recherche: _recherche, categorie: categorie, public: _public);
          final aEnfants = tous.any((a) => a.pourEnfant);
          final aSurveiller = visibles.where((a) => a.epuise || a.stockFaible).toList();
          final enBoutique = visibles.where((a) => !a.epuise && !a.stockFaible).toList();

          return RefreshIndicator(
            onRefresh: () => ref.refresh(articlesProvider.future),
            child: CustomScrollView(slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(VallySpace.s4, 2, VallySpace.s4, 10),
                sliver: SliverToBoxAdapter(
                  child: PhraseAvecChiffres(phraseStock(ResumeStock.depuis(tous), devise)),
                ),
              ),
              SliverToBoxAdapter(
                child: RangeeFiltres(children: [
                  if (aEnfants) ...[
                    for (final p in Public.values)
                      FiltrePastille(
                        libelle: p.libelle,
                        icone: p == Public.enfant ? Icons.child_care : null,
                        actif: _public == p,
                        onTap: () => setState(() => _public = p),
                      ),
                    const SizedBox(height: 24, child: VerticalDivider(width: 8)),
                  ],
                  if (categories.length > 1)
                    for (final c in categories)
                      FiltrePastille(
                        libelle: c,
                        actif: categorie == c,
                        onTap: () => setState(() => _categorie = categorie == c ? null : c),
                      ),
                ]),
              ),
              if (visibles.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.all(VallySpace.s6),
                  sliver: SliverToBoxAdapter(
                    child: Text('Aucun article ne correspond.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(VallySpace.s4, 0, VallySpace.s4, 28),
                  sliver: SliverList.list(children: [
                    if (aSurveiller.isNotEmpty) ...[
                      EnTeteGroupe(
                        titre: 'Épuisés ou presque',
                        detail: Text('${aSurveiller.length}'),
                      ),
                      _Inventaire(
                        articles: aSurveiller,
                        devise: devise,
                        onRacheter: (a) => racheterArticle(context, ref, a),
                      ),
                    ],
                    if (enBoutique.isNotEmpty) ...[
                      // Un seul groupe : pas besoin de titre.
                      if (aSurveiller.isNotEmpty)
                        EnTeteGroupe(
                          titre: 'En boutique',
                          detail: Text('${enBoutique.length}'),
                        )
                      else
                        const SizedBox(height: 10),
                      _Inventaire(articles: enBoutique, devise: devise),
                    ],
                  ]),
                ),
            ]),
          );
        },
      ),
    );
  }
}

/// Une carte-registre d'articles, une ligne par article.
class _Inventaire extends StatelessWidget {
  const _Inventaire({required this.articles, required this.devise, this.onRacheter});

  final List<Article> articles;
  final Devise devise;

  /// Raccourci « Racheter » sur chaque ligne (articles épuisés ou presque).
  final void Function(Article)? onRacheter;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        for (final (i, a) in articles.indexed) ...[
          // Le trait commence au texte, après la photo.
          if (i > 0) const TraitRegistre(retrait: 76),
          ArticleTuile(
            article: a,
            devise: devise,
            onTap: () => context.push(Routes.article(a.id)),
            onRacheter: onRacheter == null ? null : () => onRacheter!(a),
          ),
        ],
      ]),
    );
  }
}
