import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/routes.dart';
import '../../../core/widgets/elements.dart';
import '../../../core/widgets/page_erreur.dart';
import '../../../core/widgets/page_vide.dart';
import '../../../theme/app_theme.dart';
import '../../boutique/data/boutique_repository.dart';
import '../data/stock_repository.dart';
import '../domain/article.dart';
import 'widgets/article_tuile.dart';
import 'widgets/carte_resume_stock.dart';

/// Onglet Stock : valeur du stock, filtres adulte / enfant et catégorie.
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final articles = ref.watch(articlesProvider);
    final devise = ref.watch(boutiqueActiveProvider).devise;

    return Scaffold(
      appBar: AppBar(
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
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.nouvelArticle),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter un article'),
      ),
      body: articles.when(
        skipLoadingOnRefresh: true,
        loading: () => const ListeSquelette(),
        error: (e, _) =>
            PageErreur(erreur: e, onReessayer: () => ref.invalidate(articlesProvider)),
        data: (tous) {
          if (tous.isEmpty) {
            return const PageVide(
              icone: Icons.checkroom_outlined,
              titre: 'Aucun article pour l’instant',
              message: 'Ajoute ton premier article pour suivre ton stock '
                  'et ce que tu as investi.',
            );
          }
          final categories = categoriesDe(tous.where(_public.garde));
          final categorie = categories.contains(_categorie) ? _categorie : null;
          final visibles = filtrerArticles(tous,
              recherche: _recherche, categorie: categorie, public: _public);
          final aEnfants = tous.any((a) => a.pourEnfant);

          return RefreshIndicator(
            onRefresh: () => ref.refresh(articlesProvider.future),
            child: CustomScrollView(slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: VallySpace.s4),
                sliver: SliverToBoxAdapter(
                  child: CarteResumeStock(resume: ResumeStock.depuis(tous), devise: devise),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: VallySpace.s2)),
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
                        textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(VallySpace.s4, VallySpace.s2, VallySpace.s4, 96),
                  sliver: SliverToBoxAdapter(
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(children: [
                        for (final (i, a) in visibles.indexed) ...[
                          if (i > 0) const Divider(indent: 72),
                          ArticleTuile(
                            article: a,
                            devise: devise,
                            onTap: () => context.push(Routes.article(a.id)),
                          ),
                        ],
                      ]),
                    ),
                  ),
                ),
            ]),
          );
        },
      ),
    );
  }
}
