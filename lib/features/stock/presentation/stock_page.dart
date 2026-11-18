import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/routes.dart';
import '../../../core/widgets/menu_compte.dart';
import '../../../core/widgets/page_erreur.dart';
import '../../../core/widgets/page_vide.dart';
import '../../../theme/app_theme.dart';
import '../../boutique/data/boutique_repository.dart';
import '../data/stock_repository.dart';
import '../domain/article.dart';
import 'widgets/article_tuile.dart';
import 'widgets/carte_resume_stock.dart';

/// Onglet Stock : totaux, recherche, filtre par catégorie, liste.
class StockPage extends ConsumerStatefulWidget {
  const StockPage({super.key});

  @override
  ConsumerState<StockPage> createState() => _StockPageState();
}

class _StockPageState extends ConsumerState<StockPage> {
  final _recherche = TextEditingController();
  String? _categorie;

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final articles = ref.watch(articlesProvider);
    final devise = ref.watch(boutiqueActiveProvider).devise;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock'),
        actions: const [MenuCompte()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.nouvelArticle),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter un article'),
      ),
      body: articles.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => PageErreur(
          erreur: e,
          onReessayer: () => ref.invalidate(articlesProvider),
        ),
        data: (tous) {
          if (tous.isEmpty) {
            return const PageVide(
              icone: Icons.inventory_2_outlined,
              titre: 'Aucun article pour l’instant',
              message: 'Ajoute ton premier article pour suivre ton stock '
                  'et ce que tu as investi.',
            );
          }
          final categories = categoriesDe(tous);
          final categorie = categories.contains(_categorie) ? _categorie : null;
          final visibles = filtrerArticles(tous,
              recherche: _recherche.text, categorie: categorie);

          return RefreshIndicator(
            onRefresh: () => ref.refresh(articlesProvider.future),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                      VallySpace.s4, VallySpace.s2, VallySpace.s4, 0),
                  sliver: SliverList.list(children: [
                    CarteResumeStock(
                        resume: ResumeStock.depuis(tous), devise: devise),
                    const SizedBox(height: VallySpace.s4),
                    TextField(
                      controller: _recherche,
                      onChanged: (_) => setState(() {}),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Rechercher un article',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _recherche.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Effacer',
                                icon: const Icon(Icons.close),
                                onPressed: () =>
                                    setState(() => _recherche.clear()),
                              ),
                      ),
                    ),
                    const SizedBox(height: VallySpace.s2),
                  ]),
                ),
                if (categories.length > 1)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 48,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                            horizontal: VallySpace.s4),
                        children: [
                          _Filtre(
                            libelle: 'Tous',
                            actif: categorie == null,
                            onTap: () => setState(() => _categorie = null),
                          ),
                          for (final c in categories)
                            _Filtre(
                              libelle: c,
                              actif: categorie == c,
                              onTap: () => setState(() => _categorie = c),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (visibles.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.all(VallySpace.s6),
                    sliver: SliverToBoxAdapter(
                      child: Text('Aucun article ne correspond.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ),
                  )
                else
                  SliverPadding(
                    // Marge basse : la liste ne passe pas sous le bouton « + ».
                    padding: const EdgeInsets.fromLTRB(
                        VallySpace.s4, VallySpace.s2, VallySpace.s4, 96),
                    sliver: SliverList.separated(
                      itemCount: visibles.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: VallySpace.s2),
                      itemBuilder: (context, i) => ArticleTuile(
                        article: visibles[i],
                        devise: devise,
                        onTap: () =>
                            context.push(Routes.article(visibles[i].id)),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Filtre extends StatelessWidget {
  const _Filtre({required this.libelle, required this.actif, required this.onTap});

  final String libelle;
  final bool actif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: VallySpace.s2),
      child: FilterChip(
        label: Text(libelle),
        selected: actif,
        showCheckmark: false,
        onSelected: (_) => onTap(),
      ),
    );
  }
}
